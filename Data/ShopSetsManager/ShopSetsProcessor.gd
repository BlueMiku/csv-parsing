class_name ShopSetsProcessor
extends RefCounted

## Processor untuk ShopSet CSV
## Format output: { "set_name": { "available_days": [...], "item_list": { "shop": [...], "exchange": [...] } } }
## Setiap item adalah tuple: [category, product_id, sale_price, requirement]

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	var lines: Array[String] = []
	while not file.eof_reached():
		var raw := file.get_line().strip_edges()
		if not raw.is_empty():
			lines.append(raw)
	file.close()

	if lines.size() < 2:
		return _fail("CSV tidak memiliki cukup baris.")

	var result: Dictionary = {}
	var current_set := ""

	# Skip header row (index 0)
	# Kolom: 0=set_shop_name, 1=No., 2=Product Name, 3=product_category,
	#        4=product_id, 5=sale_price, 6=transaction_type,
	#        7=product_requirement, 8=lookup_tab
	for i in range(1, lines.size()):
		var cols := _parse_csv_line(lines[i])
		while cols.size() < 9:
			cols.append("")

		var set_name: String = cols[0].strip_edges()
		if not set_name.is_empty():
			current_set = set_name
			if not result.has(current_set):
				result[current_set] = {
					"available_days": [0, 1, 2, 3, 4, 5, 6],
					"item_list": { "shop": [], "exchange": [] }
				}

		if current_set.is_empty():
			continue

		# Skip baris tanpa nama produk DAN tanpa product_id
		var name_s: String = cols[2].strip_edges()
		var pid_s: String  = cols[4].strip_edges()
		if name_s.is_empty() and pid_s.is_empty():
			continue

		var category: String = cols[3].strip_edges()
		if category == "Drinks":
			category = "Beverages"
		var category_val = category if not category.is_empty() else null

		var product_id = int(pid_s) if pid_s.is_valid_int() else null
		var sale_price_s: String = cols[5].strip_edges()
		var sale_price: int = int(sale_price_s) if sale_price_s.is_valid_int() else 0
		var tx_type: String = cols[6].strip_edges()
		if tx_type.is_empty():
			tx_type = "shop"
		var req_s: String = cols[7].strip_edges()
		var requirement = req_s if not req_s.is_empty() else null

		var item = [category_val, product_id, sale_price, requirement]

		if tx_type == "exchange":
			result[current_set]["item_list"]["exchange"].append(item)
		else:
			result[current_set]["item_list"]["shop"].append(item)

	var json_str := _stringify_shopset(result)

	return {
		"success": true,
		"json_string": json_str,
		"sets": result,
		"sets_count": result.size(),
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


# ── Custom JSON stringifier ───────────────────────────────────────────────────
# Item tuples dan available_days tetap satu baris untuk keterbacaan.

func _stringify_shopset(data: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("{")
	var set_names := data.keys()
	for si in range(set_names.size()):
		var sname: String = set_names[si]
		var sdata: Dictionary = data[sname]
		var set_comma := "," if si < set_names.size() - 1 else ""

		lines.append('\t"%s":' % sname)
		lines.append("\t{")

		var days: Array = sdata["available_days"]
		var days_parts: PackedStringArray = []
		for d in days:
			days_parts.append(str(d))
		lines.append('\t\t"available_days": [%s],' % ",".join(days_parts))

		lines.append('\t\t"item_list":')
		lines.append("\t\t{")
		var item_list: Dictionary = sdata["item_list"]
		var tx_keys := ["shop", "exchange"]
		for ti in range(tx_keys.size()):
			var tx: String = tx_keys[ti]
			var items: Array = item_list[tx]
			var tx_comma := "," if ti < tx_keys.size() - 1 else ""
			if items.is_empty():
				lines.append('\t\t\t"%s": []%s' % [tx, tx_comma])
			else:
				lines.append('\t\t\t"%s":' % tx)
				lines.append("\t\t\t[")
				for ii in range(items.size()):
					var item_comma := "," if ii < items.size() - 1 else ""
					lines.append("\t\t\t\t%s%s" % [_item_to_str(items[ii]), item_comma])
				lines.append("\t\t\t]%s" % tx_comma)
		lines.append("\t\t}")

		lines.append("\t}%s" % set_comma)
	lines.append("}")
	return "\n".join(lines)


func _item_to_str(item: Array) -> String:
	var parts: PackedStringArray = []
	for v in item:
		if v == null:
			parts.append("null")
		elif typeof(v) == TYPE_STRING:
			parts.append('"%s"' % v)
		else:
			parts.append(str(v))
	return "[" + ", ".join(parts) + "]"


# ── CSV parser ────────────────────────────────────────────────────────────────

func _parse_csv_line(line: String) -> Array:
	var result := []
	var current := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current += '"'
				i += 2
				continue
			in_quotes = !in_quotes
		elif c == ',' and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += c
		i += 1
	result.append(current)
	return result


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
