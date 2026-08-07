extends Control

## Main UI Controller - Mengelola interaksi UI dan delegate logic ke managers

# Referensi UI
@onready var file_path_edit: LineEdit = %FilePathEdit
@onready var browse_button: Button = %BrowseButton
@onready var output_path_edit: LineEdit = %OutputPathEdit
@onready var output_browse_button: Button = %OutputBrowseButton
@onready var root_name_edit: LineEdit = %RootNameEdit
@onready var generate_button: Button = %GenerateButton
@onready var status_label: Label = %StatusLabel
@onready var file_dialog: FileDialog = %FileDialog
@onready var output_file_dialog: FileDialog = %OutputFileDialog

@onready var chapter_scroll_container: ScrollContainer = %ChapterScrollContainer
@onready var chapter_checkbox_container: VBoxContainer = %ChapterCheckboxContainer
@onready var select_all_button: Button = %SelectAllButton
@onready var deselect_all_button: Button = %DeselectAllButton
@onready var chapter_filter_container: VBoxContainer = %ChapterFilterContainer
@onready var open_json_viewer_button: Button = %OpenJsonViewerButton
@onready var patron_selection_container: VBoxContainer = %PatronSelectionContainer
@onready var patron_checkbox_container: VBoxContainer = %PatronCheckboxContainer

# Type indicator containers (PanelContainer)
@onready var patrons_container: PanelContainer = %PatronsContainer
@onready var dialog_container: PanelContainer = %DialogContainer
@onready var items_container: PanelContainer = %ItemsContainer
@onready var npc_properties_container: PanelContainer = %NPCPropertiesContainer
@onready var game_settings_container: PanelContainer = %GameSettingsContainer
@onready var sfx_container: PanelContainer = %SFXContainer
@onready var music_container: PanelContainer = %MusicContainer
@onready var blips_container: PanelContainer = %BlipsContainer
@onready var area_trigger_container: PanelContainer = %AreaTriggerContainer
@onready var area_name_section: HBoxContainer = %AreaNameSection
@onready var area_name_edit: LineEdit = %AreaNameEdit
@onready var game_events_container: PanelContainer = %GameEventsContainer
@onready var cutscene_trigger_container: PanelContainer = %CutsceneTriggerContainer
@onready var shop_sets_container: PanelContainer = %ShopSetsContainer
@onready var type_detection_section: VBoxContainer = $Panel/VBoxContainer/TypeDetectionSection

@onready var output_section: HBoxContainer = $Panel/VBoxContainer/OutputSection
@onready var root_name_section: HBoxContainer = $Panel/VBoxContainer/RootNameSection
@onready var buttons_container: HBoxContainer = $Panel/VBoxContainer/ButtonsContainer

enum FileType { NONE, PATRONS, DIALOG, ITEMS, NPC_PROPERTIES, SETTINGS, SFX, MUSIC, BLIP, AREA_TRIGGER, GAME_EVENTS, CUTSCENE_TRIGGERS, SHOP_SETS }

# Managers
var _type_indicator_manager: FileTypeIndicatorManager
var _preference_manager: PreferenceManager
var _group_manager: GroupManager
var _patron_manager: PatronsManager
var _csv_processor: CSVProcessor
var _ui_state_manager: UIStateManager
var _dialog_manager: DialogManager
var _validator: CSVTypeValidator

# Core components (tetap di Main untuk lifecycle management)
var _parser: Node
var _json_generator: Node
var _patron_loader: Node

# State
var _selected_file_type: FileType = FileType.NONE
var _current_csv_type: CSVConfig.CSVType = CSVConfig.CSVType.UNKNOWN

# Preload scripts
const CSVParserScript = preload("res://Data/Parser.gd")
const JSONGeneratorScript = preload("res://Data/Json_generate.gd")
const PatronsManagerScript = preload("res://Data/PatronManager/PatronsManager.gd")
const PatronDataLoaderScript = preload("res://Data/PatronManager/PatronDataLoader.gd")

func _ready() -> void:
	_init_managers()
	_connect_signals()
	_hide_all_sections()
	_ui_state_manager.show_type_selection_required()

