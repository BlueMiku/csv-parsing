class_name DataSchemas
extends RefCounted

## Preset skema untuk parsing CSV data

## Schema untuk file Dialog CSV
static func get_dialog_schema() -> Dictionary:
	return {
		"lineid": {"header_name": "lineid", "type": "string", "is_id": true},
		"name": {"header_name": "Name", "type": "string", "default": ""},
		"text": {"header_name": "text", "type": "string", "default": ""},
		"character": {"header_name": "character", "type": "array", "default": []},
		"left": {"header_name": "left", "type": "array", "default": []},
		"middle_left": {"header_name": "middle-left", "type": "array", "default": []},
		"middle": {"header_name": "middle", "type": "array", "default": []},
		"middle_right": {"header_name": "middle-right", "type": "array", "default": []},
		"right": {"header_name": "right", "type": "array", "default": []},
		"scene_properties": {"header_name": "scene_properties", "type": "scene_props", "default": []},
		"dialogue_choice": {"header_name": "dialogue_choice", "type": "string", "default": ""},
		"next_line_properties": {"header_name": "next_line_properties", "type": "next_line", "default": []},
		"give_item": {"header_name": "give_item", "type": "give_item", "default": []},
		"chapterid": {"header_name": "chapter", "type": "string", "default": ""},
		"goto": {"header_name": "goto", "type": "string", "default": ""},
		"special_effects": {"header_name": "special_effects", "type": "array", "default": []},
		"sound_effect": {"header_name": "sound_effects", "type": "string", "default": ""},
		"music_effect": {"header_name": "music_effect", "type": "string", "default": ""},
		"cg": {"header_name": "cg", "type": "cg", "default": []},
	}

## Key order untuk dialog JSON output
static func get_dialog_key_order() -> Array:
	return [
		"lineid", "name", "character", "text",
		"left", "middle_left", "middle", "middle_right", "right",
		"scene_properties", "dialogue_choice", "next_line_properties",
		"give_item", "chapterid", "goto",
		"special_effects", "sound_effect", "music_effect", "cg"
	]

## Dialog parser configuration
static func get_dialog_config() -> Dictionary:
	return {
		"schema": get_dialog_schema(),
		"group_header": "chapter",       # Grouping menggunakan kolom 'chapter'
		"header_row": 0,                   # Header ada di baris pertama (0)
		"start_row": 4,                    # Data dimulai baris ke-5
		"id_header": "lineid",             # lineid sebagai ID
		"metadata_header": "Name",         # Name column untuk deteksi BUTTONHEADER
		"metadata_value_header": "text",   # Text column untuk nilai button header
		"supported_metadata_types": ["BUTTONHEADER"],
		"key_order": get_dialog_key_order()
	}

## Untuk Items Type
## Schema untuk Key Item CSV
static func get_key_item_schema() -> Dictionary:
	return {
	"id": {"header_name": "ID", "type": "int", "is_id": true},
	"filename": {"header_name": "filename", "type": "string", "default": ""},
	"nameEnglish": {"header_name": "name_english", "type": "string", "default": ""},
	"description": {"header_name": "description", "type": "string", "default": ""},
	"bonus": {"header_name": "bonus", "type": "array", "default": []},
	"character": {"header_name": "character", "type": "string", "default": ""},
	}
	
## Key order untuk Key Item JSON output	
static func get_key_item_key_order() -> Array:
	return ["id", "filename", "nameEnglish", "description", "bonus", "character"]
	
## Key Item parser configuration
static func get_key_item_config() -> Dictionary:
	return {
	"schema": get_key_item_schema(),
	"group_header": "",
	"header_row": 0,
	"start_row": 1,
	"id_header": "id",
	"key_order": get_key_item_key_order(),
	"skip_non_numeric_id": true
	}	

