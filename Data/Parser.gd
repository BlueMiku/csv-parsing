extends Node
class_name CSVParser

## Skrip untuk parsing CSV data

# Parsing Mode
enum ParseMode {
	STRUCTURE_ONLY,  # Untuk Load Chapters - hanya struktur
	FULL_VALIDATION  # Untuk Generate - validasi penuh
}

# Configuration
var schema: Dictionary = {}
var group_header: String = ""           # Nama header untuk grouping
var header_row: int = 0                 # Baris mana yang berisi header (0-based)
var start_row: int = 1                  # Baris mulai data (setelah header)
var id_header: String = ""              # Nama header untuk ID
var skip_empty_groups: bool = true
var default_group_name: String = "Uncategorized"
var skip_non_numeric_id: bool = false   # Skip baris dengan ID non-numeric
var skip_duplicate_id: bool = false     # Skip baris jika ID sudah ada (keep yang pertama)

# Metadata configuration (header-based)
var metadata_header: String = ""        # Nama header untuk deteksi metadata type
var metadata_value_header: String = ""  # Nama header untuk nilai metadata
var supported_metadata_types: Array = []

# Dynamic Header Mapping
var _header_map: Dictionary = {}        # Mapping: header_name (lowercase) -> column_index

# Penyimpanan data
var _data_rows: Dictionary = {}
var _available_groups: Array = []
var _group_metadata: Dictionary = {}

# Error collection
var parsing_errors: Array = []  # Array of TransformError atau String
var warning_row_ids: Array[String] = []  # Array untuk menyimpan row_id yang bermasalah
var warning_details: Array[Dictionary] = []
var _current_parse_mode: ParseMode = ParseMode.FULL_VALIDATION

# Fatal warning collection
var fatal_warnings: Array[Dictionary] = []


## SET Configuration
func set_schema(new_schema: Dictionary) -> CSVParser:
	schema = new_schema
	return self
func set_group_header(header: String) -> CSVParser:
	group_header = header.to_lower().strip_edges()
	return self
func set_header_row(row: int) -> CSVParser:
	header_row = row
	return self
func set_start_row(row: int) -> CSVParser:
	start_row = row
	return self
func set_id_header(header: String) -> CSVParser:
	id_header = header.to_lower().strip_edges()
	return self
func set_skip_empty_groups(skip: bool) -> CSVParser:
	skip_empty_groups = skip
	return self
func set_default_group_name(group_name: String) -> CSVParser:
	default_group_name = group_name
	return self
func set_metadata_header(header: String) -> CSVParser:
	metadata_header = header.to_lower().strip_edges()
	return self
func set_metadata_value_header(header: String) -> CSVParser:
	metadata_value_header = header.to_lower().strip_edges()
	return self
func set_supported_metadata_types(types: Array) -> CSVParser:
	supported_metadata_types = types
	return self
func add_metadata_type(meta_type: String) -> CSVParser:
	if not supported_metadata_types.has(meta_type):
		supported_metadata_types.append(meta_type)
	return self

## Set parsing mode (STRUCTURE_ONLY atau FULL_VALIDATION)
func set_parse_mode(mode: ParseMode) -> CSVParser:
	_current_parse_mode = mode
	return self

## Cek apakah ada conversion errors (untuk mode validasi)
func has_conversion_errors() -> bool:
	for err in parsing_errors:
		if err is Dictionary and err.has("row_id"):
			return true
	return false

## Cek apakah ada fatal warnings
func has_fatal_warnings() -> bool:
	return not fatal_warnings.is_empty()

## GET warning row IDs
func get_warning_row_ids() -> Array[String]:
	return warning_row_ids

## GET warning details (ID + column) untuk highlight spesifik
func get_warning_details() -> Array[Dictionary]:
	return warning_details

## GET error messages sebagai array string (untuk tampilan UI)
func get_error_messages() -> Array[String]:
	var messages: Array[String] = []
	for err in parsing_errors:
		if err is Dictionary and err.has("message"):
			messages.append(err.message)
		elif err is String:
			messages.append(err)
	return messages

## GET fatal error messages sebagai array string (untuk tampilan UI)
func get_fatal_error_messages() -> Array[String]:
	var messages: Array[String] = []
	for err in fatal_warnings:
		if err is Dictionary and err.has("message"):
			messages.append(err.message)
	return messages

## Preset Konfigurasi untuk CSV file diambil dari DataSchemas
func configure_for_dialog() -> CSVParser:
	var config = DataSchemas.get_dialog_config()
	_apply_config(config)
	return self