func _init_managers() -> void:
	# Initialize core components
	_parser = CSVParserScript.new()
	_json_generator = JSONGeneratorScript.new()
	_patron_loader = PatronDataLoaderScript.new()
	add_child(_parser)
	add_child(_json_generator)
	add_child(_patron_loader)

	# Initialize managers
	_type_indicator_manager = _create_type_indicator_manager()
	_preference_manager = PreferenceManager.new()
	_group_manager = GroupManager.new(chapter_checkbox_container, _parser)
	_patron_manager = PatronsManagerScript.new(patron_checkbox_container)
	_ui_state_manager = UIStateManager.new(status_label)
	_dialog_manager = DialogManager.new(self)
	_dialog_manager.setup()
	_validator = CSVTypeValidator.new()

	# Load preferences
	_preference_manager.load_preferences()
	_set_file_dialog_paths()

	_csv_processor = CSVProcessor.new(_parser, _json_generator, _patron_loader, self)

	# Connect manager signals
	_connect_manager_signals()


func _create_type_indicator_manager() -> FileTypeIndicatorManager:
	var containers = {
		"patrons": patrons_container,
		"dialog": dialog_container,
		"items": items_container,
		"npc_properties": npc_properties_container,
		"game_settings": game_settings_container,
		"sfx": sfx_container,
		"music": music_container,
		"blips": blips_container,
		"area_trigger": area_trigger_container,
		"game_events": game_events_container,
		"cutscene_triggers": cutscene_trigger_container,
		"shop_sets": shop_sets_container
	}
	var manager = FileTypeIndicatorManager.new(containers, type_detection_section)
	manager.init_indicators()
	return manager

func _connect_manager_signals() -> void:
	# Type indicator manager
	_type_indicator_manager.type_selected.connect(_on_type_selected)

	# Group manager
	_group_manager.selection_changed.connect(_on_filter_selection_changed)
	_group_manager.chapters_loaded.connect(_on_chapters_loaded)
	_group_manager.load_error.connect(_on_chapter_load_error)

	# Patron manager
	_patron_manager.patron_selected.connect(_on_patron_selected)

	# CSV processor
	_csv_processor.processing_started.connect(_ui_state_manager.update_status)
	_csv_processor.processing_completed.connect(_on_processing_completed)
	_csv_processor.processing_error.connect(_on_processing_error)
	_csv_processor.processing_warning.connect(_on_processing_warning)

	# Dialog manager
	_dialog_manager.merge_confirmed.connect(_on_merge_confirmed)
	_dialog_manager.merge_canceled.connect(_on_merge_canceled)
	_dialog_manager.navigate_to_json_viewer.connect(_on_navigate_to_json_viewer)


