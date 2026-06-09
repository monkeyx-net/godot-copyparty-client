# Main.gd
# Orchestrates the dual-pane UI: local filesystem (left) + copyparty server (right).
class_name Main
extends Control

# ── Colours ───────────────────────────────────────────────────────────────────
var C_BG        := Color(0.12, 0.12, 0.14)
var C_PANEL     := Color(0.18, 0.18, 0.22)
var C_PANEL_ALT := Color(0.16, 0.16, 0.20)
var C_TOOLBAR   := Color(0.14, 0.14, 0.18)
var C_ACCENT    := Color(0.27, 0.56, 0.90)
var C_ACCENT2   := Color(0.20, 0.70, 0.50)
var C_DANGER    := Color(0.85, 0.25, 0.25)
var C_TEXT      := Color(0.90, 0.90, 0.92)
var C_SUBTEXT   := Color(0.55, 0.55, 0.62)
var C_BORDER    := Color(0.30, 0.30, 0.38)

const THEMES: Dictionary = {
	"dark": {
		"BG": Color(0.12, 0.12, 0.14), "PANEL": Color(0.18, 0.18, 0.22),
		"PANEL_ALT": Color(0.16, 0.16, 0.20), "TOOLBAR": Color(0.14, 0.14, 0.18),
		"ACCENT": Color(0.27, 0.56, 0.90), "ACCENT2": Color(0.20, 0.70, 0.50),
		"DANGER": Color(0.85, 0.25, 0.25), "TEXT": Color(0.90, 0.90, 0.92),
		"SUBTEXT": Color(0.55, 0.55, 0.62), "BORDER": Color(0.30, 0.30, 0.38),
	},
	"light": {
		"BG": Color(0.94, 0.95, 0.96), "PANEL": Color(1.00, 1.00, 1.00),
		"PANEL_ALT": Color(0.92, 0.92, 0.94), "TOOLBAR": Color(0.88, 0.89, 0.91),
		"ACCENT": Color(0.18, 0.47, 0.83), "ACCENT2": Color(0.12, 0.62, 0.42),
		"DANGER": Color(0.82, 0.18, 0.18), "TEXT": Color(0.10, 0.10, 0.12),
		"SUBTEXT": Color(0.43, 0.44, 0.48), "BORDER": Color(0.74, 0.74, 0.79),
	},
	"green": {
		"BG": Color(0.00, 0.00, 0.00), "PANEL": Color(0.00, 0.05, 0.00),
		"PANEL_ALT": Color(0.00, 0.04, 0.00), "TOOLBAR": Color(0.00, 0.03, 0.00),
		"ACCENT": Color(0.00, 0.90, 0.10), "ACCENT2": Color(0.10, 0.75, 0.00),
		"DANGER": Color(0.85, 0.25, 0.25), "TEXT": Color(0.00, 0.85, 0.00),
		"SUBTEXT": Color(0.00, 0.50, 0.00), "BORDER": Color(0.00, 0.28, 0.00),
	},
}
const _THEME_NAMES := ["dark", "light", "green", "custom"]
var _current_theme := "dark"
var _fonts: Array[Dictionary] = []
var _current_font  := "Default"

const SYMBOLS_FONT := preload("res://fonts/NotoSansSymbols2-subset.ttf")
const EMOJI_FONT   := preload("res://fonts/NotoEmoji-subset.ttf")

# ── Icons ─────────────────────────────────────────────────────────────────────
const ICO_DL     := "⬇"
const ICO_DELETE := "🗑"
const ICO_COPY   := "📋"
const ICO_MOVE   := "↪"
const ICO_LINK   := "🔗"
const ICO_LOCK   := "🔒"
const ICO_UNLOCK := "🔓"
const ICO_SEARCH := "🔍"
const ICO_XFER   := "⇄"
const ICO_FILE   := "📄"

# ── API ───────────────────────────────────────────────────────────────────────
var api: CopypartyAPI

# ── Panes ─────────────────────────────────────────────────────────────────────
var active_pane: FilePane = null

# ── Responsive layout ─────────────────────────────────────────────────────────
const _MOBILE_BP  := 560
var _mobile_mode  := false
var _has_selection := false
var _is_authed := false
var _left_pane_hidden := false

# ── Dialog state ──────────────────────────────────────────────────────────────
var active_dialog: Control = null
var _confirm_callback: Callable = Callable()
var search_entries: Array[Dictionary] = []
var move_src_path: String = ""
var move_is_copy   := false
var _mkdir_pane: FilePane = null
var _sync_local_entry:  Dictionary = {}
var _sync_remote_entry: Dictionary = {}
var _xfer_progress  := 0
var _spinning          := false
var _custom_color      := Color(0.27, 0.56, 0.90)
var _custom_bg_color   := Color(0.12, 0.12, 0.14)
var _custom_text_color := Color(0.90, 0.90, 0.92)
var _opacity           := 1.0

# ── Scene nodes: toolbar ─────────────────────────────────────────────────────
@onready var _bg:           ColorRect  = $BG
@onready var _toolbar:      PanelContainer = $VBoxContainer/Toolbar
@onready var url_input:     LineEdit   = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/UrlInput
@onready var connect_btn:   Button     = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/ConnectBtn
@onready var user_input:    LineEdit   = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/UserInput
@onready var pw_input:      LineEdit   = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/PwInput
@onready var login_btn:     Button     = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/LoginBtn
@onready var _search_btn:   Button     = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/SearchBtn
@onready var _theme_opt:    OptionButton = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/ThemeOpt
@onready var _font_opt:     OptionButton = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/FontOpt
@onready var _server_lbl:   Label      = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/ServerLabel
@onready var _user_lbl:     Label      = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/UserLabel
@onready var _pw_lbl:       Label      = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/PwLabel
@onready var _tb_sep1:      VSeparator = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/Sep1
@onready var _tb_sep2:      VSeparator = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/Sep2
@onready var _tb_sep3:      VSeparator = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/Sep3
@onready var _tb_sep4:           VSeparator        = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/Sep4
@onready var _tb_sep5:           VSeparator        = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/Sep5
@onready var _hide_l_btn:        Button            = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/HideLBtn
@onready var _opacity_slider:    HSlider           = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/OpacitySlider
@onready var _color_picker_btn:  ColorPickerButton = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/ColorPickerBtn
@onready var _color_picker_bg:   ColorPickerButton = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/ColorPickerBg
@onready var _color_picker_text: ColorPickerButton = $VBoxContainer/Toolbar/ToolbarMargin/ToolbarScroll/ToolbarHBox/ColorPickerText

# ── Scene nodes: panes ────────────────────────────────────────────────────────
@onready var left_pane:  FilePane = $VBoxContainer/ContentHBox/PaneSplit/LeftPane
@onready var right_pane: FilePane = $VBoxContainer/ContentHBox/PaneSplit/RightPane

