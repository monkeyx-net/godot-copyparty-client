# FilePane.gd
# Self-contained file-browser pane – LOCAL (DirAccess) or REMOTE (CopypartyAPI).
class_name FilePane
extends Control

# ── Colours (set by Main.gd before _ready fires via add_child) ───────────────
var C_PANEL     := Color(0.18, 0.18, 0.22)
var C_PANEL_ALT := Color(0.16, 0.16, 0.20)
var C_TOOLBAR   := Color(0.14, 0.14, 0.18)
var C_ACCENT    := Color(0.27, 0.56, 0.90)
var C_ACCENT2   := Color(0.20, 0.70, 0.50)
var C_TEXT      := Color(0.90, 0.90, 0.92)
var C_SUBTEXT   := Color(0.55, 0.55, 0.62)
var C_BORDER    := Color(0.30, 0.30, 0.38)

# ── Icons ─────────────────────────────────────────────────────────────────────
const ICO_FOLDER  := "📁"
const ICO_FILE    := "📄"
const ICO_IMAGE   := "🖼"
const ICO_AUDIO   := "🎵"
const ICO_VIDEO   := "🎬"
const ICO_ARCHIVE := "📦"
const ICO_CODE    := "💻"
const ICO_TEXT    := "📝"
const ICO_PDF     := "📕"

enum Source { LOCAL, REMOTE }

# ── Signals ───────────────────────────────────────────────────────────────────
signal selection_changed(entry: Dictionary)
signal file_opened(entry: Dictionary)
signal delete_requested(entries: Array)
signal upload_requested(dest_path: String)
signal mkdir_requested(dest_path: String)
signal status_message(msg: String)
signal drop_received(entries: Array, source_pane: FilePane)
signal directory_loaded(acct: String, perms: Array)

# ── Public state ──────────────────────────────────────────────────────────────
var source: Source = Source.REMOTE
var api: CopypartyAPI = null

var current_path: String = "/"
var current_perms: Array[String] = []
var current_acct:  String = "*"
var nav_stack: Array[String] = []
var nav_pos: int = -1
var file_entries: Array[Dictionary] = []
var selected_idxs: Array[int] = []
var _in_select_update: bool = false
var _sort_col: int = 0
var _sort_asc: bool = true

