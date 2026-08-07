extends Node
class_name JSONGenerator

## Skrip untuk membuat JSON dari data CSV

enum OutputFormat {
	GROUPED,          # Nested dari group ID dengan root wrapper
	GROUPED_NO_ROOT,  # Nested dari group ID tanpa root wrapper (langsung kategori)
	FLAT_DICT,        # Flat dictionary
	ARRAY,            # Array of items
	ID_KEYED_DICT     # Dict dengan id sebagai key
}

# Configuration
var key_order: Array = []
var output_format: OutputFormat = OutputFormat.GROUPED
var root_name: String = "Data"
var indent_string: String = "\t"
var compact_arrays: bool = true
var compact_threshold: int = 60
var no_root_wrapper: bool = false
# Internal flags
var _is_recipe_config: bool = false
var _force_root_wrapper: bool = false
var _default_root_name: String = ""
var value_field: String = ""

## SET Functions
func set_key_order(order: Array) -> JSONGenerator:
	key_order = order
	return self
func set_output_format(format: OutputFormat) -> JSONGenerator:
	output_format = format
	return self
func set_root_name(new_root_name: String) -> JSONGenerator:
	root_name = new_root_name
	return self
func set_indent(indent: String) -> JSONGenerator:
	indent_string = indent
	return self
func set_compact_arrays(compact: bool, threshold: int = 60) -> JSONGenerator:
	compact_arrays = compact
	compact_threshold = threshold
	return self
func set_no_root_wrapper(no_root: bool) -> JSONGenerator:
	no_root_wrapper = no_root
	return self

## Preset konfigurasi untuk data CSV yang diambil dari DataSchemas
func configure_for_dialog() -> JSONGenerator:
	key_order = DataSchemas.get_dialog_key_order()
	output_format = OutputFormat.GROUPED
	_is_recipe_config = false
	_force_root_wrapper = false
	_default_root_name = ""
	value_field = ""
	# no_root_wrapper ditentukan oleh UI (jika root name kosong = true)
	return self

func configure_for_ingredient() -> JSONGenerator:
	key_order = DataSchemas.get_ingredient_key_order()
	output_format = OutputFormat.GROUPED
	_is_recipe_config = false
	_force_root_wrapper = false
	_default_root_name = ""
	value_field = ""
	# no_root_wrapper ditentukan oleh UI (jika root name kosong = true)
	return self


func configure_for_recipe() -> JSONGenerator:
	key_order = DataSchemas.get_recipe_key_order()
	output_format = OutputFormat.ARRAY
	root_name = "Foods"
	no_root_wrapper = false
	_is_recipe_config = true
	_force_root_wrapper = true
	_default_root_name = "Foods"
	value_field = ""
	return self

func configure_for_beverage() -> JSONGenerator:
	key_order = DataSchemas.get_beverage_key_order()
	output_format = OutputFormat.ARRAY
	root_name = "Beverage"
	no_root_wrapper = false
	_is_recipe_config = false
	_force_root_wrapper = true
	_default_root_name = "Beverage"
	value_field = ""
	return self

func configure_for_decoration() -> JSONGenerator:
	key_order = DataSchemas.get_decoration_key_order()
	output_format = OutputFormat.ARRAY
	root_name = "Decorations"
	no_root_wrapper = false
	_is_recipe_config = false
	_force_root_wrapper = true
	_default_root_name = "Decorations"
	value_field = ""
	return self


func configure_for_sfx() -> JSONGenerator:
	key_order = DataSchemas.get_sfx_key_order()
	output_format = OutputFormat.ID_KEYED_DICT
	root_name = ""
	no_root_wrapper = true
	_is_recipe_config = false
	_force_root_wrapper = false
	_default_root_name = ""
	value_field = ""
	return self

func configure_for_music() -> JSONGenerator:
	key_order = DataSchemas.get_music_key_order()
	output_format = OutputFormat.ID_KEYED_DICT
	root_name = "Music"
	no_root_wrapper = false
	_is_recipe_config = false
	_force_root_wrapper = true
	_default_root_name = "Music"
	value_field = ""
	return self

