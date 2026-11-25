class_name NPCProperties
extends RefCounted

## Parser dan stringifier khusus untuk NPC Properties

## Prefix usia/jenis pada nama Outfit Sets -> prefix key age_gender di output.
## "robot" dipetakan ke "automaton" supaya nama lama (RobotMale...) tetap terbaca.
const AGE_PREFIXES := {
	"young": "young",
	"adult": "adult",
	"old": "old",
	"automaton": "automaton",
	"robot": "automaton"
}

var _colors_data: Dictionary = {}
var _outfit_data: Dictionary = {}
var parsing_errors: Array = []
var _base_path: String = ""


## Parse dari direktori yang berisi kedua file CSV
func parse_from_directory(dir_path: String) -> bool:
	_clear_data()
	_base_path = dir_path
	
	var config = DataSchemas.get_npc_properties_config()
	var colors_config = config.get("COLORS", {})
	var outfit_config = config.get("NPC_OUTFIT", {})
	
	var colors_path = dir_path.path_join(colors_config.get("filename", "Colors.csv"))
	if not _parse_colors_file(colors_path, colors_config):
		return false
	
	var outfit_path = dir_path.path_join(outfit_config.get("filename", "NPC.csv"))
	if not _parse_outfit_file(outfit_path, outfit_config):
		return false
	
	return true


