class_name GameplayEventsProcessor
extends RefCounted

## Processor khusus untuk GameplayEvents CSV
## Format CSV: No,Priority,EventName,start_at,single_day,expired_on,settings_name,operation,value
## settings_name/operation/value adalah parallel comma-separated lists (elemen ke-N saling berkaitan)

var _errors: Array[String] = []


## Proses file CSV dan kembalikan Dictionary {success, json_string, rows, rows_count, skipped_count, errors}
func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	var raw_rows: Array = []
	while not file.eof_reached():
		var row: Array = file.get_csv_line()
		if row.is_empty():
			continue
		if row.size() == 1 and str(row[0]).strip_edges().is_empty():
			continue
		raw_rows.append(row)
	file.close()

	if raw_rows.size() < 2:
		return _fail("CSV tidak memiliki cukup baris (hanya %d baris)." % raw_rows.size())

	var rows: Array = []
	var skipped := 0
	for i in range(1, raw_rows.size()):
		var cols: Array = raw_rows[i]
		# Skip baris komentar/catatan: kolom No harus integer valid
		if cols.is_empty() or not str(cols[0]).strip_edges().is_valid_int():
			skipped += 1
			continue
		rows.append(_parse_row(cols, i + 1))

	var json_str := _build_json(rows)

	return {
		"success": true,
		"json_string": json_str,
		"rows": rows,
		"rows_count": rows.size(),
		"skipped_count": skipped,
		"errors": _errors.duplicate()
	}


## Proses dan langsung simpan ke file output (overwrite — tidak ada merge, satu file = seluruh event list)
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


func _parse_row(cols: Array, row_number: int) -> Dictionary:
	while cols.size() < 9:
		cols.append("")

	var row := {}
	row["No"] = int(str(cols[0]).strip_edges())
	row["priority"] = int(str(cols[1]).strip_edges()) if str(cols[1]).strip_edges().is_valid_int() else 0
	row["EventName"] = str(cols[2]).strip_edges()
	row["start_at"] = str(cols[3]).strip_edges()
	row["single_day"] = str(cols[4]).strip_edges().to_lower() == "true"
	row["expired_on"] = str(cols[5]).strip_edges()
	row["targets"] = _parse_targets(cols[6], cols[7], cols[8], row_number)
	return row


## Parse settings_name/operation/value parallel comma-lists menjadi array of {setting, op, value}
func _parse_targets(settings_raw: String, operation_raw: String, value_raw: String, row_number: int) -> Array:
	var settings_parts := _split_trim(settings_raw)
	var operation_parts := _split_trim(operation_raw)
	var value_parts := _split_trim(value_raw)

	var targets: Array = []
	for i in range(settings_parts.size()):
		var setting_name: String = settings_parts[i]
		if setting_name.is_empty():
			continue

		var op: String = operation_parts[i] if i < operation_parts.size() else ""
		var value_str: String = value_parts[i] if i < value_parts.size() else ""

		if op.is_empty():
			_errors.append("Baris %d: operation kosong untuk setting '%s'." % [row_number, setting_name])
			continue
		if not ["add", "mult", "equals"].has(op):
			_errors.append("Baris %d: operation tidak dikenali '%s' untuk setting '%s' (harus add/mult/equals)." % [row_number, op, setting_name])
			continue
		if not value_str.is_valid_float():
			_errors.append("Baris %d: value tidak valid '%s' untuk setting '%s'." % [row_number, value_str, setting_name])
			continue

		var value: float = value_str.to_float()
		targets.append({
			"setting": setting_name,
			"op": op,
			"value": int(value) if int(value) == value else value
		})

	return targets


## Split by comma lalu strip_edges tiap elemen, buang elemen kosong trailing
func _split_trim(field: String) -> Array:
	var parts := str(field).split(",")
	var result: Array = []
	for part in parts:
		var trimmed: String = str(part).strip_edges()
		if trimmed.is_empty():
			continue
		result.append(trimmed)
	return result


## Build JSON string: array of event objects (root = array, tidak ada wrapper key)
func _build_json(rows: Array) -> String:
	var lines: PackedStringArray = []
	lines.append("[")

	var key_order := ["EventName", "No", "priority", "start_at", "single_day", "expired_on", "targets"]

	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var row_comma := "," if i < rows.size() - 1 else ""
		lines.append("\t{")
		for k_idx in range(key_order.size()):
			var key: String = key_order[k_idx]
			var val = row[key]
			var field_comma := "," if k_idx < key_order.size() - 1 else ""
			lines.append("\t\t\"%s\": %s%s" % [key, _val_to_json(val, 2), field_comma])
		lines.append("\t}%s" % row_comma)

	lines.append("]")
	return "\n".join(lines)


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
	var inner_indent := "\t".repeat(indent_level + 1)
	var close_indent := "\t".repeat(indent_level)
	var parts := PackedStringArray()
	for item in arr:
		parts.append("%s%s" % [inner_indent, _val_to_json(item, indent_level + 1)])
	return "[\n%s\n%s]" % [",\n".join(parts), close_indent]


func _dict_to_json(dict: Dictionary, indent_level: int) -> String:
	var close_indent := "\t".repeat(indent_level)
	if dict.is_empty():
		return "{}"
	var indent := "\t".repeat(indent_level + 1)
	var parts := PackedStringArray()
	var keys := dict.keys()
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