func configure_for_ingredient() -> CSVParser:
	var config = DataSchemas.get_ingredient_config()
	_apply_config(config)
	return self

func configure_for_recipe() -> CSVParser:
	var config = DataSchemas.get_recipe_config()
	_apply_config(config)
	return self

func configure_for_beverage() -> CSVParser:
	var config = DataSchemas.get_beverage_config()
	_apply_config(config)
	return self

func configure_for_decoration() -> CSVParser:
	var config = DataSchemas.get_decoration_config()
	_apply_config(config)
	return self


func configure_for_sfx() -> CSVParser:
	var config = DataSchemas.get_sfx_config()
	_apply_config(config)
	return self

func configure_for_music() -> CSVParser:
	var config = DataSchemas.get_music_config()
	_apply_config(config)
	return self

func configure_for_key_item() -> CSVParser:
	var config = DataSchemas.get_key_item_config()
	_apply_config(config)
	return self

func configure_for_game_settings() -> CSVParser:
	var config = DataSchemas.get_game_settings_config()
	_apply_config(config)
	return self

func configure_for_blip() -> CSVParser:
	var config = DataSchemas.get_blip_config()
	_apply_config(config)
	return self

## Helper function untuk apply config dengan default values
func _apply_config(config: Dictionary) -> void:
	schema = config.get("schema", {})
	group_header = config.get("group_header", "").to_lower()
	header_row = config.get("header_row", 0)
	start_row = config.get("start_row", 1)
	id_header = config.get("id_header", "").to_lower()
	metadata_header = config.get("metadata_header", "").to_lower()
	metadata_value_header = config.get("metadata_value_header", "").to_lower()
	supported_metadata_types = config.get("supported_metadata_types", [])
	skip_non_numeric_id = config.get("skip_non_numeric_id", false)
	skip_duplicate_id = config.get("skip_duplicate_id", false)


## Fungsi untuk parsing CSV file
func parse_csv_from_path(file_path: String) -> bool:
	_clear_data()

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var msg = "Gagal membuka file CSV: " + file_path
		push_error(msg)
		parsing_errors.append(msg)
		return false

	var rows := _read_csv_rows_from_file(file)
	file.close()
	return _parse_csv_rows(rows)

## Fungsi untuk parsing CSV text
func parse_csv_text(csv_text: String) -> bool:
	_clear_data()
	var rows: Array = []
	for record in JsonUtils.split_csv_records(csv_text):
		var line := str(record).strip_edges()
		if line.is_empty():
			continue
		rows.append(parse_csv_line(line))
	return _parse_csv_rows(rows)


## Baca semua record CSV dari file (menghormati field multiline berkutip)
func _read_csv_rows_from_file(file: FileAccess) -> Array:
	var rows: Array = []
	while not file.eof_reached():
		var row: Array = file.get_csv_line()
		if row.is_empty():
			continue
		if row.size() == 1 and str(row[0]).strip_edges().is_empty():
			continue
		rows.append(JsonUtils.normalize_csv_row(row))
	return rows


## Proses baris CSV yang sudah dipecah menjadi array field
func _parse_csv_rows(rows: Array) -> bool:
	if schema.is_empty():
		var msg = "Schema tidak ditemukan. Pastikan tipe CSV sudah dikonfigurasi dengan benar."
		push_warning(msg)
		parsing_errors.append(msg)
		return false

	if rows.size() <= header_row:
		var msg = "File CSV tidak memiliki cukup baris. Header row: %d, total baris: %d" % [header_row, rows.size()]
		push_warning(msg)
		parsing_errors.append(msg)
		return false

	if not _build_header_map_from_row(rows[header_row]):
		return false

	_validate_schema_headers()

	for i in range(start_row, rows.size()):
		var row: Array = rows[i]

		if _is_metadata_row(row):
			_store_metadata(row)
			continue

		# Skip if ID column is empty
		if not id_header.is_empty() and _header_map.has(id_header):
			var id_col = _header_map[id_header]
			if id_col >= 0 and id_col < row.size() and row[id_col].strip_edges().is_empty():
				continue

		if skip_non_numeric_id and _should_skip_non_numeric_row(row):
			continue

		var row_data = _process_row(row, i + 1)
		if row_data.is_empty():
			continue

		_store_row_data(row, row_data)

	_update_available_groups()
	return true