## Schema untuk Ingredient Data CSV
static func get_ingredient_schema() -> Dictionary:
	return {
		"id": {"header_name": "IngredientId", "type": "int", "is_id": true},
		"nameEnglish": {"header_name": "Ingredient Name", "type": "string", "default": ""},
		"nameIndonesian": {"header_name": "", "type": "string", "default": null},
		"description": {"header_name": "Description", "type": "string", "default": ""},
		"iconBig": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconHovered": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconFocused": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconDefault": {"header_name": "filename_default", "type": "string", "default": ""},
		"iconFull": {"header_name": "", "type": "string", "default": ""},
		"traits": {
			"type": "nested",
			"fields": {
				"richness": {"header_name": "Richness Gain", "type": "int", "default": 0},
				"boldness": {"header_name": "Boldness Gain", "type": "int", "default": 0},
				"fanciness": {"header_name": "Fanciness Gain", "type": "int", "default": 0}
			}
		},
		"unlockPrice": {"header_name": "Unlock Price", "type": "int_dash", "default": 0},
		"shopLocation": {"header_name": "Where to Get", "type": "string", "default": ""}
	}

## Key order untuk Ingredient JSON output
static func get_ingredient_key_order() -> Array:
	return [
		"id", "nameEnglish", "nameIndonesian", "description",
		"iconBig", "iconHovered", "iconFocused", "iconDefault", "iconFull",
		"traits", "unlockPrice", "shopLocation"
	]

## Ingredient parser configuration
static func get_ingredient_config() -> Dictionary:
	return {
		"schema": get_ingredient_schema(),
		"group_header": "type",           # Group by Type header
		"header_row": 0,                  # Baris ke-0 adalah header
		"start_row": 1,                   # Skip header row
		"id_header": "ingredientid",     # IngredientId sebagai ID
		"key_order": get_ingredient_key_order(),
	}

## Schema untuk Recipe Data CSV
static func get_recipe_schema() -> Dictionary:
	return {
		"id": {"header_name": "FoodId", "type": "int", "is_id": true},
		"nameEnglish": {"header_name": "Name", "type": "string", "default": ""},
		"nameIndonesian": {"header_name": "", "type": "string", "default": null},
		"description": {"header_name": "Description", "type": "string", "default": ""},
		"description1": {"header_name": "Description Custom 1", "type": "string", "default": ""},
		"description2": {"header_name": "Description Custom 2", "type": "string", "default": ""},
		"description3": {"header_name": "Description Custom 3", "type": "string", "default": ""},
		"iconBig": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconHovered": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconFocused": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconFull": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconDefault": {"header_name": "filename", "type": "string", "default": ""},
		"icon3": {"header_name": "", "type": "string", "default": "none"},
		"icon2": {"header_name": "", "type": "string", "default": "none"},
		"icon1": {"header_name": "", "type": "string", "default": "none"},
		"iconEmpty": {"header_name": "", "type": "string", "default": "none"},
		"recipe": {
			"type": "nested",
			"fields": {
				"base_ingredient_id": {"header_name": "Base Ingredients", "type": "recipe_ingredient", "default": -1},
				"seasoning_1_id": {"header_name": "Seasoning 1", "type": "recipe_ingredient", "default": -1},
				"seasoning_2_id": {"header_name": "Seasoning 2", "type": "recipe_ingredient", "default": -1}
			}
		},
		"trait": {"header_name": "Trait", "type": "trait_text", "default": ""},
		"traits": {
			"type": "nested",
			"fields": {
				"richness": {"header_name": "Richness", "type": "int", "default": 0},
				"boldness": {"header_name": "Boldness", "type": "int", "default": 0},
				"fanciness": {"header_name": "Fanciness", "type": "int", "default": 0}
			}
		},
		"price": {"header_name": "Sell Price", "type": "int", "default": 0},
		"eat_duration": {"header_name": "eat_duration", "type": "int", "default": 0}
	}

## Key order untuk Recipe JSON output
static func get_recipe_key_order() -> Array:
	return [
		"id", "nameEnglish", "nameIndonesian", 
		"description", "description1", "description2", "description3",
		"iconBig", "iconHovered", "iconFocused", "iconFull", "iconDefault",
		"icon3", "icon2", "icon1", "iconEmpty",
		"recipe", "trait", "traits", "price", "eat_duration"
	]

