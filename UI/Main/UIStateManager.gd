class_name UIStateManager
extends RefCounted

## Mengelola status updates dan UI state

signal status_changed(message: String)

var _status_label: Label


func _init(status_label: Label) -> void:
	_status_label = status_label


func update_status(message: String) -> void:
	_status_label.text = "Status: " + message
	status_changed.emit(message)

func _set_colors_status(colors: Color) -> void:
	_status_label.add_theme_color_override("font_color", colors)

func _reset_colors_status() -> void:
	_status_label.remove_theme_color_override("font_color")

func show_ready() -> void:
	_reset_colors_status()
	update_status("Ready - Select CSV file and output location")


func show_type_selection_required() -> void:
	_reset_colors_status()
	update_status("Pilih tipe file untuk memulai")


func show_file_type_selected(type_name: String) -> void:
	_reset_colors_status()
	update_status("Mode: %s - Pilih output location dan klik Generate" % type_name)


func show_processing(message: String = "Memproses CSV...") -> void:
	_reset_colors_status()
	update_status(message)


func show_success(message: String) -> void:
	_set_colors_status(Color(0.2, 0.85, 0.3))
	update_status(message)


func show_warning(message: String) -> void:
	_set_colors_status(Color(1.0, 0.65, 0.0))
	update_status(message)


func show_error(message: String) -> void:
	_set_colors_status(Color(1.0, 0.25, 0.25))
	update_status(message)


func show_csv_selected() -> void:
	_reset_colors_status()
	update_status("CSV file selected. Click 'Load Chapters' to see available groups.")


func show_csv_selected_with_patrons() -> void:
	_reset_colors_status()
	update_status("CSV file selected. Patron list loaded.")


func show_patron_selected(patron_name: String) -> void:
	_reset_colors_status()
	update_status("Patron terpilih: " + patron_name)


func show_patrons_loaded(count: int) -> void:
	_reset_colors_status()
	update_status("Memuat %d karakter patron." % count)


func show_no_patrons() -> void:
	_reset_colors_status()
	update_status("Tidak ada karakter patron yang ditemukan.")


func show_type_detected(type_name: String) -> void:
	_reset_colors_status()
	update_status("Terdeteksi: Format %s. Memuat grup..." % type_name)


func show_groups_found(count: int, group_label: String) -> void:
	_reset_colors_status()
	update_status("Ditemukan %d %s. Klik untuk memilih/membatalkan." % [count, group_label])


func show_selection_changed(selected: int, total: int, group_label: String) -> void:
	_reset_colors_status()
	update_status("Selected %d/%d %s" % [selected, total, group_label])


func show_batch_processing(file_count: int) -> void:
	_reset_colors_status()
	update_status("Memproses %d file CSV..." % file_count)


func show_merging(count: int) -> void:
	_reset_colors_status()
	update_status("Menggabungkan %d hasil parsing..." % count)


func show_merge_canceled() -> void:
	_reset_colors_status()
	update_status("Parsing dibatalkan oleh pengguna.")