## Cek apakah baris harus di-skip karena ID non-numeric
func _should_skip_non_numeric_row(row: Array) -> bool:
	# Cari kolom ID dari schema
	for field_name in schema:
		var field_config = schema[field_name]
		if field_config.get("is_id", false):
			var header_name = field_config.get("header_name", "").to_lower()
			var col_index = -1
			
			if field_config.has("column_index"):
				col_index = field_config.get("column_index")
			elif _header_map.has(header_name):
				col_index = _header_map[header_name]
			
			if col_index >= 0 and col_index < row.size():
				var id_value = row[col_index].strip_edges()
				# Skip jika ID kosong atau tidak bisa dikonversi ke integer
				if id_value.is_empty() or not id_value.is_valid_int():
					return true
			break
	return false


## Build header map dari baris header CSV (string mentah)
func _build_header_map(header_line: String) -> bool:
	return _build_header_map_from_row(parse_csv_line(header_line))


## Build header map dari array field header
func _build_header_map_from_row(headers: Array) -> bool:
	_header_map.clear()

	if headers.is_empty():
		var msg = "Header CSV kosong atau tidak valid."
		push_warning(msg)
		parsing_errors.append(msg)
		return false

	for i in range(headers.size()):
		var header_name = str(headers[i]).strip_edges().to_lower()
		if not header_name.is_empty():
			_header_map[header_name] = i

	return true

## Validasi semua header yang dibutuhkan schema ada dalam CSV
func _validate_schema_headers() -> void:
	for field_name in schema:
		var field_config = schema[field_name]
		var field_type = field_config.get("type", "string")
		
		if field_type == "nested":
			# Validasi nested fields
			var nested_fields = field_config.get("fields", {})
			for nested_key in nested_fields:
				var nested_config = nested_fields[nested_key]
				var header_name = nested_config.get("header_name", "").to_lower()
				var has_column_index = nested_config.has("column_index")
				if header_name.is_empty() and has_column_index:
					continue
				if not header_name.is_empty() and not _header_map.has(header_name):
					var msg = "Header tidak ditemukan: '%s' untuk field '%s.%s'. Akan menggunakan nilai default." % [header_name, field_name, nested_key]
					push_warning(msg)
					parsing_errors.append(msg)
		else:
			var header_name = field_config.get("header_name", "").to_lower()
			var has_column_index = field_config.has("column_index")
			if header_name.is_empty() and has_column_index:
				continue
			if not header_name.is_empty() and not _header_map.has(header_name):
				var msg = "Header tidak ditemukan: '%s' untuk field '%s'. Akan menggunakan nilai default." % [header_name, field_name]
				push_warning(msg)
				parsing_errors.append(msg)
	
	# Validasi group_header jika diset
	if not group_header.is_empty() and not _header_map.has(group_header):
		var msg = "Header untuk grouping tidak ditemukan: '%s'. Data tidak akan dikelompokkan." % group_header
		push_warning(msg)
		parsing_errors.append(msg)
	
	# Validasi id_header jika diset
	if not id_header.is_empty() and not _header_map.has(id_header):
		var msg = "Header untuk ID tidak ditemukan: '%s'. Akan menggunakan random ID." % id_header
		push_warning(msg)
		parsing_errors.append(msg)

## Mengosongkan data penyimpanan
func _clear_data() -> void:
	_data_rows.clear()
	_available_groups.clear()
	_group_metadata.clear()
	_header_map.clear()
	parsing_errors.clear()
	warning_row_ids.clear()
	warning_details.clear()
	fatal_warnings.clear()

## Public wrapper untuk parsing satu baris CSV menjadi array
func parse_csv_line(line: String) -> Array:
	return JsonUtils.parse_csv_line(line)

