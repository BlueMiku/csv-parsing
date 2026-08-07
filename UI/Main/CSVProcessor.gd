class_name CSVProcessor
extends RefCounted

## Menangani semua logika processing CSV (single, batch merge, patron, NPC properties)

signal processing_started(message: String)
signal processing_completed(success: bool, message: String)
signal processing_error(errors: Array)
signal processing_warning(errors: Array, json_path: String, warning_ids: Array[String], warning_details: Array[Dictionary], json_text: String, prevent_auto_save: bool)

# Preload scripts
const MergeSystemScript = preload("res://UI/MergeSystem.gd")
const NPCPropertiesScript = preload("res://Data/NPCProperties.gd")

var _parser: Node
var _json_generator: Node
var _patron_loader: Node
var _parent: Node


func _init(parser: Node, json_generator: Node, patron_loader: Node, parent: Node) -> void:
	_parser = parser
	_json_generator = json_generator
	_patron_loader = patron_loader
	_parent = parent


## Cek apakah tipe membutuhkan konfirmasi merge
func should_confirm_merge(type: CSVConfig.CSVType) -> bool:
	match type:
		CSVConfig.CSVType.INGREDIENT, \
		CSVConfig.CSVType.RECIPE, \
		CSVConfig.CSVType.BEVERAGE, \
		CSVConfig.CSVType.DECORATION, \
		CSVConfig.CSVType.KEY_ITEM:
			return true
	return false


## Process single CSV file
func process_single_csv(csv_path: String, output_path: String, csv_type: CSVConfig.CSVType, selected_groups: Array, root_name: String) -> void:
	CSVConfig.configure_all(_parser, _json_generator, csv_type)
	processing_started.emit("Memproses CSV...")
	
	# Parse dalam mode FULL_VALIDATION
	_parser.set_parse_mode(CSVParser.ParseMode.FULL_VALIDATION)
	if not _parser.parse_csv_from_path(csv_path):
		processing_error.emit(["Gagal memproses file CSV"])
		if not _parser.parsing_errors.is_empty():
			processing_error.emit(_parser.get_error_messages())
		return
	
	# Get data
	var data_to_export = _parser.get_filtered_data(selected_groups)
	if data_to_export.is_empty():
		data_to_export = _parser.get_data()
	if data_to_export.is_empty():
		processing_error.emit(["Tidak ada data untuk diekspor."])
		return

	# Generate JSON
	processing_started.emit("Membuat JSON...")
	if csv_type == CSVConfig.CSVType.SFX:
		_json_generator.set_no_root_wrapper(true)
		_json_generator.set_root_name("")
	elif root_name.is_empty():
		_json_generator.set_no_root_wrapper(true)
	else:
		_json_generator.set_no_root_wrapper(false)
		_json_generator.set_root_name(root_name)
	
	var fatal_array_issue: bool = _parser.has_fatal_warnings()
	var json_string: String = ""
	
	# Special handler untuk GAME_SETTINGS
	if csv_type == CSVConfig.CSVType.GAME_SETTINGS:
		json_string = _json_generator.generate_game_settings_json(data_to_export)
		if not json_string.is_empty():
			var file = FileAccess.open(output_path, FileAccess.WRITE)
			if file:
				file.store_string(json_string)
				file.close()
			else:
				processing_error.emit(["Gagal menulis file JSON"])
				return
	elif fatal_array_issue:
		json_string = _json_generator.generate_json_string(data_to_export)
	else:
		json_string = _json_generator.generate_json_to_path(data_to_export, output_path)
	
	if json_string.is_empty():
		processing_error.emit(["Gagal membuat JSON"])
		return
	
	var group_label = CSVConfig.get_group_label(csv_type)
	var status_msg = "Berhasil! Mengekspor %d %s ke: %s" % [data_to_export.size(), group_label, output_path]
	
	# Tampilkan warning jika ada
	if _parser.has_conversion_errors():
		if fatal_array_issue:
			status_msg = "Peringatan fatal: array wajib 5 elemen. File belum disimpan."
		processing_warning.emit(
			_parser.get_error_messages(),
			output_path,
			_parser.get_warning_row_ids(),
			_parser.get_warning_details(),
			json_string if fatal_array_issue else "",
			fatal_array_issue
		)
	else:
		processing_completed.emit(true, status_msg)


