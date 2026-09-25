class_name JsonUtils
extends RefCounted

## Utilitas bersama untuk operasi JSON

const DEFAULT_INDENT := "\t"
const COMPACT_THRESHOLD := 60

## Escape karakter khusus untuk JSON string
static func escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s


## Konversi escape sequence literal \n, \r, \t (dua karakter: backslash +
## huruf, mis. diketik manual oleh penulis dialog sebagai penanda baris baru)
## menjadi karakter kontrol sungguhan. Dipanggil saat field CSV dibaca, SEBELUM
## nilainya diproses lebih lanjut — supaya escape_json_string() (yang sudah
## benar meng-escape newline/tab asli jadi \n tunggal) tidak melihat backslash
## literal itu lagi dan menggandakannya jadi \\n. Backslash lain yang tidak
## diikuti n/r/t dibiarkan apa adanya (bukan literal escape sequence).
static func unescape_literal_control_chars(s: String) -> String:
	if s.find("\\") == -1:
		return s

	var result := ""
	var i := 0
	var length := s.length()
	while i < length:
		var c := s[i]
		if c == "\\" and i + 1 < length:
			var next := s[i + 1]
			if next == "n":
				result += "\n"
				i += 2
				continue
			elif next == "r":
				result += "\r"
				i += 2
				continue
			elif next == "t":
				result += "\t"
				i += 2
				continue
		result += c
		i += 1
	return result


## Konversi value ke JSON string dengan preservasi tipe integer
static func value_to_json(value: Variant, indent_level: int = 0, indent_string: String = DEFAULT_INDENT, compact_arrays: bool = true) -> String:
	if value is String:
		return "\"%s\"" % escape_json_string(value)
	elif value is bool:
		return "true" if value else "false"
	elif value is int:
		return str(value)
	elif value is float:
		# Jika float tanpa pecahan, tampilkan sebagai int
		if int(value) == value:
			return str(int(value))
		return str(value)
	elif value is Array:
		return array_to_json(value, indent_level, indent_string, compact_arrays)
	elif value is Dictionary:
		return dict_to_json(value, indent_level, indent_string, compact_arrays)
	elif value == null:
		return "null"
	else:
		return "\"%s\"" % str(value)


## Konversi array ke JSON string
static func array_to_json(arr: Array, indent_level: int = 0, indent_string: String = DEFAULT_INDENT, compact_arrays: bool = true) -> String:
	if arr.is_empty():
		return "[]"

	var items = []
	for item in arr:
		items.append(value_to_json(item, indent_level, indent_string, compact_arrays))

	var joined = ", ".join(items)

	if compact_arrays and joined.length() < COMPACT_THRESHOLD:
		return "[%s]" % joined

	var indent = indent_string.repeat(indent_level + 1)
	var close_indent = indent_string.repeat(indent_level)
	var formatted_items = []
	for item in arr:
		formatted_items.append("%s%s" % [indent, value_to_json(item, indent_level + 1, indent_string, compact_arrays)])
	return "[\n%s\n%s]" % [",\n".join(formatted_items), close_indent]


## Konversi dictionary ke JSON string
static func dict_to_json(dict: Dictionary, indent_level: int = 0, indent_string: String = DEFAULT_INDENT, compact_arrays: bool = true) -> String:
	if dict.is_empty():
		return "{}"

	var items = []
	for key in dict:
		items.append("\"%s\": %s" % [key, value_to_json(dict[key], indent_level, indent_string, compact_arrays)])

	var joined = ", ".join(items)

	if compact_arrays and joined.length() < COMPACT_THRESHOLD:
		return "{%s}" % joined

	var indent = indent_string.repeat(indent_level + 1)
	var close_indent = indent_string.repeat(indent_level)
	var formatted_items = []
	for key in dict:
		formatted_items.append("%s\"%s\": %s" % [indent, key, value_to_json(dict[key], indent_level + 1, indent_string, compact_arrays)])
	return "{\n%s\n%s}" % [",\n".join(formatted_items), close_indent]


