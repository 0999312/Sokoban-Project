extends Node
## Boot — 启动场景。
##
## 职责：
##   1. 加载 3 种语言翻译 → I18N
##   2. 应用 SaveManager 中的设置（音量/语言/全屏）
##   3. 跳转主菜单

const LOCALES := {
	"zh_CN": "res://locale/zh_CN.json",
	"zh_TW": "res://locale/zh_TW.json",
	"en":    "res://locale/en.json",
}

func _ready() -> void:
	print("[Boot] starting (version=%s)" % ProjectSettings.get_setting("application/config/version", "?"))
	_load_translations()
	# 等一帧，确保 SaveManager 完成 load_profile()
	await get_tree().process_frame
	SettingsApplier.apply_all()
	await get_tree().process_frame
	GameState.goto_main_menu()

func _load_translations() -> void:
	for code in LOCALES.keys():
		var path: String = LOCALES[code]
		I18NManager.load_translation(code, path)