func configure_for_key_item() -> JSONGenerator:
	key_order = DataSchemas.get_key_item_key_order()
	output_format = OutputFormat.ARRAY
	root_name = "KeyItems"
	no_root_wrapper = false
	_is_recipe_config = false
	_force_root_wrapper = true
	_default_root_name = "KeyItems"
	value_field = ""
	return self

func configure_for_game_settings() -> JSONGenerator:
	key_order = DataSchemas.get_game_settings_key_order()
	output_format = OutputFormat.FLAT_DICT
	root_name = ""
	no_root_wrapper = true
	_is_recipe_config = false
	_force_root_wrapper = false
	_default_root_name = ""
	value_field = ""
	return self

func configure_for_blip() -> JSONGenerator:
	key_order = DataSchemas.get_blip_key_order()
	output_format = OutputFormat.ID_KEYED_DICT
	root_name = ""
	no_root_wrapper = true
	_is_recipe_config = false
	_force_root_wrapper = false
	_default_root_name = ""
	value_field = ""
	return self

func configure_for_array(custom_key_order: Array = [], root: String = "Data") -> JSONGenerator:
	key_order = custom_key_order
	output_format = OutputFormat.ARRAY
	root_name = root
	no_root_wrapper = false
	_is_recipe_config = false
	_force_root_wrapper = false
	_default_root_name = ""
	value_field = ""
	return self

## Fungsi untuk membuat JSON dari data dan menyimpannya ke file
func generate_json_to_path(data, output_path: String) -> String:
	var json_string = generate_json_string(data)
	
	if json_string.is_empty():
		push_error("Failed to generate JSON string")
		return ""
	
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create JSON file: " + output_path)
		return ""
	
	file.store_string(json_string)
	file.close()
	print("JSON file generated successfully at " + output_path)
	
	return json_string

## Fungsi untuk membuat JSON dari data dan mengembalikannya sebagai String
func generate_json_string(data) -> String:
	if data is Dictionary and data.is_empty():
		push_error("Data is empty")
		return ""
	if data is Array and data.is_empty():
		push_error("Data is empty")
		return ""

	# Force default root untuk recipe jika dikosongkan dari UI dan pastikan tetap pakai wrapper
	if _is_recipe_config:
		if root_name.strip_edges().is_empty():
			root_name = "Foods"
		no_root_wrapper = false

	# Force default root jika konfigurasi mengharuskan wrapper
	if _force_root_wrapper:
		if root_name.strip_edges().is_empty():
			root_name = _default_root_name
		no_root_wrapper = false

	# Jika no_root_wrapper = true, gunakan format tanpa root
	if no_root_wrapper:
		if data is Dictionary:
			if output_format == OutputFormat.ID_KEYED_DICT:
				return _stringify_id_keyed_dict_no_root(data)
			return _stringify_grouped_no_root(data)
		elif data is Array:
			return _stringify_array_no_root(data)
	
	# Jika mode recipe atau konfigurasi memaksa root dan root kosong, set default
	if _force_root_wrapper and root_name.strip_edges().is_empty():
		root_name = _default_root_name
		no_root_wrapper = false

	match output_format:
		OutputFormat.GROUPED:
			return _stringify_grouped(data)
		OutputFormat.GROUPED_NO_ROOT:
			return _stringify_grouped_no_root(data)
		OutputFormat.FLAT_DICT:
			return _stringify_flat_dict(data)
		OutputFormat.ARRAY:
			return _stringify_array(data)
		OutputFormat.ID_KEYED_DICT:
			return _stringify_id_keyed_dict(data)
		_:
			return _stringify_grouped(data)