## Recipe parser configuration
static func get_recipe_config() -> Dictionary:
	return {
		"schema": get_recipe_schema(),
		"group_header": "",               # No grouping for recipes
		"header_row": 0,                  # Baris ke-0 adalah header
		"start_row": 3,                   # Data dimulai baris ke-2 (skip header)
		"id_header": "foodid",            # FoodId sebagai ID
		"metadata_header": "",            # No metadata
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_recipe_key_order(),
		"output_wrapper": "Foods",        # Wrap output in "Foods" key
		"skip_non_numeric_id": true
	}	

## Schema untuk Beverage Data CSV
static func get_beverage_schema() -> Dictionary:
	return {
		"id": {"header_name": "", "column_index": 0, "type": "int", "default": 0, "is_id": true},
		"isAlcohol": {"header_name": "type", "type": "alcohol_flag", "default": false},
		"nameEnglish": {"header_name": "name", "type": "string", "default": ""},
		"nameIndonesian": {"header_name": "", "type": "string", "default": "placeholder"},
		"description": {"header_name": "description", "type": "string", "default": ""},
		"shop": {"header_name": "shop", "type": "string", "default": ""},
		"keyword": {"header_name": "keywords (unused)", "type": "string", "default": ""},
		"trait": {"header_name": "trait", "type": "string", "default": ""},
		"iconBig": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconHovered": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconFocused": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconFull": {"header_name": "", "type": "string", "default": "placeholder"},
		"iconDefault": {"header_name": "filename", "type": "string", "default": ""},
		"buyPrice": {"header_name": "buy price", "type": "int_dash", "default": 0},
		"sellPrice": {"header_name": "sell price", "type": "int_dash", "default": 0}
	}

## Key order untuk Beverage JSON output
static func get_beverage_key_order() -> Array:
	return [
		"id", "isAlcohol", "nameEnglish", "nameIndonesian", "description",
		"shop", "keyword", "trait", "iconBig", "iconHovered", "iconFocused",
		"iconFull", "iconDefault", "buyPrice", "sellPrice"
	]

## Beverage parser configuration
static func get_beverage_config() -> Dictionary:
	return {
		"schema": get_beverage_schema(),
		"group_header": "",            
		"header_row": 0,
		"start_row": 3,
		"id_header": "",               
		"metadata_header": "",         
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_beverage_key_order(),
		"output_wrapper": "Beverage",
		"skip_non_numeric_id": false
	}
	
## Schema untuk Decoration Data CSV
static func get_decoration_schema() -> Dictionary:
	return {
		"id": {"header_name": "no.", "column_index": 0, "type": "int", "default": 0, "is_id": true},
		"type": {"header_name": "type", "type": "string", "default": ""},
		"nameEnglish": {"header_name": "name", "type": "string", "default": ""},
		"price": {"header_name": "price", "type": "int", "default": 0},
		"description": {"header_name": "description", "type": "string", "default": ""},
		"sprite": {"header_name": "", "type": "string", "default": "placeholder"},
		"monoslot": {"header_name": "", "type": "bool", "default": false},
		"fileName": {"header_name": "filename", "type": "string", "default": ""}
	}

## Key order untuk Decoration JSON output
static func get_decoration_key_order() -> Array:
	return [
		"id", "type", "nameEnglish", "price",
		"description", "sprite", "monoslot", "fileName"
	]
	
## Decoration parser configuration
static func get_decoration_config() -> Dictionary:
	return {
		"schema": get_decoration_schema(),
		"group_header": "",
		"header_row": 1,
		"start_row": 2,
		"id_header": "",
		"metadata_header": "",
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_decoration_key_order(),
		"output_wrapper": "Decorations",
	}	


## Schema untuk SFX.csv
static func get_sfx_schema() -> Dictionary:
	return {
		"id": {"header_name": "id", "type": "string", "default": "", "is_id": true},
		"file_name": {"header_name": "file_name", "type": "array", "default": []},
		"gain": {"header_name": "gain", "type": "float", "default": 0.0},
		"pitch_min_max": {"header_name": "pitch_min_max", "type": "float_range", "default": [1.0, 1.0]}
	}