## Process batch merge CSV files
func process_batch_merge(base_csv_path: String, final_output_path: String) -> void:
	var folder_path = base_csv_path.get_base_dir()
	var dir = DirAccess.open(folder_path)
	if dir == null:
		processing_error.emit(["Gagal membuka folder " + folder_path])
		return
	
	dir.list_dir_begin()
	var csv_files: Array[String] = []
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			csv_files.append(folder_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if csv_files.is_empty():
		processing_error.emit(["Tidak ada file CSV ditemukan di folder."])
		return
	
	processing_started.emit("Memproses %d file CSV..." % csv_files.size())
	
	var temp_json_paths: Array[String] = []
	var all_errors: Array[String] = []
	var skipped_files: Array[String] = []
	var processed_types: Array[String] = []
	var seen_types: Array[CSVConfig.CSVType] = []
	
	var mergeable_types = [
		CSVConfig.CSVType.INGREDIENT,
		CSVConfig.CSVType.RECIPE,
		CSVConfig.CSVType.BEVERAGE,
		CSVConfig.CSVType.DECORATION,
		CSVConfig.CSVType.KEY_ITEM
	]
	
	# Create temp directory
	var temp_dir = "user://temp_parsing/"
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)
	
	for csv_file in csv_files:
		var file_type = CSVConfig.detect_type(csv_file)
		
		if file_type == CSVConfig.CSVType.UNKNOWN:
			skipped_files.append(csv_file.get_file() + " (tipe tidak dikenali)")
			continue
		
		if file_type not in mergeable_types:
			var type_name = CSVConfig.get_type_name(file_type)
			skipped_files.append(csv_file.get_file() + " (tipe %s tidak dapat di-merge)" % type_name)
			continue
		
		if file_type in seen_types:
			var type_name = CSVConfig.get_type_name(file_type)
			skipped_files.append(csv_file.get_file() + " (duplikasi tipe %s diabaikan)" % type_name)
			continue
		
		seen_types.append(file_type)
		var type_name = CSVConfig.get_type_name(file_type)
		if type_name not in processed_types:
			processed_types.append(type_name)
		
		CSVConfig.configure_all(_parser, _json_generator, file_type)
		_parser.set_parse_mode(CSVParser.ParseMode.FULL_VALIDATION)
		
		if _parser.parse_csv_from_path(csv_file):
			var data = _parser.get_data()
			if not data.is_empty():
				var temp_json_name = csv_file.get_file().replace(".csv", ".json")
				var temp_path = temp_dir.path_join(temp_json_name)
				
				var original_no_root = _json_generator.no_root_wrapper
				
				_json_generator.set_no_root_wrapper(true)
				_json_generator.generate_json_to_path(data, temp_path)
				temp_json_paths.append(temp_path)
				
				_json_generator.set_no_root_wrapper(original_no_root)
			
			if _parser.has_conversion_errors():
				all_errors.append_array(_parser.get_error_messages())
		else:
			all_errors.append("Gagal parse: " + csv_file.get_file())
	
	if not skipped_files.is_empty():
		var skip_msg = "File yang di-skip (%d):\n%s" % [skipped_files.size(), "\n".join(skipped_files)]
		all_errors.insert(0, skip_msg)
	
	if temp_json_paths.is_empty():
		processing_error.emit(["Tidak ada file CSV yang valid untuk di-merge (hanya INGREDIENT, RECIPE, BEVERAGE, DECORATION, KEY_ITEM)."])
		if not all_errors.is_empty():
			processing_error.emit(all_errors)
		if DirAccess.dir_exists_absolute(temp_dir):
			DirAccess.remove_absolute(temp_dir)
		return
	
	# Merge files
	processing_started.emit("Menggabungkan %d hasil parsing..." % temp_json_paths.size())
	var merger = MergeSystemScript.new()
	_parent.add_child(merger)
	var merge_result = merger.merge_json_files(temp_json_paths, final_output_path)
	
	if merge_result.success:
		var types_merged = ", ".join(processed_types)
		var status_msg = "Berhasil menggabungkan %d file [%s] ke: %s" % [temp_json_paths.size(), types_merged, final_output_path]
		processing_completed.emit(true, status_msg)
		if not all_errors.is_empty():
			processing_error.emit(all_errors)
	else:
		processing_error.emit(merge_result.errors + all_errors)
	
	# Cleanup temp files
	for path in temp_json_paths:
		DirAccess.remove_absolute(path)
	
	var remove_dir_err = DirAccess.remove_absolute(temp_dir)
	if remove_dir_err != OK:
		push_warning("Gagal menghapus folder temp: " + temp_dir)
	
	merger.queue_free()