# ── Scene nodes ───────────────────────────────────────────────────────────────
@onready var _nav_bar:        PanelContainer = $VBoxContainer/NavBar
@onready var _source_label:   Label          = $VBoxContainer/NavBar/NavMargin/NavHBox/SourceLabel
@onready var _nav_sep1:       VSeparator     = $VBoxContainer/NavBar/NavMargin/NavHBox/NavSep1
@onready var _nav_sep2:       VSeparator     = $VBoxContainer/NavBar/NavMargin/NavHBox/NavSep2
@onready var _nav_sep3:       VSeparator     = $VBoxContainer/NavBar/NavMargin/NavHBox/NavSep3
@onready var _back_btn:       Button         = $VBoxContainer/NavBar/NavMargin/NavHBox/BackBtn
@onready var _fwd_btn:        Button         = $VBoxContainer/NavBar/NavMargin/NavHBox/FwdBtn
@onready var _home_btn:       Button         = $VBoxContainer/NavBar/NavMargin/NavHBox/HomeBtn
@onready var _refresh_btn:    Button         = $VBoxContainer/NavBar/NavMargin/NavHBox/RefreshBtn
@onready var _breadcrumb:     Label          = $VBoxContainer/NavBar/NavMargin/NavHBox/Breadcrumb
@onready var _upload_btn:     Button         = $VBoxContainer/NavBar/NavMargin/NavHBox/UploadBtn
@onready var _mkdir_btn:      Button         = $VBoxContainer/NavBar/NavMargin/NavHBox/MkdirBtn
@onready var _col_header:     PanelContainer = $VBoxContainer/ColHeader
@onready var _col_name_btn:   Button         = $VBoxContainer/ColHeader/ColMargin/ColHBox/ColNameBtn
@onready var _col_size_btn:   Button         = $VBoxContainer/ColHeader/ColMargin/ColHBox/ColSizeBtn
@onready var _col_modified_btn: Button       = $VBoxContainer/ColHeader/ColMargin/ColHBox/ColModifiedBtn
@onready var _col_type_btn:   Button         = $VBoxContainer/ColHeader/ColMargin/ColHBox/ColTypeBtn
@onready var _file_list:      Tree           = $VBoxContainer/FileList

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_theme_colors()
	_back_btn.pressed.connect(func(): navigate_back())
	_fwd_btn.pressed.connect(func(): navigate_forward())
	_home_btn.pressed.connect(func(): navigate_home())
	_refresh_btn.pressed.connect(func(): refresh())
	_upload_btn.pressed.connect(func(): upload_requested.emit(current_path))
	_mkdir_btn.pressed.connect(func(): mkdir_requested.emit(current_path))
	_col_name_btn.pressed.connect(func(): _on_column_title_pressed(0))
	_col_size_btn.pressed.connect(func(): _on_column_title_pressed(1))
	_col_modified_btn.pressed.connect(func(): _on_column_title_pressed(2))
	_col_type_btn.pressed.connect(func(): _on_column_title_pressed(3))
	_file_list.set_column_expand(0, true)
	_file_list.set_column_expand(1, false)
	_file_list.set_column_expand(2, false)
	_file_list.set_column_expand(3, false)
	_file_list.set_column_custom_minimum_width(0, 250)
	_file_list.set_column_custom_minimum_width(1, 90)
	_file_list.set_column_custom_minimum_width(2, 150)
	_file_list.set_column_custom_minimum_width(3, 55)
	_file_list.add_theme_constant_override("inner_item_margin_left",  4)
	_file_list.add_theme_constant_override("inner_item_margin_right", 4)
	_file_list.multi_selected.connect(_on_multi_selected)
	_file_list.gui_input.connect(_on_list_input)
	_file_list.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_update_column_titles()

func setup(src: Source, api_ref: CopypartyAPI, start_path: String) -> void:
	source = src
	api    = api_ref
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	if src == Source.LOCAL:
		_source_label.text = "LOCAL"
		_source_label.add_theme_color_override("font_color", C_ACCENT2)
		_upload_btn.visible = false
	else:
		_source_label.text = "REMOTE"
		_source_label.add_theme_color_override("font_color", C_ACCENT)
		_upload_btn.visible = true
	navigate_to(start_path)

# ── Public navigation ─────────────────────────────────────────────────────────
func navigate_to(path: String) -> void:
	if nav_pos < nav_stack.size() - 1:
		nav_stack.resize(nav_pos + 1)
	nav_stack.append(path)
	nav_pos = nav_stack.size() - 1
	await _load_path(path)

func navigate_back() -> void:
	if nav_pos > 0:
		nav_pos -= 1
		await _load_path(nav_stack[nav_pos])

func navigate_forward() -> void:
	if nav_pos < nav_stack.size() - 1:
		nav_pos += 1
		await _load_path(nav_stack[nav_pos])

func navigate_home() -> void:
	navigate_to("/" if source == Source.REMOTE else _home_dir())

func refresh() -> void:
	await _load_path(current_path)

func get_selected_entry() -> Dictionary:
	if selected_idxs.is_empty():
		return {}
	var i := selected_idxs[0]
	return file_entries[i].duplicate() if i < file_entries.size() else {}

func get_selected_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in selected_idxs:
		if i < file_entries.size():
			result.append(file_entries[i].duplicate())
	return result

func get_selected_count() -> int:
	return selected_idxs.size()

func deselect() -> void:
	_file_list.deselect_all()
	selected_idxs = []
	selection_changed.emit({})

