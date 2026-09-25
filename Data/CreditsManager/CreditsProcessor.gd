class_name CreditsProcessor
extends RefCounted

## Processor untuk Credits CSV
## Format: Category,Role,Name — kolom dideteksi dari header (header-mapped).
## Baris kategori hanya mengisi kolom Category, baris role pertama mengisi
## Role (+Name jika ada), baris nama tambahan hanya mengisi Name. Kolom
## kosong berarti "lanjutan dari baris sebelumnya" (mengikuti konvensi
## forward-fill sheet Google Sheets aslinya).
## Output: { "Categories": [ { "category", "jobs": [ { "title", "names": [...] } ] } ] }

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

	if not (hmap.has("category") and hmap.has("role") and hmap.has("name")):
		return _fail("Header CSV tidak sesuai — dibutuhkan kolom Category, Role, Name.")

	var categories: Array = []
	var current_category: Dictionary = {}
	var current_job: Dictionary = {}
	var skipped := 0

	for i in range(1, lines.size()):
		var line := lines[i]
		if line.strip_edges().is_empty():
			continue
		var cols := _parse_line(line)

		var category := _col(cols, hmap, "category")
		var role := _col(cols, hmap, "role")
		var person_name := _col(cols, hmap, "name")

		if category.is_empty() and role.is_empty() and person_name.is_empty():
			skipped += 1
			continue

		if not category.is_empty():
			current_category = {"category": category, "jobs": []}
			categories.append(current_category)
			current_job = {}

		if current_category.is_empty():
			# Baris nama/role muncul sebelum ada kategori sama sekali
			skipped += 1
			continue

		if not role.is_empty():
			current_job = {"title": role, "names": []}
			current_category["jobs"].append(current_job)

		if not person_name.is_empty():
			if current_job.is_empty():
				# Nama tanpa role sebelumnya (misal kategori "Special Thanks")
				current_job = {"title": "", "names": []}
				current_category["jobs"].append(current_job)
			current_job["names"].append(person_name)

	var data := {"Categories": categories}
	var json_str := JSON.stringify(data, "\t")

	return {
		"success": true,
		"json_string": json_str,
		"categories": categories,
		"categories_count": categories.size(),
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
