class_name PatronTransformer
extends RefCounted

## Script untuk mentransformasi data mentah patron ke format JSON

static func generate_character_json(data: Dictionary) -> Dictionary:
	var character_name: String = data.get("character_name", "")
	var patron_info: Dictionary = data.get("patron_info", {})
	var story_data: Array = data.get("story_data", [])
	var orders_data: Array = data.get("orders_data", [])
	var idletalk_data: Array = data.get("idletalk_data", [])
	
	var spawn_req: Array = _parse_array_field(str(patron_info.get("required_story_id_to_spawn", "")))
	var stop_req: Array = _parse_array_field(str(patron_info.get("required_story_id_to_stop","")))
	var json_output: Dictionary = {}

	json_output["character_name"] = character_name
	json_output["character_alias"] = str(patron_info.get("character_alias", ""))
	json_output["character_nick"] = str(patron_info.get("character_nick", ""))
	json_output["character_full"] = str(patron_info.get("character_full", ""))
	json_output["patron_wealth"] = str(patron_info.get("patron_wealth", "Low"))
	json_output["partner_name"] = _build_partner_name(patron_info)
	json_output["is_spawnable"] = _parse_bool(str(patron_info.get("is_spawnable", "TRUE")))
	json_output["is_evening_spawnable"] = _parse_bool(str(patron_info.get("is_evening_spawnable", "TRUE")))
	json_output["is_night_spawnable"] = _parse_bool(str(patron_info.get("is_night_spawnable", "TRUE")))
	json_output["body_type"] = _parse_array_field(str(patron_info.get("body_type", "")))
	json_output["gender"] = _parse_array_field(str(patron_info.get("gender", "")))
	json_output["text_blip"] = str(patron_info.get("text_blip", ""))
	json_output["days_spawnable"] = _parse_days_array(str(patron_info.get("day_spawnable", "")))
	json_output["required_story_id_to_name"] = _parse_array_field(str(patron_info.get("required_story_id_to_name", "")))
	
	json_output["required_story_id_to_spawn"] = spawn_req
	json_output["required_story_id_to_stop"] = stop_req
	json_output["story_requirements"] = _build_story_requirements(story_data)
	json_output["idle_talk_requirements"] = _build_idle_talk_requirements(idletalk_data)
	json_output["orders"] = _build_orders(orders_data, character_name)
	
	return json_output

## partner_name array: [nama_partner, is_partner_left]. is_partner_left hanya ada jika partner_name terisi
static func _build_partner_name(patron_info: Dictionary) -> Array:
	var partner_name: Array = _parse_array_field(str(patron_info.get("partner_name", "")))
	if not partner_name.is_empty():
		partner_name.append(_parse_bool(str(patron_info.get("is_partner_left", "FALSE"))))
	return partner_name

static func _parse_array_field(value: String) -> Array:
	if value.is_empty():
		return []
	var items: PackedStringArray = value.split(",")
	var result: Array = []
	for item in items:
		var stripped: String = item.strip_edges()
		if not stripped.is_empty():
			result.append(stripped)
	return result

static func _parse_bool(value: String) -> bool:
	return value.strip_edges().to_upper() == "TRUE"

static func _parse_days_array(value: String) -> Array:
	if value.is_empty():
		return []
	var items: PackedStringArray = value.split(",")
	var result: Array = []
	for item in items:
		var stripped: String = item.strip_edges()
		if stripped.is_valid_int():
			result.append(stripped.to_int())
	return result

