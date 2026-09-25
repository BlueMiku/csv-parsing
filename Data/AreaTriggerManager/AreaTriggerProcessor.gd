class_name AreaTriggerProcessor
extends RefCounted

## Processor khusus untuk AreaTriggerStories CSV
## Mendukung dua format:
##   v1 (legacy)  : Day di col 0, tidak ada item_story
##   v2           : Day di col 0, ada kolom item_story setelah item_requirement
##   +Keterangan  : kolom Keterangan di col 0, Day bergeser ke col 1

var _errors: Array[String] = []

# Format flags — di-set saat process() membaca header
var _k: int = 0   # 1 jika ada kolom Keterangan di col 0
var _o: int = 0   # 1 jika ada kolom item_story


## Proses file CSV dan kembalikan Dictionary {success, json_string, rows, rows_count, skipped_count, errors}
func process(csv_path: String, area_name: String) -> Dictionary:
	_errors.clear()

	if area_name.strip_edges().is_empty():
		return _fail("Area name tidak boleh kosong.")

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	var raw_lines: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty():
			raw_lines.append(line)
	file.close()

	if raw_lines.size() < 2:
		return _fail("CSV tidak memiliki cukup baris (hanya %d baris)." % raw_lines.size())

	# Deteksi format dari header
	var header_cols := _parse_csv_line(raw_lines[0])
	_k = 1 if (header_cols.size() > 0 and header_cols[0].strip_edges().to_lower() == "keterangan") else 0
	_o = 0
	for col in header_cols:
		if col.strip_edges().to_lower() == "item_story":
			_o = 1
			break

	var rows: Array = []
	var skipped := 0
	for i in range(1, raw_lines.size()):
		var cols := _parse_csv_line(raw_lines[i])
		if cols.is_empty() or not cols[_k].strip_edges().is_valid_int():
			skipped += 1
			continue
		rows.append(_parse_row(cols))

	var json_str := _build_json(area_name, rows)

	return {
		"success": true,
		"json_string": json_str,
		"rows": rows,
		"rows_count": rows.size(),
		"skipped_count": skipped,
		"errors": _errors.duplicate()
	}


## Proses dan langsung simpan ke file output, merge jika sudah ada
func process_to_file(csv_path: String, area_name: String, output_path: String) -> Dictionary:
	var parse_result := process(csv_path, area_name)
	if not parse_result.get("success", false):
		return parse_result

	var rows: Array = parse_result.get("rows", [])

	var result_dict: Dictionary = {}
	var merge_note := ""
	if FileAccess.file_exists(output_path):
		var existing_file := FileAccess.open(output_path, FileAccess.READ)
		if existing_file:
			var json := JSON.new()
			if json.parse(existing_file.get_as_text()) == OK:
				var parsed = json.get_data()
				if parsed is Dictionary:
					result_dict = parsed
					merge_note = " (merged)" if result_dict.has(area_name) else " (added)"
			else:
				merge_note = " (existing file unreadable — overwritten)"
			existing_file.close()

	result_dict[area_name] = rows
	var json_str := _build_json_multi(result_dict)

	var out_file := FileAccess.open(output_path, FileAccess.WRITE)
	if out_file == null:
		return _fail("Gagal menulis file output: " + output_path)

	out_file.store_string(json_str)
	out_file.close()

	return {
		"success": true,
		"json_string": json_str,
		"rows_count": rows.size(),
		"skipped_count": parse_result.get("skipped_count", 0),
		"merge_note": merge_note,
		"output_path": output_path,
		"errors": _errors.duplicate()
	}


func get_errors() -> Array[String]:
	return _errors


func _parse_row(cols: Array) -> Dictionary:
	var k := _k
	var o := _o

	while cols.size() < k + 43 + o:
		cols.append("")

	var row := {}
	row["day"]               = int(cols[k + 0].strip_edges())
	row["priority"]          = int(cols[k + 1].strip_edges()) if cols[k + 1].strip_edges().is_valid_int() else 0
	row["expired_on"]        = _str_or_null(cols[k + 2])
	row["start_at"]          = _str_or_null(cols[k + 3])
	row["item_requirement"]  = _parse_item_req(cols[k + 4])

	# item_story (v2 only)
	var item_story := false
	if o == 1:
		item_story = cols[k + 5].strip_edges().to_lower() == "true"
	row["item_story"] = item_story

	var no_travel: bool = cols[k + 5 + o].strip_edges().to_lower() == "true"
	row["no_travel"]         = no_travel
	row["no_travel_message"] = _str_or_null(cols[k + 6 + o])

	if item_story and no_travel:
		_errors.append("Hari %d: item_story dan no_travel keduanya TRUE — hanya satu yang boleh aktif." % row["day"])

	# auto_content (col k+7+o = chapter, k+8+o = level)
	var auto_ch: Variant = _str_or_null(cols[k + 7 + o])
	if auto_ch != null:
		var lv_s: String = cols[k + 8 + o].strip_edges()
		row["auto_content"] = {
			"chapter":        auto_ch,
			"level_required": int(lv_s) if lv_s.is_valid_int() else -1
		}
	else:
		row["auto_content"] = null

	# NPC slots — base k+9+o, 3 kolom tiap slot
	var npc_slots := {}
	for n in range(1, 7):
		var base := k + 9 + o + (n - 1) * 3
		var scene:   Variant = _str_or_null(cols[base])
		var lv_s:    String  = cols[base + 1].strip_edges()
		var content: Variant = _str_or_null(cols[base + 2])
		if scene != null or content != null:
			npc_slots[str(n)] = {
				"scene":          scene,
				"level_required": int(lv_s) if lv_s.is_valid_int() else -1,
				"content":        content
			}
	row["npc_slots"] = npc_slots

	# Object slots — base k+27+o, 3 kolom tiap slot
	var object_slots := {}
	var obj_keys := ["A", "B", "C", "D", "E"]
	for n in range(obj_keys.size()):
		var base    := k + 27 + o + n * 3
		var scene:   Variant = _str_or_null(cols[base])
		var lv_s:    String  = cols[base + 1].strip_edges()
		var content: Variant = _str_or_null(cols[base + 2])
		if lv_s != "" or content != null:
			object_slots[obj_keys[n]] = {
				"scene":          scene,
				"level_required": int(lv_s) if lv_s.is_valid_int() else -1,
				"content":        content
			}
	row["object_slots"] = object_slots

	return row