## Parse file Colors.csv
func _parse_colors_file(file_path: String, config: Dictionary) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		parsing_errors.append("Gagal membuka file Colors.csv: " + file_path)
		push_warning("NPCProperties: Gagal membuka file Colors.csv: " + file_path)
		return false
	
	var lines = file.get_as_text().split("\n")
	file.close()
	
	var parser_config = config.get("config", {})
	var header_row = parser_config.get("header_row", 0)
	var start_row = parser_config.get("start_row", 1)
	
	# Validasi file memiliki cukup baris
	if lines.size() <= header_row:
		parsing_errors.append("File Colors.csv tidak memiliki cukup baris untuk header")
		return false
	
	# Build header map
	var header_map = _build_header_map(lines[header_row])
	if header_map.is_empty():
		parsing_errors.append("Header Colors.csv kosong atau tidak valid")
		return false
	
	# Validasi required headers
	var required = config.get("required_headers", [])
	for req in required:
		if not header_map.has(req):
			parsing_errors.append("Header yang diperlukan tidak ditemukan di Colors.csv: " + req)
			return false
	
	# Parse data rows
	for i in range(start_row, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		var row = _parse_csv_line(line)
		_process_color_row(row, header_map)
	
	return true


## Parse file NPC
func _parse_outfit_file(file_path: String, config: Dictionary) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		parsing_errors.append("Gagal membuka file NPC.csv: " + file_path)
		push_warning("NPCProperties: Gagal membuka file NPC.csv: " + file_path)
		return false
	
	var lines = file.get_as_text().split("\n")
	file.close()
	
	var parser_config = config.get("config", {})
	var header_row = parser_config.get("header_row", 0)
	var start_row = parser_config.get("start_row", 1)
	
	# Validasi file memiliki cukup baris
	if lines.size() <= header_row:
		parsing_errors.append("File NPC.csv tidak memiliki cukup baris untuk header")
		return false
	
	# Build header map
	var header_map = _build_header_map(lines[header_row])
	if header_map.is_empty():
		parsing_errors.append("Header NPC.csv kosong atau tidak valid")
		return false
	
	# Validasi required headers
	var required = config.get("required_headers", [])
	for req in required:
		if not header_map.has(req):
			parsing_errors.append("Header yang diperlukan tidak ditemukan di NPC.csv: " + req)
			return false
	
	# Parse data rows
	for i in range(start_row, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		var row = _parse_csv_line(line)
		_process_outfit_row(row, header_map)
	
	return true


## Build header map dari baris header
func _build_header_map(header_line: String) -> Dictionary:
	var map = {}
	var headers = _parse_csv_line(header_line)
	for i in range(headers.size()):
		var name = headers[i].strip_edges().to_lower()
		if not name.is_empty():
			map[name] = i
	return map


## Parse CSV line dengan handling quote
func _parse_csv_line(line: String) -> Array:
	return JsonUtils.parse_csv_line(line)


## Process row dari Colors.csv
func _process_color_row(row: Array, header_map: Dictionary) -> void:
	var color_idx = header_map.get("color", -1)
	if color_idx < 0 or color_idx >= row.size():
		return
	
	var color_name = row[color_idx].strip_edges()
	if color_name.is_empty():
		return
	
	# Ambil 4 kode warna (kolom 2-5, index 2,3,4,5)
	var color_codes = []
	for col_idx in [2, 3, 4, 5]:
		if col_idx < row.size():
			var hex = row[col_idx].strip_edges()
			if not hex.is_empty():
				color_codes.append(_parse_color_hex(hex))
			else:
				color_codes.append("")
		else:
			color_codes.append("")
	
	_colors_data[color_name] = color_codes


## Parse color hex value internal
func _parse_color_hex(raw_value: String) -> String:
	var trimmed = raw_value.strip_edges()
	if trimmed.is_empty():
		return ""
	if not trimmed.begins_with("#"):
		return "#" + trimmed
	return trimmed


## Process row dari NPC Parser Sheet.csv
func _process_outfit_row(row: Array, header_map: Dictionary) -> void:
	var no_idx = header_map.get("no.", -1)
	var name_idx = header_map.get("npc name", -1)
	var outfit_idx = header_map.get("outfit sets", -1)
	var _tscn_idx = header_map.get("name .tscn", -1)
	
	if no_idx < 0 or no_idx >= row.size():
		return
	
	var no_val = row[no_idx].strip_edges()
	# Skip player row atau row kosong
	if not no_val.is_valid_int() or no_val == "0":
		return
	
	var npc_name = ""
	if name_idx >= 0 and name_idx < row.size():
		npc_name = row[name_idx].strip_edges()
	
	if npc_name.is_empty():
		return
	
	var outfit_set = ""
	if outfit_idx >= 0 and outfit_idx < row.size():
		outfit_set = row[outfit_idx].strip_edges()
	
	# Tentukan gender/age dari outfit_set name
	var age_gender = _detect_age_gender(outfit_set)
	
	# Parse properties dengan urutan yang sesuai npc_properties.json
	var properties = {}
	properties["hair_type"] = _get_property_array(row, header_map, "parser hair")
	properties["hair_colors"] = _get_property_array(row, header_map, "parser hair color")
	properties["accessories"] = _get_property_array(row, header_map, "parser accessories")
	properties["accessory_colors"] = _get_property_array(row, header_map, "parser accessories color")
	properties["outfit_colors"] = _get_property_array(row, header_map, "parser outfit color")
	properties["eye_colors"] = _get_property_array(row, header_map, "parser eye color")
	properties["body_colors"] = _get_property_array(row, header_map, "parser body color")
	
	# Generate NPC key (format: NPC_Name)
	var npc_key = _generate_npc_key(npc_name, outfit_set)
	
	if not _outfit_data.has(npc_key):
		_outfit_data[npc_key] = {}
	
	_outfit_data[npc_key][age_gender] = properties


## Deteksi age/gender dari outfit set name, hasilnya "<usia>_<gender>"
## (young_male, young_female, adult_male, adult_female, old_male, old_female,
## automaton_male, automaton_female).
func _detect_age_gender(outfit_set: String) -> String:
	# Buang underscore supaya "Young_Male" dan "YoungMale" diperlakukan sama
	var lower = outfit_set.to_lower().replace("_", "")
	for prefix in AGE_PREFIXES:
		var age: String = AGE_PREFIXES[prefix]
		# "female" dicek dulu karena kata itu mengandung "male"
		if lower.contains(prefix + "female"):
			return age + "_female"
		if lower.contains(prefix + "male"):
			return age + "_male"
	# Tanpa prefix usia: anggap young
	if lower.contains("female"):
		return "young_female"
	return "young_male"


## Ambil bagian tipe dari outfit set, mis. "AdultFemaleEmployee" -> "Employee".
## Kosong jika outfit set tidak diawali prefix usia yang dikenal.
func _extract_outfit_type(outfit_set: String) -> String:
	var lower = outfit_set.to_lower()
	for prefix in AGE_PREFIXES:
		if not lower.begins_with(prefix):
			continue
		var type_part = outfit_set.substr(prefix.length()).lstrip("_")
		var rest_lower = type_part.to_lower()
		if rest_lower.begins_with("female"):
			type_part = type_part.substr(6)
		elif rest_lower.begins_with("male"):
			type_part = type_part.substr(4)
		return type_part.lstrip("_")
	return ""


## Generate NPC key dari nama dan outfit set
func _generate_npc_key(npc_name: String, outfit_set: String) -> String:
	# Coba extract dari outfit_set jika ada format NPC_Type
	var type_part = _extract_outfit_type(outfit_set)
	if not type_part.is_empty():
		return "NPC_" + type_part

	# Fallback ke npc_name
	if npc_name.contains(" "):
		return npc_name.replace(" ", "_")
	return "NPC_" + npc_name


## Get property array dari row
func _get_property_array(row: Array, header_map: Dictionary, header_name: String) -> Array:
	var idx = header_map.get(header_name, -1)
	if idx < 0 or idx >= row.size():
		return []
	
	var raw = row[idx].strip_edges()
	return _parse_npc_property_array(raw)


## Parse NPC property array format: "Name|Weight,Name|Weight,..."
func _parse_npc_property_array(raw_value: String) -> Array:
	var trimmed = raw_value.strip_edges()
	if trimmed.is_empty():
		return []
	
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
			result.append([pair[0].strip_edges(), 1])
	return result


## Generate output
func generate_output() -> Dictionary:
	var output = {
		"colors": _colors_data,
		"outfit_types": _outfit_data
	}
	return output


## Get data warna
func get_colors_data() -> Dictionary:
	return _colors_data


## Get data outfit
func get_outfit_data() -> Dictionary:
	return _outfit_data


## Cek apakah ada error
func has_errors() -> bool:
	return not parsing_errors.is_empty()


## Get error messages
func get_error_messages() -> Array:
	return parsing_errors


## Clear semua data
func _clear_data() -> void:
	_colors_data.clear()
	_outfit_data.clear()
	parsing_errors.clear()
	_base_path = ""


## Detect file type berdasarkan header
static func detect_file_type(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return "UNKNOWN"
	
	var first_line = file.get_line().to_lower()
	file.close()
	
	var config = DataSchemas.get_npc_properties_config()
	
	# Check Colors pattern
	var colors_patterns = config.get("COLORS", {}).get("header_patterns", [])
	for pattern in colors_patterns:
		if _matches_pattern(first_line, pattern):
			return "COLORS"
	
	# Check NPC_OUTFIT pattern
	var outfit_patterns = config.get("NPC_OUTFIT", {}).get("header_patterns", [])
	for pattern in outfit_patterns:
		if _matches_pattern(first_line, pattern):
			return "NPC_OUTFIT"
	
	return "UNKNOWN"


## Check apakah header matches pattern
static func _matches_pattern(header: String, pattern: Array) -> bool:
	for keyword in pattern:
		if header.find(keyword) < 0:
			return false
	return true


## Convert NPC Properties data ke JSON string dengan format khusus
static func stringify(data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("{")
	
	var top_keys = data.keys()
	for t_idx in range(top_keys.size()):
		var top_key = top_keys[t_idx]
		var top_value = data[top_key]
		var top_comma = "," if t_idx < top_keys.size() - 1 else ""
		
		if top_key == "colors":
			lines.append("  \"colors\": {")
			lines.append(_stringify_colors(top_value))
			lines.append("  }%s" % top_comma)
		elif top_key == "outfit_types":
			lines.append("  \"outfit_types\": {")
			lines.append(_stringify_outfit_types(top_value))
			lines.append("  }%s" % top_comma)
	
	lines.append("}")
	return "\n".join(lines)


## Stringify colors section dengan inline array format
static func _stringify_colors(colors: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var keys = colors.keys()
	
	for c_idx in range(keys.size()):
		var color_name = keys[c_idx]
		var color_values = colors[color_name]
		var comma = "," if c_idx < keys.size() - 1 else ""
		
		# Format inline: "ColorName": ["#hex1", "#hex2", "#hex3", "#hex4"]
		var hex_strs: PackedStringArray = PackedStringArray()
		for hex in color_values:
			hex_strs.append("\"%s\"" % hex)
		lines.append("    \"%s\": [%s]%s" % [color_name, ", ".join(hex_strs), comma])
	
	return "\n".join(lines)


## Stringify outfit_types section
static func _stringify_outfit_types(outfit_types: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var npc_keys = outfit_types.keys()
	
	for n_idx in range(npc_keys.size()):
		var npc_name = npc_keys[n_idx]
		var npc_data = outfit_types[npc_name]
		var npc_comma = "," if n_idx < npc_keys.size() - 1 else ""
		
		lines.append("    \"%s\": {" % npc_name)
		
		var gender_keys = npc_data.keys()
		for g_idx in range(gender_keys.size()):
			var gender = gender_keys[g_idx]
			var gender_data = npc_data[gender]
			var gender_comma = "," if g_idx < gender_keys.size() - 1 else ""
			
			lines.append("      \"%s\": {" % gender)
			lines.append(_stringify_gender_properties(gender_data))
			lines.append("      }%s" % gender_comma)
		
		lines.append("    }%s" % npc_comma)
	
	return "\n".join(lines)


## Stringify gender properties dengan inline array of arrays
static func _stringify_gender_properties(props: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	
	# Urutan key yang benar sesuai
	var ordered_keys = ["hair_type", "hair_colors", "accessories", "accessory_colors", "outfit_colors", "eye_colors", "body_colors"]
	
	var valid_keys: Array = []
	for key in ordered_keys:
		if props.has(key):
			valid_keys.append(key)
	
	for p_idx in range(valid_keys.size()):
		var prop_name = valid_keys[p_idx]
		var prop_value = props[prop_name]
		var comma = "," if p_idx < valid_keys.size() - 1 else ""
		
		# Format inline array of arrays
		var pairs: PackedStringArray = PackedStringArray()
		for pair in prop_value:
			if pair is Array and pair.size() >= 2:
				pairs.append("[\"%s\", %d]" % [pair[0], pair[1]])
		lines.append("        \"%s\": [%s]%s" % [prop_name, ", ".join(pairs), comma])
	
	return "\n".join(lines)
