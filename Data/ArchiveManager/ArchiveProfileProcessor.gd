class_name ArchiveProfileProcessor
extends RefCounted

## Processor untuk Archive List CSV (tab Profiles, Codex, Items, Story, DAN
## Tutorial).
## Format: No.,Tab,TypeButton,json,ParentFolder,SourceId,ContentFormat,Keterangan,
## ButtonTitle,Content,Requirements,image — kolom dideteksi dari header (header-mapped).
## Baris di-branch berdasarkan kolom Tab.
##
## -- Tab Profiles --
## Baris dikelompokkan berdasarkan kolom "json" (satu entry per karakter), dengan
## "stages" berisi setiap baris encounter milik karakter itu, terurut naik
## berdasarkan No. — dipakai ArchiveMenuUi untuk memilih stage tertinggi yang
## requirement-nya sudah terpenuhi di Globals.player_character.completed_stories.
##
## -- Tab Codex, Items & Story --
## Ketiganya pakai mekanisme identik (lihat _parse_folder_itemlist_row()):
## TypeButton membedakan baris "folder" (header grup, mis. "title_folder_glossary")
## dari baris "itemlist" (entry di dalam grup itu). Baris itemlist menaut ke
## folder induknya lewat kolom ParentFolder, yang berisi NILAI NUMERIK kolom
## No. milik baris folder tsb (foreign key eksplisit, bukan inferensi urutan
## baris) — mis. folder "title_folder_glossary" ber-No.=42, lalu itemlist
## "title_augment0" punya ParentFolder=42 untuk menaut ke folder itu.
## SourceId menandai bagian mana di file konten bersama (codex.json / items.json)
## yang dipakai baris itu — kosong untuk Story (lihat di bawah). TIDAK
## divalidasi/di-resolve di sini, cuma dibawa apa adanya untuk dipakai
## ArchiveManager saat runtime. Untuk Items, ContentFormat dan Requirements
## kosong di semua baris (unlock-nya bukan completed_stories-driven seperti
## Codex/Profiles — lihat catatan di ArchiveManager saat itu dibangun) — tetap
## dibawa apa adanya, kosong atau tidak.
## Itemlist yang ParentFolder-nya tidak menunjuk ke folder manapun (typo/folder
## belum ditulis, atau baris placeholder kosong di ujung sheet) di-skip dan
## dicatat sebagai warning, bukan bikin gagal total.
##
## Story berbeda dari Codex/Items dalam DUA hal:
## 1. Kolom "json" per-baris itemlist bukan konstanta ("story"), tapi tag
##    grouping per-karakter (mis. "BagasAgastia", "FhanaChandra", "MainStory")
##    — dibawa apa adanya di key "json" tiap item, TIDAK dipakai untuk grouping
##    di processor ini (beda dari tab Profiles, yang justru grouping by json).
## 2. Kolom Content untuk Story bukan daftar key deskripsi bebas seperti Codex/
##    Items — isinya daftar NAMA STORY FLAG lain (termasuk kemungkinan varian
##    cabang dialog mis. "PROLOGUE1WARM"/"PROLOGUE1COLD"), sementara
##    Requirements cuma satu flag utama. Resolusi mana yang ditampilkan (semua
##    vs pilih salah satu sesuai completed_stories) adalah urusan ArchiveManager
##    saat runtime, bukan processor ini — di sini Content tetap cuma di-split
##    jadi Array string mentah, sama seperti tab lain.
##
## button_title dan content TIDAK di-resolve di sini (semua tab) — keduanya
## tetap berupa key mentah dari CSV, baru di-resolve saat runtime lewat file
## konten (lihat ArchiveProfileContentProcessor untuk Profiles; codex.json
## untuk Codex; items.json untuk Items; Story belum punya file konten sendiri).
## Kolom Keterangan (catatan internal pembuat CSV, tidak pernah dipakai game)
## sengaja tidak dibawa ke output.
## Output: { "Profiles": [ { "json", "stages": [ { "no", "content_format",
## "button_title", "content": [...], "requirements": [...], "image" }, ... ] } ],
## "Codex": [ { "no", "button_title", "requirements": [...], "items": [ { "no",
## "button_title", "content": [...], "content_format", "source_id",
## "requirements": [...], "image", "json" }, ... ] } ], "Items": [ <struktur
## sama seperti Codex> ], "Story": [ <struktur sama seperti Codex — folder-level
## "requirements" populated here (unlike Codex/Items, always []); item-level
## "json" berisi tag karakter> ], "Tutorial": [ { "no", "button_title",
## "content": [...], "content_format", "source_id", "requirements": [...],
## "image", "json" }, ... ] — flat, tanpa folder wrapper (lihat catatan Tab
## Tutorial di atas) }
## -- Tab Tutorial --
## BEDA dari Codex/Items/Story: Tutorial FLAT, tidak ada baris "folder" sama
## sekali di CSV (semua baris Tutorial ber-TypeButton "itemlist", ParentFolder
## selalu kosong) — jadi TIDAK pakai _parse_folder_itemlist_row(). Output-nya
## array item polos, sama shape-nya dengan item Codex/Items/Story (termasuk
## "requirements", dicek lewat completed_stories sama seperti Codex/Profiles —
## unlock Tutorial di gameplay sendiri sudah di-migrasi ke story-flag lewat
## PlayerCharacter.insert_completed_story(), bukan dict Globals.tutorial_state
## yang lama lagi) TANPA key "items"/folder wrapper.
##
## process_to_file() menulis ke output_path dengan merge, bukan overwrite —
## key top-level lain yang sudah ada di file itu dipertahankan; hanya key
## "Profiles", "Codex", "Items", "Story", dan "Tutorial" yang diganti. Parameter
## opsional story_lookup_output_path menulis build_story_chapter_lookup()'s
## hasil ke file TERPISAH (bukan merge — selalu ditimpa ulang, data turunan murni).

