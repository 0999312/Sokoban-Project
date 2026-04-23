extends Node
## Boot — 启动场景。
##
## 职责：
##   1. 加载 3 种语言翻译 → I18N
##   2. 配置 SoundManager 默认总线（SFX/UI/Music）
##   3. 应用 SaveManager 中的设置（音量/语言/全屏）
##   4. 跳转主菜单

const LOCALES := {
	"zh_CN": "res://locale/zh_CN.json",
	"zh_TW": "res://locale/zh_TW.json",
	"en":    "res://locale/en.json",
}

func _ready() -> void:
	print("[Boot] starting (version=%s)" % ProjectSettings.get_setting("application/config/version", "?"))
	_load_translations()
	_configure_sound_manager()
	# 等一帧，确保 SaveManager 完成 load_profile()
	await get_tree().process_frame
	SettingsApplier.apply_all()
	await get_tree().process_frame
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