# Custom stringify untuk grouped format (dengan root wrapper)
func _stringify_grouped(data: Dictionary) -> String:
	var lines = []
	lines.append("{")
	lines.append("%s\"%s\": {" % [indent_string, root_name])
	
	var group_keys = data.keys()
	for g_idx in range(group_keys.size()):
		var group = group_keys[g_idx]
		var group_data = data[group]
		var group_comma = "," if g_idx < group_keys.size() - 1 else ""
		
		if group_data is Dictionary:
			lines.append("%s\"%s\": {" % [indent_string.repeat(2), group])
			lines.append_array(_stringify_dict_items(group_data, 3))
			lines.append("%s}%s" % [indent_string.repeat(2), group_comma])
		elif group_data is Array:
			lines.append("%s\"%s\": [" % [indent_string.repeat(2), group])
			lines.append_array(_stringify_array_items(group_data, 3))
			lines.append("%s]%s" % [indent_string.repeat(2), group_comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent_string.repeat(2), group, _value_to_json(group_data, 2), group_comma])
	
	lines.append("%s}" % indent_string)
	lines.append("}")
	
	return "\n".join(lines)


# Custom stringify untuk grouped format tanpa root wrapper (langsung kategori)
func _stringify_grouped_no_root(data: Dictionary) -> String:
	var lines = []
	lines.append("{")
	
	var group_keys = data.keys()
	for g_idx in range(group_keys.size()):
		var group = group_keys[g_idx]
		var group_data = data[group]
		var group_comma = "," if g_idx < group_keys.size() - 1 else ""
		
		if group_data is Dictionary:
			# Cek apakah ini nested dictionary (berisi items) atau flat dict
			var first_value = group_data.values()[0] if not group_data.is_empty() else null
			if first_value is Dictionary:
				# Nested - konversi ke array
				lines.append("%s\"%s\": [" % [indent_string, group])
				var items_array = group_data.values()
				lines.append_array(_stringify_array_items(items_array, 2))
				lines.append("%s]%s" % [indent_string, group_comma])
			else:
				# Flat dictionary
				lines.append("%s\"%s\": {" % [indent_string, group])
				lines.append_array(_stringify_dict_items(group_data, 2))
				lines.append("%s}%s" % [indent_string, group_comma])
		elif group_data is Array:
			lines.append("%s\"%s\": [" % [indent_string, group])
			lines.append_array(_stringify_array_items(group_data, 2))
			lines.append("%s]%s" % [indent_string, group_comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent_string, group, _value_to_json(group_data, 1), group_comma])
	
	lines.append("}")
	
	return "\n".join(lines)

## Custom stringify untuk dictionary items (handle both data items and metadata)
func _stringify_dict_items(data: Dictionary, indent_level: int) -> Array:
	var lines = []
	var item_keys = data.keys()
	var indent = indent_string.repeat(indent_level)
	
	for i_idx in range(item_keys.size()):
		var item_id = item_keys[i_idx]
		var item = data[item_id]
		var comma = "," if i_idx < item_keys.size() - 1 else ""
		
		if item is Dictionary:
			# Normal data item (nested object)
			lines.append("%s\"%s\": {" % [indent, item_id])
			lines.append_array(_stringify_object_fields(item, indent_level + 1))
			lines.append("%s}%s" % [indent, comma])
		elif item is Array:
			lines.append("%s\"%s\": %s%s" % [indent, item_id, _value_to_json(item, indent_level), comma])
		else:
			# Primitive values (String, int, float, bool, null) - includes metadata like BUTTONHEADER
			lines.append("%s\"%s\": %s%s" % [indent, item_id, _value_to_json(item, indent_level), comma])
	
	return lines



## Custom stringify untuk flat dictionary format
func _stringify_flat_dict(data: Dictionary) -> String:
	var lines = []
	lines.append("{")
	lines.append("%s\"%s\": {" % [indent_string, root_name])
	
	var flat_data = _flatten_dict(data)
	lines.append_array(_stringify_dict_items(flat_data, 2))
	
	lines.append("%s}" % indent_string)
	lines.append("}")
	
	return "\n".join(lines)