# ── Scene nodes: detail panel ─────────────────────────────────────────────────
@onready var _detail_panel:  PanelContainer = $VBoxContainer/ContentHBox/DetailPanel
@onready var detail_name:    Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/DetailName
@onready var detail_size:    Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/InfoGrid/SizeVal
@onready var detail_date:    Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/InfoGrid/DateVal
@onready var detail_ext:     Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/InfoGrid/ExtVal
@onready var detail_url_lbl: Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/DetailUrlLabel
@onready var detail_url:     LineEdit = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/DetailUrl
@onready var dl_btn:         Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/DlBtn
@onready var transfer_btn:   Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/TransferBtn
@onready var copy_btn:       Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/CopyBtn
@onready var move_btn:       Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/MoveBtn
@onready var delete_btn:     Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/DeleteBtn
@onready var url_copy_btn:   Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/UrlCopyBtn
@onready var _sync_btn:      Button   = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionGrid/SyncBtn
@onready var status_log:     TextEdit = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/StatusLog
@onready var _godocog1:      Sprite2D = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/LogoBox/CopyartyLogo2/GodoCog1
@onready var _godocog2:      Sprite2D = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/LogoBox/CopyartyLogo2/GodoCog2
@onready var progress_bar:   ProgressBar = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ProgRow/ProgressBar
@onready var progress_label: Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ProgRow/ProgressLabel
@onready var _detail_title:  Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/DetailTitle
@onready var _actions_label: Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/ActionsLabel
@onready var _log_label:     Label    = $VBoxContainer/ContentHBox/DetailPanel/DetailMargin/DetailScroll/DetailVBox/LogLabel

# ── Scene nodes: overlay & dialogs ───────────────────────────────────────────
@onready var overlay:          ColorRect     = $Overlay
@onready var _search_dialog:   PanelContainer = $SearchDialog
@onready var search_input:     LineEdit       = $SearchDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SearchRow/SearchInput
@onready var search_results:   ItemList       = $SearchDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SearchResults
@onready var _mkdir_dialog:    PanelContainer = $MkdirDialog
@onready var mkdir_input:      LineEdit       = $MkdirDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MkdirInput
@onready var _move_dialog:     PanelContainer = $MoveDialog
@onready var move_input:       LineEdit       = $MoveDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MoveInput
@onready var _confirm_dialog:  PanelContainer = $ConfirmDialog
@onready var _confirm_msg_label: Label        = $ConfirmDialog/DlgBase/DlgMargin/DlgInner/DlgContent/ConfirmMsg
@onready var _sync_dialog:     PanelContainer = $SyncDialog
@onready var _sync_local_ts:   Label = $SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncInfoGrid/LocalTs
@onready var _sync_local_sz:   Label = $SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncInfoGrid/LocalSz
@onready var _sync_remote_ts:  Label = $SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncInfoGrid/RemoteTs
@onready var _sync_remote_sz:  Label = $SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncInfoGrid/RemoteSz
@onready var _sync_newer_lbl:  Label = $SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/NewerLabel

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	api = CopypartyAPI.new()
	add_child(api)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if SYMBOLS_FONT:
		ThemeDB.fallback_font = SYMBOLS_FONT
	_fonts = _scan_fonts()

	# Toolbar signals
	url_input.text_submitted.connect(_on_connect_pressed.unbind(1))
	connect_btn.pressed.connect(_on_connect_pressed)
	user_input.text_submitted.connect(func(_t): pw_input.grab_focus())
	pw_input.text_submitted.connect(_on_login_pressed.unbind(1))
	login_btn.pressed.connect(_on_login_pressed)
	_search_btn.pressed.connect(_show_search_dialog)
	_hide_l_btn.pressed.connect(_toggle_left_pane)
	get_window().files_dropped.connect(_on_os_files_dropped)
	if OS.has_feature("web"):
		_setup_web_drop_listener()

	# Opacity slider
	_opacity_slider.value = _opacity
	_opacity_slider.value_changed.connect(func(v: float):
		_opacity = v
		modulate.a = v
	)

	# Theme selector
	_theme_opt.add_item("Dark",   0)
	_theme_opt.add_item("Light",  1)
	_theme_opt.add_item("Green",  2)
	_theme_opt.add_item("Custom", 3)
	_theme_opt.selected = _THEME_NAMES.find(_current_theme)
	_theme_opt.item_selected.connect(func(idx: int):
		_current_theme = _THEME_NAMES[idx]
		var is_custom := _current_theme == "custom"
		_tb_sep5.visible           = is_custom
		_color_picker_btn.visible  = is_custom
		_color_picker_bg.visible   = is_custom
		_color_picker_text.visible = is_custom
		_apply_theme(_current_theme)
	)
	_color_picker_btn.color = _custom_color
	_color_picker_btn.color_changed.connect(func(color: Color): _custom_color = color)
	_color_picker_btn.popup_closed.connect(func():
		if _current_theme == "custom":
			_apply_custom_theme(_custom_color)
	)
	_color_picker_bg.color = _custom_bg_color
	_color_picker_bg.color_changed.connect(func(color: Color): _custom_bg_color = color)
	_color_picker_bg.popup_closed.connect(func():
		if _current_theme == "custom":
			_apply_custom_theme(_custom_color)
	)
	_color_picker_text.color = _custom_text_color
	_color_picker_text.color_changed.connect(func(color: Color): _custom_text_color = color)
	_color_picker_text.popup_closed.connect(func():
		if _current_theme == "custom":
			_apply_custom_theme(_custom_color)
	)

	# Font selector
	for i in _fonts.size():
		_font_opt.add_item(_fonts[i]["name"], i)
		if _fonts[i]["name"] == _current_font:
			_font_opt.selected = i
	_font_opt.item_selected.connect(func(idx: int):
		_current_font = _fonts[idx]["name"]
		_apply_font(_fonts[idx]["path"])
	)

	# Detail panel buttons
	dl_btn.pressed.connect(_on_download_pressed)
	transfer_btn.pressed.connect(_on_transfer_pressed)
	copy_btn.pressed.connect(_on_copy_pressed)
	move_btn.pressed.connect(_on_move_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)
	url_copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(detail_url.text))

	# Overlay
	overlay.gui_input.connect(_on_overlay_input)

	# Dialog close buttons
	$SearchDialog/DlgBase/DlgMargin/DlgInner/TitleRow/CloseXBtn.pressed.connect(_close_dialog)
	$MkdirDialog/DlgBase/DlgMargin/DlgInner/TitleRow/CloseXBtn.pressed.connect(_close_dialog)
	$MoveDialog/DlgBase/DlgMargin/DlgInner/TitleRow/CloseXBtn.pressed.connect(_close_dialog)
	$ConfirmDialog/DlgBase/DlgMargin/DlgInner/TitleRow/CloseXBtn.pressed.connect(_close_dialog)

	# Search dialog
	search_input.text_submitted.connect(_do_search.unbind(1))
	$SearchDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SearchRow/SearchGoBtn.pressed.connect(_do_search)
	search_results.item_activated.connect(_on_search_result_activated)
	$SearchDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SearchCloseBtn.pressed.connect(_close_dialog)

	# Mkdir dialog
	mkdir_input.text_submitted.connect(_do_mkdir.unbind(1))
	$MkdirDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MkdirBtnRow/MkdirCancelBtn.pressed.connect(_close_dialog)
	$MkdirDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MkdirBtnRow/MkdirOkBtn.pressed.connect(_do_mkdir)

	# Move dialog
	move_input.text_submitted.connect(_do_move.unbind(1))
	$MoveDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MoveBtnRow/MoveCancelBtn.pressed.connect(_close_dialog)
	$MoveDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MoveBtnRow/MoveCopyBtn.pressed.connect(
		func(): move_is_copy = true; _do_move())
	$MoveDialog/DlgBase/DlgMargin/DlgInner/DlgContent/MoveBtnRow/MoveOkBtn.pressed.connect(
		func(): move_is_copy = false; _do_move())

	# Confirm dialog
	$ConfirmDialog/DlgBase/DlgMargin/DlgInner/DlgContent/ConfirmBtnRow/ConfirmCancelBtn.pressed.connect(_close_dialog)
	$ConfirmDialog/DlgBase/DlgMargin/DlgInner/DlgContent/ConfirmBtnRow/ConfirmOkBtn.pressed.connect(func():
		_close_dialog()
		if _confirm_callback.is_valid():
			_confirm_callback.call()
	)

	# Sync dialog
	$SyncDialog/DlgBase/DlgMargin/DlgInner/TitleRow/CloseXBtn.pressed.connect(_close_dialog)
	$SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncBtnRow/SyncCancelBtn.pressed.connect(_close_dialog)
	$SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncBtnRow/UseLocalBtn.pressed.connect(
		func(): _close_dialog(); _do_sync(true))
	$SyncDialog/DlgBase/DlgMargin/DlgInner/DlgContent/SyncBtnRow/UseRemoteBtn.pressed.connect(
		func(): _close_dialog(); _do_sync(false))
	_sync_btn.pressed.connect(_on_sync_pressed)

	# File pane setup
	_apply_file_pane_colors(left_pane)
	_apply_file_pane_colors(right_pane)
	left_pane.setup(FilePane.Source.LOCAL, api, _local_home())
	right_pane.setup(FilePane.Source.REMOTE, api, "/")

	_connect_pane(left_pane)
	_connect_pane(right_pane)
	right_pane.upload_requested.connect(_on_upload_requested)
	right_pane.directory_loaded.connect(_on_right_pane_loaded)

	# Apply visual theme
	_apply_main_theme_colors()
	_apply_font("")
	call_deferred("_apply_responsive_layout")
	_set_status("Enter server URL and press Connect.")

