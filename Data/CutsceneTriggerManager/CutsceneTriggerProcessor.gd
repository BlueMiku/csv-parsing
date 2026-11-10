class_name CutsceneTriggerProcessor
extends RefCounted

## Processor untuk CutsceneTriggerReqs CSV
## Format: Moment, day, chapter_to_trigger, priority, expired_on, start_at_1,
##         start_at_2, start_at_delay, area_lv_requirement, item_requirement_1/2/3
## Kolom dideteksi dari header (header-mapped), bukan posisi tetap.
## Output: { "<Moment>": [ { row }, ... ], ... } — baris dikelompokkan per nilai
## kolom Moment (mis. NewDay, BeforeOpen, AfterClose) sesuai urutan kemunculan
## pertama di CSV; Moment tidak ikut ditulis di dalam objek row.

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	# get_csv_line() membaca satu record CSV utuh, termasuk sel dengan newline di
	# dalam kutip (mis. kolom catatan multi-baris), jadi tidak perlu split per baris.
	var raw_headers := file.get_csv_line()
	if raw_headers.size() > 0:
		raw_headers[0] = raw_headers[0].trim_prefix("﻿")  # buang BOM jika ada

	# Build header → index map (case-insensitive, strip whitespace)
	var hmap: Dictionary = {}
	for i in range(raw_headers.size()):
		hmap[raw_headers[i].strip_edges().to_lower()] = i

	if not hmap.has("moment"):
		file.close()
		return _fail("Header CSV tidak sesuai — dibutuhkan kolom Moment.")

	var moments: Dictionary = {}  # moment -> Array of row, insertion-ordered
	var rows_count: int = 0
	var skipped: int = 0
	var record_num: int = 1  # header = baris 1, sama seperti nomor baris di sheet
	var has_data: bool = false

	while not file.eof_reached():
		var cols := Array(file.get_csv_line())
		record_num += 1
		if _is_blank_record(cols):
			continue
		has_data = true

		var row := _build_row(cols, hmap, record_num)
		if row.is_empty():
			skipped += 1
			continue

		var moment := _str(cols, hmap, "moment")
		if moment.is_empty():
			_errors.append("Baris %d: kolom Moment kosong untuk '%s', baris dilewati." % [record_num, row["chapter_to_trigger"]])
			skipped += 1
			continue

		if not moments.has(moment):
			moments[moment] = []
		moments[moment].append(row)
		rows_count += 1

	file.close()

	if not has_data:
		return _fail("CSV harus memiliki header row dan setidaknya satu baris data.")

	# sort_keys=false: urutan Moment mengikuti CSV; key di dalam row sudah
	# disusun alfabetis di _build_row().
	var json_str := JSON.stringify(moments, "  ", false)

	return {
		"success": true,
		"json_string": json_str,
		"moments": moments,
		"moments_count": moments.size(),
		"rows_count": rows_count,
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

	# Key disusun alfabetis supaya cocok dengan CutsceneTriggers.json (sort_keys=false saat stringify)
	return {
		"area_lv_requirement":  _parse_area_lv_req(cols, h, "area_lv_requirement", row_num),
		"chapter_to_trigger":   chapter,
		"day":                  _int(cols, h, "day", -1),
		"expired_on":           _nullable(cols, h, "expired_on"),
		"item_requirement_1":   _parse_item_req(cols, h, "item_requirement_1", row_num),
		"item_requirement_2":   _parse_item_req(cols, h, "item_requirement_2", row_num),
		"item_requirement_3":   _parse_item_req(cols, h, "item_requirement_3", row_num),
		"priority":             _int(cols, h, "priority", 0),
		"start_at_1":           _nullable(cols, h, "start_at_1"),
		"start_at_2":           _nullable(cols, h, "start_at_2"),
		"start_at_delay":       _int(cols, h, "start_at_delay", 0),
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

## Baris yang benar-benar kosong (tanpa koma sama sekali), mis. baris akhir file.
## Baris seperti ",,,," tetap dihitung sebagai data lalu di-skip di _build_row().
func _is_blank_record(cols: Array) -> bool:
	return cols.is_empty() or (cols.size() == 1 and str(cols[0]).strip_edges().is_empty())


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
