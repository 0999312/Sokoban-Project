extends Control
## SettingsPanel — 静态多 Tab 设置面板（覆盖层）。
##
## 结构：
##   Card (固定 720×520) → Header (Title / Back) + TabContainer
##     - TabGame  : 语言 / 全屏 / 高对比度 / 减弱动画
##     - TabAudio : Master / Music / SFX / UI
##     - TabInput : 键位重绑（动态生成行）
##
## 每个 Tab 的内容都是 ScrollContainer 包 VBox，
## 因此即使内容超过 Card 高度，也能在面板内滚动而不撑出固定面板。
##
## 改动即时应用并保存（无 Apply 按钮，沿用 Phase 2 行为）。

@onready var dim: ColorRect = %Dim
@onready var card: Panel = %Card
@onready var lbl_title: Label = %LblTitle
@onready var btn_back: Button = %BtnBack
@onready var tabs: TabContainer = %Tabs

# Tab 1: Game
@onready var lbl_lang: Label = %LblLang
@onready var opt_lang: OptionButton = %OptLang
@onready var chk_fullscreen: CheckBox = %ChkFullscreen
@onready var chk_high_contrast: CheckBox = %ChkHighContrast
@onready var chk_reduce_motion: CheckBox = %ChkReduceMotion

# Tab 2: Audio
@onready var lbl_master: Label = %LblMaster
@onready var sl_master: HSlider = %SlMaster
@onready var lbl_music: Label = %LblMusic
@onready var sl_music: HSlider = %SlMusic
@onready var lbl_sfx: Label = %LblSfx
@onready var sl_sfx: HSlider = %SlSfx
@onready var lbl_ui: Label = %LblUi
@onready var sl_ui: HSlider = %SlUi

# Tab 3: Input
@onready var lbl_input_header: Label = %LblInputHeader
@onready var btn_reset_bindings: Button = %BtnResetBindings
@onready var lbl_col_action: Label = %LblColAction
@onready var lbl_col_kb: Label = %LblColKb
@onready var lbl_col_pad: Label = %LblColPad
@onready var rebind_list: VBoxContainer = %RebindList

const LOCALES := [
	{ "code": "zh_CN", "label": "简体中文" },
	{ "code": "zh_TW", "label": "繁體中文" },
	{ "code": "en",    "label": "English" },
]

const _REBIND_GAMEPLAY := [
	{ "key": "move_up",    "i18n": "input.action.move_up"    },
	{ "key": "move_down",  "i18n": "input.action.move_down"  },
	{ "key": "move_left",  "i18n": "input.action.move_left"  },
	{ "key": "move_right", "i18n": "input.action.move_right" },
	{ "key": "undo",       "i18n": "input.action.undo"       },
	{ "key": "redo",       "i18n": "input.action.redo"       },
	{ "key": "restart",    "i18n": "input.action.restart"    },
	{ "key": "pause",      "i18n": "input.action.pause"      },
]

const _REBIND_EDITOR := [
	{ "key": "editor_toggle_board_mode", "i18n": "input.action.editor_toggle_board_mode" },
	{ "key": "editor_paint",             "i18n": "input.action.editor_paint" },
	{ "key": "editor_erase",             "i18n": "input.action.editor_erase" },
	{ "key": "editor_tool_prev",         "i18n": "input.action.editor_tool_prev" },
	{ "key": "editor_tool_next",         "i18n": "input.action.editor_tool_next" },
	{ "key": "editor_color_prev",        "i18n": "input.action.editor_color_prev" },
	{ "key": "editor_color_next",        "i18n": "input.action.editor_color_next" },
	{ "key": "editor_shape_cycle",       "i18n": "input.action.editor_shape_cycle" },
	{ "key": "editor_pan_modifier",      "i18n": "input.action.editor_pan_modifier" },
	{ "key": "editor_test_play",         "i18n": "input.action.editor_test_play" },
]

const _REBIND_UI := [
	{ "key": "ui_up",     "i18n": "input.action.ui_up"     },
	{ "key": "ui_down",   "i18n": "input.action.ui_down"   },
	{ "key": "ui_left",   "i18n": "input.action.ui_left"   },
	{ "key": "ui_right",  "i18n": "input.action.ui_right"  },
	{ "key": "ui_accept", "i18n": "input.action.ui_accept" },
	{ "key": "ui_cancel", "i18n": "input.action.ui_cancel" },
]

