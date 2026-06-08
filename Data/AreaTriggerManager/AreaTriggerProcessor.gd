class_name AreaTriggerProcessor
extends RefCounted

## Processor khusus untuk AreaTriggerStories CSV
## Format CSV: data spawn NPC dan Object di area trigger berdasarkan hari

# Column index groups: [scene_col, lv_col, content_col]
const NPC_SLOT_COLS := {
	"1": [9,  10, 11],
	"2": [12, 13, 14],
	"3": [15, 16, 17],
	"4": [18, 19, 20],
	"5": [21, 22, 23],
	"6": [24, 25, 26],
}

const OBJECT_SLOT_COLS := {
	"A": [27, 28, 29],
	"B": [30, 31, 32],
	"C": [33, 34, 35],
	"D": [36, 37, 38],
	"E": [39, 40, 41],
}

const MIN_COLS := 42

var _errors: Array[String] = []


## Proses file CSV dan kembalikan JSON string dengan area_name sebagai root key
## Mengembalikan Dictionary {success, json_string, rows_count, skipped_count, errors}
func process(csv_path: String, area_name: String) -> Dictionary:
	_errors.clear()

	if area_name.strip_edges().is_empty():
		return _fail("Area name tidak boleh kosong.")

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	# Baca semua baris
	var raw_lines: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty():
			raw_lines.append(line)
	file.close()

	if raw_lines.size() < 2:
		return _fail("CSV tidak memiliki cukup baris (hanya %d baris)." % raw_lines.size())

	# Skip header (index 0), proses baris data
	var rows: Array = []
	var skipped := 0
	for i in range(1, raw_lines.size()):
		var cols := _parse_csv_line(raw_lines[i])
		# Skip baris yang kolom Day-nya bukan integer valid (baris komentar/catatan)
		if cols.is_empty() or not cols[0].strip_edges().is_valid_int():
			skipped += 1
			continue
		rows.append(_parse_row(cols))

	# Build JSON string (single-area, untuk preview)
	var json_str := _build_json(area_name, rows)

	return {
		"success": true,
		"json_string": json_str,
		"rows": rows,
		"rows_count": rows.size(),
		"skipped_count": skipped,
		"errors": _errors.duplicate()
	}


## Proses dan langsung simpan ke file output.
## Jika file output sudah ada, data area baru akan di-merge ke dalamnya.
func process_to_file(csv_path: String, area_name: String, output_path: String) -> Dictionary:
	var parse_result := process(csv_path, area_name)
	if not parse_result.get("success", false):
		return parse_result

	var rows: Array = parse_result.get("rows", [])

	# Merge into existing JSON jika file sudah ada
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

	# Build JSON dari result gabungan (bisa berisi lebih dari 1 area)
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


## GET error messages
func get_errors() -> Array[String]:
	return _errors


func _parse_row(cols: Array) -> Dictionary:
	# Pastikan cukup kolom
	while cols.size() < MIN_COLS:
		cols.append("")

	var row := {}
	row["day"]               = int(cols[0].strip_edges())
	row["priority"]          = int(cols[1].strip_edges()) if cols[1].strip_edges().is_valid_int() else 0
	row["expired_on"]        = _str_or_null(cols[2])
	row["start_at"]          = _str_or_null(cols[3])
	row["item_requirement"]  = _parse_item_req(cols[4])
	row["no_travel"]         = cols[5].strip_edges().to_lower() == "true"
	row["no_travel_message"] = _str_or_null(cols[6])

	# auto_content (col 7 = chapter name, col 8 = level requirement)
	var auto_ch: Variant = _str_or_null(cols[7])
	if auto_ch != null:
		var lv_s: String = cols[8].strip_edges()
		row["auto_content"] = {
			"chapter":        auto_ch,
			"level_required": int(lv_s) if lv_s.is_valid_int() else -1
		}
	else:
		row["auto_content"] = null

	# NPC slots (scene / level_required / content)
	var npc_slots := {}
	for slot_key in NPC_SLOT_COLS:
		var idx: Array = NPC_SLOT_COLS[slot_key]
		var scene:   Variant = _str_or_null(cols[idx[0]])
		var lv_s:    String  = cols[idx[1]].strip_edges()
		var content: Variant = _str_or_null(cols[idx[2]])
		if scene != null or content != null:
			npc_slots[slot_key] = {
				"scene":          scene,
				"level_required": int(lv_s) if lv_s.is_valid_int() else -1,
				"content":        content
			}
	row["npc_slots"] = npc_slots

	# Object slots (scene / level_required / content)
	# scene boleh kosong (posisi ditentukan oleh background), tapi tetap ditulis jika ada data
	var object_slots := {}
	for slot_key in OBJECT_SLOT_COLS:
		var idx: Array = OBJECT_SLOT_COLS[slot_key]
		var scene:   Variant = _str_or_null(cols[idx[0]])
		var lv_s:    String  = cols[idx[1]].strip_edges()
		var content: Variant = _str_or_null(cols[idx[2]])
		if lv_s != "" or content != null:
			object_slots[slot_key] = {
				"scene":          scene,
				"level_required": int(lv_s) if lv_s.is_valid_int() else -1,
				"content":        content
			}
	row["object_slots"] = object_slots

	return row


## Parse field item_requirement: "type,id,qty" → dict, atau null jika kosong
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


## Parser CSV line sederhana dengan dukungan quoted fields
func _parse_csv_line(line: String) -> Array:
	var result := []
	var current := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == '"':
			# "" di dalam quoted field → literal quote
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


## String atau null jika kosong
func _str_or_null(s: String):
	var t := s.strip_edges()
	return t if not t.is_empty() else null


## Build JSON single-area: { "area_name": [ ...rows... ] }
func _build_json(area_name: String, rows: Array) -> String:
	return _build_json_multi({area_name: rows})


## Build JSON multi-area: { "area1": [...], "area2": [...], ... }
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


## Stringify rows menjadi array lines dengan indentasi 2 level
func _stringify_area_rows(rows: Array) -> PackedStringArray:
	var lines: PackedStringArray = []
	var key_order := [
		"auto_content",
		"day",
		"expired_on",
		"item_requirement",
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


## Cek apakah ada key valid setelah index ini, return "," atau ""
func _has_next_key(row: Dictionary, key_order: Array, current_idx: int) -> String:
	for i in range(current_idx + 1, key_order.size()):
		if row.has(key_order[i]):
			return ","
	return ""


## Konversi nilai GDScript ke JSON string
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