# ─────────────────────────────────────────────────────────────────────────────
#  Responsive layout
# ─────────────────────────────────────────────────────────────────────────────
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var narrow := DisplayServer.window_get_size().x < _MOBILE_BP
	if narrow != _mobile_mode:
		_mobile_mode = narrow
		left_pane.set_compact(narrow)
		right_pane.set_compact(narrow)
	_detail_panel.visible = not _mobile_mode or _has_selection

# ─────────────────────────────────────────────────────────────────────────────
#  Toolbar callbacks
# ─────────────────────────────────────────────────────────────────────────────
func _toggle_left_pane() -> void:
	_left_pane_hidden = not _left_pane_hidden
	left_pane.visible = not _left_pane_hidden
	_hide_l_btn.text         = "▶ L" if _left_pane_hidden else "◀ L"
	_hide_l_btn.tooltip_text = "Show left pane" if _left_pane_hidden else "Hide left pane"

func _connect_pane(pane: FilePane) -> void:
	pane.selection_changed.connect(_on_pane_selection_changed.bind(pane))
	pane.file_opened.connect(_on_pane_file_opened.bind(pane))
	pane.delete_requested.connect(_on_pane_delete_requested.bind(pane))
	pane.status_message.connect(_set_status)
	pane.mkdir_requested.connect(_on_mkdir_requested.bind(pane))
	pane.drop_received.connect(_on_drop_received.bind(pane))

func _on_connect_pressed() -> void:
	var url := url_input.text.strip_edges()
	if url.is_empty():
		_set_status("Please enter a server URL.")
		return
	if not url.begins_with("http"):
		url = "http://" + url
		url_input.text = url
	var user := user_input.text.strip_edges()
	var pw   := pw_input.text.strip_edges()
	var auth := (user + ":" + pw) if (user and pw) else pw
	api.configure(url, auth)
	right_pane.navigate_to("/")

func _set_auth_ui(authed: bool) -> void:
	_is_authed         = authed
	_user_lbl.visible  = not authed
	user_input.visible = not authed
	_pw_lbl.visible    = not authed
	pw_input.visible   = not authed
	_apply_btn(login_btn, C_DANGER if authed else C_ACCENT2)

func _on_login_pressed() -> void:
	var url := url_input.text.strip_edges()
	if _is_authed:
		api.configure(url, "")
		login_btn.text = ICO_UNLOCK + " Auth"
		_set_auth_ui(false)
		_set_status("Auth cleared.")
		right_pane.refresh()
		return
	var user := user_input.text.strip_edges()
	var pw   := pw_input.text.strip_edges()
	if pw.is_empty():
		_set_status("Enter a password to authenticate.")
		return
	var auth := (user + ":" + pw) if (user and pw) else pw
	if user.is_empty() or OS.has_feature("web"):
		api.configure(url, auth)
		login_btn.text = ICO_LOCK + " Authed"
		_set_auth_ui(true)
		_set_status("Password set." if user.is_empty() else "Auth set via password parameter.")
		right_pane.refresh()
		return
	api.configure(url, auth)
	_set_status("Logging in…")
	var ok := await api.login(user, pw)
	if ok:
		login_btn.text = ICO_LOCK + " Authed"
		_set_status("Logged in as %s." % user)
	else:
		login_btn.text = ICO_LOCK + " Authed"
		_set_status("Auth set via password header.")
	_set_auth_ui(true)
	right_pane.refresh()

# ─────────────────────────────────────────────────────────────────────────────
#  Pane signal handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_right_pane_loaded(acct: String, perms: Array) -> void:
	if acct == "*":
		login_btn.text = ICO_UNLOCK + " Auth"
		_set_auth_ui(false)
	else:
		login_btn.text = ICO_LOCK + " " + acct
		_set_auth_ui(true)
	var del_ok := "delete" in perms
	var mov_ok := "move" in perms and "write" in perms
	if not del_ok or not mov_ok:
		var missing := []
		if not del_ok: missing.append("delete")
		if not mov_ok: missing.append("move")
		_set_status("Logged in as %s — missing perms: %s" % [acct, ", ".join(missing)] if acct != "*" \
			else "Not authenticated — connect with user:password to enable file operations")

func _on_pane_selection_changed(entry: Dictionary, pane: FilePane) -> void:
	if not entry.is_empty():
		active_pane = pane
	if active_pane == pane:
		_update_detail_panel(entry)

func _on_pane_file_opened(entry: Dictionary, pane: FilePane) -> void:
	active_pane = pane
	if pane.source == FilePane.Source.LOCAL:
		OS.shell_open(entry.get("href", ""))
	else:
		var url := api.get_download_url(_entry_vpath(entry))
		if url:
			OS.shell_open(url)

func _on_pane_delete_requested(entries: Array, pane: FilePane) -> void:
	active_pane = pane
	if entries.size() == 1:
		_confirm_delete(entries[0])
	else:
		_confirm_delete_multi(entries)

func _on_upload_requested(dest_path: String) -> void:
	if not api.is_configured():
		_set_status("Not connected.")
		return
	var menu := PopupMenu.new()
	menu.add_item("Upload files…",  0)
	menu.add_item("Upload folder…", 1)
	menu.id_pressed.connect(func(id: int):
		if id == 0:
			_open_files_upload(dest_path)
		else:
			_open_folder_upload(dest_path)
	)
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i.ZERO))

func _open_files_upload(dest_path: String) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	fd.access    = FileDialog.ACCESS_FILESYSTEM
	fd.title     = "Select files to upload"
	fd.files_selected.connect(func(paths: PackedStringArray):
		fd.queue_free()
		await _do_upload_files(paths, dest_path)
	)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered(Vector2i(800, 600))

func _open_folder_upload(dest_path: String) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.access    = FileDialog.ACCESS_FILESYSTEM
	fd.title     = "Select folder to upload"
	fd.dir_selected.connect(func(path: String):
		fd.queue_free()
		var folder_name := path.get_file()
		var total := _count_local_files(path)
		_show_progress(max(total, 1))
		_xfer_progress = 0
		_set_status("Uploading %s/ …" % folder_name)
		var n := await _upload_dir(path, dest_path)
		_hide_progress()
		_set_status("Uploaded %d file(s) from %s/." % [n, folder_name])
		right_pane.refresh()
	)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered(Vector2i(800, 600))

