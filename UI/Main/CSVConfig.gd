class_name CSVConfig
extends RefCounted

## Skrip untuk menentukan tipe CSV dan konfigurasi parser dan generator

enum CSVType {
	DIALOG,
	INGREDIENT,
	RECIPE,
	BEVERAGE,
	DECORATION,
	KEY_ITEM,
	PATRON,
	NPC_PROPERTIES,
	GAME_SETTINGS,
	SFX,
	MUSIC,
	BLIP,
	AREA_TRIGGER,
	UNKNOWN
}

const TYPE_CONFIGS: Dictionary = {
	CSVType.DIALOG: {
		"name": "dialog",
		"group_label": "chapters",
		"root_name": "Default",
		"header_patterns": [["lineid", "text"]],
		"required_headers": ["lineid", "text"]
	},
	CSVType.INGREDIENT: {
		"name": "ingredient",
		"group_label": "categories",
		"root_name": "",
		"header_patterns": [["ingredientid"], ["ingredient name"], ["item", "type"]],
		"required_headers": []
	},
	CSVType.RECIPE: {
		"name": "recipe",
		"group_label": "foods",
		"root_name": "Foods",
		"header_patterns": [["foodid", "name", "base ingredients"]],
		"required_headers": ["foodid", "name"]
	},
	CSVType.BEVERAGE: {
		"name": "beverage",
		"group_label": "items",
		"root_name": "Beverage",
		"header_patterns": [["name", "type", "description", "buy price", "sell price", "filename"]],
		"required_headers": ["name", "type", "filename"]
	},
	CSVType.DECORATION: {
		"name": "decoration",
		"group_label": "items",
		"root_name": "Decorations",
		"header_patterns": [["no.", "type", "filename", "name", "price", "description"]],
		"required_headers": ["no.", "name", "filename"]
	},
	CSVType.KEY_ITEM: {
		"name": "key_item",
		"group_label": "items",
		"root_name": "KeyItems",
		"header_patterns": [["id", "filename", "name_english", "description", "bonus", "character"]],
		"required_headers": ["id", "filename", "name_english"]
	},
	CSVType.PATRON: {
		"name": "patron",
		"group_label": "characters",
		"root_name": "",
		"header_patterns": [
			["patronid", "character_name"],
			["character_name", "patron_wealth"],
			["character_name", "character_name_stranger"],
			["storyreqs", "character_name", "chapter_name", "storyid"],
			["set_order_name", "entry_1_id", "entry_2_id"],
			["idletalkreqs", "character_name", "chapter_name"],
			["idletalkreqs", "character_name", "chapter_name", "storyid"]
		],
		"required_headers": ["character_name"]
	},
	CSVType.NPC_PROPERTIES: {
		"name": "npc_properties",
		"group_label": "npc_data",
		"root_name": "",
		"header_patterns": [
			["type", "color", "color codes"],
			["no.", "npc name", "outfit sets", "parser hair"]
		],
		"required_headers": [],
		"is_multi_file": true
	},
	CSVType.GAME_SETTINGS: {
		"name": "game_settings",
		"group_label": "settings",
		"root_name": "",
		"header_patterns": [["settings_name", "default_value", "keterangan"]],
		"required_headers": ["settings_name", "default_value"]
	},
	CSVType.SFX: {
		"name": "sfx",
		"group_label": "sfx_files",
		"root_name": "",
		"header_patterns": [["no.", "implemented", "id", "gain", "pitch_min_max", "file_name"]],
		"required_headers": ["id", "file_name", "gain"]
	},
	CSVType.MUSIC: {
		"name": "music",
		"group_label": "music_files",
		"root_name": "Music",
		"header_patterns": [["no.", "filename", "offset", "script code", "penggunaan"]],
		"required_headers": ["filename", "script code"]
	},
	CSVType.BLIP: {
		"name": "blip",
		"group_label": "blips",
		"root_name": "",
		"header_patterns": [["character_nick", "text_blip"]],
		"required_headers": ["character_nick", "text_blip"]
	},
	CSVType.AREA_TRIGGER: {
		"name": "area_trigger_stories",
		"group_label": "rows",
		"root_name": "",
		"header_patterns": [["day", "priority", "expired_on", "start_at", "no_travel", "autocontent"]],
		"required_headers": ["day", "priority", "expired_on", "no_travel"],
		"is_custom_processor": true
	},
	CSVType.UNKNOWN: {
		"name": "unknown",
		"group_label": "items",
		"root_name": "",
		"header_patterns": [],
		"required_headers": []
	}
}


