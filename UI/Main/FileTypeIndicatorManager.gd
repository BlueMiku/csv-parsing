class_name FileTypeIndicatorManager
extends RefCounted

## Manager untuk handle type indicator UI (show/hide/highlight containers)

signal type_selected(file_type: int)

# Container references
var _containers: Dictionary
var _type_detection_section: VBoxContainer

# Style
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat

# State
var _selected_type: int = 0  # FileType.NONE

# Mapping dari CSVType ke FileType
const CSV_TYPE_TO_FILE_TYPE: Dictionary = {
	CSVConfig.CSVType.DIALOG: 2,  # FileType.DIALOG
	CSVConfig.CSVType.INGREDIENT: 3,  # FileType.ITEMS
	CSVConfig.CSVType.RECIPE: 3,  # FileType.ITEMS
	CSVConfig.CSVType.BEVERAGE: 3,  # FileType.ITEMS
	CSVConfig.CSVType.DECORATION: 3,  # FileType.ITEMS
	CSVConfig.CSVType.KEY_ITEM: 3,  # FileType.ITEMS
	CSVConfig.CSVType.PATRON: 1,  # FileType.PATRONS
	CSVConfig.CSVType.NPC_PROPERTIES: 4,  # FileType.NPC_PROPERTIES
	CSVConfig.CSVType.GAME_SETTINGS: 5,  # FileType.SETTINGS
	CSVConfig.CSVType.SFX: 6,  # FileType.SFX
	CSVConfig.CSVType.MUSIC: 7,  # FileType.MUSIC
	CSVConfig.CSVType.BLIP: 8,  # FileType.BLIP
	CSVConfig.CSVType.UNKNOWN: 0  # FileType.NONE
}


func _init(containers: Dictionary, section: VBoxContainer) -> void:
	_containers = containers
	_type_detection_section = section
	_init_styles()


## Initialize styles untuk normal dan selected state
func _init_styles() -> void:
	# Style untuk state normal (transparent dengan border)
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0, 0, 0, 0)
	_style_normal.border_color = Color(0.5, 0.5, 0.5, 1)
	_style_normal.set_border_width_all(1)
	_style_normal.set_corner_radius_all(4)

	# Style untuk state selected (highlight dengan warna)
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.15, 0.4, 0.7, 0.5)
	_style_selected.border_color = Color(0.2, 0.6, 1.0, 1)
	_style_selected.set_border_width_all(2)
	_style_selected.set_corner_radius_all(4)


## Apply style normal ke semua containers
func init_indicators() -> void:
	for container in _get_all_containers():
		container.add_theme_stylebox_override("panel", _style_normal)


## Hide semua type indicators
func hide_all() -> void:
	for container in _get_all_containers():
		container.visible = false
	_type_detection_section.visible = false


## Show type indicator berdasarkan FileType
func show_type(file_type: int) -> void:
	hide_all()
	
	_type_detection_section.visible = true
	
	var container = _get_container_for_type(file_type)
	if container:
		container.visible = true
		container.add_theme_stylebox_override("panel", _style_selected)
		_selected_type = file_type
		type_selected.emit(file_type)


## Show type indicator berdasarkan CSVType (auto-detect)
func show_type_for_csv_type(csv_type: int) -> void:
	var file_type = CSV_TYPE_TO_FILE_TYPE.get(csv_type, 0)
	if file_type != 0:
		show_type(file_type)


## Reset ke state awal (NONE)
func reset() -> void:
	_selected_type = 0
	hide_all()


## GET selected file type
func get_selected_type() -> int:
	return _selected_type


## GET container untuk FileType tertentu
func _get_container_for_type(file_type: int) -> PanelContainer:
	match file_type:
		1: return _containers.get("patrons")
		2: return _containers.get("dialog")
		3: return _containers.get("items")
		4: return _containers.get("npc_properties")
		5: return _containers.get("game_settings")
		6: return _containers.get("sfx")
		7: return _containers.get("music")
		8: return _containers.get("blips")
	return null


## GET semua containers sebagai array
func _get_all_containers() -> Array:
	return [
		_containers.get("patrons"),
		_containers.get("dialog"),
		_containers.get("items"),
		_containers.get("npc_properties"),
		_containers.get("game_settings"),
		_containers.get("sfx"),
		_containers.get("music"),
		_containers.get("blips")
	]
