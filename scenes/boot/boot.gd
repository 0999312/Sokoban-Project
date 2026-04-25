extends Node
## Boot — 启动场景。
##
## 职责：
##   1. 加载 3 种语言翻译 → I18N
##   2. 配置 SoundManager 默认总线（SFX/UI/Music）
##   3. 显示 Splash 画面 1s（Logo + 项目名）
##   4. 应用 SaveManager 中的设置（音量/语言/全屏）
##   5. 跳转主菜单

const LOCALES := {
	"zh_CN": "res://locale/zh_CN.json",
	"zh_TW": "res://locale/zh_TW.json",
	"en":    "res://locale/en.json",
}

const SPLASH_DURATION := 1.0
const FADE_IN := 0.35
const FADE_OUT := 0.35

func _ready() -> void:
	print("[Boot] starting (version=%s)" % ProjectSettings.get_setting("application/config/version", "?"))
	_load_translations()
	_configure_sound_manager()
	# 等一帧，确保 SaveManager 完成 load_profile()
	await get_tree().process_frame
	SettingsApplier.apply_all()
	# 应用持久化的输入绑定（gameplay + editor + UI）
	InputManager.deserialize_bindings(SaveManager.get_input_bindings())
	InputManager.deserialize_editor_bindings(SaveManager.get_editor_input_bindings())
	InputManager.deserialize_ui_bindings(SaveManager.get_ui_input_bindings())
	# 替换默认 Label 为 Splash 画面
	var splash_root := _build_splash()
	await _animate_splash(splash_root)
	GameState.goto_main_menu()

func _load_translations() -> void:
	for code in LOCALES.keys():
		var path: String = LOCALES[code]
		I18NManager.load_translation(code, path)

func _configure_sound_manager() -> void:
	# SoundManager autoload 来自 addons/sound_manager 插件，名称为 "SoundManager"
	# 把默认 bus 显式锁定到项目自定义 bus_layout 中存在的总线名
	var root := (Engine.get_main_loop() as SceneTree).root
	var sm: Node = root.get_node_or_null("SoundManager")
	if sm == null:
		push_warning("[Boot] SoundManager autoload not found; sound_manager plugin disabled?")
		return
	if sm.has_method("set_default_sound_bus"):
		sm.set_default_sound_bus("SFX")
	if sm.has_method("set_default_ui_sound_bus"):
		sm.set_default_ui_sound_bus("UI")
	if sm.has_method("set_default_music_bus"):
		sm.set_default_music_bus("Music")
	print("[Boot] SoundManager configured (SFX/UI/Music)")

# --- Splash ---

func _build_splash() -> Control:
	# 移除场景中的占位 Label
	var old: Node = get_node_or_null("Label")
	if old != null:
		old.queue_free()

	var root := Control.new()
	root.name = "SplashRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate = Color(1, 1, 1, 0)  # 起始透明
	# 深色背景，避免引擎默认灰色透出
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# Logo 容器（垂直居中）
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	# Icon
	var icon_tex: Texture2D = load("res://icon_new.png") as Texture2D
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(128, 128)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
	# Title — 与 i18n 解耦，启动 splash 阶段还未应用语言，固定显示中英联名
	var title := Label.new()
	title.text = "Sokoban Project · 搬箱计划"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(title)
	# Subtitle
	var sub := Label.new()
	sub.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	v.add_child(sub)

	# 让 VBox 自适应到中心：Center preset 不会自动居中尺寸，需要手动量
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(v)
	root.add_child(holder)

	add_child(root)
	return root

func _animate_splash(root: Control) -> void:
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, FADE_IN)
	tw.tween_interval(SPLASH_DURATION - FADE_IN - FADE_OUT)
	tw.tween_property(root, "modulate:a", 0.0, FADE_OUT)
	await tw.finished