## Mengubah satu baris CSV menjadi dictionary menggunakan Dynamic Header Mapping
func _process_row(row: Array, row_number: int = 0) -> Dictionary:
	if schema.is_empty():
		return {}
	
	var result = {}
	var row_id = _get_row_id_preview(row)
	var errors_before_count = parsing_errors.size()
	
	# Gunakan temporary error log jika mode STRUCTURE_ONLY
	var error_log = parsing_errors if _current_parse_mode == ParseMode.FULL_VALIDATION else []
	
	for field_name in schema:
		var field_config = schema[field_name]
		var field_type = field_config.get("type", "string")
		
		# Handle nested fields
		if field_type == "nested":
			var nested_fields = field_config.get("fields", {})
			var nested_result = {}
			for nested_key in nested_fields:
				var nested_config = nested_fields[nested_key]
				var nested_header = nested_config.get("header_name", "").to_lower()
				var nested_type = nested_config.get("type", "string")
				var nested_default = nested_config.get("default", "")
				var use_column_index = nested_config.has("column_index")
				var nested_col_index = nested_config.get("column_index", -1)
				if not nested_header.is_empty() and _header_map.has(nested_header):
					nested_col_index = _header_map[nested_header]
				elif use_column_index:
					nested_col_index = nested_config.column_index
				if nested_col_index < 0 or nested_col_index >= row.size():
					nested_result[nested_key] = nested_default
					continue
				var nested_raw = row[nested_col_index].strip_edges()
				var nested_context = "Baris %d [ID: %s], Kolom: %s.%s" % [row_number, row_id, field_name, nested_key]
				nested_result[nested_key] = FieldTransformers.transform(nested_raw, nested_type, nested_default, error_log, nested_context, row_id, row_number, "%s.%s" % [field_name, nested_key])
			result[field_name] = nested_result
			continue
		
		# Handle normal fields
		var header_name = field_config.get("header_name", "").to_lower()
		var default_value = field_config.get("default", "")
		var use_column_index = field_config.has("column_index")
		var column_index = field_config.get("column_index", -1)
		
		# Lookup column index dari _header_map atau fallback column_index
		if not header_name.is_empty() and _header_map.has(header_name):
			column_index = _header_map[header_name]
		elif use_column_index:
			column_index = field_config.column_index
		else:
			result[field_name] = default_value
			continue
		
		if column_index >= row.size() or column_index < 0:
			result[field_name] = default_value
			continue
		
		var raw_value = row[column_index].strip_edges()
		var context = "Baris %d [ID: %s], Kolom: %s" % [row_number, row_id, field_name]
		result[field_name] = FieldTransformers.transform(raw_value, field_type, default_value, error_log, context, row_id, row_number, field_name)
	
	# Jika Full Validasi maka track row_id dan kolom yang memiliki error
	if _current_parse_mode == ParseMode.FULL_VALIDATION:
		var errors_after_count = parsing_errors.size()
		if errors_after_count > errors_before_count and not row_id.is_empty():
			if not warning_row_ids.has(row_id):
				warning_row_ids.append(row_id)
			for i in range(errors_before_count, errors_after_count):
				var err = parsing_errors[i]
				if err is Dictionary:
					if err.get("is_fatal", false):
						fatal_warnings.append(err)
					# Inline _extract_field_name_from_context logic
					var field_name_from_err = ""
					var texts: Array = [
						err.get("field_name", "").strip_edges(),
						err.get("message", "").strip_edges()
					]
					for text in texts:
						if text.is_empty():
							continue
						var kolom_idx = text.find("Kolom:")
						if kolom_idx != -1:
							var after_kolom = text.substr(kolom_idx + 6).strip_edges()
							var header_idx = after_kolom.find(" (header:")
							if header_idx != -1:
								field_name_from_err = after_kolom.substr(0, header_idx).strip_edges()
							else:
								var dot_idx = after_kolom.find(".")
								if dot_idx != -1:
									field_name_from_err = after_kolom.substr(0, dot_idx).strip_edges()
								else:
									field_name_from_err = after_kolom.strip_edges()
							break
						else:
							field_name_from_err = text
							break
					if field_name_from_err.is_empty():
						continue
					var detail = {"id": row_id, "column": field_name_from_err, "_pending_group": true}
					warning_details.append(detail)
	
	# Skip rows with empty ID
	var id_field = _get_id_field_name()
	if id_field != "" and result.has(id_field):
		var id_val = result[id_field]
		# Skip jika ID kosong
		if str(id_val).strip_edges().is_empty():
			return {}
		# Skip jika ID adalah 0 (default dari konversi gagal) dan raw value bukan "0"
		# Hanya berlaku untuk tipe int, skip untuk tipe string
		if id_val is int and id_val == 0:
			# Cek raw value dari kolom ID
			var id_col = -1
			var id_config = schema.get(id_field, {})
			var id_header = id_config.get("header_name", "").to_lower()
			if not id_header.is_empty() and _header_map.has(id_header):
				id_col = _header_map[id_header]
			elif id_config.has("column_index"):
				id_col = id_config.get("column_index", -1)
			if id_col >= 0 and id_col < row.size():
				var raw_id = row[id_col].strip_edges()
				# Jika raw bukan "0" tapi hasil konversi 0, berarti konversi gagal - skip baris ini
				if raw_id != "0" and not raw_id.is_valid_int():
					return {}
	
	# Calculate trait text untuk recipe jika traits dan trait field ada
	if result.has("traits") and result.has("trait"):
		var traits = result.get("traits", {})
		if traits is Dictionary:
			var richness = traits.get("richness", 0)
			var boldness = traits.get("boldness", 0)
			var fanciness = traits.get("fanciness", 0)
			# Hanya calculate jika ada nilai valid (bukan default -9999)
			if richness != -9999 and boldness != -9999 and fanciness != -9999:
				result["trait"] = FieldTransformers.calculate_trait_text(richness, boldness, fanciness)
			else:
				result["trait"] = "   "  # Default 3 spasi untuk invalid values
	
	# Terapkan default icon khusus ingredient berdasarkan tipe
	_apply_ingredient_icon_defaults(row, result)
	
	return result