var _rebind_rows: Array = []      # { context: "gameplay"|"editor"|"ui", action, i18n, name_lbl, btn_kb, btn_pad }
var _listening_btn: Button = null
var _listening_action: String = ""
var _listening_slot: int = -1
var _listening_context: String = ""   # "gameplay" | "editor" | "ui"
var _pending_event: InputEvent = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_locales()
	_load_from_settings()
	_build_rebind_rows()
	_refresh_texts()
	_bind_signals()
	opt_lang.grab_focus.call_deferred()
	# UI 点击音效（一次性挂载到全部 Button）
	if has_node("/root/Sfx"):
		Sfx.attach_ui(self)

func _exit_tree() -> void:
	if EventBus and EventBus.has_method("unsubscribe"):
		EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

# --- Wiring ---

func _bind_signals() -> void:
	dim.gui_input.connect(_on_dim_input)
	btn_back.pressed.connect(_close)
	opt_lang.item_selected.connect(_on_lang_selected)
	sl_master.value_changed.connect(_on_master_changed)
	sl_music.value_changed.connect(_on_music_changed)
	sl_sfx.value_changed.connect(_on_sfx_changed)
	sl_ui.value_changed.connect(_on_ui_changed)
	chk_fullscreen.toggled.connect(_on_fullscreen_toggled)
	chk_high_contrast.toggled.connect(_on_hc_toggled)
	chk_reduce_motion.toggled.connect(_on_rm_toggled)
	btn_reset_bindings.pressed.connect(_on_reset_bindings)
	if EventBus and EventBus.has_method("subscribe"):
		EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _on_dim_input(event: InputEvent) -> void:
	# 监听重绑时不允许点击背景关闭，避免误操作
	if _listening_btn != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _close() -> void:
	_cancel_listen()
	queue_free()

# --- Data load / refresh ---

func _populate_locales() -> void:
	opt_lang.clear()
	for entry in LOCALES:
		opt_lang.add_item(entry.label)

func _load_from_settings() -> void:
	var locale: String = SaveManager.get_setting("locale", "zh_CN")
	var idx := 0
	for i in LOCALES.size():
		if LOCALES[i].code == locale:
			idx = i
			break
	opt_lang.selected = idx
	sl_master.value = float(SaveManager.get_setting("volume_master", 1.0))
	sl_music.value  = float(SaveManager.get_setting("volume_music", 0.8))
	sl_sfx.value    = float(SaveManager.get_setting("volume_sfx", 1.0))
	sl_ui.value     = float(SaveManager.get_setting("volume_ui", 1.0))
	chk_fullscreen.button_pressed    = bool(SaveManager.get_setting("fullscreen", false))
	chk_high_contrast.button_pressed = bool(SaveManager.get_setting("high_contrast", false))
	chk_reduce_motion.button_pressed = bool(SaveManager.get_setting("reduce_motion", false))

func _refresh_texts() -> void:
	lbl_title.text = tr("settings.title")
	btn_back.text = tr("settings.back")
	# Tab 标题
	tabs.set_tab_title(0, tr("settings.tab.game"))
	tabs.set_tab_title(1, tr("settings.tab.audio"))
	tabs.set_tab_title(2, tr("settings.tab.input"))
	# Game
	lbl_lang.text = tr("settings.language")
	chk_fullscreen.text    = tr("settings.fullscreen")
	chk_high_contrast.text = tr("settings.high_contrast")
	chk_reduce_motion.text = tr("settings.reduce_motion")
	# Audio
	lbl_master.text = tr("settings.volume_master")
	lbl_music.text  = tr("settings.volume_music")
	lbl_sfx.text    = tr("settings.volume_sfx")
	lbl_ui.text     = tr("settings.volume_ui")
	# Input
	lbl_input_header.text = tr("settings.input_section")
	btn_reset_bindings.text = tr("settings.reset_bindings")
	lbl_col_action.text = tr("settings.input_col.action")
	lbl_col_kb.text     = tr("settings.input_col.keyboard")
	lbl_col_pad.text    = tr("settings.input_col.gamepad")
	_refresh_rebind_labels()

