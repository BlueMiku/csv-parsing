class_name FieldTransformers
extends RefCounted

## Skrip untuk mengubah value field berdasarkan type

## Lookup dinamis nama ingredient (lowercase) -> IngredientId, dibangun dari
## file Ingredient CSV yang sesungguhnya. Diisi oleh CSVProcessor sebelum
## parsing Recipe CSV supaya base_ingredient_id / seasoning_x_id selalu
## mengikuti data ingredient terbaru, bukan tabel hardcoded.
static var _ingredient_id_lookup: Dictionary = {}

## Set lookup nama ingredient -> id (dipanggil sebelum parsing Recipe CSV)
static func set_ingredient_lookup(lookup: Dictionary) -> void:
	_ingredient_id_lookup = lookup

## Kosongkan lookup ingredient (dipanggil saat mulai memproses CSV non-Recipe)
static func clear_ingredient_lookup() -> void:
	_ingredient_id_lookup = {}

## Buat error dictionary dengan detail
static func create_error(msg: String, r_id: String = "", line: int = 0, field: String = "", is_fatal: bool = false) -> Dictionary:
	return {
		"message": msg,
		"row_id": r_id,
		"line_number": line,
		"field_name": field,
		"is_fatal": is_fatal
	}

## Transform value berdasarkan type
## error_log: Array opsional untuk mengumpulkan pesan error
## context: String konteks lokasi data (misal: "Baris [ID: 5], Kolom: amount")
## row_id: ID dari baris yang sedang diproses
## line_number: Nomor baris dalam CSV
## field_name: Nama field yang sedang diproses
static func transform(raw_value: String, field_type: String, default_value = null, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "") -> Variant:
	if raw_value.is_empty() and default_value != null:
		return default_value
	
	if _is_all_empty_parts(raw_value):
		return _get_empty_default_for_type(field_type, default_value)
	
	match field_type:
		"string":
			return raw_value
		"int":
			if raw_value.is_valid_int():
				return raw_value.to_int()
			else:
				var default_int = default_value if default_value != null else 0
				if not raw_value.is_empty():
					var msg = "Konversi Integer Gagal: '%s' pada %s. Menggunakan default: %s" % [raw_value, context, str(default_int)]
					push_warning(msg)
					_log_error(error_log, msg, row_id, line_number, field_name if not field_name.is_empty() else context)
				return default_int
		"float":
			if raw_value.is_valid_float():
				return raw_value.to_float()
			else:
				var default_float = default_value if default_value != null else 0.0
				if not raw_value.is_empty():
					var msg = "Konversi Float Gagal: '%s' pada %s. Menggunakan default: %s" % [raw_value, context, str(default_float)]
					push_warning(msg)
					_log_error(error_log, msg, row_id, line_number, field_name if not field_name.is_empty() else context)
				return default_float
		"bool":
			return raw_value.to_lower() == "true"
		"array":
			return _apply_default_if_empty(parse_array(raw_value), default_value, [])
		"array_int":
			return _apply_default_if_empty(parse_array_int(raw_value, error_log, context, row_id, line_number), default_value, [])
		"float_range":
			return _apply_default_if_empty(parse_float_range(raw_value, error_log, context, row_id, line_number, field_name if not field_name.is_empty() else context), default_value, [1.0, 1.0])
		"scene_props":
			return _apply_default_if_empty(parse_scene_props(raw_value, error_log, context, row_id, line_number, field_name if not field_name.is_empty() else "scene_properties"), default_value, [])
		"next_line":
			return _apply_default_if_empty(parse_next_line(raw_value, error_log, context, row_id, line_number, field_name if not field_name.is_empty() else "next_line_properties"), default_value, [])
		"traits":
			return _apply_default_if_empty(parse_traits(raw_value, error_log, context, row_id, line_number), default_value, {})
		"trait_text":
			return raw_value 
		"recipe_ingredient":
			return parse_recipe_ingredient(raw_value)
		"int_dash":
			if raw_value == "-" or raw_value.is_empty():
				return default_value if default_value != null else 0
			if raw_value.is_valid_int():
				return raw_value.to_int()
			else:
				var default_int = default_value if default_value != null else 0
				var msg_int = "Konversi Integer Gagal: '%s' pada %s. Menggunakan default: %s" % [raw_value, context, str(default_int)]
				push_warning(msg_int)
				_log_error(error_log, msg_int, row_id, line_number, field_name if not field_name.is_empty() else context)
				return default_int
		"alcohol_flag":
			var lowered = raw_value.to_lower()
			if lowered == "alcohol":
				return true
			if lowered == "non alcohol" or lowered == "non-alcohol":
				return false
			return default_value if default_value != null else false
		"color_hex":
			return parse_color_hex(raw_value, default_value)
		"npc_property_array":
			return _apply_default_if_empty(parse_npc_property_array(raw_value, default_value), default_value, [])
		"settings_value":
			return _apply_default_if_empty(parse_settings_value(raw_value, default_value), default_value, "")
		"give_item":
			return _apply_default_if_empty(parse_give_item(raw_value, default_value), default_value, [])
		"cg":
			return _apply_default_if_empty(parse_cg(raw_value, default_value), default_value, [])
		_:
			return raw_value