## Custom stringify untuk id-keyed dict format: { "id": { "field1": val, ... } }
## id adalah key dict, value berisi field lainnya sesuai key_order
func _stringify_id_keyed_dict(data: Dictionary) -> String:
	var lines = []
	lines.append("{")
	lines.append("%s\"%s\": {" % [indent_string, root_name])
	
	# Flatten semua entries ke satu dict id -> row_data
	var flat: Dictionary = {}
	for key in data:
		var val = data[key]
		if val is Dictionary:
			var first = val.values()[0] if not val.is_empty() else null
			if first is Dictionary:
				# grouped: { group: { id: row_data } }
				for inner_key in val:
					flat[inner_key] = val[inner_key]
			else:
				# flat: { id: row_data }
				flat[key] = val
		else:
			flat[key] = val
	
	var ids = flat.keys()
	for i in range(ids.size()):
		var entry_id = ids[i]
		var row = flat[entry_id]
		var comma = "," if i < ids.size() - 1 else ""
		if row is Dictionary:
			if not value_field.is_empty() and row.has(value_field):
				lines.append("%s\"%s\": %s%s" % [indent_string.repeat(2), entry_id, _value_to_json(row[value_field], 2), comma])
			else:
				lines.append("%s\"%s\": {" % [indent_string.repeat(2), entry_id])
				# Output fields in key_order, skip "id" field itself
				var ordered_fields = key_order if not key_order.is_empty() else row.keys()
				var field_list = ordered_fields.filter(func(k): return k != "id" and row.has(k))
				for f_idx in range(field_list.size()):
					var field = field_list[f_idx]
					var field_comma = "," if f_idx < field_list.size() - 1 else ""
					lines.append("%s\"%s\": %s%s" % [indent_string.repeat(3), field, _value_to_json(row[field], 3), field_comma])
				lines.append("%s}%s" % [indent_string.repeat(2), comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent_string.repeat(2), entry_id, _value_to_json(row, 2), comma])
	
	lines.append("%s}" % indent_string)
	lines.append("}")
	
	return "\n".join(lines)


## Custom stringify untuk id-keyed dict tanpa root wrapper: { "id": { ... }, ... }
func _stringify_id_keyed_dict_no_root(data: Dictionary) -> String:
	var lines: Array = []
	lines.append("{")

	# Flatten semua entries ke satu dict id -> row_data
	var flat: Dictionary = {}
	for key in data:
		var val = data[key]
		if val is Dictionary:
			var first = val.values()[0] if not val.is_empty() else null
			if first is Dictionary:
				# grouped: { group: { id: row_data } }
				for inner_key in val:
					flat[inner_key] = val[inner_key]
			else:
				# flat: { id: row_data }
				flat[key] = val
		else:
			flat[key] = val

	var ids = flat.keys()
	for i in range(ids.size()):
		var entry_id = ids[i]
		var row = flat[entry_id]
		var comma = "," if i < ids.size() - 1 else ""

		if row is Dictionary:
			if not value_field.is_empty() and row.has(value_field):
				lines.append("%s\"%s\": %s%s" % [indent_string, entry_id, _value_to_json(row[value_field], 1), comma])
			else:
				lines.append("%s\"%s\": {" % [indent_string, entry_id])
				var ordered_fields = key_order if not key_order.is_empty() else row.keys()
				var field_list = ordered_fields.filter(func(k): return k != "id" and row.has(k))
				for f_idx in range(field_list.size()):
					var field = field_list[f_idx]
					var field_comma = "," if f_idx < field_list.size() - 1 else ""
					lines.append("%s\"%s\": %s%s" % [indent_string.repeat(2), field, _value_to_json(row[field], 2), field_comma])
				lines.append("%s}%s" % [indent_string, comma])
		else:
			lines.append("%s\"%s\": %s%s" % [indent_string, entry_id, _value_to_json(row, 1), comma])

	lines.append("}")
	return "\n".join(lines)

## Fungsi untuk menggabungkan semua data dalam dictionary
func _flatten_dict(data: Dictionary) -> Dictionary:
	var result = {}
	for key in data:
		if data[key] is Dictionary:
			var first_value = data[key].values()[0] if not data[key].is_empty() else null
			if first_value is Dictionary:
				for inner_key in data[key]:
					result[inner_key] = data[key][inner_key]
			else:
				result[key] = data[key]
		else:
			result[key] = data[key]
	return result

