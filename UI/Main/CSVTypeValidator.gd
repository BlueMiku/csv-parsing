class_name CSVTypeValidator
extends RefCounted

## Validator untuk validasi file CSV berdasarkan type yang terdeteksi

## Validasi file CSV berdasarkan detected type
func validate_file(path: String, detected_type: CSVConfig.CSVType, patron_loader: Node = null) -> Dictionary:
	match detected_type:
		CSVConfig.CSVType.PATRON:
			return _validate_patron(path, patron_loader)

		CSVConfig.CSVType.DIALOG, \
		CSVConfig.CSVType.INGREDIENT, \
		CSVConfig.CSVType.RECIPE, \
		CSVConfig.CSVType.BEVERAGE, \
		CSVConfig.CSVType.DECORATION, \
		CSVConfig.CSVType.KEY_ITEM, \
		CSVConfig.CSVType.NPC_PROPERTIES, \
		CSVConfig.CSVType.GAME_SETTINGS, \
		CSVConfig.CSVType.SFX, \
		CSVConfig.CSVType.MUSIC, \
		CSVConfig.CSVType.BLIP:
			return { "valid": true }

		_:
			return { "valid": false, "message": "Tipe file tidak dikenali" }


## Validasi khusus untuk Patrons type
func _validate_patron(path: String, patron_loader: Node = null) -> Dictionary:
	if patron_loader == null:
		return { "valid": false, "message": "Patron loader tidak ditemukan" }

	var dir = path.get_base_dir()
	var result = patron_loader.validate_files_only(dir)

	if result.get("success", false):
		return { "valid": true }
	else:
		var errors: Array = result.get("errors", [])
		if errors.size() > 0:
			return { "valid": false, "message": "File tidak sesuai format Patrons", "errors": errors }
		return { "valid": false, "message": "File tidak sesuai format Patrons" }


## Validasi cepat (tanpa patron loader) untuk type lain
func validate_quick(path: String, detected_type: CSVConfig.CSVType) -> Dictionary:
	match detected_type:
		CSVConfig.CSVType.PATRON:
			# Untuk patron, validasi sederhana hanya cek file exists
			if not FileAccess.file_exists(path):
				return { "valid": false, "message": "File CSV tidak ditemukan" }
			return { "valid": true }

		CSVConfig.CSVType.DIALOG, \
		CSVConfig.CSVType.INGREDIENT, \
		CSVConfig.CSVType.RECIPE, \
		CSVConfig.CSVType.BEVERAGE, \
		CSVConfig.CSVType.DECORATION, \
		CSVConfig.CSVType.KEY_ITEM, \
		CSVConfig.CSVType.NPC_PROPERTIES, \
		CSVConfig.CSVType.GAME_SETTINGS, \
		CSVConfig.CSVType.SFX, \
		CSVConfig.CSVType.MUSIC, \
		CSVConfig.CSVType.BLIP:
			return { "valid": true }

		_:
			return { "valid": false, "message": "Tipe file tidak dikenali" }


## Cek apakah type membutuhkan validasi khusus
func requires_special_validation(csv_type: CSVConfig.CSVType) -> bool:
	return csv_type == CSVConfig.CSVType.PATRON


## Get list of supported types
static func get_supported_types() -> Array:
	return [
		CSVConfig.CSVType.DIALOG,
		CSVConfig.CSVType.INGREDIENT,
		CSVConfig.CSVType.RECIPE,
		CSVConfig.CSVType.BEVERAGE,
		CSVConfig.CSVType.DECORATION,
		CSVConfig.CSVType.KEY_ITEM,
		CSVConfig.CSVType.PATRON,
		CSVConfig.CSVType.NPC_PROPERTIES,
		CSVConfig.CSVType.GAME_SETTINGS,
		CSVConfig.CSVType.SFX,
		CSVConfig.CSVType.MUSIC,
		CSVConfig.CSVType.BLIP
	]