func _on_lang_changed(_e) -> void:
	_refresh_texts()

# --- Tab 1 / 2 callbacks ---

func _on_lang_selected(idx: int) -> void:
	var code: String = LOCALES[idx].code
	SaveManager.set_setting("locale", code)
	SettingsApplier.apply_one("locale", code)

func _on_master_changed(v: float) -> void:
	SaveManager.set_setting("volume_master", v, false)
	SettingsApplier.apply_one("volume_master", v)

func _on_music_changed(v: float) -> void:
	SaveManager.set_setting("volume_music", v, false)
	SettingsApplier.apply_one("volume_music", v)

func _on_sfx_changed(v: float) -> void:
	SaveManager.set_setting("volume_sfx", v, false)
	SettingsApplier.apply_one("volume_sfx", v)

func _on_ui_changed(v: float) -> void:
	SaveManager.set_setting("volume_ui", v, false)
	SettingsApplier.apply_one("volume_ui", v)

func _on_fullscreen_toggled(on: bool) -> void:
	SaveManager.set_setting("fullscreen", on)
	SettingsApplier.apply_one("fullscreen", on)

func _on_hc_toggled(on: bool) -> void:
	SaveManager.set_setting("high_contrast", on)

func _on_rm_toggled(on: bool) -> void:
	SaveManager.set_setting("reduce_motion", on)

# --- Tab 3: Rebinding ---

func _build_rebind_rows() -> void:
	for c in rebind_list.get_children():
		c.queue_free()
	_rebind_rows.clear()

	# 第一段：gameplay
	_add_section_header("settings.input_group.gameplay")
	for entry in _REBIND_GAMEPLAY:
		_add_rebind_row("gameplay", entry.key, entry.i18n)
	# 分隔
	var sep := HSeparator.new()
	rebind_list.add_child(sep)
	# 第二段：editor
	_add_section_header("settings.input_group.editor")
	for entry in _REBIND_EDITOR:
		_add_rebind_row("editor", entry.key, entry.i18n)
	# 分隔
	sep = HSeparator.new()
	rebind_list.add_child(sep)
	# 第二段：UI
	_add_section_header("settings.input_group.ui")
	for entry in _REBIND_UI:
		_add_rebind_row("ui", entry.key, entry.i18n)

func _add_section_header(i18n_key: String) -> void:
	var lbl := Label.new()
	lbl.text = tr(i18n_key)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.modulate = Color(1, 1, 1, 0.85)
	lbl.set_meta("_i18n_key", i18n_key)
	rebind_list.add_child(lbl)