var _errors: Array[String] = []


func process(csv_path: String) -> Dictionary:
	_errors.clear()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return _fail("Gagal membuka file CSV: " + csv_path)

	var csv_text := file.get_as_text()
	file.close()

	var lines := csv_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)

	if lines.size() < 2:
		return _fail("CSV tidak memiliki cukup baris (hanya %d baris)." % lines.size())

	# Build header -> index map (case-insensitive, strip whitespace)
	var raw_headers := _parse_line(lines[0])
	var hmap: Dictionary = {}
	for i in range(raw_headers.size()):
		hmap[raw_headers[i].strip_edges().to_lower()] = i

	var required := ["tab", "typebutton", "json", "contentformat", "buttontitle", "content", "requirements"]
	for key in required:
		if not hmap.has(key):
			return _fail("Header CSV tidak sesuai — dibutuhkan kolom %s." % key)

	var profile_groups: Dictionary = {}      # json -> entry dict, insertion-ordered
	var codex_folders: Array = []            # folder entry dicts, insertion-ordered
	var codex_folders_by_no: Dictionary = {} # no (int) -> folder entry dict (same instance as in codex_folders)
	var items_folders: Array = []
	var items_folders_by_no: Dictionary = {}
	var story_folders: Array = []
	var story_folders_by_no: Dictionary = {}
	var tutorial_items: Array = []
	var skipped := 0

	for i in range(1, lines.size()):
		var line := lines[i]
		if line.strip_edges().is_empty():
			continue
		var cols := _parse_line(line)

		var tab_lower := _col(cols, hmap, "tab").to_lower()
		var no_raw := _col(cols, hmap, "no.")
		var no_val: int = no_raw.to_int() if no_raw.is_valid_int() else 0

		if tab_lower == "profiles":
			var json_key := _col(cols, hmap, "json")
			var button_title := _col(cols, hmap, "buttontitle")
			if json_key.is_empty() or button_title.is_empty():
				skipped += 1
				continue

			var stage := {
				"no": no_val,
				"content_format": _col(cols, hmap, "contentformat"),
				"button_title": button_title,
				"content": _split_list(_col(cols, hmap, "content")),
				"requirements": _split_list(_col(cols, hmap, "requirements")),
				"image": _col(cols, hmap, "image"),
			}

			if not profile_groups.has(json_key):
				profile_groups[json_key] = {"json": json_key, "stages": []}
			profile_groups[json_key]["stages"].append(stage)

		elif tab_lower == "codex":
			if not _parse_folder_itemlist_row(cols, hmap, no_val, "Codex", codex_folders, codex_folders_by_no):
				skipped += 1

		elif tab_lower == "items":
			if not _parse_folder_itemlist_row(cols, hmap, no_val, "Items", items_folders, items_folders_by_no):
				skipped += 1

		elif tab_lower == "story":
			if not _parse_folder_itemlist_row(cols, hmap, no_val, "Story", story_folders, story_folders_by_no):
				skipped += 1

		elif tab_lower == "tutorial":
			var button_title := _col(cols, hmap, "buttontitle")
			if button_title.is_empty():
				skipped += 1
				continue
			tutorial_items.append({
				"no": no_val,
				"button_title": button_title,
				"content": _split_list(_col(cols, hmap, "content")),
				"content_format": _col(cols, hmap, "contentformat"),
				"source_id": _col(cols, hmap, "sourceid"),
				"requirements": _split_list(_col(cols, hmap, "requirements")),
				"image": _col(cols, hmap, "image"),
				"json": _col(cols, hmap, "json"),
			})

	var profiles: Array = []
	for json_key in profile_groups.keys():
		var entry = profile_groups[json_key]
		entry["stages"].sort_custom(func(a, b): return a["no"] < b["no"])
		profiles.append(entry)

	var data := {"Profiles": profiles, "Codex": codex_folders, "Items": items_folders, "Story": story_folders, "Tutorial": tutorial_items}
	var json_str := JSON.stringify(data, "\t")

	return {
		"success": true,
		"json_string": json_str,
		"profiles": profiles,
		"profiles_count": profiles.size(),
		"codex": codex_folders,
		"codex_folder_count": codex_folders.size(),
		"items": items_folders,
		"items_folder_count": items_folders.size(),
		"story": story_folders,
		"story_folder_count": story_folders.size(),
		"tutorial": tutorial_items,
		"tutorial_count": tutorial_items.size(),
		"skipped_count": skipped,
		"errors": _errors.duplicate()
	}


