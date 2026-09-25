class_name ArchiveProfileContentProcessor
extends RefCounted

## Processor untuk CSV konten profile per-karakter (mis. "... - Farah.csv").
## Format: id,content_name,content,:,len,RAW — kolom dideteksi dari header
## (header-mapped); kolom ":", len, dan RAW hanya bantuan untuk pembuat CSV
## (word count, preview gabungan) dan tidak dibawa ke output.
## Baris metadata di atas data asli (nama karakter, status export, timestamp
## import) dan baris kosong sisa di akhir sheet dilewati — dikenali lewat kolom
## id yang harus berupa angka valid DAN content_name yang tidak kosong.
## Output flat: { content_name: content, ... } — dipakai ArchiveMenuUi untuk
## resolve key dari button_title/content di archive_profiles.json (lihat
## ArchiveProfileProcessor) menjadi teks yang sebenarnya ditampilkan. Disimpan
## per-karakter (nama file = nilai kolom "json" milik karakter itu, mis.
## profile_farah.json) supaya bisa di-load on-demand, bukan sekaligus semua.

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	var csv_text := file.get_as_text()
	file.close()

	var lines := csv_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)

	if lines.size() < 2:
		return _fail("CSV tidak memiliki cukup baris (hanya %d baris)." % lines.size())

	# Build header -> index map (case-insensitive, strip whitespace)
	var raw_headers := _parse_line(lines[0])
	var hmap: Dictionary = {}
	for i in range(raw_headers.size()):
		hmap[raw_headers[i].strip_edges().to_lower()] = i

	if not (hmap.has("id") and hmap.has("content_name") and hmap.has("content")):
		return _fail("Header CSV tidak sesuai — dibutuhkan kolom id, content_name, content.")

	var content_map: Dictionary = {}  # content_name -> content, insertion-ordered
	var skipped := 0

	for i in range(1, lines.size()):
		var line := lines[i]
		if line.strip_edges().is_empty():
			continue
		var cols := _parse_line(line)

		var id_raw := _col(cols, hmap, "id")
		var content_name := _col(cols, hmap, "content_name")
		# Baris metadata (id non-numerik, mis. "Farah"/"Exported"/"Imported") dan
		# baris kosong sisa (id numerik tapi content_name kosong) dilewati di sini.
		if not id_raw.is_valid_int() or content_name.is_empty():
			skipped += 1
			continue

		if content_map.has(content_name):
			var dup_msg = "content_name duplikat: '%s' (baris %d) — entri sebelumnya ditimpa." % [content_name, i + 1]
			push_warning(dup_msg)
			_errors.append(dup_msg)

		content_map[content_name] = _col(cols, hmap, "content")

	var json_str := JSON.stringify(content_map, "\t")

	return {
		"success": true,
		"json_string": json_str,
		"content_map": content_map,
		"entries_count": content_map.size(),
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

func _col(cols: Array, h: Dictionary, key: String) -> String:
	if not h.has(key):
		return ""
	var idx: int = h[key]
	if idx >= cols.size():
		return ""
	return JsonUtils.unescape_literal_control_chars(str(cols[idx]).strip_edges())


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