## Key order untuk SFX JSON output
static func get_sfx_key_order() -> Array:
	return ["file_name", "gain", "pitch_min_max"]

## SFX parser configuration
static func get_sfx_config() -> Dictionary:
	return {
		"schema": get_sfx_schema(),
		"group_header": "",
		"header_row": 0,
		"start_row": 1,
		"id_header": "id",
		"metadata_header": "",
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_sfx_key_order(),
		"skip_non_numeric_id": false
	}

## Schema untuk Music.csv
static func get_music_schema() -> Dictionary:
	return {
		"script_code": {"header_name": "Script Code", "type": "string", "default": "", "is_id": true},
		"filename": {"header_name": "Filename", "type": "string", "default": ""},
		"offset": {"header_name": "Offset", "type": "float_range", "default": [0.0, 0.0]}
	}

## Key order untuk Music JSON output
static func get_music_key_order() -> Array:
	return ["filename", "offset"]

## Music parser configuration
static func get_music_config() -> Dictionary:
	return {
		"schema": get_music_schema(),
		"group_header": "",
		"header_row": 0,
		"start_row": 1,
		"id_header": "script code",
		"metadata_header": "",
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_music_key_order(),
		"skip_non_numeric_id": false
	}

## Schema untuk NPC Properties CSV	
## Schema untuk Colors.csv - Data warna
static func get_npc_colors_schema() -> Dictionary:
	return {
		"type": {"header_name": "Type", "type": "string", "default": ""},
		"color": {"header_name": "Color", "type": "string", "default": "", "is_id": true},
		"color_code_1": {"header_name": "Color Codes", "type": "color_hex", "default": ""},
		"color_code_2": {"header_name": "", "column_index": 3, "type": "color_hex", "default": ""},
		"color_code_3": {"header_name": "", "column_index": 4, "type": "color_hex", "default": ""},
		"color_code_4": {"header_name": "", "column_index": 5, "type": "color_hex", "default": ""}
	}

## Schema untuk NPC Parser Sheet.csv - Data NPC outfit
static func get_npc_outfit_schema() -> Dictionary:
	return {
		"no": {"header_name": "No.", "type": "int", "default": 0, "is_id": true},
		"npc_name": {"header_name": "NPC Name", "type": "string", "default": ""},
		"outfit_sets": {"header_name": "Outfit Sets", "type": "string", "default": ""},
		"tscn_name": {"header_name": "Name .tscn", "type": "string", "default": ""},
		"hair_type": {"header_name": "Parser Hair", "type": "npc_property_array", "default": []},
		"hair_colors": {"header_name": "Parser Hair Color", "type": "npc_property_array", "default": []},
		"accessories": {"header_name": "Parser Accessories", "type": "npc_property_array", "default": []},
		"accessory_colors": {"header_name": "Parser Accessories Color", "type": "npc_property_array", "default": []},
		"body_colors": {"header_name": "Parser Body Color", "type": "npc_property_array", "default": []},
		"eye_colors": {"header_name": "Parser Eye Color", "type": "npc_property_array", "default": []},
		"outfit_colors": {"header_name": "Parser Outfit Color", "type": "npc_property_array", "default": []}
	}

## Key order untuk NPC Colors JSON output
static func get_npc_colors_key_order() -> Array:
	return ["type", "color", "color_code_1", "color_code_2", "color_code_3", "color_code_4"]

## Key order untuk NPC Outfit JSON output  
static func get_npc_outfit_key_order() -> Array:
	return [
		"no", "npc_name", "outfit_sets", "tscn_name",
		"hair_type", "hair_colors", "accessories", "accessory_colors",
		"body_colors", "eye_colors", "outfit_colors"
	]

## NPC Colors parser configuration
static func get_npc_colors_config() -> Dictionary:
	return {
		"schema": get_npc_colors_schema(),
		"group_header": "",
		"header_row": 0,
		"start_row": 1,
		"id_header": "color",
		"metadata_header": "",
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_npc_colors_key_order()
	}