func _parse_item_req(s: String):
	var t := s.strip_edges()
	if t.is_empty():
		return null
	var parts := t.split(",")
	if parts.size() != 3:
		_errors.append("item_requirement format tidak valid: \"%s\" (diharapkan \"type,id,qty\")" % t)
		return null
	return {
		"type": parts[0].strip_edges(),
		"id":   int(parts[1].strip_edges()),
		"qty":  int(parts[2].strip_edges())
	}


func _parse_csv_line(line: String) -> Array:
	var result := []
	var current := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current += '"'
				i += 2
				continue
			in_quotes = !in_quotes
		elif c == ',' and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += c
		i += 1
	result.append(current)
	return result


func _str_or_null(s: String):
	var t := JsonUtils.unescape_literal_control_chars(s.strip_edges())
	return t if not t.is_empty() else null


func _build_json(area_name: String, rows: Array) -> String:
	return _build_json_multi({area_name: rows})


func _build_json_multi(areas: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("{")

	var area_keys := areas.keys()
	area_keys.sort()
	for a_idx in range(area_keys.size()):
		var area_name: String = area_keys[a_idx]
		var rows: Array = areas[area_name]
		var area_comma := "," if a_idx < area_keys.size() - 1 else ""

		lines.append("\t\"%s\": [" % _escape(area_name))
		lines.append_array(_stringify_area_rows(rows))
		lines.append("\t]%s" % area_comma)

	lines.append("}")
	return "\n".join(lines)


func _stringify_area_rows(rows: Array) -> PackedStringArray:
	var lines: PackedStringArray = []
	var key_order := [
		"auto_content",
		"day",
		"expired_on",
		"item_requirement",
		"item_story",
		"no_travel",
		"no_travel_message",
		"npc_slots",
		"object_slots",
		"priority",
		"start_at"
	]

	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var row_comma := "," if i < rows.size() - 1 else ""
		lines.append("\t\t{")

		for k_idx in range(key_order.size()):
			var key: String = key_order[k_idx]
			if not row.has(key):
				continue
			var val = row[key]
			var field_comma := _has_next_key(row, key_order, k_idx)
			lines.append("\t\t\t\"%s\": %s%s" % [key, _val_to_json(val, 3), field_comma])

		lines.append("\t\t}%s" % row_comma)

	return lines


func _has_next_key(row: Dictionary, key_order: Array, current_idx: int) -> String:
	for i in range(current_idx + 1, key_order.size()):
		if row.has(key_order[i]):
			return ","
	return ""


func _val_to_json(val, indent_level: int) -> String:
	if val == null:
		return "null"
	elif val is bool:
		return "true" if val else "false"
	elif val is int:
		return str(val)
	elif val is float:
		return str(int(val)) if int(val) == val else str(val)
	elif val is String:
		return "\"%s\"" % _escape(val)
	elif val is Array:
		return _array_to_json(val, indent_level)
	elif val is Dictionary:
		return _dict_to_json(val, indent_level)
	return "\"%s\"" % str(val)


func _array_to_json(arr: Array, indent_level: int) -> String:
	if arr.is_empty():
		return "[]"
	var parts := PackedStringArray()
	for item in arr:
		parts.append(_val_to_json(item, indent_level + 1))
	return "[%s]" % ", ".join(parts)


func _dict_to_json(dict: Dictionary, indent_level: int) -> String:
	var close_indent := "\t".repeat(indent_level)
	if dict.is_empty():
		return "{\n\n%s}" % close_indent
	var indent := "\t".repeat(indent_level + 1)
	var parts := PackedStringArray()
	var keys := dict.keys()
	keys.sort()
	for key in keys:
		parts.append("%s\"%s\": %s" % [indent, key, _val_to_json(dict[key], indent_level + 1)])
	return "{\n%s\n%s}" % [",\n".join(parts), close_indent]


func _escape(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