## Konversi float ke int jika nilainya bilangan bulat (untuk JSON parse result)
static func convert_floats_to_ints(data: Variant) -> Variant:
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data.keys():
			result[key] = convert_floats_to_ints(data[key])
		return result
	elif data is Array:
		var result: Array = []
		for item in data:
			result.append(convert_floats_to_ints(item))
		return result
	elif data is float:
		# Cek apakah float adalah bilangan bulat
		if is_equal_approx(data, float(int(data))):
			return int(data)
		return data
	else:
		return data


## Memecah teks CSV menjadi record logis (newline di dalam field berkutip tetap satu record)
static func split_csv_records(csv_text: String) -> Array:
	var records: Array = []
	var current_record := ""
	var in_quotes := false
	var i := 0

	while i < csv_text.length():
		var c: String = csv_text[i]
		if c == '"':
			if in_quotes and i + 1 < csv_text.length() and csv_text[i + 1] == '"':
				current_record += '""'
				i += 1
			else:
				in_quotes = not in_quotes
			current_record += '"'
		elif (c == "\n" or c == "\r") and not in_quotes:
			if c == "\r" and i + 1 < csv_text.length() and csv_text[i + 1] == "\n":
				i += 1
			if not current_record.strip_edges().is_empty():
				records.append(current_record)
			current_record = ""
		else:
			current_record += c
		i += 1

	if not current_record.strip_edges().is_empty():
		records.append(current_record)

	return records


## Normalisasi satu baris hasil FileAccess.get_csv_line
static func normalize_csv_row(row: Array) -> Array:
	if row.is_empty():
		return row
	if row.size() == 1 and str(row[0]).contains(","):
		var raw_line := str(row[0])
		if raw_line.begins_with('"') and raw_line.ends_with('"'):
			raw_line = raw_line.substr(1, raw_line.length() - 2)
		return parse_csv_line(raw_line)
	return row


## Parse CSV line dengan handling quote (shared utility)
static func parse_csv_line(line: String) -> Array:
	# Cek apakah seluruh baris dibungkus kutip ganda (bad CSV export)
	var trimmed = line.strip_edges()

	# Cek apakah dimulai dan diakhiri dengan kutip
	if trimmed.begins_with('"') and trimmed.ends_with('"') and trimmed.length() > 2:
		# Parse normal dulu
		var normal_result = _parse_csv_line_internal(trimmed)

		# Jika hasil normal hanya 1 kolom (seluruh baris jadi satu field),
		# coba unwrap dan parse lagi
		if normal_result.size() == 1:
			var inner = trimmed.substr(1, trimmed.length() - 2)
			# Konversi escaped quotes dari outer wrapping
			inner = inner.replace('""', '"')
			var unwrapped_result = _parse_csv_line_internal(inner)
			# Jika unwrapped menghasilkan lebih banyak kolom, gunakan itu
			if unwrapped_result.size() > normal_result.size():
				return unwrapped_result

		# Jika jumlah kolom normal terlalu sedikit dibanding yang diharapkan
		if normal_result.size() < 10:
			var inner = trimmed.substr(1, trimmed.length() - 2)
			inner = inner.replace('""', '"')
			var unwrapped_result = _parse_csv_line_internal(inner)
			if unwrapped_result.size() >= normal_result.size():
				return unwrapped_result

		return normal_result

	return _parse_csv_line_internal(line)


## Internal CSV line parser
static func _parse_csv_line_internal(line: String) -> Array:
	var result = []
	var current_field = ""
	var in_quotes = false
	var i = 0

	while i < line.length():
		var c = line[i]
		if c == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current_field += '"'
				i += 1
			else:
				in_quotes = !in_quotes
		elif c == ',' and !in_quotes:
			result.append(current_field)
			current_field = ""
		else:
			current_field += c
		i += 1

	result.append(current_field)
	return result