## Shared parsing for the folder/itemlist + numeric ParentFolder FK mechanism
## (Codex, Items — Story differs, not handled here). Returns true if the row
## produced a folder or item entry; false if it should count as skipped (the
## caller increments the shared skipped counter — kept here rather than
## returning a count so both call sites stay one-liners).
func _parse_folder_itemlist_row(cols: Array, hmap: Dictionary, no_val: int, tab_label: String, folders: Array, folders_by_no: Dictionary) -> bool:
	var type_button := _col(cols, hmap, "typebutton").to_lower()
	var button_title := _col(cols, hmap, "buttontitle")
	if button_title.is_empty():
		return false

	if type_button == "folder":
		var folder_entry := {
			"no": no_val,
			"button_title": button_title,
			# Always empty for Codex/Items folders; Story folders DO populate
			# this (e.g. "Prologue" -> "PROLOGUE") — whether/how a Story folder
			# actually gates on it at runtime isn't decided yet, just carried
			# through raw here so it's not silently dropped.
			"requirements": _split_list(_col(cols, hmap, "requirements")),
			"items": [],
		}
		folders.append(folder_entry)
		folders_by_no[no_val] = folder_entry
		return true

	elif type_button == "itemlist":
		var parent_raw := _col(cols, hmap, "parentfolder")
		var parent_no: int = parent_raw.to_int() if parent_raw.is_valid_int() else -1
		if not folders_by_no.has(parent_no):
			_errors.append("Baris %s No.%d ('%s') — ParentFolder %s tidak menunjuk ke folder manapun, dilewati." % [tab_label, no_val, button_title, parent_raw])
			return false

		var item := {
			"no": no_val,
			"button_title": button_title,
			"content": _split_list(_col(cols, hmap, "content")),
			"content_format": _col(cols, hmap, "contentformat"),
			"source_id": _col(cols, hmap, "sourceid"),
			"requirements": _split_list(_col(cols, hmap, "requirements")),
			"image": _col(cols, hmap, "image"),
			# Constant "codex"/"items" literal for those two tabs (unused), but
			# for Story this is a per-character grouping tag (e.g. "BagasAgastia",
			# "MainStory") — carried through as-is, not resolved/validated here.
			"json": _col(cols, hmap, "json"),
		}
		folders_by_no[parent_no]["items"].append(item)
		return true

	return false


