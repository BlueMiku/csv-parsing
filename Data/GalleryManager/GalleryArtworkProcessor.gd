class_name GalleryArtworkProcessor
extends RefCounted

## Processor untuk Album Artwork CSV
## Format: ID,Requirement,filename,Title,groupid — kolom dideteksi dari
## header (header-mapped). Baris dengan groupid yang sama dikelompokkan
## menjadi satu entry gallery (satu slot di grid), dengan "filenames" berisi
## urutan file per baris dalam urutan CSV — dipakai Artwork Viewer untuk
## cycle antar file dalam satu slot. groupid murni data key internal,
## tidak pernah ditampilkan — Title tetap satu-satunya teks yang dirender.
## Output: { "Artworks": [ { "group_id", "title", "requirement", "filenames": [...] } ] }

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

	if not (hmap.has("filename") and hmap.has("title") and hmap.has("groupid")):
		return _fail("Header CSV tidak sesuai — dibutuhkan kolom filename, Title, groupid.")

	var groups: Dictionary = {}  # groupid -> entry dict, insertion-ordered
	var skipped := 0

	for i in range(1, lines.size()):
		var line := lines[i]
		if line.strip_edges().is_empty():
			continue
		var cols := _parse_line(line)

		var group_id := _col(cols, hmap, "groupid")
		var filename := _col(cols, hmap, "filename")
		var title := _col(cols, hmap, "title")
		var requirement := _col(cols, hmap, "requirement")

		if group_id.is_empty() or filename.is_empty():
			skipped += 1
			continue

		if not groups.has(group_id):
			# First row seen for this groupid supplies the title/requirement.
			var group_id_val = int(group_id) if group_id.is_valid_int() else group_id
			groups[group_id] = {
				"group_id": group_id_val,
				"title": title,
				"requirement": requirement,
				"filenames": []
			}

		groups[group_id]["filenames"].append(filename)

	var artwork_list: Array = []
	for group_id in groups.keys():
		artwork_list.append(groups[group_id])

	var data := {"Artworks": artwork_list}
	var json_str := JSON.stringify(data, "\t")

	return {
		"success": true,
		"json_string": json_str,
		"artworks": artwork_list,
		"artworks_count": artwork_list.size(),
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