## Process PATRON type CSV
func process_patron_csv(csv_path: String, output_path: String) -> void:
	var selected_patron: String = GlobalData.selected_patron
	if selected_patron.is_empty():
		processing_error.emit(["Tidak ada karakter patron yang dipilih. Pilih karakter dari daftar patron terlebih dahulu."])
		return
	
	var dir: String = csv_path.get_base_dir()
	var output_dir: String = output_path.get_base_dir()
	
	processing_started.emit("Memproses data patron: " + selected_patron + "...")
	
	var result: Dictionary = _patron_loader.process_character(dir, output_dir, selected_patron)
	
	if result.get("success", false):
		var file_path: String = result.get("file_path", "")
		var errors: Array = result.get("errors", [])
		
		if errors.size() > 0:
			processing_completed.emit(true, "JSON berhasil dibuat dengan %d warning: %s" % [errors.size(), file_path])
			processing_warning.emit(
				errors,
				file_path,
				[] as Array[String],
				[] as Array[Dictionary],
				"",
				false
			)
		else:
			processing_completed.emit(true, "JSON berhasil dibuat: " + file_path)
		
		print("[CSVProcessor] Patron JSON saved to: ", file_path)
	else:
		var errors: Array = result.get("errors", [])
		if errors.size() > 0:
			processing_error.emit(errors)
		else:
			processing_error.emit(["Gagal memproses data patron"])


## Process NPC_PROPERTIES type CSV
func process_npc_properties_csv(csv_path: String, output_path: String) -> void:
	var dir_path: String = csv_path.get_base_dir()
	
	processing_started.emit("Memproses data NPC Properties...")
	
	var npc_parser = NPCPropertiesScript.new()
	
	if not npc_parser.parse_from_directory(dir_path):
		var errors = npc_parser.get_error_messages()
		if errors.size() > 0:
			processing_error.emit(errors)
		else:
			processing_error.emit(["Gagal memproses file NPC Properties"])
		return
	
	# Generate output
	var output_data = npc_parser.generate_output()
	
	if output_data.is_empty():
		processing_error.emit(["Tidak ada data untuk diekspor"])
		return
	
	# Convert to JSON string dengan format yang sesuai
	var json_string = NPCProperties.stringify(output_data)
	
	# Save to file
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		processing_error.emit(["Gagal menulis file: " + output_path])
		return
	
	file.store_string(json_string)
	file.close()
	
	# Report success
	var colors_count = output_data.get("colors", {}).size()
	var outfit_count = output_data.get("outfit_types", {}).size()
	processing_completed.emit(true, "Berhasil! %d warna dan %d outfit types diekspor ke: %s" % [colors_count, outfit_count, output_path])
	
	print("[CSVProcessor] NPC Properties JSON saved to: ", output_path)