## Catat error ke array jika tersedia (sekarang menyimpan Dictionary)
static func _log_error(error_log: Array, message: String, row_id: String = "", line_number: int = 0, field: String = "", is_fatal: bool = false) -> void:
	if error_log != null and not message.is_empty():
		var err = create_error(message, row_id, line_number, field, is_fatal)
		error_log.append(err)


## Jika result adalah string kosong, return default sesuai tipe default_value
static func _apply_default_if_empty(result: Variant, default_value: Variant, fallback: Variant) -> Variant:
	if result is String and result == "":
		if default_value != null:
			return default_value
		return fallback
	return result


## Return default value sesuai type field untuk kasus empty parts (seperti ",,,")
static func _get_empty_default_for_type(field_type: String, default_value: Variant) -> Variant:
	match field_type:
		"string", "trait_text", "color_hex":
			return default_value if default_value != null else ""
		"int", "int_dash":
			return default_value if default_value != null else 0
		"float":
			return default_value if default_value != null else 0.0
		"bool", "alcohol_flag":
			return default_value if default_value != null else false
		"float_range":
			return default_value if default_value != null else [1.0, 1.0]
		"array", "array_int", "scene_props", "next_line", "npc_property_array", "give_item", "special_effects", "cg":
			return default_value if default_value != null else []
		"traits":
			return default_value if default_value != null else {}
		"recipe_ingredient":
			return default_value if default_value != null else -1
		"settings_value":
			return default_value if default_value != null else ""
		_:
			return default_value if default_value != null else ""


## Cek apakah field hanya berisi separator tanpa konten
static func _is_all_empty_parts(field: String) -> bool:
	var parts = field.split(",")
	for part in parts:
		if not part.strip_edges().is_empty():
			return false
	return true


## Parse field menjadi array string
static func parse_array(field: String) -> Variant:
	if _is_all_empty_parts(field):
		return ""
	
	var result = []
	var parts = field.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


## Parse field menjadi array integer
static func parse_array_int(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0) -> Variant:
	if _is_all_empty_parts(field):
		return ""
	
	var result = []
	var parts = field.split(",")
	for i in range(parts.size()):
		var trimmed = parts[i].strip_edges()
		if trimmed.is_valid_int():
			result.append(trimmed.to_int())
		elif not trimmed.is_empty():
			var msg = "Integer tidak valid dalam array: '%s' pada index %d di %s. Nilai dilewati." % [trimmed, i, context]
			push_warning(msg)
			_log_error(error_log, msg, row_id, line_number, context)
	return result


## Parse min/max range menjadi array dua float (mis. "0.9,1.1" -> [0.9, 1.1])
static func parse_float_range(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "") -> Variant:
	if _is_all_empty_parts(field):
		return ""

	var values: Array = []
	var parts = field.split(",")
	for i in range(parts.size()):
		var trimmed = parts[i].strip_edges()
		if trimmed.is_empty():
			continue
		if trimmed.is_valid_float():
			values.append(trimmed.to_float())
		else:
			var msg = "Float tidak valid dalam range: '%s' pada index %d di %s. Nilai dilewati." % [trimmed, i, context]
			push_warning(msg)
			_log_error(error_log, msg, row_id, line_number, field_name)

	if values.size() >= 2:
		return [values[0], values[1]]
	if values.size() == 1:
		return [values[0], values[0]]

	return ""


