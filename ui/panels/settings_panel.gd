extends Control
## SettingsPanel — 设置面板（覆盖层，Esc/点击背景关闭）。
## 改动即时应用并保存（无 Apply 按钮）。

@onready var dim: ColorRect = %Dim
@onready var card: Panel = %Card
@onready var lbl_title: Label = %LblTitle
@onready var lbl_lang: Label = %LblLang
@onready var opt_lang: OptionButton = %OptLang
@onready var lbl_master: Label = %LblMaster
@onready var sl_master: HSlider = %SlMaster
@onready var lbl_music: Label = %LblMusic
@onready var sl_music: HSlider = %SlMusic
@onready var lbl_sfx: Label = %LblSfx
@onready var sl_sfx: HSlider = %SlSfx
@onready var chk_fullscreen: CheckBox = %ChkFullscreen
@onready var chk_high_contrast: CheckBox = %ChkHighContrast
@onready var chk_reduce_motion: CheckBox = %ChkReduceMotion
@onready var btn_back: Button = %BtnBack

const LOCALES := [
	{ "code": "zh_CN", "label": "简体中文" },
	{ "code": "zh_TW", "label": "繁體中文" },
	{ "code": "en",    "label": "English" },
]

# Phase 5 P5-F: 键位重绑动态区
const _REBIND_ACTIONS := [
	{ "key": "move_up",    "i18n": "input.action.move_up"    },
	{ "key": "move_down",  "i18n": "input.action.move_down"  },
	{ "key": "move_left",  "i18n": "input.action.move_left"  },
	{ "key": "move_right", "i18n": "input.action.move_right" },
	{ "key": "undo",       "i18n": "input.action.undo"       },
	{ "key": "redo",       "i18n": "input.action.redo"       },
	{ "key": "restart",    "i18n": "input.action.restart"    },
	{ "key": "pause",      "i18n": "input.action.pause"      },
]

var _rebind_section: VBoxContainer = null
var _rebind_rows: Array = []      # 每项 { action, lbl, btn_kb, btn_pad, slots:[0,2] }
var _listening_btn: Button = null # 当前等待新输入的按钮
var _listening_action: String = ""
var _listening_slot: int = -1
var _pending_event: InputEvent = null   # 用于 conflict 确认对话框

func _ready() -> void:
	_populate_locales()
	_load_from_settings()
	_build_rebind_section()
	_refresh_texts()
	# 监听语言变化，刷新自身文案
	EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))
	# 监听设备变化以刷新键位标签（高亮当前设备）
	if InputManager.has_signal("device_changed"):
		InputManager.device_changed.connect(_on_device_changed)

	dim.gui_input.connect(_on_dim_input)
	btn_back.pressed.connect(_close)
	opt_lang.item_selected.connect(_on_lang_selected)
	sl_master.value_changed.connect(_on_master_changed)
	sl_music.value_changed.connect(_on_music_changed)
	sl_sfx.value_changed.connect(_on_sfx_changed)
	chk_fullscreen.toggled.connect(_on_fullscreen_toggled)
	chk_high_contrast.toggled.connect(_on_hc_toggled)
	chk_reduce_motion.toggled.connect(_on_rm_toggled)

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _close() -> void:
	queue_free()

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
	sl_music.value = float(SaveManager.get_setting("volume_music", 0.8))
	sl_sfx.value = float(SaveManager.get_setting("volume_sfx", 1.0))
	chk_fullscreen.button_pressed = bool(SaveManager.get_setting("fullscreen", false))
	chk_high_contrast.button_pressed = bool(SaveManager.get_setting("high_contrast", false))
	chk_reduce_motion.button_pressed = bool(SaveManager.get_setting("reduce_motion", false))

func _refresh_texts() -> void:
	lbl_title.text = tr("settings.title")
	lbl_lang.text = tr("settings.language")
	lbl_master.text = tr("settings.volume_master")
	lbl_music.text = tr("settings.volume_music")
	lbl_sfx.text = tr("settings.volume_sfx")
	chk_fullscreen.text = tr("settings.fullscreen")
	chk_high_contrast.text = tr("settings.high_contrast")
	chk_reduce_motion.text = tr("settings.reduce_motion")
	btn_back.text = tr("settings.back")

func _on_lang_changed(_e) -> void:
	_refresh_texts()

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

func _on_fullscreen_toggled(on: bool) -> void:
	SaveManager.set_setting("fullscreen", on)
	SettingsApplier.apply_one("fullscreen", on)

func _on_hc_toggled(on: bool) -> void:
	SaveManager.set_setting("high_contrast", on)

func _on_rm_toggled(on: bool) -> void:
	SaveManager.set_setting("reduce_motion", on)

# --- Phase 5 P5-F: 键位重绑 ---