func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	output_browse_button.pressed.connect(_on_output_browse_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	output_file_dialog.file_selected.connect(_on_output_file_selected)
	generate_button.pressed.connect(_on_generate_pressed)
	open_json_viewer_button.pressed.connect(_on_open_json_viewer_pressed)
	select_all_button.pressed.connect(_group_manager.select_all)
	deselect_all_button.pressed.connect(_group_manager.deselect_all)

func _on_browse_pressed() -> void:
	file_dialog.title = "Select CSV File"
	if not _preference_manager.get_last_csv_dir().is_empty() and DirAccess.dir_exists_absolute(_preference_manager.get_last_csv_dir()):
		file_dialog.current_dir = _preference_manager.get_last_csv_dir()
	file_dialog.popup_centered()

func _on_output_browse_pressed() -> void:
	if not _preference_manager.get_last_output_dir().is_empty() and DirAccess.dir_exists_absolute(_preference_manager.get_last_output_dir()):
		output_file_dialog.current_dir = _preference_manager.get_last_output_dir()
	output_file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	file_dialog.hide()
	await get_tree().process_frame

	# Save preference
	_preference_manager.set_last_csv_dir(path.get_base_dir())
	_preference_manager.save_preferences()

	# Auto-detect dan highlight type
	var detected_type = CSVConfig.detect_type(path)
	_type_indicator_manager.show_type_for_csv_type(detected_type)
	_selected_file_type = _type_indicator_manager.get_selected_type()

	# Validate
	var validation = _validator.validate_file(path, detected_type, _patron_loader)
	if not validation.valid:
		_ui_state_manager.show_error(validation.message)
		_show_errors(validation.get("errors", []))
		_type_indicator_manager.reset()
		_selected_file_type = FileType.NONE
		return

	# Update UI
	file_path_edit.text = path
	_update_sections_visibility()

	# Handle by type
	match _selected_file_type:
		FileType.PATRONS:
			_handle_patron_file(path)
		FileType.NPC_PROPERTIES:
			_current_csv_type = CSVConfig.CSVType.NPC_PROPERTIES
			_ui_state_manager.show_file_type_selected("NPC Properties")
		FileType.AREA_TRIGGER:
			_current_csv_type = CSVConfig.CSVType.AREA_TRIGGER
			_ui_state_manager.show_file_type_selected("Area Trigger")
			# Auto-extract area name dari nama file (strip prefix seperti "(DEMO) " dan suffix duplikat)
			var raw := path.get_file().get_basename()
			var bracket_end := raw.rfind(") ")
			if bracket_end != -1:
				raw = raw.substr(bracket_end + 2)
			var trail := raw.find("(")
			if trail != -1:
				raw = raw.substr(0, trail).strip_edges()
			if not raw.is_empty():
				area_name_edit.text = raw
		FileType.GAME_EVENTS:
			_current_csv_type = CSVConfig.CSVType.GAME_EVENTS
			_ui_state_manager.show_file_type_selected("Gameplay Events")
		FileType.CUTSCENE_TRIGGERS:
			_current_csv_type = CSVConfig.CSVType.CUTSCENE_TRIGGERS
			_ui_state_manager.show_file_type_selected("Cutscene Triggers")
		FileType.SHOP_SETS:
			_current_csv_type = CSVConfig.CSVType.SHOP_SETS
			_ui_state_manager.show_file_type_selected("Shop Sets")
		_:
			_load_chapters(path)

	# Set default output path
	if output_path_edit.text.is_empty():
		output_path_edit.text = _get_default_output_path(path)

func _on_output_file_selected(path: String) -> void:
	if not path.ends_with(".json"):
		path += ".json"
	output_path_edit.text = path

	# Save preference
	_preference_manager.set_last_output_dir(path.get_base_dir())
	_preference_manager.save_preferences()

func _load_chapters(csv_path: String) -> void:
	_current_csv_type = CSVConfig.detect_type(csv_path)
	_group_manager.load_chapters(csv_path, _current_csv_type)

func _on_chapters_loaded(groups: Array, type_name: String) -> void:
	if groups.is_empty():
		_ui_state_manager.show_file_type_selected(type_name)
		chapter_filter_container.visible = false
		chapter_scroll_container.visible = false
	else:
		chapter_filter_container.visible = true
		chapter_scroll_container.visible = true
		_group_manager.populate(groups)
		var group_label = CSVConfig.get_group_label(_current_csv_type)
		_ui_state_manager.show_groups_found(groups.size(), group_label)

func _on_chapter_load_error(message: String, errors: Array) -> void:
	_ui_state_manager.show_error(message)
	_dialog_manager.show_error_report(errors)

func _handle_patron_file(path: String) -> void:
	var patrons_file_path: String = _patron_loader.get_detected_file_path("PATRONS")
	if not patrons_file_path.is_empty():
		_load_patrons(patrons_file_path)
		patron_selection_container.visible = true
		_ui_state_manager.show_csv_selected_with_patrons()
	else:
		_ui_state_manager.show_file_type_selected("Patrons")

func _load_patrons(path: String) -> void:
	var rows = PatronParser.parse_patron_csv(path)
	if rows.is_empty():
		var filename = path.get_file()
		_ui_state_manager.show_error("Gagal membuka file " + filename)
		return

	var patron_config = DataSchemas.get_patron_files_config()
	var target_header: String = patron_config["PATRONS"]["char_header"]

	var patron_names = []
	var headers = rows[0]
	var name_idx = -1

	for i in range(headers.size()):
		if str(headers[i]).strip_edges().to_lower() == target_header.to_lower():
			name_idx = i
			break

	if name_idx == -1:
		_ui_state_manager.show_error("Kolom '%s' tidak ditemukan di %s" % [target_header, patron_config["PATRONS"]["filename"]])
		patron_selection_container.visible = false
		return

	for i in range(1, rows.size()):
		var row = rows[i]
		if row.size() > name_idx:
			var character_name = str(row[name_idx]).strip_edges()
			if not character_name.is_empty():
				patron_names.append(character_name)

	if patron_names.is_empty():
		_ui_state_manager.show_no_patrons()
		patron_selection_container.visible = false
	else:
		_ui_state_manager.show_patrons_loaded(patron_names.size())
		patron_selection_container.visible = true
		_patron_manager.populate(patron_names)

func _on_patron_selected(patron_name: String) -> void:
	_ui_state_manager.show_patron_selected(patron_name)
	print("[Main] Selected patron saved to GlobalData: ", GlobalData.selected_patron)

	var csv_path = file_path_edit.text.strip_edges()
	if not csv_path.is_empty():
		var dir = csv_path.get_base_dir()
		var result = _patron_loader.load_patron_data(dir, patron_name)
		if result.get("success", false):
			print("[Main] Mapped data for ", patron_name, ": ", result.get("data", {}).keys())
		else:
			var errors: Array = result.get("errors", [])
			if errors.size() > 0:
				_show_errors(errors)

func _on_generate_pressed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()

	if not _validate_paths(csv_path, output_path):
		return

	output_path = output_path.trim_suffix(".json") + ".json"

	match _selected_file_type:
		FileType.PATRONS:
			_csv_processor.process_patron_csv(csv_path, output_path)
		FileType.NPC_PROPERTIES:
			_csv_processor.process_npc_properties_csv(csv_path, output_path)
		FileType.AREA_TRIGGER:
			var area_name := area_name_edit.text.strip_edges()
			if area_name.is_empty():
				_ui_state_manager.show_error("Area Name tidak boleh kosong!")
				return
			_csv_processor.process_area_trigger_csv(csv_path, output_path, area_name)
		FileType.GAME_EVENTS:
			_csv_processor.process_game_events_csv(csv_path, output_path)
		FileType.CUTSCENE_TRIGGERS:
			_csv_processor.process_cutscene_trigger_csv(csv_path, output_path)
		FileType.SHOP_SETS:
			_csv_processor.process_shop_sets_csv(csv_path, output_path)
		FileType.ITEMS:
			_current_csv_type = CSVConfig.detect_type(csv_path)
			if not _is_item_type(_current_csv_type):
				_ui_state_manager.show_error("File CSV tidak sesuai dengan tipe Items")
				return
			_process_with_merge_check(csv_path, output_path)
		_:
			_process_with_merge_check(csv_path, output_path)

func _process_with_merge_check(csv_path: String, output_path: String) -> void:
	if _csv_processor.should_confirm_merge(_current_csv_type):
		_dialog_manager.show_merge_confirmation()
	else:
		_do_generate(csv_path, output_path)

func _do_generate(csv_path: String, output_path: String) -> void:
	var selected_groups = _group_manager.get_selected()
	var root_name = root_name_edit.text.strip_edges()
	_csv_processor.process_single_csv(csv_path, output_path, _current_csv_type, selected_groups, root_name)

func _on_processing_completed(success: bool, message: String) -> void:
	if success:
		_ui_state_manager.show_success(message)
	else:
		_ui_state_manager.show_error(message)

func _on_processing_error(errors: Array) -> void:
	if errors.size() > 0:
		_ui_state_manager.show_error(str(errors[0]))
	call_deferred("_show_errors_deferred", errors)

func _show_errors_deferred(errors: Array) -> void:
	_dialog_manager.show_error_report(errors)

func _on_processing_warning(errors: Array, json_path: String, warning_ids: Array[String], warning_details: Array[Dictionary], json_text: String, prevent_auto_save: bool) -> void:
	# Susun ringkasan bagian yang bermasalah dari warning_details
	var affected_ids: Array[String] = []
	for detail in warning_details:
		var row_id = detail.get("row_id", "")
		if not row_id.is_empty() and row_id not in affected_ids:
			affected_ids.append(row_id)
	
	# Jika tidak ada dari detail, gunakan warning_ids
	if affected_ids.is_empty():
		for wid in warning_ids:
			if not wid.is_empty() and wid not in affected_ids:
				affected_ids.append(wid)
	
	var warning_msg: String
	if prevent_auto_save:
		warning_msg = "Warning fatal: %d baris bermasalah (file belum disimpan)" % errors.size()
	else:
		warning_msg = "Selesai dengan %d peringatan" % errors.size()
		if affected_ids.size() > 0:
			var preview := ", ".join(affected_ids.slice(0, mini(5, affected_ids.size())))
			if affected_ids.size() > 5:
				preview += " ... (+%d lagi)" % (affected_ids.size() - 5)
			warning_msg += " — Bagian bermasalah: [%s]" % preview
	
	_ui_state_manager.show_warning(warning_msg)
	_dialog_manager.show_error_report_with_navigation(errors, json_path, warning_ids, warning_details, json_text, prevent_auto_save)

func _on_merge_confirmed() -> void:
	var csv_path = file_path_edit.text.strip_edges()
	var output_path = output_path_edit.text.strip_edges()
	_csv_processor.process_batch_merge(csv_path, output_path)

func _on_merge_canceled() -> void:
	_ui_state_manager.show_merge_canceled()

func _on_navigate_to_json_viewer() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")

func _on_open_json_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/JSON UI/Json UI.tscn")

func _on_filter_selection_changed(selected: Array) -> void:
	var total = _group_manager.get_total_count()
	var count = _group_manager.get_selected_count()
	var group_label = CSVConfig.get_group_label(_current_csv_type)
	_ui_state_manager.show_selection_changed(count, total, group_label)

func _on_type_selected(file_type: FileType) -> void:
	_selected_file_type = file_type

func _is_item_type(csv_type: CSVConfig.CSVType) -> bool:
	return csv_type in [
		CSVConfig.CSVType.INGREDIENT,
		CSVConfig.CSVType.RECIPE,
		CSVConfig.CSVType.BEVERAGE,
		CSVConfig.CSVType.DECORATION,
		CSVConfig.CSVType.KEY_ITEM,
		CSVConfig.CSVType.BLIP
	]

func _validate_paths(csv_path: String, output_path: String) -> bool:
	if csv_path.is_empty():
		_ui_state_manager.show_error("Please select a CSV file")
		return false

	if output_path.is_empty():
		_ui_state_manager.show_error("Please select output JSON location")
		return false

	return true

func _get_default_output_path(csv_path: String) -> String:
	var dir = csv_path.get_base_dir()
	var filename = csv_path.get_file().get_basename()
	return dir.path_join(filename + ".json")

func _update_sections_visibility() -> void:
	_hide_all_sections()

	match _selected_file_type:
		FileType.PATRONS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.DIALOG:
			output_section.visible = true
			root_name_section.visible = true
			buttons_container.visible = true
		FileType.ITEMS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.NPC_PROPERTIES:
			output_section.visible = true
			buttons_container.visible = true
		FileType.SETTINGS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.SFX:
			output_section.visible = true
			buttons_container.visible = true
		FileType.MUSIC:
			output_section.visible = true
			buttons_container.visible = true
		FileType.BLIP:
			output_section.visible = true
			buttons_container.visible = true
		FileType.AREA_TRIGGER:
			output_section.visible = true
			area_name_section.visible = true
			buttons_container.visible = true
		FileType.GAME_EVENTS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.CUTSCENE_TRIGGERS:
			output_section.visible = true
			buttons_container.visible = true
		FileType.SHOP_SETS:
			output_section.visible = true
			buttons_container.visible = true

func _hide_all_sections() -> void:
	output_section.visible = false
	root_name_section.visible = false
	area_name_section.visible = false
	buttons_container.visible = false
	chapter_filter_container.visible = false
	patron_selection_container.visible = false

func _show_errors(errors: Array) -> void:
	if errors.size() > 0:
		call_deferred("_show_errors_deferred", errors)

func _set_file_dialog_paths() -> void:
	if not _preference_manager.get_last_csv_dir().is_empty() and DirAccess.dir_exists_absolute(_preference_manager.get_last_csv_dir()):
		file_dialog.current_dir = _preference_manager.get_last_csv_dir()
	if not _preference_manager.get_last_output_dir().is_empty() and DirAccess.dir_exists_absolute(_preference_manager.get_last_output_dir()):
		output_file_dialog.current_dir = _preference_manager.get_last_output_dir()