## Parse scene_properties dengan konversi boolean
## Array harus memiliki tepat 5 elemen (comma-separated, empty slots allowed)
static func parse_scene_props(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "scene_properties") -> Variant:
	if _is_all_empty_parts(field):
		return ""
	
	var result = []
	var parts = field.split(",")
	
	# Validasi panjang array berdasarkan jumlah comma-separated parts
	# Harus tepat 5 parts (bisa termasuk empty)
	if parts.size() != 5 and not field.strip_edges().is_empty():
		var msg = "Array scene_properties harus memiliki tepat 5 elemen (comma-separated), ditemukan %d elemen pada %s." % [parts.size(), context]
		push_warning(msg)
		_log_error(error_log, msg, row_id, line_number, field_name, true)
	
	# Parse setiap part
	for i in range(parts.size()):
		var part = parts[i].strip_edges()
		# Tambahkan empty/default untuk empty parts
		if part.is_empty():
			result.append("")
			continue
		if result.is_empty():
			# Elemen pertama harus boolean
			if part.to_lower() != "true" and part.to_lower() != "false":
				var msg = "Boolean tidak valid di scene_props: '%s' pada index %d di %s. Diharapkan true/false." % [part, i, context]
				push_warning(msg)
				_log_error(error_log, msg, row_id, line_number, field_name)
			result.append(part.to_lower() == "true")
		elif result.size() == 3:
			if part.to_lower() == "true":
				result.append(true)
			elif part.to_lower() == "false" or part.to_lower() == "none":
				result.append(false)
			else:
				result.append(part)
		else:
			if part.to_lower() == "true":
				result.append(true)
			elif part.to_lower() == "false":
				result.append(false)
			else:
				result.append(part)
	
	return result


## Parse next_line_properties dengan konversi tipe
## Array harus memiliki tepat 5 elemen (comma-separated, empty slots allowed)
static func parse_next_line(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0, field_name: String = "next_line_properties") -> Variant:
	if _is_all_empty_parts(field):
		return ""
	
	var result = []
	var parts = field.split(",")
	
	# Validasi panjang array berdasarkan jumlah comma-separated parts
	# Harus tepat 5 parts (bisa termasuk empty)
	if parts.size() != 5 and not field.strip_edges().is_empty():
		var msg = "Array next_line_properties harus memiliki tepat 5 elemen (comma-separated), ditemukan %d elemen pada %s." % [parts.size(), context]
		push_warning(msg)
		_log_error(error_log, msg, row_id, line_number, field_name, true)
	
	# Parse setiap part
	for part in parts:
		var trimmed = part.strip_edges()
		# Tambahkan empty string untuk empty parts (placeholder)
		if trimmed.is_empty():
			result.append("")
			continue
		if trimmed.is_valid_int():
			result.append(int(trimmed))
		elif trimmed.to_lower() == "true":
			result.append(true)
		elif trimmed.to_lower() == "false":
			result.append(false)
		else:
			result.append(trimmed)
	

	return result


## Parsing sesuai dengan traits fields
static func parse_traits(field: String, error_log: Array = [], context: String = "", row_id: String = "", line_number: int = 0) -> Variant:
	if _is_all_empty_parts(field):
		return ""
	
	var result = {}
	var parts = field.split(",")
	var keys = ["richness", "boldness", "fanciness"]
	for i in range(min(parts.size(), keys.size())):
		var value = parts[i].strip_edges()
		if value.is_valid_int():
			result[keys[i]] = value.to_int()
		else:
			if not value.is_empty():
				var msg = "Integer tidak valid untuk trait '%s': '%s' di %s. Menggunakan default: 0" % [keys[i], value, context]
				push_warning(msg)
				_log_error(error_log, msg, row_id, line_number, context)
			result[keys[i]] = 0
	return result


## Parse recipe ingredient name to ID
## Returns -1 for invalid ingredients (-, Bebas, empty) or names not found
## in the dynamic ingredient lookup (see set_ingredient_lookup)
static func parse_recipe_ingredient(raw_value: String) -> int:
	var trimmed = raw_value.strip_edges()
	if trimmed.is_empty() or trimmed == "-" or trimmed.to_lower() == "bebas":
		return -1

	var key = trimmed.to_lower()
	if _ingredient_id_lookup.has(key):
		return _ingredient_id_lookup[key]
	return -1

## Return sebagai kombinasi teks (e.g., "Light  Luxurious")
static func calculate_trait_text(richness: int, boldness: int, fanciness: int) -> String:
	var richness_text = _get_richness_text(richness)
	var boldness_text = _get_boldness_text(boldness)
	var fanciness_text = _get_fanciness_text(fanciness)
	
	return richness_text + boldness_text + fanciness_text

