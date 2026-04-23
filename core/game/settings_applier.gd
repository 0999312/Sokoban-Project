class_name SettingsApplier
extends RefCounted
## SettingsApplier — 把 SaveManager.profile.settings 应用到运行时。
##
## 调用：SettingsApplier.apply_all() 或 apply_one(key, value)
##
## 总线对照（参考 res://resources/audio/default_bus_layout.tres）：
##   Master / Music / SFX / UI

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

# 缺失总线只警告一次，避免日志刷屏
static var _missing_bus_warned: Dictionary = {}

static func apply_all() -> void:
	var s: Dictionary = SaveManager.profile.get("settings", {})
	apply_locale(s.get("locale", "zh_CN"))
	apply_volume(BUS_MASTER, s.get("volume_master", 1.0))
	apply_volume(BUS_MUSIC, s.get("volume_music", 0.8))
	apply_volume(BUS_SFX, s.get("volume_sfx", 1.0))
	apply_volume(BUS_UI, s.get("volume_ui", 1.0))
	apply_fullscreen(s.get("fullscreen", false))

static func apply_one(key: String, value: Variant) -> void:
	match key:
		"locale":
			apply_locale(value)
		"volume_master":
			apply_volume(BUS_MASTER, value)
		"volume_music":
			apply_volume(BUS_MUSIC, value)
		"volume_sfx":
			apply_volume(BUS_SFX, value)
		"volume_ui":
			apply_volume(BUS_UI, value)
		"fullscreen":
			apply_fullscreen(value)
		_:
			pass

static func apply_locale(locale: String) -> void:
	I18NManager.set_language(locale)

static func apply_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		if not _missing_bus_warned.has(bus_name):
			_missing_bus_warned[bus_name] = true
			push_warning("[SettingsApplier] audio bus '%s' not found; check default_bus_layout.tres" % bus_name)
		return
	var db: float = -80.0 if linear <= 0.001 else linear_to_db(clampf(linear, 0.0, 1.0))
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, linear <= 0.001)

static func apply_fullscreen(on: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
