class_name AreaDevelopmentProcessor
extends RefCounted

## Processor untuk Area Development CSV (AreaDev) -> area_development.json
## Kolom dideteksi dari header (header-mapped). Baris pertama tiap area mengisi
## kolom Name (key area) dan Area Name; baris berikutnya mengosongkan Name
## (forward-fill ala Google Sheets). Baris kosong dipakai sebagai pemisah.
##
## Output mengikuti area_development.json milik game:
##   { "<area_key>": { "Name": "<Area Name>",
##       "Level": { "<N>": { "Segment", "Money", "Description", "Perks", "Max" } } } }
##
## Penting: nomor level di JSON bergeser satu dari sheet. Level N di JSON berisi
## Description dan Max dari level N di sheet (kondisi area sekarang), tetapi
## Segment, Money (kolom Price) dan Perks (kolom Reward Message) diambil dari
## level N+1 (biaya dan hasil untuk naik ke level berikutnya). Level terakhir
## memakai nilai level terakhir sheet itu sendiri (sama seperti entri sebelumnya).

## Key area = Name dalam huruf kecil tanpa spasi, kecuali yang ada di sini.
const AREA_KEY_OVERRIDES := {"bale banjar": "bale"}

## Urutan area di area_development.json yang sekarang dipakai game. Area yang tidak
## ada di daftar ini ditaruh setelahnya sesuai urutan di sheet.
const AREA_ORDER := ["storefront", "aguave", "blumart", "shoreline", "heartdecor", "wetmarket", "bale"]

const REQUIRED_HEADERS := ["name", "lv", "price", "segment", "max", "area name", "description", "reward message"]

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	# get_csv_line() membaca satu record utuh, termasuk sel multi-baris (mis. Reward Message)
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

	var areas: Dictionary = {}      # area_key -> { "levels": { int -> row } }
	var area_keys: Array[String] = []  # urutan kemunculan di sheet
	var current_key := ""
	var skipped := 0
	var record_num := 1  # header = baris 1, sama seperti nomor baris di sheet

	while not file.eof_reached():
		var cols := Array(file.get_csv_line())
		record_num += 1
		if _is_blank_record(cols):
			continue

		var name_cell := _str(cols, hmap, "name")
		var lv_cell := _str(cols, hmap, "lv")

		if not name_cell.is_empty():
			var key := _area_key(name_cell)
			if areas.has(key):
				_errors.append("Baris %d: area '%s' (key '%s') sudah ada sebelumnya, blok ini diabaikan." % [record_num, name_cell, key])
				current_key = ""
			else:
				areas[key] = {"levels": {}}
				area_keys.append(key)
				current_key = key

		if lv_cell.is_empty():
			# baris pemisah (hanya berisi koma) tidak perlu dilaporkan
			if not _row_is_empty(cols):
				skipped += 1
			continue
		if current_key.is_empty():
			_errors.append("Baris %d: baris level tanpa area di atasnya, dilewati." % record_num)
			skipped += 1
			continue
		if not lv_cell.is_valid_int():
			_errors.append("Baris %d: kolom Lv bukan integer ('%s'), baris dilewati." % [record_num, lv_cell])
			skipped += 1
			continue

		var level := lv_cell.to_int()
		var levels: Dictionary = areas[current_key]["levels"]
		if levels.has(level):
			_errors.append("Baris %d: level %d untuk area '%s' duplikat, memakai baris pertama." % [record_num, level, current_key])
			skipped += 1
			continue
		levels[level] = {
			"row": record_num,
			"area_name": _str(cols, hmap, "area name"),
			"price": _str(cols, hmap, "price"),
			"segment": _str(cols, hmap, "segment"),
			"max": _str(cols, hmap, "max"),
			"description": _str(cols, hmap, "description"),
			"reward": _str(cols, hmap, "reward message"),
		}

	file.close()

	if area_keys.is_empty():
		return _fail("Tidak ada area yang ditemukan di CSV.")

	var result: Dictionary = {}
	var levels_count := 0
	for key in _ordered_keys(area_keys):
		var area := _build_area(key, areas[key]["levels"])
		if area.is_empty():
			continue
		result[key] = area
		levels_count += area["Level"].size()

	if result.is_empty():
		return _fail("Tidak ada area dengan level yang valid.")

	# sort_keys=false supaya urutan area dan field mengikuti area_development.json
	var json_str := JSON.stringify(result, "\t", false)

	return {
		"success": true,
		"json_string": json_str,
		"areas": result,
		"areas_count": result.size(),
		"levels_count": levels_count,
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


## Susun satu area. levels: { int -> row dict }
func _build_area(key: String, levels: Dictionary) -> Dictionary:
	if levels.is_empty():
		_errors.append("Area '%s' tidak punya baris level, dilewati." % key)
		return {}

	var level_numbers: Array = levels.keys()
	level_numbers.sort()
	var last_index := level_numbers.size() - 1

	var first_row: Dictionary = levels[level_numbers[0]]
	var area_name: String = first_row["area_name"]
	if area_name.is_empty():
		_errors.append("Baris %d: Area Name kosong untuk area '%s'." % [first_row["row"], key])

	var level_out: Dictionary = {}
	for i in range(level_numbers.size()):
		var current: Dictionary = levels[level_numbers[i]]
		# Biaya, segment, dan hasil upgrade ada di level berikutnya; level terakhir memakai dirinya sendiri
		var next: Dictionary = levels[level_numbers[mini(i + 1, last_index)]]
		var label := "%s level %d" % [key, level_numbers[i]]
		level_out[str(level_numbers[i])] = {
			"Segment": _int(next["segment"], "Segment", label, next["row"]),
			"Money": _int(next["price"], "Price", label, next["row"]),
			"Description": current["description"],
			"Perks": next["reward"],
			"Max": str(current["max"]).to_upper() == "TRUE"
		}

	return {"Name": area_name, "Level": level_out}


## Key area dari kolom Name: huruf kecil tanpa spasi, kecuali ada di AREA_KEY_OVERRIDES.
func _area_key(name_cell: String) -> String:
	var lowered := name_cell.strip_edges().to_lower()
	if AREA_KEY_OVERRIDES.has(lowered):
		return AREA_KEY_OVERRIDES[lowered]
	return lowered.replace(" ", "")


## Area yang ada di AREA_ORDER lebih dulu (sesuai urutan itu), sisanya sesuai urutan sheet.
func _ordered_keys(area_keys: Array[String]) -> Array[String]:
	var ordered: Array[String] = []
	for key in AREA_ORDER:
		if key in area_keys:
			ordered.append(key)
	for key in area_keys:
		if key not in ordered:
			ordered.append(key)
	return ordered


func _int(value: String, column: String, label: String, row_num: int) -> int:
	if value.is_valid_int():
		return value.to_int()
	_errors.append("Baris %d: %s untuk %s bukan integer ('%s'), memakai 0." % [row_num, column, label, value])
	return 0


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
