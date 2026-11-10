class_name UpdateManager
extends Node

## Auto-updater: cek release terbaru di GitHub Releases, download exe baru, lalu
## ganti exe yang sedang berjalan lewat script PowerShell kecil (exe yang sedang
## jalan tidak bisa ditimpa dari dalam prosesnya sendiri, jadi penggantian
## dilakukan setelah aplikasi menutup).
## Versi saat ini dibaca dari project setting application/config/version.
## Hanya aktif di build export Windows, bukan di editor.

signal update_check_finished(update_available: bool)

const REPO := "BlueMiku/csv-parsing"
const API_URL := "https://api.github.com/repos/%s/releases/latest" % REPO
const ASSET_SUFFIX := "-windows.zip"
const USER_AGENT := "AIO-Parser-Updater"
const UPDATE_DIR := "user://update"
const MAX_NOTES_LENGTH := 600

var _check_request: HTTPRequest
var _download_request: HTTPRequest
var _prompt_dialog: ConfirmationDialog
var _message_dialog: AcceptDialog
var _pending: Dictionary = {}  # { version, url, size, digest, notes }
var _zip_path: String = ""


func _ready() -> void:
	_check_request = HTTPRequest.new()
	_check_request.timeout = 10.0
	add_child(_check_request)
	_check_request.request_completed.connect(_on_check_completed)

	_download_request = HTTPRequest.new()
	_download_request.use_threads = true
	add_child(_download_request)
	_download_request.request_completed.connect(_on_download_completed)

	_prompt_dialog = ConfirmationDialog.new()
	_prompt_dialog.title = "Update tersedia"
	_prompt_dialog.ok_button_text = "Update"
	_prompt_dialog.cancel_button_text = "Nanti"
	_prompt_dialog.dialog_autowrap = true
	_prompt_dialog.confirmed.connect(_on_update_confirmed)
	add_child(_prompt_dialog)

	_message_dialog = AcceptDialog.new()
	_message_dialog.dialog_autowrap = true
	add_child(_message_dialog)

	set_process(false)


## Versi aplikasi yang sedang berjalan (dari project setting).
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## "v1.2.3" / "1.2.3-beta" -> [1, 2, 3]. Bagian setelah "-" diabaikan.
static func parse_version(version: String) -> Array[int]:
	var core := version.strip_edges().trim_prefix("v").split("-")[0]
	var result: Array[int] = []
	for part in core.split("."):
		result.append(part.to_int())
	return result


## true jika candidate lebih baru dari current.
static func is_newer(candidate: String, current: String) -> bool:
	var a := parse_version(candidate)
	var b := parse_version(current)
	for i in range(maxi(a.size(), b.size())):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false


## Cek release terbaru. Diam-diam kalau sudah terbaru / tidak ada koneksi.
## force = true melewati pengecekan "bukan build export" (dipakai untuk testing).
func check_for_updates(force: bool = false) -> void:
	if OS.get_name() != "Windows":
		return
	if OS.has_feature("editor") and not force:
		print("[UpdateManager] Editor terdeteksi, pengecekan update dilewati.")
		return

	_cleanup_update_dir()

	var headers := PackedStringArray(["User-Agent: " + USER_AGENT, "Accept: application/vnd.github+json"])
	var err := _check_request.request(API_URL, headers)
	if err != OK:
		push_warning("[UpdateManager] Gagal memulai pengecekan update (error %d)." % err)
		update_check_finished.emit(false)


func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK or response_code != 200:
		# 404 = belum ada release sama sekali; keduanya bukan hal yang perlu diganggu ke user
		print("[UpdateManager] Pengecekan update dilewati (result=%d, http=%d)." % [result, response_code])
		update_check_finished.emit(false)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		push_warning("[UpdateManager] Respons GitHub tidak valid.")
		update_check_finished.emit(false)
		return

	var latest := str(data.get("tag_name", "")).trim_prefix("v")
	var current := current_version()
	if latest.is_empty() or not is_newer(latest, current):
		print("[UpdateManager] Sudah versi terbaru (%s, release terbaru: %s)." % [current, latest])
		update_check_finished.emit(false)
		return

	var asset := _find_asset(data.get("assets", []))
	if asset.is_empty():
		push_warning("[UpdateManager] Release %s tidak punya asset *%s." % [latest, ASSET_SUFFIX])
		update_check_finished.emit(false)
		return

	_pending = {
		"version": latest,
		"url": str(asset.get("browser_download_url", "")),
		"size": int(asset.get("size", 0)),
		"digest": str(asset.get("digest", "")),
		"notes": str(data.get("body", "")).strip_edges()
	}

	var notes: String = _pending["notes"]
	if notes.length() > MAX_NOTES_LENGTH:
		notes = notes.substr(0, MAX_NOTES_LENGTH).strip_edges() + "…"
	var text := "Versi %s tersedia (kamu memakai %s)." % [latest, current]
	if not notes.is_empty():
		text += "\n\n" + notes
	text += "\n\nUpdate sekarang? Aplikasi akan menutup dan terbuka lagi otomatis."
	_prompt_dialog.dialog_text = text
	_prompt_dialog.popup_centered(Vector2i(520, 220))
	update_check_finished.emit(true)


func _find_asset(assets: Array) -> Dictionary:
	for asset in assets:
		if asset is Dictionary and str(asset.get("name", "")).to_lower().ends_with(ASSET_SUFFIX):
			return asset
	return {}


