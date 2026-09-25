class_name CutsceneTriggerProcessor
extends RefCounted

## Processor untuk CutsceneTriggerReqs CSV
## Format: day, chapter_to_trigger, priority, expired_on, start_at,
##         start_at_delay, area_lv_requirement, item_requirement_1/2/3
## Kolom dideteksi dari header (header-mapped), bukan posisi tetap.

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	var csv_text := file.get_as_text()
	file.close()

	var lines := csv_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")

	if lines.size() < 2:
		return _fail("CSV harus memiliki header row dan setidaknya satu baris data.")

	# Build header → index map (case-insensitive, strip whitespace)
	var raw_headers := _parse_line(lines[0])
	var hmap: Dictionary = {}
	for i in range(raw_headers.size()):
		hmap[raw_headers[i].strip_edges().to_lower()] = i

	var rows: Array = []
	var skipped: int = 0

	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var cols := _parse_line(line)
		var row := _build_row(cols, hmap, i + 1)
		if row.is_empty():
			skipped += 1
			continue
		rows.append(row)

	var json_str := JSON.stringify(rows, "\t")

	return {
		"success": true,
		"json_string": json_str,
		"rows": rows,
		"rows_count": rows.size(),
		"skipped_count": skipped,
		"errors": _errors.duplicate()
	}


func process_to_file(csv_path: String, output_path: String) -> Dictionary:
	var result := process(csv_path)
	if not result.get("success", false):
		return result

	var out_file := FileAccess.open(output_path, FileAccess.WRITE)
	if out_file == null:
		return _fail("Gagal menulis file output: " + output_path)

	out_file.store_string(result["json_string"])
	out_file.close()

	result["output_path"] = output_path
	return result


func get_errors() -> Array[String]:
	return _errors


func _build_row(cols: Array, h: Dictionary, row_num: int) -> Dictionary:
	# Skip baris tanpa chapter_to_trigger
	var chapter := _str(cols, h, "chapter_to_trigger")
	if chapter.is_empty():
		return {}

	return {
		"day":                  _int(cols, h, "day", -1),
		"chapter_to_trigger":   chapter,
		"priority":             _int(cols, h, "priority", 0),
		"expired_on":           _nullable(cols, h, "expired_on"),
		"start_at":             _nullable(cols, h, "start_at"),
		"start_at_delay":       _int(cols, h, "start_at_delay", 0),
		"area_lv_requirement":  _parse_area_lv_req(cols, h, "area_lv_requirement", row_num),
		"item_requirement_1":   _parse_item_req(cols, h, "item_requirement_1", row_num),
		"item_requirement_2":   _parse_item_req(cols, h, "item_requirement_2", row_num),
		"item_requirement_3":   _parse_item_req(cols, h, "item_requirement_3", row_num),
	}


## Format: "area_name,level" → { "area": last_segment, "level": int }
func _parse_area_lv_req(cols: Array, h: Dictionary, key: String, row_num: int):
	var raw := _str(cols, h, key)
	if raw.is_empty():
		return null
	var parts := raw.split(",")
	if parts.size() != 2:
		_errors.append("Baris %d: '%s' format tidak valid '%s' (diharapkan \"area_name,level\")" % [row_num, key, raw])
		return null
	var full_area := parts[0].strip_edges()
	var lvl_str   := parts[1].strip_edges()
	if not lvl_str.is_valid_int():
		_errors.append("Baris %d: '%s' level bukan integer di '%s'" % [row_num, key, raw])
		return null
	# Ambil segmen terakhir: "background_izakaya_storefront" → "storefront"
	var segments := full_area.split("_")
	var area_key := segments[segments.size() - 1]
	return {
		"area":  area_key,
		"level": lvl_str.to_int()
	}


## Format: "type,id,qty" → { "type", "id", "qty" }
func _parse_item_req(cols: Array, h: Dictionary, key: String, row_num: int):
	var raw := _str(cols, h, key)
	if raw.is_empty():
		return null
	var parts := raw.split(",")
	if parts.size() != 3:
		_errors.append("Baris %d: '%s' format tidak valid '%s' (diharapkan \"type,id,qty\")" % [row_num, key, raw])
		return null
	var id_str  := parts[1].strip_edges()
	var qty_str := parts[2].strip_edges()
	if not id_str.is_valid_int() or not qty_str.is_valid_int():
		_errors.append("Baris %d: '%s' id/qty bukan integer di '%s'" % [row_num, key, raw])
		return null
	return {
		"type": parts[0].strip_edges(),
		"id":   id_str.to_int(),
		"qty":  qty_str.to_int()
	}


# ── Column helpers ────────────────────────────────────────────────────────────

func _str(cols: Array, h: Dictionary, key: String) -> String:
	if not h.has(key): return ""
	var idx: int = h[key]
	if idx >= cols.size(): return ""
	return JsonUtils.unescape_literal_control_chars(cols[idx].strip_edges())

func _nullable(cols: Array, h: Dictionary, key: String):
	var v := _str(cols, h, key)
	return null if v.is_empty() else v

func _int(cols: Array, h: Dictionary, key: String, default: int) -> int:
	var s := _str(cols, h, key)
	if s.is_empty() or not s.is_valid_int(): return default
	return s.to_int()


# ── CSV parser ────────────────────────────────────────────────────────────────

## Escaped-quote pairs ("") need BOTH characters consumed as one unit — a
## plain `for i in range(...)` loop can't skip an index, so the previous
## version appended the literal quote for the first "" but then reprocessed
## the second quote as an independent (wrong) toggle, desyncing in_quotes
## for the rest of the line whenever a field contained escaped quotes. Any
## comma after that point got read as a real delimiter instead of literal
## content, corrupting the field and every column after it on that row.
func _parse_line(line: String) -> Array:
	var result: Array = []
	var field := ""
	var in_quotes := false
	var i := 0
	var length := line.length()
	while i < length:
		var c := line[i]
		if c == '"':
			if in_quotes and i + 1 < length and line[i + 1] == '"':
				field += '"'
				i += 1  # also consume the second quote of the escaped pair
			else:
				in_quotes = !in_quotes
		elif c == ',' and not in_quotes:
			result.append(field)
			field = ""
		else:
			field += c
		i += 1
	result.append(field)
	return result


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
