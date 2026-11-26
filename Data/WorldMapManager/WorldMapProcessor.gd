class_name WorldMapProcessor
extends RefCounted

## Processor untuk WorldMap CSV -> worldmap.json
## Format: No., LocationNode, LocationCoordinates, MarkerOffset, TargetTscn,
##         Requirements, LocationTres — kolom dideteksi dari header (header-mapped).
## Output mengikuti worldmap.json milik game:
##   { "worldmap_locations": [ { "id", "location_node", "location_coordinates": [x, y],
##       "marker_offset": [x, y], "target_tscn", "requirements", "location_tres" } ] }
## Nilai diambil apa adanya dari sheet. Catatan: game memakai location_node sebagai
## nama folder aset (res://Assets/UI/map/<location_node>) dan, dalam huruf kecil,
## sebagai key area, jadi isinya harus sama persis dengan nama itu.

const REQUIRED_HEADERS := ["no.", "locationnode", "locationcoordinates", "markeroffset", "targettscn", "requirements", "locationtres"]

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	# get_csv_line() membaca satu record utuh, termasuk koma di dalam kutip ("442, 92")
	var raw_headers := file.get_csv_line()
	if raw_headers.size() > 0:
		raw_headers[0] = raw_headers[0].trim_prefix("﻿")  # buang BOM jika ada

	var hmap: Dictionary = {}
	for i in range(raw_headers.size()):
		hmap[raw_headers[i].strip_edges().to_lower()] = i

	var missing: Array[String] = []
	for header in REQUIRED_HEADERS:
		if not hmap.has(header):
			missing.append(header)
	if not missing.is_empty():
		file.close()
		return _fail("Header CSV tidak sesuai — kolom tidak ditemukan: %s." % ", ".join(missing))

	var locations: Array = []
	var seen_ids: Dictionary = {}
	var skipped := 0
	var record_num := 1  # header = baris 1, sama seperti nomor baris di sheet

	while not file.eof_reached():
		var cols := Array(file.get_csv_line())
		record_num += 1
		if _is_blank_record(cols):
			continue

		var no_cell := _str(cols, hmap, "no.")
		if not no_cell.is_valid_int():
			# baris pemisah (semua sel kosong) tidak perlu dilaporkan
			if not _row_is_empty(cols):
				_errors.append("Baris %d: kolom No. bukan integer ('%s'), baris dilewati." % [record_num, no_cell])
				skipped += 1
			continue

		var id := no_cell.to_int()
		if seen_ids.has(id):
			_errors.append("Baris %d: No. %d duplikat dengan baris %d." % [record_num, id, seen_ids[id]])
		else:
			seen_ids[id] = record_num

		var location_node := _str(cols, hmap, "locationnode")
		if location_node.is_empty():
			_errors.append("Baris %d: LocationNode kosong untuk No. %d." % [record_num, id])

		# Urutan key sama dengan worldmap.json
		locations.append({
			"id": id,
			"location_node": location_node,
			"location_coordinates": _int_pair(_str(cols, hmap, "locationcoordinates"), "LocationCoordinates", record_num),
			"marker_offset": _int_pair(_str(cols, hmap, "markeroffset"), "MarkerOffset", record_num),
			"target_tscn": _str(cols, hmap, "targettscn"),
			"requirements": _str(cols, hmap, "requirements"),
			"location_tres": _str(cols, hmap, "locationtres")
		})

	file.close()

	if locations.is_empty():
		return _fail("Tidak ada baris lokasi yang valid di CSV.")

	# sort_keys=false supaya urutan key mengikuti worldmap.json
	var json_str := JSON.stringify({"worldmap_locations": locations}, "\t", false)

	return {
		"success": true,
		"json_string": json_str,
		"locations": locations,
		"locations_count": locations.size(),
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


## "442, 92" -> [442, 92]. Format salah -> [0, 0] plus peringatan.
func _int_pair(raw: String, column: String, row_num: int) -> Array:
	var parts := raw.split(",")
	if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
		return [parts[0].strip_edges().to_int(), parts[1].strip_edges().to_int()]
	_errors.append("Baris %d: %s harus berformat \"x, y\" (dua integer), ditemukan '%s'. Memakai [0, 0]." % [row_num, column, raw])
	return [0, 0]


# ── Column helpers ────────────────────────────────────────────────────────────

func _str(cols: Array, h: Dictionary, key: String) -> String:
	if not h.has(key):
		return ""
	var idx: int = h[key]
	if idx >= cols.size():
		return ""
	return JsonUtils.unescape_literal_control_chars(str(cols[idx]).strip_edges())


## Record tanpa isi sama sekali (mis. baris terakhir file).
func _is_blank_record(cols: Array) -> bool:
	return cols.is_empty() or (cols.size() == 1 and str(cols[0]).strip_edges().is_empty())


## Baris yang semua selnya kosong (baris pemisah ",,,,").
func _row_is_empty(cols: Array) -> bool:
	for col in cols:
		if not str(col).strip_edges().is_empty():
			return false
	return true


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