## Process AREA_TRIGGER type CSV
func process_area_trigger_csv(csv_path: String, output_path: String, area_name: String) -> void:
	if area_name.strip_edges().is_empty():
		processing_error.emit(["Area Name tidak boleh kosong. Isi nama area sebelum generate."])
		return

	processing_started.emit("Memproses Area Trigger: " + area_name + "...")

	var processor := AreaTriggerProcessor.new()
	var result := processor.process_to_file(csv_path, area_name.strip_edges(), output_path)

	if not result.get("success", false):
		var errors: Array = result.get("errors", [])
		if errors.is_empty():
			processing_error.emit(["Gagal memproses file Area Trigger"])
		else:
			processing_error.emit(errors)
		return

	var rows_count: int = result.get("rows_count", 0)
	var skipped: int = result.get("skipped_count", 0)
	var merge_note: String = result.get("merge_note", "")
	var skip_note := (" (%d baris non-data di-skip)" % skipped) if skipped > 0 else ""
	var status_msg := "Berhasil! %d baris diekspor%s%s → %s" % [rows_count, skip_note, merge_note, output_path]

	var proc_errors: Array = result.get("errors", [])
	if proc_errors.size() > 0:
		processing_warning.emit(
			proc_errors,
			output_path,
			[] as Array[String],
			[] as Array[Dictionary],
			"",
			false
		)
	else:
		processing_completed.emit(true, status_msg)

	print("[CSVProcessor] Area Trigger JSON saved to: ", output_path)


## Process CUTSCENE_TRIGGERS type CSV
func process_cutscene_trigger_csv(csv_path: String, output_path: String) -> void:
	processing_started.emit("Memproses Cutscene Triggers...")

	var processor := CutsceneTriggerProcessor.new()
	var result := processor.process_to_file(csv_path, output_path)

	if not result.get("success", false):
		var errors: Array = result.get("errors", [])
		processing_error.emit(errors if not errors.is_empty() else ["Gagal memproses file Cutscene Triggers"])
		return

	var rows_count: int = result.get("rows_count", 0)
	var skipped: int = result.get("skipped_count", 0)
	var skip_note := (" (%d baris di-skip)" % skipped) if skipped > 0 else ""
	var status_msg := "Berhasil! %d trigger diekspor%s → %s" % [rows_count, skip_note, output_path]

	var proc_errors: Array = result.get("errors", [])
	if proc_errors.size() > 0:
		processing_warning.emit(proc_errors, output_path, [] as Array[String], [] as Array[Dictionary], "", false)
	else:
		processing_completed.emit(true, status_msg)

	print("[CSVProcessor] Cutscene Triggers JSON saved to: ", output_path)


## Process SHOP_SETS type CSV
func process_shop_sets_csv(csv_path: String, output_path: String) -> void:
	processing_started.emit("Memproses Shop Sets...")

	var processor := ShopSetsProcessor.new()
	var result := processor.process_to_file(csv_path, output_path)

	if not result.get("success", false):
		var errors: Array = result.get("errors", [])
		processing_error.emit(errors if not errors.is_empty() else ["Gagal memproses file Shop Sets"])
		return

	var sets_count: int = result.get("sets_count", 0)
	var status_msg := "Berhasil! %d shop sets diekspor → %s" % [sets_count, output_path]

	var proc_errors: Array = result.get("errors", [])
	if proc_errors.size() > 0:
		processing_warning.emit(proc_errors, output_path, [] as Array[String], [] as Array[Dictionary], "", false)
	else:
		processing_completed.emit(true, status_msg)

	print("[CSVProcessor] Shop Sets JSON saved to: ", output_path)


## Process GAME_EVENTS type CSV
func process_game_events_csv(csv_path: String, output_path: String) -> void:
	processing_started.emit("Memproses Gameplay Events...")

	var processor := GameplayEventsProcessor.new()
	var result := processor.process_to_file(csv_path, output_path)

	if not result.get("success", false):
		var errors: Array = result.get("errors", [])
		if errors.is_empty():
			processing_error.emit(["Gagal memproses file Gameplay Events"])
		else:
			processing_error.emit(errors)
		return

	var rows_count: int = result.get("rows_count", 0)
	var skipped: int = result.get("skipped_count", 0)
	var skip_note := (" (%d baris non-data di-skip)" % skipped) if skipped > 0 else ""
	var status_msg := "Berhasil! %d event diekspor%s → %s" % [rows_count, skip_note, output_path]

	var proc_errors: Array = result.get("errors", [])
	if proc_errors.size() > 0:
		processing_warning.emit(
			proc_errors,
			output_path,
			[] as Array[String],
			[] as Array[Dictionary],
			"",
			false
		)
	else:
		processing_completed.emit(true, status_msg)

	print("[CSVProcessor] Gameplay Events JSON saved to: ", output_path)