## Custom stringify untuk array format
func _stringify_array(data) -> String:
	var lines = []
	lines.append("{")
	lines.append("%s\"%s\": [" % [indent_string, root_name])
	
	var array_data: Array = []
	if data is Dictionary:
		array_data = _dict_to_array(data)
	elif data is Array:
		array_data = data
	
	lines.append_array(_stringify_array_items(array_data, 2))
	
	lines.append("%s]" % indent_string)
	lines.append("}")
	
	return "\n".join(lines)

## Custom stringify untuk array format tanpa root wrapper
func _stringify_array_no_root(data) -> String:
	var lines = []
	lines.append("[")
	
	var array_data: Array = []
	if data is Dictionary:
		array_data = _dict_to_array(data)
	elif data is Array:
		array_data = data
	
	lines.append_array(_stringify_array_items(array_data, 1))
	
	lines.append("]")
	
	return "\n".join(lines)

## Fungsi untuk menggabungkan semua data dalam dictionary ke dalam array
func _dict_to_array(data: Dictionary) -> Array:
	var result = []
	for key in data:
		if data[key] is Dictionary:
			var first_value = data[key].values()[0] if not data[key].is_empty() else null
			if first_value is Dictionary:
				for inner_key in data[key]:
					result.append(data[key][inner_key])
			else:
				result.append(data[key])
		else:
			result.append({"id": key, "value": data[key]})
	return result

## Custom stringify untuk array items
func _stringify_array_items(data: Array, indent_level: int) -> Array:
	var lines = []
	var indent = indent_string.repeat(indent_level)
	
	for i_idx in range(data.size()):
		var item = data[i_idx]
		var comma = "," if i_idx < data.size() - 1 else ""
		
		if item is Dictionary:
			lines.append("%s{" % indent)
			lines.append_array(_stringify_object_fields(item, indent_level + 1))
			lines.append("%s}%s" % [indent, comma])
		else:
			lines.append("%s%s%s" % [indent, _value_to_json(item, indent_level), comma])
	
	return lines

## Custom stringify untuk object fields
func _stringify_object_fields(obj: Dictionary, indent_level: int) -> Array:
	var lines = []
	var indent = indent_string.repeat(indent_level)
	
	var keys_to_use = _get_ordered_keys(obj)
	
	for k_idx in range(keys_to_use.size()):
		var key = keys_to_use[k_idx]
		var value = obj[key]
		var value_str = _value_to_json(value, indent_level)
		var comma = "," if k_idx < keys_to_use.size() - 1 else ""
		lines.append("%s\"%s\": %s%s" % [indent, key, value_str, comma])
	
	return lines

## GET keys dalam urutan yang sudah ditentukan
func _get_ordered_keys(obj: Dictionary) -> Array:
	var keys_to_use = []
	
	if not key_order.is_empty():
		for key in key_order:
			if obj.has(key):
				keys_to_use.append(key)
		for key in obj.keys():
			if not keys_to_use.has(key):
				keys_to_use.append(key)
	else:
		keys_to_use = obj.keys()
	
	return keys_to_use

## Fungsi untuk mengubah value menjadi JSON string
func _value_to_json(value, indent_level: int = 0) -> String:
	if value is String:
		return "\"%s\"" % _escape_json_string(value)
	elif value is bool:
		return "true" if value else "false"
	elif value is int:
		return str(value)
	elif value is float:
		# Jika float tanpa pecahan, tampilkan sebagai int agar tidak jadi 1.0 di JSON
		if int(value) == value:
			return str(int(value))
		return str(value)
	elif value is Array:
		return _array_to_json(value, indent_level)
	elif value is Dictionary:
		return _dict_to_json(value, indent_level)
	elif value == null:
		return "null"
	else:
		return "\"%s\"" % str(value)

