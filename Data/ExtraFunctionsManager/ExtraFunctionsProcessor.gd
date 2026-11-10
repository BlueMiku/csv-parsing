class_name ExtraFunctionsProcessor
extends RefCounted

## Processor untuk Extra Functions CSV (misal: request/quest NPC)
## Format: kolom "extra_function_name" menjadi key utama, dan semua kolom lain
## di baris yang sama (kecuali kolom "no") menjadi key di dalam object-nya.
## Kolom dideteksi dari header (header-mapped), jadi kolom baru yang ditambahkan
## ke sheet otomatis ikut ter-parse tanpa perlu mengubah kode.
## Output: { "<extra_function_name>": { "<header>": "<value>", ... }, ... }

const KEY_COLUMN := "extra_function_name"
const IGNORED_COLUMNS := ["no", "no."]
## Kolom yang nilainya diubah jadi array [type: String, id: int, qty: int]
const ITEM_ARRAY_COLUMN := "requested_item"

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	# Baca baris header — get_csv_line() sudah menangani kutip, koma, dan newline di dalam kutip
	var raw_headers := file.get_csv_line()
	if raw_headers.size() > 0:
		raw_headers[0] = raw_headers[0].trim_prefix("﻿")  # buang BOM jika ada

	var key_index := -1
	var value_columns: Array[Dictionary] = []  # [{ "name": String, "index": int }]
	for i in range(raw_headers.size()):
		var header := raw_headers[i].strip_edges()
		var lowered := header.to_lower()
		if header.is_empty() or lowered in IGNORED_COLUMNS:
			continue
		if lowered == KEY_COLUMN:
			key_index = i
			continue
		value_columns.append({"name": header, "index": i})

	if key_index == -1:
		file.close()
		return _fail("Header CSV tidak sesuai — dibutuhkan kolom %s." % KEY_COLUMN)

	var entries: Dictionary = {}
	var skipped := 0

	while not file.eof_reached():
		var cols := file.get_csv_line()
		if _is_blank_row(cols):
			continue

		var function_name := _cell(cols, key_index)
		if function_name.is_empty():
			skipped += 1
			continue

		if entries.has(function_name):
			_errors.append("%s duplikat: '%s' — baris kedua diabaikan, memakai baris pertama." % [KEY_COLUMN, function_name])
			skipped += 1
			continue

		var entry: Dictionary = {}
		for column in value_columns:
			var value := _cell(cols, column["index"])
			if column["name"].to_lower() == ITEM_ARRAY_COLUMN:
				entry[column["name"]] = _parse_item_array(value, function_name)
			else:
				entry[column["name"]] = value
		entries[function_name] = entry

	file.close()

	if entries.is_empty():
		return _fail("Tidak ada baris dengan %s yang terisi." % KEY_COLUMN)

	# sort_keys = false supaya urutan kolom sheet tetap terjaga di JSON
	var json_str := JSON.stringify(entries, "\t", false)

	return {
		"success": true,
		"json_string": json_str,
		"entries": entries,
		"functions_count": entries.size(),
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


# ── Column helpers ────────────────────────────────────────────────────────────

func _cell(cols: PackedStringArray, idx: int) -> String:
	if idx < 0 or idx >= cols.size():
		return ""
	return JsonUtils.unescape_literal_control_chars(cols[idx].strip_edges())


## "key_items,8,1" -> ["key_items", 8, 1]. Elemen pertama selalu String,
## elemen kedua dan ketiga selalu int. Sel kosong -> [].
func _parse_item_array(raw: String, function_name: String) -> Array:
	if raw.is_empty():
		return []

	var parts := raw.split(",")
	if parts.size() != 3:
		_errors.append("%s: %s harus berformat 'type,id,qty' (3 elemen), ditemukan '%s'." % [function_name, ITEM_ARRAY_COLUMN, raw])

	var result: Array = [parts[0].strip_edges()]
	for i in range(1, parts.size()):
		var part := parts[i].strip_edges()
		if part.is_valid_int():
			result.append(part.to_int())
		else:
			_errors.append("%s: elemen ke-%d pada %s harus int, ditemukan '%s'. Menggunakan 0." % [function_name, i + 1, ITEM_ARRAY_COLUMN, part])
			result.append(0)
	return result


func _is_blank_row(cols: PackedStringArray) -> bool:
	for col in cols:
		if not col.strip_edges().is_empty():
			return false
	return true


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