## NPC Outfit parser configuration
static func get_npc_outfit_config() -> Dictionary:
	return {
		"schema": get_npc_outfit_schema(),
		"group_header": "",
		"header_row": 0,
		"start_row": 1,
		"id_header": "no.",
		"metadata_header": "",
		"metadata_value_header": "",
		"supported_metadata_types": [],
		"key_order": get_npc_outfit_key_order()
	}

## NPC Properties multi-file configuration
static func get_npc_properties_config() -> Dictionary:
	return {
		"COLORS": {
			"filename": "Colors.csv",
			"config": get_npc_colors_config(),
			"required_headers": ["color", "color codes"],
			"header_patterns": [["type", "color", "color codes"]]
		},
		"NPC_OUTFIT": {
			"filename": "NPC Parser Sheet.csv",
			"config": get_npc_outfit_config(),
			"required_headers": ["npc name", "parser hair"],
			"header_patterns": [["no.", "npc name", "outfit sets", "parser hair"]]
		},
		"output_structure": {
			"colors": "COLORS",      # Key dalam output JSON -> source data
			"outfit_types": "NPC_OUTFIT"
		},
		"transformers": {
			"colors": "_transform_colors_data",
			"outfit_types": "_transform_outfit_data"
		}
	}

## Schema untuk GameSettings
static func get_game_settings_schema() -> Dictionary:
	return {
		"settings_name": {"header_name": "settings_name", "type": "string", "is_id": true},
		"default_value": {"header_name": "default_value", "type": "settings_value", "default": ""}
	}

## Key order untuk GameSettings JSON output
static func get_game_settings_key_order() -> Array:
	return ["settings_name", "default_value"]

## GameSettings parser configuration
static func get_game_settings_config() -> Dictionary:
	return {
		"schema": get_game_settings_schema(),
		"group_header": "",
		"header_row": 0,
		"start_row": 1,
		"id_header": "settings_name",
		"key_order": get_game_settings_key_order(),
		"output_format": "settings_grouped"  # Custom format untuk grouping by prefix
	}

## Schema untuk Blips
static func get_blip_schema() -> Dictionary:
	return {
		"character_nick": {"header_name": "character_nick", "type": "string", "default": "", "is_id": true},
		"blips": {"header_name": "text_blip", "type": "string", "default": ""},
		"thumb": {"header_name": "thumb", "type": "string", "default": ""},
	}

## Key order untuk Blips JSON output
static func get_blip_key_order() -> Array:
	return ["blips", "thumb"]

static func get_blip_config() -> Dictionary:
	return {
	"schema": get_blip_schema(),
	"group_header": "",
	"header_row": 0,
	"start_row": 1,
	"id_header": "character_nick",
	"key_order": get_blip_key_order(),
	"skip_duplicate_id": true
	}

## Patron System Configuration - Detection by header patterns
static func get_patron_files_config() -> Dictionary:
	return {
		"PATRONS": {
			"filename": "Patrons.csv",
			"char_header": "character_name",
			"required_headers": ["patronid", "character_name", "patron_wealth"]
		},
		"STORY": {
			"filename": "PatronStory.csv",
			"char_header": "character_name",
			"required_headers": ["storyreqs", "character_name", "chapter_name", "storyid"]
		},
		"ORDERS": {
			"filename": "Orders.csv",
			"char_header": "set_order_name",
			"required_headers": ["set_order_name", "entry_1_id", "entry_2_id"]
		},
		"IDLETALK": {
			"filename": "IdleTalkReqs.csv",
			"char_header": "character_name",
			"required_headers": ["idletalkreqs", "character_name", "chapter_name"]
		}
	}

## AreaTriggerStories header patterns untuk deteksi otomatis
static func get_area_trigger_header_patterns() -> Array:
	return [["day", "priority", "expired_on", "start_at", "no_travel", "autocontent"]]

static func get_area_trigger_required_headers() -> Array:
	return ["day", "priority", "expired_on", "no_travel"]