# ── Loading ───────────────────────────────────────────────────────────────────
func _load_path(path: String) -> void:
	current_path = path
	_breadcrumb.text = path
	_back_btn.disabled = (nav_pos <= 0)
	_fwd_btn.disabled  = (nav_pos >= nav_stack.size() - 1)
	file_entries.clear()
	selected_idxs = []
	_in_select_update = false
	_file_list.clear()
	selection_changed.emit({})

	if source == Source.LOCAL:
		_load_local(path)
	else:
		await _load_remote(path)

func _load_local(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		status_message.emit("Cannot open: " + path)
		return

	var dirs: Array[Dictionary]  = []
	var files: Array[Dictionary] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full: String = path.path_join(fname)
			if dir.current_is_dir():
				dirs.append({"name": fname, "href": full,
					"size": -1, "ext": "", "ts": 0, "is_dir": true, "local": true})
			else:
				var fa  := FileAccess.open(full, FileAccess.READ)
				var sz  := fa.get_length() if fa else -1
				var ts: int = FileAccess.get_modified_time(full)
				files.append({"name": fname, "href": full, "size": sz,
					"ext": fname.get_extension().to_lower(),
					"ts": ts, "is_dir": false, "local": true})
		fname = dir.get_next()
	dir.list_dir_end()

	current_perms = ["read", "write", "delete", "move"]
	file_entries.append_array(dirs)
	file_entries.append_array(files)
	_sort_entries()
	_populate_list()
	status_message.emit("%d folder(s), %d file(s)" % [dirs.size(), files.size()])

func _load_remote(path: String) -> void:
	if not api.is_configured():
		status_message.emit("Not connected – enter a URL and press Connect.")
		return
	status_message.emit("Loading " + path + " …")
	var result: Variant = await api.list_directory(path)
	if result == null:
		status_message.emit("Failed to load: " + path)
		return
	current_perms = Array(result.get("perms", []), TYPE_STRING, "", null)
	current_acct  = result.get("acct",  "*")
	var dirs: Array[Dictionary]  = Array(result.get("dirs",  []), TYPE_DICTIONARY, "", null)
	var files: Array[Dictionary] = Array(result.get("files", []), TYPE_DICTIONARY, "", null)
	file_entries.append_array(dirs)
	file_entries.append_array(files)
	_sort_entries()
	_populate_list()
	status_message.emit("%d folder(s), %d file(s)" % [dirs.size(), files.size()])
	directory_loaded.emit(current_acct, current_perms)

func _populate_list() -> void:
	_file_list.clear()
	var root := _file_list.create_item()
	for i in file_entries.size():
		var entry: Dictionary = file_entries[i]
		var icon     := _entry_icon(entry)
		var is_dir:  bool = entry.get("is_dir", false)
		var size_str := "—" if is_dir else Format.size(entry.get("size", 0))
		var date_str := Format.ts(entry.get("ts", 0))
		var ext_str: String = ("dir" if is_dir else entry.get("ext", "").to_upper())
		var ti := _file_list.create_item(root)
		ti.set_text(0, icon + "  " + entry.get("name", "?"))
		ti.set_text(1, "" if _compact else size_str)
		ti.set_text(2, "" if _compact else date_str)
		ti.set_text(3, "" if _compact else ext_str)
		ti.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		ti.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
		ti.set_text_alignment(3, HORIZONTAL_ALIGNMENT_RIGHT)
		ti.set_metadata(0, i)

# ── Sorting ──────────────────────────────────────────────────────────────────
const _COL_NAMES := ["Name", "Size", "Modified", "Type"]

func _update_column_titles() -> void:
	for i in _COL_NAMES.size():
		var t: String = _COL_NAMES[i]
		if i == _sort_col:
			t += "  " + ("▴" if _sort_asc else "▾")
		match i:
			0: _col_name_btn.text = t
			1: _col_size_btn.text = t
			2: _col_modified_btn.text = t
			3: _col_type_btn.text = t

func _sort_entries() -> void:
	file_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ad: bool = a.get("is_dir", false)
		var bd: bool = b.get("is_dir", false)
		if ad != bd:
			return ad
		var less: bool
		match _sort_col:
			1: less = a.get("size", 0)   < b.get("size", 0)
			2: less = a.get("ts",   0)   < b.get("ts",   0)
			3: less = a.get("ext",  "") < b.get("ext",  "")
			_: less = a.get("name", "") < b.get("name", "")
		return less if _sort_asc else not less)

