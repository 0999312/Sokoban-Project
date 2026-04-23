extends Control
## MainMenu — 主菜单（Phase 2）。

@onready var lbl_title: Label = %LblTitle
@onready var btn_play: Button = %BtnPlay
@onready var btn_levels: Button = %BtnLevels
@onready var btn_editor: Button = %BtnEditor
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var lbl_status: Label = %LblStatus
@onready var settings_layer: CanvasLayer = $SettingsLayer

const SETTINGS_PANEL_SCENE := preload("res://ui/panels/settings_panel.tscn")

func _ready() -> void:
	btn_play.pressed.connect(_on_play)
	btn_levels.pressed.connect(_on_levels)
	btn_editor.pressed.connect(_on_editor)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)
	_refresh_texts()
	# 监听语言切换事件
	EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_language_changed"))
	# UI 点击音效（递归挂全部 Button）
	Sfx.attach_ui(self)
	# 主菜单 BGM
	Sfx.play_bgm("menu", 1.0)

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_language_changed"))

func _on_language_changed(_event) -> void:
	_refresh_texts()

func _refresh_texts() -> void:
	lbl_title.text = tr("menu.title")
	btn_play.text = tr("menu.play")
	btn_levels.text = tr("menu.levels")
	btn_editor.text = tr("menu.editor")
	btn_settings.text = tr("menu.settings")
	btn_quit.text = tr("menu.quit")
	var ver: String = ProjectSettings.get_setting("application/config/version", "?")
	lbl_status.text = tr("menu.version_status").format([ver, LevelLibrary.get_level_count()])

func _on_play() -> void:
	GameState.goto_level_select()

func _on_levels() -> void:
	GameState.goto_level_select()

func _on_editor() -> void:
	GameState.goto_editor()

func _on_settings() -> void:
	# 已打开则忽略
	if settings_layer.get_child_count() > 0:
		return
	var panel := SETTINGS_PANEL_SCENE.instantiate()
	settings_layer.add_child(panel)
	Sfx.attach_ui(panel)

func _on_quit() -> void:
	GameState.quit_game()