static func _build_story_requirements(story_data: Array) -> Dictionary:
	var story_reqs: Dictionary = {}
	if story_data.is_empty():
		return story_reqs
	
	var unlock_req: Dictionary = {}
	var progress_reqs: Dictionary = {}
	
	for entry in story_data:
		var chapter_name: String = str(entry.get("chapter_name", ""))
		
		var req_entry: Dictionary = {
			"StoryId": _parse_array_field(str(entry.get("StoryId", ""))),
			"Visits": _parse_int(str(entry.get("Visits", "0"))),
			"Other_Visits": _parse_other_visits(str(entry.get("Other_Visits", ""))),
			"key_item": _parse_int(str(entry.get("key_item", "0"))),
			"Duration": _parse_int(str(entry.get("Duration", "0"))),
			"story_time": str(entry.get("story_time", "default")),
			"spawn_override": str(entry.get("spawn_override", "default")),
			"wealth_override": str(entry.get("wealth_override", "default"))
		}
		
		var badge_gain: int = _parse_int(str(entry.get("badge_gain", "0")))
		if badge_gain > 0:
			req_entry["badge_gain"] = badge_gain
		
		if chapter_name == "APPEAR":
			unlock_req = req_entry
		else:
			progress_reqs[chapter_name] = req_entry
	
	if not unlock_req.is_empty():
		story_reqs["UnlockCharacterRequirement"] = unlock_req
	
	if not progress_reqs.is_empty():
		story_reqs["CharacterProgressRequirements"] = progress_reqs
	
	return story_reqs

static func _build_idle_talk_requirements(idletalk_data: Array) -> Dictionary:
	var idle_reqs: Dictionary = {}
	var talk_entries: Dictionary = {}
	
	for entry in idletalk_data:
		var chapter_name: String = str(entry.get("chapter_name", ""))
		if chapter_name.is_empty():
			continue
		
		talk_entries[chapter_name] = {
			"StoryId": str(entry.get("StoryId", "")),
			"key_item": _parse_int(str(entry.get("key_item", "0")))
		}
	
	if not talk_entries.is_empty():
		idle_reqs["IdleTalkRequirements"] = talk_entries
	
	return idle_reqs

static func _build_orders(orders_data: Array, character_name: String) -> Dictionary:
	var orders: Dictionary = {}
	
	for entry in orders_data:
		var order_set_name: String = str(entry.get("set_order_name", ""))
		var set_key: String = "set0"
		var orders_pos: int = order_set_name.find("Orders")
		if orders_pos != -1:
			var set_num: String = order_set_name.substr(orders_pos + 6)
			if not set_num.is_empty():
				set_key = "set" + set_num
		
		if not orders.has(set_key):
			orders[set_key] = {}
		
		var order_no: String = str(entry.get("no.", ""))
		if order_no.is_empty():
			continue
		
		var order_entry: Dictionary = {
			"entry_1_id": _parse_order_id(str(entry.get("entry_1_id", ""))),
			"entry_1_qty": _parse_int(str(entry.get("entry_1_qty", "1"))),
			"entry_2_id": _parse_order_id(str(entry.get("entry_2_id", ""))),
			"entry_2_qty": _parse_int(str(entry.get("entry_2_qty", "1"))),
			"traits": _build_order_traits(entry),
			"weighted_chance": _parse_int(str(entry.get("weighted_chance", "10")))
		}
		
		orders[set_key][order_no] = order_entry
	
	return orders

static func _parse_int(value: String) -> int:
	var stripped: String = value.strip_edges()
	if stripped.is_valid_int():
		return stripped.to_int()
	return 0

static func _parse_other_visits(value: String) -> Array:
	if value.is_empty():
		return []
	var parts: PackedStringArray = value.split(",")
	var result: Array = []
	var i: int = 0
	while i < parts.size():
		var name_part: String = parts[i].strip_edges()
		if not name_part.is_empty():
			if i + 1 < parts.size() and parts[i + 1].strip_edges().is_valid_int():
				result.append({"character": name_part, "visits": parts[i + 1].strip_edges().to_int()})
				i += 2
				continue
			else:
				result.append(name_part)
		i += 1
	return result

static func _parse_order_id(value: String) -> Variant:
	var stripped: String = value.strip_edges()
	if stripped.is_valid_int():
		return stripped.to_int()
	return stripped

static func _build_order_traits(entry: Dictionary) -> Array:
	var traits: Array = []
	var has_trait: bool = false
	var trait_keys: Array = ["trait_1", "trait_2", "trait_3 (drink)"]
	for trait_key in trait_keys:
		var trait_val: String = str(entry.get(trait_key, "")).strip_edges()
		if not trait_val.is_empty() and trait_val != "-":
			traits.append(trait_val)
			has_trait = true
		else:
			traits.append("")
	return traits if has_trait else []