func _add_rebind_row(ctx: String, action_key: String, i18n_key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = tr(i18n_key)
	name_lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(name_lbl)
	var btn_kb := Button.new()
	btn_kb.focus_mode = Control.FOCUS_ALL
	btn_kb.text = _slot_label(ctx, action_key, 0)
	btn_kb.custom_minimum_size = Vector2(140, 0)
	btn_kb.pressed.connect(func(): _begin_listen(btn_kb, ctx, action_key, 0))
	row.add_child(btn_kb)
	var btn_pad := Button.new()
	btn_pad.focus_mode = Control.FOCUS_ALL
	btn_pad.text = _slot_label(ctx, action_key, 2)
	btn_pad.custom_minimum_size = Vector2(140, 0)
	btn_pad.pressed.connect(func(): _begin_listen(btn_pad, ctx, action_key, 2))
	row.add_child(btn_pad)
	rebind_list.add_child(row)
	_rebind_rows.append({
		"context": ctx,
		"action": action_key,
		"i18n": i18n_key,
		"name_lbl": name_lbl,
		"btn_kb": btn_kb,
		"btn_pad": btn_pad,
	})

func _slot_label(ctx: String, action_name: String, slot: int) -> String:
	var lbl: String = ""
	if ctx == "ui":
		lbl = InputManager.get_ui_binding_label(action_name, slot)
	elif ctx == "editor":
		lbl = InputManager.get_editor_binding_label(action_name, slot)
	else:
		lbl = InputManager.get_binding_label(action_name, slot)
	if lbl == "":
		return tr("input.rebind.unbound")
	return lbl

func _begin_listen(btn: Button, ctx: String, action_name: String, slot: int) -> void:
	if _listening_btn != null:
		return
	_listening_btn = btn
	_listening_context = ctx
	_listening_action = action_name
	_listening_slot = slot
	btn.text = tr("input.rebind.listening")
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if _listening_btn != null:
		if event is InputEventKey:
			var ke: InputEventKey = event
			if not ke.pressed or ke.echo:
				return
			if ke.keycode == KEY_ESCAPE:
				_cancel_listen()
				get_viewport().set_input_as_handled()
				return
			if ke.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
				return
			_apply_or_confirm(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton:
			var jb: InputEventJoypadButton = event
			if not jb.pressed:
				return
			_apply_or_confirm(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			# 重绑监听中点鼠标 = 取消监听，避免误绑左键
			if (event as InputEventMouseButton).pressed:
				_cancel_listen()
				get_viewport().set_input_as_handled()
			return
		return
	# 非监听态：Esc 关闭面板
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _cancel_listen() -> void:
	if _listening_btn != null:
		_listening_btn.text = _slot_label(_listening_context, _listening_action, _listening_slot)
	_listening_btn = null
	_listening_action = ""
	_listening_slot = -1
	_listening_context = ""
	_pending_event = null

func _apply_or_confirm(event: InputEvent) -> void:
	var conflict: String = ""
	if _listening_context == "ui":
		conflict = InputManager.find_ui_binding_conflict(_listening_action, event)
	elif _listening_context == "editor":
		conflict = InputManager.find_editor_binding_conflict(_listening_action, event)
	else:
		conflict = InputManager.find_binding_conflict(_listening_action, event)
	if conflict != "":
		_pending_event = event
		_show_conflict_dialog(conflict)
		return
	_apply_pending(event)

func _apply_pending(event: InputEvent) -> void:
	if _listening_context == "ui":
		InputManager.set_ui_binding(_listening_action, _listening_slot, event)
	elif _listening_context == "editor":
		InputManager.set_editor_binding(_listening_action, _listening_slot, event)
	else:
		InputManager.set_binding(_listening_action, _listening_slot, event)
	_persist_bindings()
	_refresh_rebind_labels()
	_listening_btn = null
	_listening_action = ""
	_listening_slot = -1
	_listening_context = ""
	_pending_event = null

func _show_conflict_dialog(other_action: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.exclusive = false
	dlg.dialog_text = tr("input.rebind.conflict").format([tr("input.action." + other_action)])
	dlg.title = tr("input.rebind.conflict_title")
	var ctx := _listening_context
	dlg.confirmed.connect(func():
		if ctx == "ui":
			InputManager.clear_ui_event_from_other(_listening_action, _pending_event)
		elif ctx == "editor":
			InputManager.clear_editor_event_from_other(_listening_action, _pending_event)
		else:
			InputManager.clear_event_from_other(_listening_action, _pending_event)
		_apply_pending(_pending_event)
		_pending_event = null
	)
	dlg.canceled.connect(func():
		_cancel_listen()
		_pending_event = null
	)
	add_child(dlg)
	dlg.popup_centered()
	dlg.get_ok_button().grab_focus.call_deferred()

func _on_reset_bindings() -> void:
	InputManager.reset_all_bindings()
	InputManager.reset_all_editor_bindings()
	InputManager.reset_all_ui_bindings()
	_persist_bindings()
	_refresh_rebind_labels()

func _persist_bindings() -> void:
	SaveManager.set_input_bindings(InputManager.serialize_bindings())
	SaveManager.set_editor_input_bindings(InputManager.serialize_editor_bindings())
	SaveManager.set_ui_input_bindings(InputManager.serialize_ui_bindings())

func _refresh_rebind_labels() -> void:
	for row in _rebind_rows:
		row.btn_kb.text = _slot_label(row.context, row.action, 0)
		row.btn_pad.text = _slot_label(row.context, row.action, 2)
		row.name_lbl.text = tr(row.i18n)
	# 刷新 section header
	for c in rebind_list.get_children():
		if c is Label and c.has_meta("_i18n_key"):
			c.text = tr(c.get_meta("_i18n_key"))