func _build_rebind_section() -> void:
	# 撑大 Card 高度以容纳新增内容
	if card != null:
		card.offset_top = -360.0
		card.offset_bottom = 360.0
	# 在 btn_back 之前插入分隔 + 标题 + 重置按钮 + 列表
	var vbox: VBoxContainer = btn_back.get_parent() as VBoxContainer
	if vbox == null: return
	var insert_at := btn_back.get_index()

	# UI 音量 slider（P5-A 引入了 UI 总线）
	var row_ui := HBoxContainer.new()
	row_ui.add_theme_constant_override("separation", 12)
	var lbl_ui := Label.new()
	lbl_ui.name = "LblUiVol"
	lbl_ui.text = tr("settings.volume_ui")
	lbl_ui.custom_minimum_size = Vector2(140, 0)
	row_ui.add_child(lbl_ui)
	var sl_ui := HSlider.new()
	sl_ui.name = "SlUiVol"
	sl_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl_ui.min_value = 0.0
	sl_ui.max_value = 1.0
	sl_ui.step = 0.01
	sl_ui.value = float(SaveManager.get_setting("volume_ui", 1.0))
	sl_ui.value_changed.connect(func(v):
		SaveManager.set_setting("volume_ui", v, false)
		SettingsApplier.apply_one("volume_ui", v)
	)
	row_ui.add_child(sl_ui)
	vbox.add_child(row_ui)
	vbox.move_child(row_ui, insert_at); insert_at += 1

	var sep := HSeparator.new()
	vbox.add_child(sep)
	vbox.move_child(sep, insert_at); insert_at += 1

	var hdr := HBoxContainer.new()
	var lbl := Label.new()
	lbl.name = "LblInputTitle"
	lbl.text = tr("settings.input_section")
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(lbl)
	var btn_reset := Button.new()
	btn_reset.name = "BtnResetBindings"
	btn_reset.text = tr("settings.reset_bindings")
	btn_reset.pressed.connect(_on_reset_bindings)
	hdr.add_child(btn_reset)
	vbox.add_child(hdr)
	vbox.move_child(hdr, insert_at); insert_at += 1

	# Grid: action / keyboard / gamepad
	_rebind_section = VBoxContainer.new()
	_rebind_section.add_theme_constant_override("separation", 4)
	for entry in _REBIND_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		name_lbl.text = tr(entry.i18n)
		name_lbl.custom_minimum_size = Vector2(140, 0)
		row.add_child(name_lbl)
		var btn_kb := Button.new()
		btn_kb.text = _slot_label(entry.key, 0)
		btn_kb.custom_minimum_size = Vector2(110, 0)
		btn_kb.pressed.connect(func(): _begin_listen(btn_kb, entry.key, 0))
		row.add_child(btn_kb)
		var btn_pad := Button.new()
		btn_pad.text = _slot_label(entry.key, 2)
		btn_pad.custom_minimum_size = Vector2(110, 0)
		btn_pad.pressed.connect(func(): _begin_listen(btn_pad, entry.key, 2))
		row.add_child(btn_pad)
		_rebind_section.add_child(row)
		_rebind_rows.append({
			"action": entry.key,
			"i18n": entry.i18n,
			"name_lbl": name_lbl,
			"btn_kb": btn_kb,
			"btn_pad": btn_pad,
		})
	vbox.add_child(_rebind_section)
	vbox.move_child(_rebind_section, insert_at)
	# 新建按钮也挂上 ui_click 音效
	Sfx.attach_ui(self)

func _slot_label(action_name: String, slot: int) -> String:
	var lbl: String = InputManager.get_binding_label(action_name, slot)
	if lbl == "": return tr("input.rebind.unbound")
	return lbl

func _begin_listen(btn: Button, action_name: String, slot: int) -> void:
	if _listening_btn != null: return
	_listening_btn = btn
	_listening_action = action_name
	_listening_slot = slot
	btn.text = tr("input.rebind.listening")
	# 短暂吃掉所有 Esc 防止意外关闭面板
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if _listening_btn != null:
		# 重绑监听优先于 close
		if event is InputEventKey:
			var ke: InputEventKey = event
			if not ke.pressed or ke.echo: return
			if ke.keycode == KEY_ESCAPE:
				# 取消重绑
				_cancel_listen()
				get_viewport().set_input_as_handled()
				return
			# 拒绝纯修饰键
			if ke.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
				return
			_apply_or_confirm(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton:
			var jb: InputEventJoypadButton = event
			if not jb.pressed: return
			_apply_or_confirm(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			# 鼠标按钮只用于取消监听（避免误绑）
			if (event as InputEventMouseButton).pressed:
				_cancel_listen()
				get_viewport().set_input_as_handled()
			return
	# 非监听态：保留原 Esc 关闭
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _cancel_listen() -> void:
	if _listening_btn != null:
		_listening_btn.text = _slot_label(_listening_action, _listening_slot)
	_listening_btn = null
	_listening_action = ""
	_listening_slot = -1

func _apply_or_confirm(event: InputEvent) -> void:
	var conflict: String = InputManager.find_binding_conflict(_listening_action, event)
	if conflict != "":
		_pending_event = event
		_show_conflict_dialog(conflict)
		return
	_apply_pending(event)

func _apply_pending(event: InputEvent) -> void:
	InputManager.set_binding(_listening_action, _listening_slot, event)
	_persist_bindings()
	_refresh_rebind_labels()
	_listening_btn = null
	_listening_action = ""
	_listening_slot = -1

func _show_conflict_dialog(other_action: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = tr("input.rebind.conflict").format([tr("input.action." + other_action)])
	dlg.title = tr("input.rebind.conflict_title")
	dlg.confirmed.connect(func():
		# 强制覆盖：先清掉 conflict 的占用槽，再写入
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

func _on_reset_bindings() -> void:
	InputManager.reset_all_bindings()
	_persist_bindings()
	_refresh_rebind_labels()

func _persist_bindings() -> void:
	SaveManager.set_input_bindings(InputManager.serialize_bindings())

func _refresh_rebind_labels() -> void:
	for row in _rebind_rows:
		row.btn_kb.text = _slot_label(row.action, 0)
		row.btn_pad.text = _slot_label(row.action, 2)
		row.name_lbl.text = tr(row.i18n)

func _on_device_changed(_dev: int) -> void:
	# 设备变化主要影响外部 InputHint；面板内文案保持不变
	pass