static func _get_richness_text(value: int) -> String:
	if value < -3:
		return "Plain "
	elif value >= -3 and value < 0:
		return "Light "
	elif value == 0:
		return " "
	elif value > 0 and value <= 3:
		return "Rich "
	else:  # value > 3
		return "Savory "
		
static func _get_boldness_text(value: int) -> String:
	if value < -3:
		return "Delicate "
	elif value >= -3 and value < 0:
		return "Mild "
	elif value == 0:
		return " "
	elif value > 0 and value <= 3:
		return "Bold "
	else:  # value > 3
		return "Strong "
		
static func _get_fanciness_text(value: int) -> String:
	if value < -3:
		return "Modest"
	elif value >= -3 and value < 0:
		return "Traditional"
	elif value == 0:
		return " "
	elif value > 0 and value <= 3:
		return "Fancy"
	else:  # value > 3
		return "Luxurious"


## Parse color hex value
static func parse_color_hex(raw_value: String, default_value = "") -> String:
	var trimmed = raw_value.strip_edges()
	if trimmed.is_empty():
		return default_value if default_value != null else ""
	# Tambahkan # di depan jika belum ada
	if not trimmed.begins_with("#"):
		return "#" + trimmed
	return trimmed


## Parse NPC property array format
static func parse_npc_property_array(raw_value: String, default_value = []) -> Variant:
	var trimmed = raw_value.strip_edges()
	if trimmed.is_empty():
		return default_value if default_value != null else []
	
	if _is_all_empty_parts(trimmed):
		return ""
	
	var result = []
	var parts = trimmed.split(",")
	for part in parts:
		var pair = part.strip_edges().split("|")
		if pair.size() >= 2:
			var name_val = pair[0].strip_edges()
			var weight_str = pair[1].strip_edges()
			var weight = weight_str.to_int() if weight_str.is_valid_int() else 0
			result.append([name_val, weight])
		elif pair.size() == 1 and not pair[0].strip_edges().is_empty():
			# Jika tidak ada weight, default ke 1
			result.append([pair[0].strip_edges(), 1])
	return result


## Parse settings value (field bisa berupa string, int, atau array of int)
static func parse_settings_value(raw_value: String, default_value = "") -> Variant:
	var trimmed = raw_value.strip_edges()
	if trimmed.is_empty():
		return default_value if default_value != null else ""
	
	if _is_all_empty_parts(trimmed):
		return ""
	
	# Cek apakah bisa diparse sebagai array of int
	if trimmed.find(",") >= 0:
		var parts = trimmed.split(",")
		var int_array: Array = []
		var all_ints = true
		for part in parts:
			var val = part.strip_edges()
			if val.is_valid_int():
				int_array.append(val.to_int())
			else:
				all_ints = false
				break
		if all_ints and int_array.size() > 0:
			return int_array
		# Return sebagai string jika tidak semua elemen bisa diparse sebagai int
		return trimmed
	
	# Cek apakah bisa diparse sebagai int tunggal
	if trimmed.is_valid_int():
		return trimmed.to_int()
	
	# Return sebagai string
	return trimmed


## Parse give_item field
static func parse_give_item(field: String, default_value = []) -> Variant:
	var trimmed = field.strip_edges()
	if trimmed.is_empty():
		return default_value if default_value != null else []
	
	var parts = trimmed.split(",")
	var has_content = false
	for part in parts:
		if not part.strip_edges().is_empty():
			has_content = true
			break
	
	# Jika semua kosong seperti ",,," return string kosong
	if not has_content:
		return ""
	
	# Parse array
	var result = []
	for part in parts:
		var val = part.strip_edges()
		if val.is_empty():
			result.append("")
		elif val.is_valid_int():
			result.append(val.to_int())
		else:
			result.append(val)
	
	return result


## Parse cg field: [string, [array]]
static func parse_cg(field: String, default_value = []) -> Variant:
	var trimmed = field.strip_edges()
	if trimmed.is_empty():
		return default_value if default_value != null else []
	
	if _is_all_empty_parts(trimmed):
		return ""
	
	var parts = trimmed.split(",")
	if parts.is_empty():
		return default_value if default_value != null else []
	
	var main_value = parts[0].strip_edges()
	var sub_values: Array = []
	for i in range(1, parts.size()):
		var sub = parts[i].strip_edges()
		if not sub.is_empty():
			sub_values.append(sub)
	
	return [main_value, sub_values]