## Fungsi untuk mengubah array menjadi JSON string
func _array_to_json(arr: Array, indent_level: int) -> String:
	if arr.is_empty():
		return "[]"
	
	var items = []
	for item in arr:
		items.append(_value_to_json(item, indent_level))
	
	var joined = ", ".join(items)
	
	if compact_arrays and joined.length() < compact_threshold:
		return "[%s]" % joined
	
	var indent = indent_string.repeat(indent_level + 1)
	var close_indent = indent_string.repeat(indent_level)
	var formatted_items = []
	for item in arr:
		formatted_items.append("%s%s" % [indent, _value_to_json(item, indent_level + 1)])
	return "[\n%s\n%s]" % [",\n".join(formatted_items), close_indent]

## Fungsi untuk mengubah dictionary menjadi JSON string
func _dict_to_json(dict: Dictionary, indent_level: int) -> String:
	if dict.is_empty():
		return "{}"
	
	var items = []
	for key in dict:
		items.append("\"%s\": %s" % [key, _value_to_json(dict[key], indent_level)])
	
	var joined = ", ".join(items)
	
	if compact_arrays and joined.length() < compact_threshold:
		return "{%s}" % joined
	
	var indent = indent_string.repeat(indent_level + 1)
	var close_indent = indent_string.repeat(indent_level)
	var formatted_items = []
	for key in dict:
		formatted_items.append("%s\"%s\": %s" % [indent, key, _value_to_json(dict[key], indent_level + 1)])
	return "{\n%s\n%s}" % [",\n".join(formatted_items), close_indent]

func _escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s

## Generate JSON khusus untuk GameSettings - group by prefix
func generate_game_settings_json(data: Dictionary) -> String:
	# Prefix mapping: settings_name prefix -> group name
	var prefix_map = {
		"globals_": "Globals",
		"player_": "Player",
		"patron_": "Patron",
		"gameplay_": "Gameplay"
	}
	
	# Group data dari prefix
	var grouped: Dictionary = {}
	for prefix in prefix_map.values():
		grouped[prefix] = {}
	
	# Data bisa dalam format flat {row_id: row_data} atau grouped {group: {row_id: row_data}}
	for key in data.keys():
		var value = data[key]
		if value is Dictionary:
			# Cek apakah ini row_data langsung (memiliki settings_name) atau group
			if value.has("settings_name"):
				# Flat format: langsung row_data
				_process_setting(value, prefix_map, grouped)
			else:
				# Grouped format: value adalah {row_id: row_data}
				for row_id in value.keys():
					var row_data = value[row_id]
					if row_data is Dictionary:
						_process_setting(row_data, prefix_map, grouped)
	
	# Filter non-empty groups
	var non_empty_groups: Array = []
	for group_name in grouped.keys():
		if not grouped[group_name].is_empty():
			non_empty_groups.append(group_name)
	
	# Build JSON output
	var lines = []
	lines.append("{")
	
	for g_idx in range(non_empty_groups.size()):
		var group_name = non_empty_groups[g_idx]
		var group_settings = grouped[group_name]
		var group_comma = "," if g_idx < non_empty_groups.size() - 1 else ""
		
		lines.append("%s\"%s\":" % [indent_string, group_name])
		lines.append("%s{" % [indent_string])
		
		var setting_keys = group_settings.keys()
		for s_idx in range(setting_keys.size()):
			var key = setting_keys[s_idx]
			var value = group_settings[key]
			var comma = "," if s_idx < setting_keys.size() - 1 else ""
			lines.append("%s\"%s\": %s%s" % [indent_string.repeat(2), key, _value_to_json(value, 2), comma])
		
		lines.append("%s}%s" % [indent_string, group_comma])
	
	lines.append("}")
	return "\n".join(lines)

## Helper untuk process single setting
func _process_setting(setting: Variant, prefix_map: Dictionary, grouped: Dictionary) -> void:
	if not setting is Dictionary:
		return
	
	var settings_name: String = setting.get("settings_name", "")
	var value = setting.get("default_value", "")
	
	if settings_name.is_empty():
		return
	
	# Cari prefix yang sesuai
	for prefix in prefix_map.keys():
		if settings_name.begins_with(prefix):
			var group_name = prefix_map[prefix]
			var key_name = settings_name.substr(prefix.length())
			grouped[group_name][key_name] = value
			return
	# No match
	pass