func _on_mkdir_requested(_dest_path: String, pane: FilePane) -> void:
	if pane.source == FilePane.Source.REMOTE and not api.is_configured():
		_set_status("Not connected.")
		return
	_mkdir_pane = pane
	mkdir_input.text = ""
	_show_dialog("MkdirDialog")
	mkdir_input.grab_focus()

# ─────────────────────────────────────────────────────────────────────────────
#  Detail panel
# ─────────────────────────────────────────────────────────────────────────────
func _update_detail_panel(entry: Dictionary) -> void:
	if entry.is_empty():
		_clear_detail()
		return
	_has_selection = true
	if _mobile_mode:
		_detail_panel.visible = true

	var count:    int   = active_pane.get_selected_count() if active_pane else 1
	var is_local: bool  = entry.get("local", false)
	var perms:    Array = active_pane.current_perms if active_pane else []

	if count > 1:
		var total:   int  = 0
		var has_dir: bool = false
		for e in active_pane.get_selected_entries():
			if e.get("is_dir", false):
				has_dir = true
			else:
				total += e.get("size", 0) as int
		detail_name.text    = "%d items selected" % count
		detail_size.text    = "—" if has_dir else Format.size(total)
		detail_date.text    = "—"
		detail_ext.text     = "—"
		detail_url_lbl.text = ""
		detail_url.text     = ""
		dl_btn.text         = "Open All" if is_local else ICO_DL + " Download All"
		transfer_btn.text   = ICO_XFER + (" Upload →" if is_local else " ← Save All")
		dl_btn.disabled       = false
		transfer_btn.disabled = false
		copy_btn.disabled     = true
		move_btn.disabled     = true
		url_copy_btn.disabled = true
		delete_btn.disabled   = not (is_local or "delete" in perms)
		_sync_btn.disabled    = true
		return

	var entry_name: String = entry.get("name",   "?")
	var file_size: int  = entry.get("size",   0)
	var ts:     int    = entry.get("ts",     0)
	var ext:    String = entry.get("ext",    "—")
	var is_dir: bool   = entry.get("is_dir", false)

	detail_name.text = entry_name
	detail_size.text = "—" if is_dir else Format.size(file_size)
	detail_date.text = Format.ts(ts)
	detail_ext.text  = "Directory" if is_dir else ext.to_upper()

	if is_local:
		detail_url_lbl.text   = "Local Path"
		detail_url.text       = entry.get("href", "")
		dl_btn.text           = "Open"
		transfer_btn.text     = ICO_XFER + " Upload →"
		url_copy_btn.text     = ICO_LINK + " Copy Path"
		url_copy_btn.disabled = false
		copy_btn.disabled     = true
		move_btn.disabled     = true
	else:
		detail_url_lbl.text   = "Direct URL"
		detail_url.text       = api.get_download_url(_entry_vpath(entry))
		dl_btn.text           = ICO_DL + " Download"
		transfer_btn.text     = ICO_XFER + " ← Save"
		url_copy_btn.text     = ICO_LINK + " Copy URL"
		url_copy_btn.disabled = false
		copy_btn.disabled     = not ("write" in perms)
		move_btn.disabled     = not ("move" in perms and "write" in perms)

	dl_btn.disabled       = false
	transfer_btn.disabled = false
	delete_btn.disabled   = not (is_local or "delete" in perms)
	var other_pane := right_pane if active_pane == left_pane else left_pane
	_sync_btn.disabled = not (
		not is_dir
		and active_pane.get_selected_count() == 1
		and left_pane.source != right_pane.source
		and not other_pane.find_entry_by_name(entry.get("name", "")).is_empty()
	)

func _clear_detail() -> void:
	_has_selection = false
	detail_name.text = "—"
	detail_size.text = "—"
	detail_date.text = "—"
	detail_ext.text  = "—"
	detail_url.text  = ""
	dl_btn.disabled       = true
	transfer_btn.disabled = true
	copy_btn.disabled     = true
	move_btn.disabled     = true
	delete_btn.disabled   = true
	url_copy_btn.disabled = false
	_sync_btn.disabled    = true
	if _mobile_mode:
		_detail_panel.visible = false

# ─────────────────────────────────────────────────────────────────────────────
#  Dialogs
# ─────────────────────────────────────────────────────────────────────────────
func _show_dialog(dname: String) -> void:
	if active_dialog:
		active_dialog.visible = false
	var dlg := find_child(dname, true, false) as Control
	if dlg:
		active_dialog = dlg
		overlay.visible = true
		dlg.visible = true
		var vp := get_viewport_rect().size
		var w  := minf(dlg.custom_minimum_size.x, vp.x * 0.92)
		var h  := minf(dlg.custom_minimum_size.y, vp.y * 0.88)
		dlg.anchor_left   = 0.5; dlg.anchor_right  = 0.5
		dlg.anchor_top    = 0.5; dlg.anchor_bottom  = 0.5
		dlg.offset_left   = -w * 0.5; dlg.offset_right  = w * 0.5
		dlg.offset_top    = -h * 0.5; dlg.offset_bottom = h * 0.5

func _close_dialog() -> void:
	overlay.visible = false
	if active_dialog:
		active_dialog.visible = false
		active_dialog = null

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_dialog()

# ─────────────────────────────────────────────────────────────────────────────
#  File actions
# ─────────────────────────────────────────────────────────────────────────────
func _on_download_pressed() -> void:
	if active_pane == null:
		return
	for entry in active_pane.get_selected_entries():
		if entry.get("local", false):
			OS.shell_open(entry.get("href", ""))
		else:
			var url := api.get_download_url(_entry_vpath(entry))
			if url:
				OS.shell_open(url)

func _on_transfer_pressed() -> void:
	if active_pane == null:
		return
	var entries := active_pane.get_selected_entries()
	if entries.is_empty():
		return
	_show_progress(entries.size())
	await get_tree().process_frame
	if active_pane == left_pane:
		for entry in entries:
			await _transfer_local_to_remote(entry, right_pane.current_path)
		_hide_progress()
		await right_pane.refresh()
	else:
		for entry in entries:
			await _transfer_remote_to_local(entry, left_pane.current_path)
		_hide_progress()
		await left_pane.refresh()

func _on_drop_received(entries: Array, source_pane: FilePane, dest_pane: FilePane) -> void:
	if entries.is_empty():
		return
	_show_progress(entries.size())
	await get_tree().process_frame
	for entry in entries:
		if source_pane.source == FilePane.Source.LOCAL and dest_pane.source == FilePane.Source.REMOTE:
			await _transfer_local_to_remote(entry, dest_pane.current_path)
		elif source_pane.source == FilePane.Source.REMOTE and dest_pane.source == FilePane.Source.LOCAL:
			await _transfer_remote_to_local(entry, dest_pane.current_path)
	_hide_progress()
	await dest_pane.refresh()