## Stringify dictionary dengan custom formatting (untuk MergeSystem)
static func stringify_dict(data: Dictionary, indent_string: String = DEFAULT_INDENT) -> String:
	var lines: Array[String] = []
	lines.append("{")

	var keys = data.keys()
	for i in range(keys.size()):
		var key = keys[i]
		var value = data[key]
		var comma = "," if i < keys.size() - 1 else ""

		if value is Array:
			lines.append("%s\"%s\": [" % [indent_string, key])
			lines.append_array(stringify_array_items(value, 2, indent_string))
			lines.append("%s]%s" % [indent_string, comma])
		elif value is Dictionary:
			lines.append("%s\"%s\": %s%s" % [indent_string, key, stringify_nested_dict(value, 1, indent_string), comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent_string, key, value_to_json(value, 1, indent_string, false), comma])

	lines.append("}")
	return "\n".join(lines)


## Stringify array items dengan indentasi
static func stringify_array_items(arr: Array, indent_level: int, indent_string: String = DEFAULT_INDENT) -> Array[String]:
	var lines: Array[String] = []
	var indent = indent_string.repeat(indent_level)

	for i in range(arr.size()):
		var item = arr[i]
		var comma = "," if i < arr.size() - 1 else ""

		if item is Dictionary:
			lines.append("%s{" % indent)
			lines.append_array(stringify_object_fields(item, indent_level + 1, indent_string))
			lines.append("%s}%s" % [indent, comma])
		elif item is Array:
			lines.append("%s%s%s" % [indent, stringify_inline_array(item, indent_string), comma])
		else:
			lines.append("%s%s%s" % [indent, value_to_json(item, indent_level, indent_string, false), comma])

	return lines


## Stringify object fields dengan key order yang sudah diurutkan
static func stringify_object_fields(obj: Dictionary, indent_level: int, indent_string: String = DEFAULT_INDENT) -> Array[String]:
	var lines: Array[String] = []
	var indent = indent_string.repeat(indent_level)
	var keys = obj.keys()

	for i in range(keys.size()):
		var key = keys[i]
		var value = obj[key]
		var comma = "," if i < keys.size() - 1 else ""

		if value is Dictionary:
			lines.append("%s\"%s\": %s%s" % [indent, key, stringify_nested_dict(value, indent_level, indent_string), comma])
		elif value is Array:
			lines.append("%s\"%s\": %s%s" % [indent, key, stringify_inline_array(value, indent_string), comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent, key, value_to_json(value, indent_level, indent_string, false), comma])

	return lines


## Stringify nested dictionary (untuk object di dalam object)
static func stringify_nested_dict(dict: Dictionary, indent_level: int, indent_string: String = DEFAULT_INDENT) -> String:
	if dict.is_empty():
		return "{}"

	var items: Array[String] = []
	for key in dict.keys():
		var value = dict[key]
		if value is Dictionary:
			items.append("\"%s\": %s" % [key, stringify_nested_dict(value, indent_level + 1, indent_string)])
		elif value is Array:
			items.append("\"%s\": %s" % [key, stringify_inline_array(value, indent_string)])
		else:
			items.append("\"%s\": %s" % [key, value_to_json(value, indent_level, indent_string, false)])

	return "{%s}" % ", ".join(items)


## Stringify array secara inline (compact)
static func stringify_inline_array(arr: Array, indent_string: String = DEFAULT_INDENT) -> String:
	if arr.is_empty():
		return "[]"

	var items: Array[String] = []
	for item in arr:
		if item is Dictionary:
			items.append(stringify_nested_dict(item, 0, indent_string))
		elif item is Array:
			items.append(stringify_inline_array(item, indent_string))
		else:
			items.append(value_to_json(item, 0, indent_string, false))

	return "[%s]" % ", ".join(items)