## Preview ID untuk baris (sebelum parsing penuh) menggunakan header mapping
func _get_row_id_preview(row: Array) -> String:
	if not id_header.is_empty() and _header_map.has(id_header):
		var col_index = _header_map[id_header]
		if col_index < row.size():
			var id_val = row[col_index].strip_edges()
			if not id_val.is_empty():
				return id_val
	# Fallback: cari field dengan is_id dan column_index
	for field_name in schema:
		var cfg = schema[field_name]
		if cfg.get("is_id", false) and cfg.has("column_index"):
			var idx = int(cfg.get("column_index", -1))
			if idx >= 0 and idx < row.size():
				var raw_id = row[idx].strip_edges()
				if not raw_id.is_empty():
					return raw_id
	return "tidak diketahui"

## Menyimpan data baris ke penyimpanan data
func _store_row_data(row: Array, row_data: Dictionary) -> void:
	var row_id = _get_row_id(row, row_data)
	
	# Cek apakah grouping diaktifkan dan header ditemukan
	if not group_header.is_empty() and _header_map.has(group_header):
		var group_col = _header_map[group_header]
		if group_col < row.size():
			var group_key = row[group_col].strip_edges()
			# Normalisasi khusus ingredient agar sesuai contoh JSON
			group_key = _normalize_group_key(group_key)
			
			if group_key.is_empty():
				if skip_empty_groups:
					return
				else:
					group_key = default_group_name
			
			if not _data_rows.has(group_key):
				_data_rows[group_key] = {}
			
			if skip_duplicate_id and _data_rows[group_key].has(row_id):
				return
				
			_data_rows[group_key][row_id] = row_data
			
			# Update warning_details dengan group info untuk row ini
			_update_warning_details_with_group(row_id, group_key)
			return
	
	if skip_duplicate_id and _data_rows.has(row_id):
		return
		
	# Tidak ada grouping, simpan langsung
	_data_rows[row_id] = row_data

func _normalize_group_key(group_key: String) -> String:
	if group_header == "type":
		var lowered = group_key.to_lower()
		if lowered == "base":
			return "Main"
		if lowered == "seasoning":
			return "Seasoning"
	return group_key


## Update warning_details dengan group info untuk row_id tertentu
## Hanya update detail yang memiliki marker _pending_group (baru ditambahkan di row ini)
func _update_warning_details_with_group(row_id: String, group_key: String) -> void:
	for i in range(warning_details.size()):
		var detail = warning_details[i]
		# Hanya update detail yang match row_id dan memiliki _pending_group marker
		if detail.get("id") == row_id and detail.has("_pending_group"):
			warning_details[i]["group"] = group_key
			warning_details[i].erase("_pending_group")  # Hapus marker

## GET ID untuk baris data
func _get_row_id(row: Array, row_data: Dictionary) -> String:
	# Coba dari row_data (sudah di-transform)
	var id_field = _get_id_field_name()
	if id_field != "" and row_data.has(id_field):
		return str(row_data[id_field])
	
	# Coba dari row langsung via header mapping
	if not id_header.is_empty() and _header_map.has(id_header):
		var col_index = _header_map[id_header]
		if col_index < row.size():
			var id_val = row[col_index].strip_edges()
			if not id_val.is_empty():
				return id_val
	
	return str(randi())

## GET ID field name
func _get_id_field_name() -> String:
	for field_name in schema:
		if schema[field_name].get("is_id", false):
			return field_name
	return ""

## Update list group yang tersedia
func _update_available_groups() -> void:
	_available_groups.clear()
	# Jika grouping aktif, ambil semua group keys
	if not group_header.is_empty() and _header_map.has(group_header):
		for group in _data_rows.keys():
			if not _available_groups.has(group):
				_available_groups.append(group)



