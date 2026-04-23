extends Control
## MainMenu — 主菜单（Phase 2 + Phase 5 美化）。

@onready var lbl_title: Label = %LblTitle
@onready var btn_play: Button = %BtnPlay
@onready var btn_levels: Button = %BtnLevels
@onready var btn_editor: Button = %BtnEditor
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var lbl_status: Label = %LblStatus
@onready var settings_layer: CanvasLayer = $SettingsLayer

const SETTINGS_PANEL_SCENE := preload("res://ui/panels/settings_panel.tscn")

# Phase 5 P5-D: 浮动背景的箱子贴图
const _BG_CRATES := [
	preload("res://assets/crate/crate_1.png"),
	preload("res://assets/crate/crate_2.png"),
	preload("res://assets/crate/crate_3.png"),
	preload("res://assets/crate/crate_4.png"),
	preload("res://assets/crate/crate_5.png"),
]

func _ready() -> void:
	_decorate_title()
	_spawn_floating_crates()
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

# --- Phase 5 P5-D: 标题装饰 + 背景箱子 ---

func _decorate_title() -> void:
	if lbl_title == null: return
	# 暖色 + 黑色阴影 + 双层增强（避免引入图片资源）
	lbl_title.add_theme_color_override("font_color", Color(0.97, 0.86, 0.55))
	lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	lbl_title.add_theme_constant_override("shadow_offset_x", 3)
	lbl_title.add_theme_constant_override("shadow_offset_y", 3)
	lbl_title.add_theme_constant_override("shadow_outline_size", 6)

func _spawn_floating_crates() -> void:
	# 在背景层（z 最低）撒 6-8 个 crate 贴图，循环上下浮动
	# 节点放在 self 直接子节点，但 z_index 小于 Buttons
	var bg_layer := Node2D.new()
	bg_layer.name = "FloatingCrates"
	bg_layer.z_index = -10
	add_child(bg_layer)
	move_child(bg_layer, 1)  # 位于 Bg(0) 之后、其他控件之前

	var rng := RandomNumberGenerator.new()
	rng.seed = 0x50C0BA7  # 固定种子，每次启动布局一致
	const COUNT := 7
	for i in COUNT:
		var spr := Sprite2D.new()
		spr.texture = _BG_CRATES[i % _BG_CRATES.size()]
		spr.modulate = Color(1.0, 1.0, 1.0, 0.10)  # 极低透明
		spr.scale = Vector2(0.85, 0.85)
		var x := rng.randf_range(80.0, 1200.0)
		var y := rng.randf_range(80.0, 640.0)
		spr.position = Vector2(x, y)
		spr.rotation = rng.randf_range(-0.15, 0.15)
		bg_layer.add_child(spr)
		# 浮动动画（reduce_motion 时降幅极小）
		var amp := 8.0 if A11y.is_reduce_motion() else 18.0
		var dur := 4.5 + rng.randf_range(-0.8, 0.8)
		var tw := spr.create_tween().set_loops()
		tw.tween_property(spr, "position:y", y - amp, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(spr, "position:y", y + amp, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