## Deteksi tipe CSV dari path file
static func detect_type(csv_path: String) -> CSVType:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_warning("CSVConfig: Gagal membuka file CSV: " + csv_path)
		return CSVType.UNKNOWN
	
	var headers: Array = []
	while not file.eof_reached() and headers.size() < 3:
		headers.append(file.get_line().to_lower())
	file.close()
	
	for header_line in headers:
		var detected = _detect_from_header(header_line, true)
		if detected != CSVType.UNKNOWN:
			return detected
	
	# Jika tetap tidak terdeteksi, warn sekali dengan header pertama
	if headers.size() > 0:
		push_warning("CSVConfig: Format CSV tidak dikenali. Header: " + headers[0])
	return CSVType.UNKNOWN


## Get detailed error message saat CSV type UNKNOWN
static func get_detection_error(csv_path: String) -> String:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return "Gagal membuka file CSV: " + csv_path
	
	var first_line = file.get_line()
	file.close()
	
	var header = first_line.to_lower()
	var error_msg = "Format CSV tidak dikenali.\n\n"
	error_msg += "Header yang ditemukan:\n%s\n\n" % first_line
	return error_msg

## Deteksi tipe CSV dari header string dengan strict validation
static func _detect_from_header(header: String, suppress_warning: bool = false) -> CSVType:
	header = header.to_lower()
	
	# Check GAME_SETTINGS type first (GameSettings.csv)
	for pattern in TYPE_CONFIGS[CSVType.GAME_SETTINGS]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.GAME_SETTINGS
	
	# Check NPC_PROPERTIES type first (Colors.csv, NPC Parser Sheet.csv)
	for pattern in TYPE_CONFIGS[CSVType.NPC_PROPERTIES]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.NPC_PROPERTIES
	
	# Check PATRON type first (Patrons.csv, PatronStory.csv, Orders.csv, IdleTalkReqs.csv)
	for pattern in TYPE_CONFIGS[CSVType.PATRON]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.PATRON
	
	# Check RECIPE type (harus ada foodid dan base ingredients)
	for pattern in TYPE_CONFIGS[CSVType.RECIPE]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.RECIPE
	
	# Check BEVERAGE type
	for pattern in TYPE_CONFIGS[CSVType.BEVERAGE]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.BEVERAGE
	
	# Check DECORATION type
	for pattern in TYPE_CONFIGS[CSVType.DECORATION]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.DECORATION
	
	# Check SFX type
	for pattern in TYPE_CONFIGS[CSVType.SFX]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.SFX
	
	# Check MUSIC type
	for pattern in TYPE_CONFIGS[CSVType.MUSIC]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.MUSIC

	# Check BLIP type
	for pattern in TYPE_CONFIGS[CSVType.BLIP]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.BLIP
	
	# Check KEY_ITEM type
	for pattern in TYPE_CONFIGS[CSVType.KEY_ITEM]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.KEY_ITEM
	
	# Check INGREDIENT type
	for pattern in TYPE_CONFIGS[CSVType.INGREDIENT]["header_patterns"]:
		if _matches_pattern(header, pattern):
			return CSVType.INGREDIENT

	# Check DIALOG type dengan strict validation (harus ada lineid dan text)
	var dialog_required = TYPE_CONFIGS[CSVType.DIALOG]["required_headers"]
	if _matches_pattern(header, dialog_required):
		return CSVType.DIALOG
	
	# Tidak cocok dengan format manapun
	if not suppress_warning:
		push_warning("CSVConfig: Format CSV tidak dikenali. Header: " + header)
	return CSVType.UNKNOWN