func _on_column_title_pressed(col: int) -> void:
	if _sort_col == col:
		_sort_asc = not _sort_asc
	else:
		_sort_col = col
		_sort_asc = true
	_update_column_titles()
	_sort_entries()
	_populate_list()

# ── Item callbacks ────────────────────────────────────────────────────────────
func _on_multi_selected(item: TreeItem, column: int, _is_sel: bool) -> void:
	if _in_select_update:
		return
	_in_select_update = true
	if column != 0:
		item.deselect(column)
		_in_select_update = false
		return
	selected_idxs = []
	var ti: TreeItem = _file_list.get_next_selected(null)
	while ti != null:
		var idx := ti.get_metadata(0) as int
		if not selected_idxs.has(idx):
			selected_idxs.append(idx)
		ti = _file_list.get_next_selected(ti)
	selected_idxs.sort()
	_in_select_update = false
	selection_changed.emit(get_selected_entry())

func _activate_entry(idx: int) -> void:
	if idx < 0 or idx >= file_entries.size():
		return
	var entry: Dictionary = file_entries[idx]
	if entry.get("is_dir"):
		var dest: String
		if source == Source.LOCAL:
			dest = entry.get("href", current_path)
		else:
			dest = current_path.rstrip("/") + "/" + entry.get("name", "")
		navigate_to(dest)
	else:
		file_opened.emit(entry)

func _on_list_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var ti := _file_list.get_item_at_position(event.position)
		if ti != null:
			_activate_entry(ti.get_metadata(0) as int)
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if not selected_idxs.is_empty():
					_activate_entry(selected_idxs[0])
			KEY_BACKSPACE:
				navigate_back()
			KEY_F5:
				refresh()
			KEY_DELETE:
				if not selected_idxs.is_empty():
					delete_requested.emit(get_selected_entries())

# ── Drag and drop ────────────────────────────────────────────────────────────
func _get_drag_data(at_position: Vector2) -> Variant:
	if _file_list.get_column_at_position(at_position) != 0:
		return null
	if selected_idxs.is_empty():
		return null
	var entries: Array[Dictionary]
	if selected_idxs.size() > 1:
		entries = get_selected_entries()
	else:
		var idx := selected_idxs[0]
		if idx >= file_entries.size():
			return null
		entries = [file_entries[idx].duplicate()]
	if entries.is_empty():
		return null
	var lbl := Label.new()
	if entries.size() == 1:
		lbl.text = ("📁  " if entries[0].get("is_dir") else "📄  ") + entries[0].get("name", "?")
	else:
		lbl.text = "📄  %d items" % entries.size()
	lbl.add_theme_color_override("font_color", C_TEXT)
	_file_list.set_drag_preview(lbl)
	return {"type": "fp_entry", "entries": entries, "pane": self}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return (data is Dictionary
		and data.get("type") == "fp_entry"
		and data.get("pane") != self)

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if not (data is Dictionary and data.get("type") == "fp_entry"):
		return
	var src: FilePane = data.get("pane") as FilePane
	var entries: Array[Dictionary] = data.get("entries", [] as Array[Dictionary])
	if src != null and not entries.is_empty():
		drop_received.emit(entries, src)

