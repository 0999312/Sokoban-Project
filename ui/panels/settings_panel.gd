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

func _ready() -> void:
	_populate_locales()
	_load_from_settings()
	_refresh_texts()
	# 监听语言变化，刷新自身文案
	EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

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