## Cek apakah header string memenuhi pattern
static func _matches_pattern(header: String, pattern: Array) -> bool:
	for keyword in pattern:
		if header.find(keyword) < 0:
			return false
	return true


## Configure parser berdasarkan tipe CSV
static func configure_parser(parser: Node, csv_type: CSVType) -> void:
	if parser == null:
		return

	match csv_type:
		CSVType.INGREDIENT:
			parser.configure_for_ingredient()
		CSVType.DIALOG:
			parser.configure_for_dialog()
		CSVType.RECIPE:
			parser.configure_for_recipe()
		CSVType.BEVERAGE:
			parser.configure_for_beverage()
		CSVType.DECORATION:
			parser.configure_for_decoration()
		CSVType.SFX:
			parser.configure_for_sfx()
		CSVType.MUSIC:
			parser.configure_for_music()
		CSVType.KEY_ITEM:
			parser.configure_for_key_item()
		CSVType.PATRON:
			pass # Tipe patron menggunakan parser di PatronDataLoader
		CSVType.NPC_PROPERTIES:
			pass # Tipe NPC_PROPERTIES menggunakan multi-file parser di NPCProperties
		CSVType.GAME_SETTINGS:
			parser.configure_for_game_settings()
		CSVType.BLIP:
			parser.configure_for_blip()
		CSVType.AREA_TRIGGER:
			pass  # Tipe ini menggunakan processor khusus di AreaTriggerProcessor


## Configure generator berdasarkan tipe CSV
static func configure_generator(generator: Node, csv_type: CSVType) -> void:
	if generator == null:
		return

	match csv_type:
		CSVType.INGREDIENT:
			generator.configure_for_ingredient()
		CSVType.DIALOG:
			generator.configure_for_dialog()
		CSVType.RECIPE:
			generator.configure_for_recipe()
		CSVType.BEVERAGE:
			generator.configure_for_beverage()
		CSVType.DECORATION:
			generator.configure_for_decoration()
		CSVType.SFX:
			generator.configure_for_sfx()
		CSVType.MUSIC:
			generator.configure_for_music()
		CSVType.KEY_ITEM:
			generator.configure_for_key_item()
		CSVType.PATRON:
			pass # Tipe patron menggunakan generator di PatronDataLoader
		CSVType.NPC_PROPERTIES:
			pass # Tipe NPC_PROPERTIES menggunakan multi-file generator di NPCProperties
		CSVType.GAME_SETTINGS:
			generator.configure_for_game_settings()
		CSVType.BLIP:
			generator.configure_for_blip()
		CSVType.AREA_TRIGGER:
			pass  # Tipe ini menggunakan processor khusus di AreaTriggerProcessor


## Konfigurasi parser dan generator secara bersamaan
static func configure_all(parser: Node, generator: Node, csv_type: CSVType) -> void:
	configure_parser(parser, csv_type)
	configure_generator(generator, csv_type)

## Get string name dari tipe
static func get_type_name(csv_type: CSVType) -> String:
	return TYPE_CONFIGS.get(csv_type, TYPE_CONFIGS[CSVType.DIALOG])["name"]
## Get label untuk groups berdasarkan tipe
static func get_group_label(csv_type: CSVType) -> String:
	return TYPE_CONFIGS.get(csv_type, TYPE_CONFIGS[CSVType.DIALOG])["group_label"]
## Get default root name berdasarkan tipe
static func get_default_root_name(csv_type: CSVType) -> String:
	return TYPE_CONFIGS.get(csv_type, TYPE_CONFIGS[CSVType.DIALOG])["root_name"]