## Reverse lookup: setiap chapter flag di kolom Content (SEMUA baris itemlist
## Story, lintas folder) -> button_title baris itu. Satu baris dengan N flag
## di Content menghasilkan N entry, semuanya menunjuk ke button_title yang
## sama (mis. "DEMO1_2"/"PROLOGUE1WARM"/"PROLOGUE1COLD"/dst semuanya ->
## "title_demo1_2"). Dipakai save-slot UI: flag chapter mentah yang tersimpan
## di save data (mis. Globals.current_chapter) di-lookup balik ke button_title
## lewat dict ini, lalu button_title itu di-resolve lagi lewat Story.json
## untuk teks yang ditampilkan ke pemain — dua langkah lookup, bukan satu.
func build_story_chapter_lookup(story_folders: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for folder in story_folders:
		for item in folder.get("items", []):
			var button_title: String = item.get("button_title", "")
			for chapter_flag in item.get("content", []):
				lookup[chapter_flag] = button_title
	return lookup


## Menulis hasil parse ke output_path, di-merge ke JSON yang sudah ada di sana
## (bukan overwrite polos) — supaya key tab lain di file yang sama dipertahankan.
## story_lookup_output_path opsional: kalau diisi, build_story_chapter_lookup()
## juga ditulis ke situ SEBAGAI FILE TERPISAH — bukan di-merge (ini murni data
## turunan, aman untuk selalu ditimpa ulang tiap kali CSV diproses lagi, beda
## dari output_path utama yang bisa berbagi file dengan tab lain).
func process_to_file(csv_path: String, output_path: String, story_lookup_output_path: String = "") -> Dictionary:
	var result := process(csv_path)
	if not result.get("success", false):
		return result

	var merged_data := _load_existing_json(output_path)
	merged_data["Profiles"] = result["profiles"]
	merged_data["Codex"] = result["codex"]
	merged_data["Items"] = result["items"]
	merged_data["Story"] = result["story"]
	merged_data["Tutorial"] = result["tutorial"]
	var merged_json_str := JSON.stringify(merged_data, "\t")

	var out_file := FileAccess.open(output_path, FileAccess.WRITE)
	if out_file == null:
		return _fail("Gagal menulis file output: " + output_path)

	out_file.store_string(merged_json_str)
	out_file.close()

	result["json_string"] = merged_json_str
	result["output_path"] = output_path

	if not story_lookup_output_path.is_empty():
		var lookup := build_story_chapter_lookup(result["story"])
		var lookup_file := FileAccess.open(story_lookup_output_path, FileAccess.WRITE)
		if lookup_file == null:
			_errors.append("Gagal menulis file Story chapter lookup: " + story_lookup_output_path)
			result["errors"] = _errors.duplicate()
		else:
			lookup_file.store_string(JSON.stringify(lookup, "\t"))
			lookup_file.close()
			result["story_lookup_output_path"] = story_lookup_output_path
			result["story_lookup_count"] = lookup.size()

	return result


## Baca JSON yang sudah ada di output_path (kalau ada dan valid) supaya bisa
## di-merge, bukan ditimpa. File belum ada / rusak / bukan Dictionary -> {}.
func _load_existing_json(output_path: String) -> Dictionary:
	if not FileAccess.file_exists(output_path):
		return {}
	var file := FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.get_data()
	return data if data is Dictionary else {}


func get_errors() -> Array[String]:
	return _errors


# ── Column helpers ────────────────────────────────────────────────────────────

func _col(cols: Array, h: Dictionary, key: String) -> String:
	if not h.has(key):
		return ""
	var idx: int = h[key]
	if idx >= cols.size():
		return ""
	return JsonUtils.unescape_literal_control_chars(str(cols[idx]).strip_edges())


## Split kolom comma-separated (Content, Requirements) menjadi array string,
## membuang bagian kosong (mis. trailing comma atau field yang sama sekali kosong).
func _split_list(field: String) -> Array:
	var result: Array = []
	if field.strip_edges().is_empty():
		return result
	for part in field.split(","):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


# ── CSV parser ────────────────────────────────────────────────────────────────

## Escaped-quote pairs ("") need BOTH characters consumed as one unit — a
## plain `for i in range(...)` loop can't skip an index, so the previous
## version appended the literal quote for the first "" but then reprocessed
## the second quote as an independent (wrong) toggle, desyncing in_quotes
## for the rest of the line whenever a field contained escaped quotes. Any
## comma after that point got read as a real delimiter instead of literal
## content, corrupting the field and every column after it on that row.
func _parse_line(line: String) -> Array:
	var result: Array = []
	var field := ""
	var in_quotes := false
	var i := 0
	var length := line.length()
	while i < length:
		var c := line[i]
		if c == '"':
			if in_quotes and i + 1 < length and line[i + 1] == '"':
				field += '"'
				i += 1  # also consume the second quote of the escaped pair
			else:
				in_quotes = !in_quotes
		elif c == ',' and not in_quotes:
			result.append(field)
			field = ""
		else:
			field += c
		i += 1
	result.append(field)
	return result


func _fail(msg: String) -> Dictionary:
	_errors.append(msg)
	return {"success": false, "errors": _errors.duplicate()}