# ── Theming ───────────────────────────────────────────────────────────────────
func _apply_theme_colors() -> void:
	_apply_panel_style(_nav_bar, C_TOOLBAR)
	_apply_panel_style(_col_header, C_PANEL_ALT)
	for sep in [_nav_sep1, _nav_sep2, _nav_sep3]:
		_apply_vsep_style(sep)
	for btn in [_back_btn, _fwd_btn, _home_btn, _refresh_btn, _mkdir_btn]:
		_apply_btn_style(btn, C_PANEL)
	_apply_btn_style(_upload_btn, C_ACCENT2)
	_breadcrumb.add_theme_color_override("font_color", C_TEXT)
	for col_btn in [_col_name_btn, _col_size_btn, _col_modified_btn, _col_type_btn]:
		col_btn.add_theme_color_override("font_color",         C_SUBTEXT)
		col_btn.add_theme_color_override("font_hover_color",   C_TEXT)
		col_btn.add_theme_color_override("font_pressed_color", C_TEXT)
	var tp := StyleBoxFlat.new()
	tp.bg_color = C_PANEL
	_file_list.add_theme_stylebox_override("panel", tp)
	_file_list.add_theme_stylebox_override("focus",  tp)
	var ts := StyleBoxFlat.new()
	ts.bg_color = C_ACCENT.darkened(0.3)
	_file_list.add_theme_stylebox_override("selected",       ts)
	_file_list.add_theme_stylebox_override("selected_focus", ts)
	_file_list.add_theme_color_override("font_color",          C_TEXT)
	_file_list.add_theme_color_override("font_selected_color", Color.WHITE)
	_file_list.add_theme_color_override("guide_color",         C_BORDER)
	_file_list.add_theme_constant_override("draw_guides", 1)

func _apply_panel_style(panel: PanelContainer, bg: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	panel.add_theme_stylebox_override("panel", s)

func _apply_vsep_style(sep: VSeparator) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color             = C_BORDER
	st.content_margin_left  = 0
	st.content_margin_right = 0
	sep.add_theme_stylebox_override("separator", st)

func _apply_btn_style(btn: Button, bg: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = bg
	n.set_corner_radius_all(4)
	n.content_margin_left = 10; n.content_margin_right  = 10
	n.content_margin_top  = 4;  n.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", p)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = bg.darkened(0.3)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_pressed_color",  C_TEXT)
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", C_SUBTEXT)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _home_dir() -> String:
	var h := OS.get_environment("HOME")
	if h:
		return h
	h = OS.get_environment("USERPROFILE")
	return h if h else "/"

func _entry_icon(entry: Dictionary) -> String:
	if entry.get("is_dir"):
		return ICO_FOLDER
	var ext: String = entry.get("ext", "").to_lower()
	match ext:
		"jpg", "jpeg", "png", "gif", "webp", "bmp", "svg", "ico", "tiff", "avif":
			return ICO_IMAGE
		"mp3", "flac", "ogg", "opus", "wav", "aac", "m4a", "wma":
			return ICO_AUDIO
		"mp4", "mkv", "avi", "mov", "wmv", "webm", "m4v", "flv":
			return ICO_VIDEO
		"zip", "tar", "gz", "xz", "bz2", "7z", "rar", "zst":
			return ICO_ARCHIVE
		"py", "gd", "js", "ts", "go", "rs", "c", "cpp", "h", "cs", "java", "sh", "rb", "php":
			return ICO_CODE
		"txt", "md", "rst", "log", "csv", "json", "xml", "yaml", "toml", "ini", "cfg":
			return ICO_TEXT
		"pdf":
			return ICO_PDF
	return ICO_FILE

func find_entry_by_name(fname: String) -> Dictionary:
	for e in file_entries:
		if e.get("name", "") == fname:
			return e
	return {}

var _compact := false

func set_compact(compact: bool) -> void:
	if _compact == compact:
		return
	_compact = compact
	_file_list.set_column_custom_minimum_width(1, 0  if compact else 90)
	_file_list.set_column_custom_minimum_width(2, 0  if compact else 150)
	_file_list.set_column_custom_minimum_width(3, 0  if compact else 55)
	_col_size_btn.visible     = not compact
	_col_modified_btn.visible = not compact
	_col_type_btn.visible     = not compact
	_populate_list()