func _transfer_local_to_remote(entry: Dictionary, dest_path: String) -> void:
	var entry_name: String = entry.get("name", "")
	progress_label.text = entry_name
	if entry.get("is_dir", false):
		var total := _count_local_files(entry.get("href", ""))
		progress_bar.max_value = max(total, 1)
		progress_bar.value     = 0
		_xfer_progress         = 0
		_set_status("Uploading %s/ …" % entry_name)
		var n := await _upload_dir(entry.get("href", ""), dest_path)
		_set_status("Uploaded %d file(s) from %s/." % [n, entry_name])
	else:
		progress_bar.max_value = 1
		progress_bar.value     = 0
		_set_status("Uploading %s …" % entry_name)
		var data := FileAccess.get_file_as_bytes(entry.get("href", ""))
		if data.is_empty():
			_set_status("Cannot read: " + entry.get("href", ""))
			return
		var code := await api.upload_file(dest_path, entry_name, data)
		progress_bar.value = 1
		_set_status(("Uploaded %s." % entry_name) if code in [200, 201] else ("Upload failed (HTTP %d): %s" % [code, entry_name]))

func _transfer_remote_to_local(entry: Dictionary, dest_path: String) -> void:
	var entry_name: String = entry.get("name", "")
	progress_label.text = entry_name
	if entry.get("is_dir", false):
		progress_bar.max_value = 1
		progress_bar.value     = 0
		_xfer_progress         = 0
		_set_status("Downloading %s/ …" % entry_name)
		var n := await _download_dir(_entry_vpath(entry), dest_path)
		_set_status("Downloaded %d file(s) from %s/." % [n, entry_name])
	else:
		progress_bar.max_value = 1
		progress_bar.value     = 0
		_set_status("Downloading %s …" % entry_name)
		var data := await api.download_file(_entry_vpath(entry))
		if data.is_empty():
			_set_status("Download failed: " + entry_name)
			return
		var dest: String = dest_path.path_join(entry_name)
		var fa := FileAccess.open(dest, FileAccess.WRITE)
		if fa == null:
			_set_status("Cannot write: " + dest)
			return
		fa.store_buffer(data)
		progress_bar.value = 1
		_set_status("Saved %s." % entry_name)