## Cek apakah baris ini adalah metadata
func _is_metadata_row(row: Array) -> bool:
	if metadata_header.is_empty() or not _header_map.has(metadata_header):
		return false
	
	var meta_col = _header_map[metadata_header]
	if meta_col >= row.size():
		return false
	
	var meta_type = row[meta_col].strip_edges()
	return supported_metadata_types.has(meta_type)

## Simpan metadata ke penyimpanan metadata
func _store_metadata(row: Array) -> void:
	# Validasi group_header ada
	if group_header.is_empty() or not _header_map.has(group_header):
		return
	
	var group_col = _header_map[group_header]
	if group_col >= row.size():
		return
	
	var group_key = row[group_col].strip_edges()
	if group_key.is_empty():
		return
	
	# Get metadata type
	if metadata_header.is_empty() or not _header_map.has(metadata_header):
		return
	
	var meta_col = _header_map[metadata_header]
	if meta_col >= row.size():
		return
	
	var meta_type = row[meta_col].strip_edges()
	
	# Get metadata value
	var meta_value = ""
	if not metadata_value_header.is_empty() and _header_map.has(metadata_value_header):
		var value_col = _header_map[metadata_value_header]
		if value_col < row.size():
			meta_value = row[value_col].strip_edges()
	
	if not _group_metadata.has(group_key):
		_group_metadata[group_key] = {}
	
	_group_metadata[group_key][meta_type] = meta_value

## GET Functions
func get_data() -> Dictionary:
	return _data_rows
func get_data_with_metadata() -> Dictionary:
	return _merge_metadata_into_data(_data_rows)
func get_group_metadata() -> Dictionary:
	return _group_metadata
func get_metadata_for_group(group_key: String) -> Dictionary:
	return _group_metadata.get(group_key, {})
func get_available_groups() -> Array:
	return _available_groups
	
## GET data yang telah difilter	
func get_filtered_data(selected_groups: Array) -> Dictionary:
	if selected_groups.is_empty():
		return _merge_metadata_into_data(_data_rows)
	
	var filtered = {}
	for group in selected_groups:
		if _data_rows.has(group):
			filtered[group] = _data_rows[group]
	return _merge_metadata_into_data(filtered)
	
## GET data dalam bentuk array	
func get_data_as_array() -> Array:
	var result = []
	# Cek apakah data dikelompokkan
	var is_grouped = not group_header.is_empty() and _header_map.has(group_header)
	if is_grouped:
		for group in _data_rows:
			for id in _data_rows[group]:
				result.append(_data_rows[group][id])
	else:
		for id in _data_rows:
			result.append(_data_rows[id])
	return result

## Merge metadata ke data
func _merge_metadata_into_data(data: Dictionary) -> Dictionary:
	var result = {}
	for group_key in data:
		result[group_key] = {}
		# Add metadata first
		if _group_metadata.has(group_key):
			for meta_key in _group_metadata[group_key]:
				result[group_key][meta_key] = _group_metadata[group_key][meta_key]
		# Then add data items
		for item_key in data[group_key]:
			result[group_key][item_key] = data[group_key][item_key]
	return result

func _apply_ingredient_icon_defaults(row: Array, row_data: Dictionary) -> void:
	if not row_data.has("iconBig") or not _header_map.has(group_header):
		return
	var type_value := ""
	if group_header != "" and _header_map.has(group_header):
		var type_col = _header_map[group_header]
		if type_col < row.size():
			type_value = row[type_col].strip_edges().to_lower()
	if type_value == "seasoning":
		for field in ["iconBig", "iconHovered", "iconFocused", "iconFull"]:
			if row_data.get(field, "") in ["", "placeholder"]:
				row_data[field] = "none"
	elif type_value == "base":
		for field in ["iconBig", "iconHovered", "iconFocused", "iconFull"]:
			if row_data.get(field, "") == "":
				row_data[field] = "placeholder"
		# Hapus field ekonomi yang tidak muncul di contoh Base
		if row_data.has("unlockPrice") and row_data.get("unlockPrice", 0) == 0:
			row_data.erase("unlockPrice")
		if row_data.has("shopLocation") and str(row_data.get("shopLocation", "")).strip_edges() == "":
			row_data.erase("shopLocation")
	elif type_value != "":
		for field in ["iconBig", "iconHovered", "iconFocused", "iconFull"]:
			if row_data.get(field, "") == "":
				row_data[field] = "placeholder"