func _on_update_confirmed() -> void:
	if OS.has_feature("editor"):
		_show_message("Update", "Update otomatis hanya jalan di build export, bukan di editor.")
		return

	# Pastikan folder tempat exe berada bisa ditulis sebelum download
	var exe_dir := OS.get_executable_path().get_base_dir()
	var probe_path := exe_dir.path_join(".update_write_test")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		_show_message("Update gagal", "Folder aplikasi tidak bisa ditulis:\n%s\n\nPindahkan aplikasi ke folder biasa (mis. Documents) atau update manual." % exe_dir)
		return
	probe.close()
	DirAccess.remove_absolute(probe_path)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATE_DIR))
	_zip_path = ProjectSettings.globalize_path(UPDATE_DIR).path_join("update.zip")
	_download_request.download_file = _zip_path

	var headers := PackedStringArray(["User-Agent: " + USER_AGENT])
	var err := _download_request.request(_pending["url"], headers)
	if err != OK:
		_show_message("Update gagal", "Tidak bisa memulai download (error %d)." % err)
		return

	_show_message("Mengunduh update", "Mengunduh versi %s… 0%%" % _pending["version"])
	_message_dialog.get_ok_button().disabled = true
	set_process(true)


func _process(_delta: float) -> void:
	var total: int = _download_request.get_body_size()
	if total <= 0:
		total = int(_pending.get("size", 0))
	if total > 0:
		var percent := int(100.0 * _download_request.get_downloaded_bytes() / total)
		_message_dialog.dialog_text = "Mengunduh versi %s… %d%%" % [_pending["version"], clampi(percent, 0, 100)]


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	_message_dialog.get_ok_button().disabled = false

	if result != OK or response_code != 200:
		_show_message("Update gagal", "Download gagal (result=%d, http=%d)." % [result, response_code])
		_cleanup_update_dir()
		return

	# Verifikasi checksum jika GitHub menyediakan digest untuk asset ini
	var digest: String = _pending.get("digest", "")
	if digest.begins_with("sha256:"):
		var actual := FileAccess.get_sha256(_zip_path)
		if actual.to_lower() != digest.trim_prefix("sha256:").to_lower():
			_show_message("Update gagal", "Checksum file update tidak cocok. Update dibatalkan demi keamanan.")
			_cleanup_update_dir()
			return

	var new_exe := ProjectSettings.globalize_path(UPDATE_DIR).path_join("new_app.exe")
	if not _extract_exe(_zip_path, new_exe):
		_show_message("Update gagal", "Tidak menemukan file .exe di dalam update.")
		_cleanup_update_dir()
		return

	_apply_update(new_exe)


## Ambil exe utama (bukan *.console.exe) dari zip dan tulis ke out_path.
func _extract_exe(zip_path: String, out_path: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return false

	var target_name := ""
	for file_name in reader.get_files():
		var lowered := file_name.to_lower()
		if lowered.ends_with(".exe") and not lowered.ends_with(".console.exe"):
			target_name = file_name
			break
	if target_name.is_empty():
		reader.close()
		return false

	var bytes := reader.read_file(target_name)
	reader.close()
	if bytes.is_empty():
		return false

	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	out.close()
	return true


## Tulis script PowerShell yang menunggu aplikasi ini keluar, mengganti exe,
## lalu menjalankannya lagi. Setelah itu aplikasi ini menutup diri.
func _apply_update(new_exe: String) -> void:
	var target_exe := OS.get_executable_path().replace("/", "\\")
	var source_exe := new_exe.replace("/", "\\")
	var script_path := ProjectSettings.globalize_path(UPDATE_DIR).path_join("apply_update.ps1").replace("/", "\\")

	var script := _build_apply_script(source_exe, target_exe, script_path, OS.get_process_id(), true)

	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		_show_message("Update gagal", "Tidak bisa menulis script update.")
		return
	file.store_string(script)
	file.close()

	var pid := OS.create_process("powershell.exe", [
		"-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script_path
	])
	if pid <= 0:
		_show_message("Update gagal", "Tidak bisa menjalankan script update.")
		return

	get_tree().quit()


## Isi script PowerShell: tunggu proses lama keluar, ganti exe (retry selama
## file masih terkunci), jalankan exe baru, lalu hapus script ini sendiri.
func _build_apply_script(source_exe: String, target_exe: String, script_path: String, wait_pid: int, relaunch: bool) -> String:
	var lines: Array[String] = [
		"Wait-Process -Id %d -Timeout 60 -ErrorAction SilentlyContinue" % wait_pid,
		"for ($i = 0; $i -lt 40; $i++) {",
		"  try {",
		"    Move-Item -LiteralPath '%s' -Destination '%s' -Force -ErrorAction Stop" % [_ps_quote(source_exe), _ps_quote(target_exe)],
		"    break",
		"  } catch {",
		"    Start-Sleep -Milliseconds 500",
		"  }",
		"}"
	]
	if relaunch:
		lines.append("Start-Process -FilePath '%s'" % _ps_quote(target_exe))
	lines.append("Remove-Item -LiteralPath '%s' -Force -ErrorAction SilentlyContinue" % _ps_quote(script_path))
	lines.append("")
	return "\n".join(lines)


func _ps_quote(value: String) -> String:
	return value.replace("'", "''")


func _show_message(title: String, text: String) -> void:
	_message_dialog.title = title
	_message_dialog.dialog_text = text
	if not _message_dialog.visible:
		_message_dialog.popup_centered(Vector2i(480, 160))


## Hapus sisa download/script dari update sebelumnya.
func _cleanup_update_dir() -> void:
	var dir_path := ProjectSettings.globalize_path(UPDATE_DIR)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