func _upload_dir(local_path: String, remote_dest: String) -> int:
	var dir_name := local_path.get_file()
	var remote_sub := remote_dest.rstrip("/") + "/" + dir_name
	await api.make_directory(remote_dest, dir_name)
	var dir := DirAccess.open(local_path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full: String = local_path.path_join(fname)
			if dir.current_is_dir():
				count += await _upload_dir(full, remote_sub)
			else:
				var data := FileAccess.get_file_as_bytes(full)
				if not data.is_empty():
					progress_label.text = fname
					var code := await api.upload_file(remote_sub, fname, data)
					if code in [200, 201]:
						count += 1
						_xfer_progress += 1
						progress_bar.max_value = max(progress_bar.max_value, _xfer_progress)
						progress_bar.value     = _xfer_progress
		fname = dir.get_next()
	dir.list_dir_end()
	return count

func _download_dir(remote_path: String, local_dest: String) -> int:
	var dir_name := remote_path.rstrip("/").get_file()
	var local_sub := local_dest.path_join(dir_name)
	DirAccess.make_dir_recursive_absolute(local_sub)
	var result: Variant = await api.list_directory(remote_path)
	if result == null:
		return 0
	var count := 0
	for e in result.get("files", []):
		progress_label.text = e.get("name", "")
		var data := await api.download_file(_entry_vpath(e))
		if not data.is_empty():
			var fa := FileAccess.open(local_sub.path_join(e.get("name", "")), FileAccess.WRITE)
			if fa:
				fa.store_buffer(data)
				count += 1
				_xfer_progress += 1
				progress_bar.max_value = max(progress_bar.max_value, _xfer_progress)
				progress_bar.value = _xfer_progress
	for e in result.get("dirs", []):
		count += await _download_dir(_entry_vpath(e), local_sub)
	return count

func _count_local_files(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := path.path_join(fname)
			if dir.current_is_dir():
				count += _count_local_files(full)
			else:
				count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count

func _on_delete_pressed() -> void:
	if active_pane == null:
		return
	var entries := active_pane.get_selected_entries()
	if entries.is_empty():
		return
	if entries.size() == 1:
		_confirm_delete(entries[0])
	else:
		_confirm_delete_multi(entries)

func _confirm_delete(entry: Dictionary) -> void:
	var entry_name: String = entry.get("name", "?")
	_confirm_msg_label.text = 'Delete "%s"?\nThis cannot be undone.' % entry_name
	_confirm_callback = func(): _do_delete(entry)
	_show_dialog("ConfirmDialog")

func _do_delete(entry: Dictionary) -> void:
	if entry.get("local", false):
		var path: String = entry.get("href", "")
		var err := OS.move_to_trash(path)
		var msg := "Moved to trash." if err == OK else "Delete failed (error %d)." % err
		await left_pane.refresh()
		_set_status(msg)
	else:
		_set_status("Deleting…")
		var result := await api.delete_path(_entry_vpath(entry))
		var code: int    = result[0]
		var body: String = result[1]
		var msg := "Deleted." if code == 200 else "Delete failed (HTTP %d): %s" % [code, body]
		await right_pane.refresh()
		_set_status(msg)

func _confirm_delete_multi(entries: Array) -> void:
	_confirm_msg_label.text = 'Delete %d items?\nThis cannot be undone.' % entries.size()
	_confirm_callback = func(): _do_delete_multi(entries)
	_show_dialog("ConfirmDialog")

func _do_delete_multi(entries: Array) -> void:
	var ok_count := 0
	var fail_count := 0
	for entry in entries:
		if entry.get("local", false):
			var err := OS.move_to_trash(entry.get("href", ""))
			if err == OK:
				ok_count += 1
			else:
				fail_count += 1
		else:
			var result := await api.delete_path(_entry_vpath(entry))
			if result[0] == 200:
				ok_count += 1
			else:
				fail_count += 1
	if fail_count == 0:
		_set_status("Deleted %d item(s)." % ok_count)
	else:
		_set_status("Deleted %d, failed %d." % [ok_count, fail_count])
	left_pane.refresh()
	right_pane.refresh()

func _on_sync_pressed() -> void:
	var entry  := active_pane.get_selected_entry()
	var fname: String = entry.get("name", "")
	var other  := right_pane if active_pane == left_pane else left_pane
	var match  := other.find_entry_by_name(fname)
	if match.is_empty():
		_set_status("No matching file found in the other pane.")
		return
	if active_pane.source == FilePane.Source.LOCAL:
		_sync_local_entry = entry;  _sync_remote_entry = match
	else:
		_sync_local_entry = match;  _sync_remote_entry = entry
	_sync_local_ts.text  = Format.ts(_sync_local_entry.get("ts", 0))
	_sync_local_sz.text  = Format.size(_sync_local_entry.get("size", 0))
	_sync_remote_ts.text = Format.ts(_sync_remote_entry.get("ts", 0))
	_sync_remote_sz.text = Format.size(_sync_remote_entry.get("size", 0))
	var lts: int = _sync_local_entry.get("ts", 0)
	var rts: int = _sync_remote_entry.get("ts", 0)
	if lts > rts:
		_sync_newer_lbl.text = "Local is newer — recommended: Use Local →"
	elif rts > lts:
		_sync_newer_lbl.text = "Remote is newer — recommended: ← Use Remote"
	else:
		_sync_newer_lbl.text = "Both versions have the same timestamp."
	_show_dialog("SyncDialog")

func _do_sync(use_local: bool) -> void:
	if use_local:
		await _transfer_local_to_remote(_sync_local_entry, right_pane.current_path)
		await right_pane.refresh()
	else:
		await _transfer_remote_to_local(_sync_remote_entry, left_pane.current_path)
		await left_pane.refresh()

func _on_copy_pressed() -> void:
	if active_pane != right_pane:
		return
	var entry: Dictionary = right_pane.get_selected_entry()
	if entry.is_empty():
		return
	move_src_path = _entry_vpath(entry)
	move_is_copy  = true
	move_input.text = right_pane.current_path.rstrip("/") + "/" + entry.get("name", "copy")
	_show_dialog("MoveDialog")

func _on_move_pressed() -> void:
	if active_pane != right_pane:
		return
	var entry: Dictionary = right_pane.get_selected_entry()
	if entry.is_empty():
		return
	move_src_path = _entry_vpath(entry)
	move_is_copy  = false
	move_input.text = right_pane.current_path.rstrip("/") + "/" + entry.get("name", "")
	_show_dialog("MoveDialog")

func _do_move() -> void:
	var dst := move_input.text.strip_edges()
	if dst.is_empty() or move_src_path.is_empty():
		return
	_close_dialog()
	_set_status(("Copying" if move_is_copy else "Moving") + "…")
	var ok: bool
	if move_is_copy:
		ok = await api.copy_path(move_src_path, dst)
	else:
		ok = await api.move_path(move_src_path, dst)
	_set_status("Done." if ok else "Operation failed.")
	right_pane.refresh()

# ─────────────────────────────────────────────────────────────────────────────
#  Progress helpers
# ─────────────────────────────────────────────────────────────────────────────
func _show_progress(max_val: int = 1) -> void:
	_detail_panel.visible  = true
	progress_bar.max_value = max_val
	progress_bar.value     = 0
	progress_bar.visible   = true
	progress_label.visible = true
	if not _spinning:
		_spinning = true
		_run_spin()

func _hide_progress() -> void:
	progress_bar.visible   = false
	progress_label.visible = false
	if _mobile_mode and not _has_selection:
		_detail_panel.visible = false
	_spinning = false
	_godocog1.rotation = 0.0
	_godocog2.rotation = 0.0

func _run_spin() -> void:
	_godocog1.rotation = 0.0
	_godocog2.rotation = 0.0
	var t_prev := Time.get_ticks_msec()
	while _spinning:
		await get_tree().process_frame
		var t_now := Time.get_ticks_msec()
		var dt    := (t_now - t_prev) / 1000.0
		t_prev = t_now
		_godocog1.rotation += dt * TAU / 1.5
		_godocog2.rotation -= dt * TAU / 1.5
		var remaining := progress_bar.max_value - progress_bar.value
		if remaining > 0.001:
			progress_bar.value += remaining * dt * 0.4

func _on_os_files_dropped(files: PackedStringArray) -> void:
	var mp := get_global_mouse_position()
	var vp := get_viewport().get_mouse_position()
	print("files_dropped: global_mouse=%s  viewport_mouse=%s  left_rect=%s  right_rect=%s" % [
		mp, vp, left_pane.get_global_rect(), right_pane.get_global_rect()])
	var target: FilePane
	if right_pane.get_global_rect().has_point(mp):
		target = right_pane
	elif left_pane.get_global_rect().has_point(mp):
		target = left_pane
	else:
		return
	var dest := target.current_path
	if target.source == FilePane.Source.LOCAL:
		await _save_dropped_files_locally(files, dest, target)
		return
	var file_paths: PackedStringArray = []
	for p in files:
		if DirAccess.dir_exists_absolute(p):
			_show_progress()
			await get_tree().process_frame
			await _upload_dir(p, dest)
			_hide_progress()
			target.refresh()
		else:
			file_paths.append(p)
	if not file_paths.is_empty():
		await _upload_os_files(file_paths, dest, target)

func _setup_web_drop_listener() -> void:
	# Inject a JS drop listener (capture phase, before Godot's handler) that
	# recursively enumerates dropped directories and stores a filename→relpath map
	# in window._dropPaths. GDScript reads this map in _upload_os_files to reconstruct
	# folder structure, since Godot's files_dropped signal flattens all paths.
	JavaScriptBridge.eval("""
(function(){
    window._dropPaths={};
    function scanDir(entry,prefix,cb){
        var reader=entry.createReader(),all=[];
        (function read(){reader.readEntries(function(batch){
            if(!batch.length){
                var n=all.length;if(!n){cb();return;}
                all.forEach(function(e){
                    var p=prefix+'/'+e.name;
                    if(e.isDirectory){scanDir(e,p,function(){if(!--n)cb();});}
                    else{window._dropPaths[e.name]=p.charAt(0)==='/'?p.slice(1):p;if(!--n)cb();}
                });
            }else{all=all.concat(Array.from(batch));read();}
        });})();
    }
    document.addEventListener('drop',function(e){
        window._dropPaths={};
        var entries=Array.from(e.dataTransfer.items||[])
            .map(function(i){return i.webkitGetAsEntry?i.webkitGetAsEntry():null;})
            .filter(function(e){return e&&e.isDirectory;});
        var n=entries.length;if(!n)return;
        entries.forEach(function(d){scanDir(d,d.name,function(){if(!--n){}});});
    },true);
})();
""")

func _upload_os_files(paths: PackedStringArray, dest: String, pane: FilePane) -> void:
	var all_rels: Array[String] = []
	var all_data: Array[PackedByteArray] = []

	if OS.has_feature("web"):
		# Read the filename→relpath map captured by the JS drop listener before any await,
		# then read all file data — both must happen before the first yield (temp cleanup).
		var paths_json: String = JavaScriptBridge.eval("JSON.stringify(window._dropPaths||{})")
		var js_map: Dictionary = JSON.parse_string(paths_json) if paths_json else {}
		for p in paths:
			var fname := p.get_file()
			var rel: String = js_map.get(fname, "")
			all_rels.append(rel if rel else fname)
			all_data.append(FileAccess.get_file_as_bytes(p))
	else:
		var base := paths[0].get_base_dir()
		for p in paths:
			while base != "/" and base != "" and not p.begins_with(base + "/"):
				base = base.get_base_dir()
		for p in paths:
			all_rels.append(p.trim_prefix(base).trim_prefix("/"))
			all_data.append(FileAccess.get_file_as_bytes(p))

	var subdirs: Array[String] = []
	for rel in all_rels:
		var rel_dir := rel.get_base_dir()
		if rel_dir and rel_dir not in subdirs:
			subdirs.append(rel_dir)
	subdirs.sort()
	for d in subdirs:
		var so_far := dest
		for part in d.split("/"):
			await api.make_directory(so_far, part)
			so_far = so_far.rstrip("/") + "/" + part

	_show_progress(all_rels.size())
	await get_tree().process_frame
	var success := 0
	for i in all_rels.size():
		var rel        := all_rels[i]
		var remote_dir := dest.rstrip("/") + ("/" + rel.get_base_dir() if rel.get_base_dir() else "")
		if all_data[i].is_empty():
			_set_status("Cannot read: " + rel)
			continue
		var code := await api.upload_file(remote_dir, rel.get_file(), all_data[i])
		if code in [200, 201]:
			success += 1
		else:
			_set_status("Upload failed (%d): %s" % [code, rel])
	_hide_progress()
	_set_status("Uploaded %d/%d file(s)." % [success, all_rels.size()])
	pane.refresh()

func _save_dropped_files_locally(files: PackedStringArray, dest_path: String, refresh_pane: FilePane) -> void:
	var all_data: Array[PackedByteArray] = []
	for p in files:
		all_data.append(FileAccess.get_file_as_bytes(p))
	_show_progress(files.size())
	await get_tree().process_frame
	var success := 0
	for i in files.size():
		var fname := files[i].get_file()
		var data := all_data[i]
		progress_bar.value = float(i)
		_set_status("Saving %s …" % fname)
		if data.is_empty():
			_set_status("Cannot read: " + files[i])
			continue
		var fa := FileAccess.open(dest_path.path_join(fname), FileAccess.WRITE)
		if fa == null:
			_set_status("Cannot write: " + dest_path.path_join(fname))
			continue
		fa.store_buffer(data)
		success += 1
	_hide_progress()
	_set_status("Saved %d/%d file(s)." % [success, files.size()])
	refresh_pane.refresh()

# ─────────────────────────────────────────────────────────────────────────────
#  Upload
# ─────────────────────────────────────────────────────────────────────────────
func _do_upload_files(paths: PackedStringArray, dest_path: String, refresh_pane: FilePane = null) -> void:
	if paths.is_empty():
		return
	var all_data: Array[PackedByteArray] = []
	for fpath in paths:
		all_data.append(FileAccess.get_file_as_bytes(fpath))
	_show_progress(paths.size())
	await get_tree().process_frame
	var success := 0
	for i in paths.size():
		var fpath: String = paths[i]
		var fname: String = fpath.get_file()
		var data: PackedByteArray = all_data[i]
		progress_bar.value  = float(i)
		progress_label.text = "%d/%d" % [i + 1, paths.size()]
		_set_status("Uploading %s …" % fname)
		if data.is_empty():
			_set_status("Cannot read: " + fpath)
			continue
		var code := await api.upload_file(dest_path, fname, data)
		progress_bar.value = float(i + 1)
		if code in [200, 201]:
			success += 1
		else:
			_set_status("Upload failed (HTTP %d): %s" % [code, fname])
	_hide_progress()
	_set_status("Uploaded %d/%d file(s)." % [success, paths.size()])
	var pane := refresh_pane if refresh_pane != null else right_pane
	pane.refresh()

# ─────────────────────────────────────────────────────────────────────────────
#  Mkdir / Search
# ─────────────────────────────────────────────────────────────────────────────
func _do_mkdir() -> void:
	var folder_name := mkdir_input.text.strip_edges()
	if folder_name.is_empty() or _mkdir_pane == null:
		return
	_close_dialog()
	_set_status("Creating folder…")
	if _mkdir_pane.source == FilePane.Source.LOCAL:
		var new_path := _mkdir_pane.current_path.path_join(folder_name)
		var err := DirAccess.make_dir_recursive_absolute(new_path)
		_set_status("Folder created." if err == OK else "Create failed.")
	else:
		var ok := await api.make_directory(_mkdir_pane.current_path, folder_name)
		_set_status("Folder created." if ok else "Create failed.")
	_mkdir_pane.refresh()

func _show_search_dialog() -> void:
	if not api.is_configured():
		_set_status("Not connected.")
		return
	search_results.clear()
	search_entries.clear()
	_show_dialog("SearchDialog")
	search_input.grab_focus()

func _do_search() -> void:
	var query := search_input.text.strip_edges()
	if query.is_empty():
		return
	search_results.clear()
	search_entries.clear()
	search_results.add_item("Searching…")
	_set_status("Searching: " + query)
	var result: Variant = await api.search(query, "/")
	search_results.clear()
	if result == null:
		search_results.add_item("Search failed — check connection or server indexing.")
		_set_status("Search failed.")
		return
	var hits: Array = []
	if result is Dictionary:
		hits = result.get("hits", result.get("files", []))
	elif result is Array:
		hits = result
	if hits.is_empty():
		search_results.add_item("No results found.")
		_set_status("Search: no results.")
		return
	for h in hits:
		if h is Dictionary:
			var rp: String   = h.get("rp", h.get("href", ""))
			var sz: int      = h.get("sz", 0)
			var ts: int      = h.get("ts", 0)
			var entry_name: String = rp.rsplit("/", true, 1)[-1].uri_decode() if "/" in rp else rp
			search_results.add_item("%s  %s  (%s)" % [ICO_FILE, entry_name, Format.size(sz)])
			search_entries.append({"href": rp, "name": entry_name, "size": sz, "ts": ts,
				"is_dir": false, "ext": ""})
	_set_status("Search: %d result(s)." % hits.size())

func _on_search_result_activated(idx: int) -> void:
	if idx < 0 or idx >= search_entries.size():
		return
	var entry: Dictionary = search_entries[idx]
	var rp: String = entry.get("href", "/")
	var dir := rp.rsplit("/", true, 1)[0] if "/" in rp else "/"
	_close_dialog()
	right_pane.navigate_to(dir)

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _entry_vpath(entry: Dictionary) -> String:
	var href: String = entry.get("href", "")
	if "?" in href:
		href = href.split("?")[0]
	return href

func _local_home() -> String:
	var h := OS.get_environment("HOME")
	if h:
		return h
	h = OS.get_environment("USERPROFILE")
	return h if h else "/"

func _set_status(msg: String) -> void:
	if status_log == null:
		return
	var cur := status_log.text
	status_log.text = msg if cur.is_empty() else cur + "\n" + msg
	status_log.scroll_vertical = INF

# ─────────────────────────────────────────────────────────────────────────────
#  Theming
# ─────────────────────────────────────────────────────────────────────────────
func _apply_file_pane_colors(pane: FilePane) -> void:
	pane.C_PANEL     = C_PANEL
	pane.C_PANEL_ALT = C_PANEL_ALT
	pane.C_TOOLBAR   = C_TOOLBAR
	pane.C_ACCENT    = C_ACCENT
	pane.C_ACCENT2   = C_ACCENT2
	pane.C_TEXT      = C_TEXT
	pane.C_SUBTEXT   = C_SUBTEXT
	pane.C_BORDER    = C_BORDER

func _apply_theme(theme_name: String) -> void:
	if theme_name == "custom":
		_apply_custom_theme(_custom_color)
		return
	var t: Dictionary = THEMES[theme_name]
	C_BG        = t["BG"];       C_PANEL     = t["PANEL"]
	C_PANEL_ALT = t["PANEL_ALT"]; C_TOOLBAR  = t["TOOLBAR"]
	C_ACCENT    = t["ACCENT"];   C_ACCENT2   = t["ACCENT2"]
	C_DANGER    = t["DANGER"];   C_TEXT      = t["TEXT"]
	C_SUBTEXT   = t["SUBTEXT"];  C_BORDER    = t["BORDER"]
	_apply_file_pane_colors(left_pane)
	_apply_file_pane_colors(right_pane)
	left_pane._apply_theme_colors()
	right_pane._apply_theme_colors()
	left_pane._source_label.add_theme_color_override("font_color", C_ACCENT2)
	right_pane._source_label.add_theme_color_override("font_color", C_ACCENT)
	_apply_main_theme_colors()
	_set_status("Theme: " + theme_name)

func _apply_custom_theme(color: Color) -> void:
	_custom_color = color
	var h  := color.h
	var s  := maxf(color.s, 0.3)
	var bg := _custom_bg_color
	C_BG        = bg
	C_PANEL     = Color.from_hsv(bg.h, bg.s, minf(bg.v + 0.08, 1.0))
	C_PANEL_ALT = Color.from_hsv(bg.h, bg.s, minf(bg.v + 0.06, 1.0))
	C_TOOLBAR   = Color.from_hsv(bg.h, bg.s, minf(bg.v + 0.04, 1.0))
	C_ACCENT    = Color.from_hsv(h, maxf(color.s, 0.50), maxf(color.v, 0.60))
	C_ACCENT2   = Color.from_hsv(fmod(h + 0.33, 1.0), maxf(color.s, 0.50), maxf(color.v, 0.60))
	C_DANGER    = Color(0.85, 0.25, 0.25)
	C_TEXT      = _custom_text_color
	C_SUBTEXT   = Color.from_hsv(_custom_text_color.h, _custom_text_color.s,
			_custom_text_color.v * 0.6)
	C_BORDER    = Color.from_hsv(h, s * 0.30, 0.35)
	_apply_file_pane_colors(left_pane)
	_apply_file_pane_colors(right_pane)
	left_pane._apply_theme_colors()
	right_pane._apply_theme_colors()
	left_pane._source_label.add_theme_color_override("font_color", C_ACCENT2)
	right_pane._source_label.add_theme_color_override("font_color", C_ACCENT)
	_apply_main_theme_colors()

func _apply_main_theme_colors() -> void:
	_bg.color = C_BG
	_apply_panel_bg(_toolbar, C_TOOLBAR)
	_apply_panel_bg(_detail_panel, C_PANEL)
	for sep in [_tb_sep1, _tb_sep2, _tb_sep3, _tb_sep4, _tb_sep5]:
		_apply_vsep(sep)
	for cpb in [_color_picker_btn, _color_picker_bg, _color_picker_text]:
		cpb.add_theme_color_override("font_color", C_TEXT)
	for lbl in [_server_lbl, _user_lbl, _pw_lbl]:
		lbl.add_theme_color_override("font_color", C_SUBTEXT)
	_apply_btn(connect_btn, C_ACCENT)
	_apply_btn(login_btn, C_DANGER if _is_authed else C_ACCENT2)
	_apply_btn(_search_btn, C_PANEL)
	_apply_option_btn(_theme_opt)
	_apply_option_btn(_font_opt)
	_style_line_edit(url_input)
	_style_line_edit(user_input)
	_style_line_edit(pw_input)
	_detail_title.add_theme_color_override("font_color", C_ACCENT)
	for lbl in [_actions_label, _log_label, detail_url_lbl]:
		lbl.add_theme_color_override("font_color", C_SUBTEXT)
	for lbl in [detail_name, detail_size, detail_date, detail_ext]:
		lbl.add_theme_color_override("font_color", C_TEXT)
	_style_line_edit(detail_url)
	_apply_btn(dl_btn, C_ACCENT)
	_apply_btn(transfer_btn, C_ACCENT2)
	_apply_btn(copy_btn, C_PANEL)
	_apply_btn(move_btn, C_PANEL)
	_apply_btn(delete_btn, C_DANGER)
	_apply_btn(url_copy_btn, C_PANEL)
	_apply_btn(_sync_btn, C_ACCENT2)
	status_log.add_theme_color_override("font_color", C_TEXT)
	var sls := StyleBoxFlat.new()
	sls.bg_color = C_BG
	sls.set_corner_radius_all(4)
	sls.content_margin_left = 6; sls.content_margin_right  = 6
	sls.content_margin_top  = 4; sls.content_margin_bottom = 4
	status_log.add_theme_stylebox_override("normal", sls)
	status_log.add_theme_stylebox_override("focus",  sls)
	progress_label.add_theme_color_override("font_color", C_SUBTEXT)
	for dlg in [_search_dialog, _mkdir_dialog, _move_dialog, _confirm_dialog, _sync_dialog]:
		_apply_dialog_style(dlg)
	search_results.add_theme_color_override("font_color", C_TEXT)
	var sl := StyleBoxFlat.new()
	sl.bg_color = C_BG
	search_results.add_theme_stylebox_override("panel", sl)
	_style_line_edit(search_input)
	_style_line_edit(mkdir_input)
	_style_line_edit(move_input)
	for dlg_name in ["SearchDialog", "MkdirDialog", "MoveDialog", "ConfirmDialog", "SyncDialog"]:
		_apply_dialog_btns(dlg_name)

func _apply_dialog_btns(dlg_name: String) -> void:
	var inner := find_child(dlg_name, true, false)
	if inner == null:
		return
	for btn in inner.find_children("*", "Button", true, false):
		var txt: String = (btn as Button).text
		if txt == "✕" or txt == "Cancel" or txt == "Close":
			_apply_btn(btn as Button, C_PANEL)
		elif txt == "Create" or txt == "Search":
			_apply_btn(btn as Button, C_ACCENT)
		elif txt == "Copy":
			_apply_btn(btn as Button, C_ACCENT2)
		elif txt == "Move":
			_apply_btn(btn as Button, C_ACCENT)
		elif "Delete" in txt:
			_apply_btn(btn as Button, C_DANGER)
		else:
			_apply_btn(btn as Button, C_PANEL)
	for lbl in inner.find_children("*", "Label", true, false):
		var l := lbl as Label
		if l.get_theme_font_size("font_size") >= 14:
			l.add_theme_color_override("font_color", C_ACCENT)
		else:
			l.add_theme_color_override("font_color", C_TEXT)

func _apply_dialog_style(dlg: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_ALT
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size  = 8
	dlg.add_theme_stylebox_override("panel", style)

func _apply_panel_bg(panel: PanelContainer, bg: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	panel.add_theme_stylebox_override("panel", s)

func _apply_vsep(sep: VSeparator) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color             = C_BORDER
	st.content_margin_left  = 0
	st.content_margin_right = 0
	sep.add_theme_stylebox_override("separator", st)
	sep.custom_minimum_size = Vector2(1, 0)

func _apply_btn(btn: Button, bg: Color) -> void:
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

func _apply_option_btn(ob: OptionButton) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = C_PANEL
	s.set_corner_radius_all(4)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top  = 4;  s.content_margin_bottom = 4
	ob.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = C_PANEL.lightened(0.15)
	ob.add_theme_stylebox_override("hover", h)
	ob.add_theme_color_override("font_color", C_TEXT)

func _style_line_edit(le: LineEdit) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8; s.content_margin_right  = 8
	s.content_margin_top  = 4; s.content_margin_bottom = 4
	le.add_theme_stylebox_override("normal", s)
	var fs := s.duplicate() as StyleBoxFlat
	fs.border_color = C_ACCENT
	le.add_theme_stylebox_override("focus", fs)
	le.add_theme_color_override("font_color",             C_TEXT)
	le.add_theme_color_override("font_placeholder_color", C_SUBTEXT)

func _scan_fonts() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"name": "Default", "path": ""}]
	var candidates: Array[Dictionary] = [
		{"name": "OpenDyslexic", "path": "res://fonts/OpenDyslexic3-Regular.ttf"},
		{"name": "Roboto",       "path": "res://fonts/Roboto-Regular.ttf"},
	]
	for c: Dictionary in candidates:
		if ResourceLoader.exists(c["path"]):
			result.append(c)
	result.sort_custom(func(a, b):
		if a["name"] == "Default": return true
		if b["name"] == "Default": return false
		return a["name"] < b["name"]
	)
	return result

func _apply_font(path: String) -> void:
	var font: FontFile = null
	if path.is_empty():
		for f: Dictionary in _fonts:
			if f["name"] == "Roboto" and not f["path"].is_empty():
				font = ResourceLoader.load(f["path"]) as FontFile
				break
	else:
		font = ResourceLoader.load(path) as FontFile
	if font:
		var fbs := font.get_fallbacks()
		if SYMBOLS_FONT and not fbs.has(SYMBOLS_FONT):
			fbs.append(SYMBOLS_FONT)
		if EMOJI_FONT and not fbs.has(EMOJI_FONT):
			fbs.append(EMOJI_FONT)
		font.set_fallbacks(fbs)
		var t := Theme.new()
		t.default_font = font
		theme = t
	else:
		theme = null
