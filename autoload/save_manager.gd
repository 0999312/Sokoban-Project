extends Node
## SaveManager — 本地存档管理 Autoload。
##
## 路径：user://save/profile.json （Steam Cloud 兼容）
## 写入策略：原子写入（.tmp → rename）
## 版本迁移：按 version 字段累进升级

const SAVE_DIR := "user://save"
const SAVE_PATH := "user://save/profile.json"
const SAVE_TMP := "user://save/profile.json.tmp"
const CURRENT_VERSION := 1

const DEFAULT_LOCALE := "zh_CN"

signal save_loaded(profile: Dictionary)
signal save_written()
signal settings_changed(key: String, value: Variant)

var profile: Dictionary = _default_profile()

func _ready() -> void:
	_ensure_dir()
	load_profile()

func _default_profile() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"settings": _default_settings(),
		"progress": {},
		"stats": { "total_steps": 0, "total_time_ms": 0, "completed_levels": 0 },
		"user_levels_index": [],
	}

func _default_settings() -> Dictionary:
	return {
		"locale": DEFAULT_LOCALE,
		"volume_master": 1.0,
		"volume_music": 0.8,
		"volume_sfx": 1.0,
		"fullscreen": false,
		"high_contrast": false,
		"reduce_motion": false,
	}

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] no save found, using defaults")
		save_loaded.emit(profile)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] failed to open save file")
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[SaveManager] save file corrupted, using defaults")
		return
	profile = _migrate(data)
	# 合并默认 settings（兼容老存档新增字段）
	var defaults := _default_settings()
	var s: Dictionary = profile.get("settings", {})
	for k in defaults.keys():
		if not s.has(k):
			s[k] = defaults[k]
	profile["settings"] = s
	print("[SaveManager] loaded version=%s" % profile.get("version"))
	save_loaded.emit(profile)

func save_profile() -> void:
	_ensure_dir()
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] failed to open tmp save")
		return
	f.store_string(JSON.stringify(profile, "\t"))
	f.close()
	# atomic rename
	var d := DirAccess.open(SAVE_DIR)
	if d != null:
		if FileAccess.file_exists(SAVE_PATH):
			d.remove(SAVE_PATH.get_file())
		d.rename(SAVE_TMP.get_file(), SAVE_PATH.get_file())
	save_written.emit()

func _migrate(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("version", 0))
	# 未来：if v < 2: data = _migrate_v1_to_v2(data)
	if v != CURRENT_VERSION:
		data["version"] = CURRENT_VERSION
	return data

# --- Progress API ---

func record_level_complete(level_id: String, stars: int, steps: int, time_ms: int) -> void:
	var p: Dictionary = profile.get("progress", {})
	var prev: Dictionary = p.get(level_id, {})
	var best_steps: int = prev.get("best_steps", 999999)
	var best_time: int = prev.get("best_time_ms", 999999999)
	var was_completed: bool = prev.has("stars")
	p[level_id] = {
		"stars": maxi(stars, prev.get("stars", 0)),
		"best_steps": mini(steps, best_steps),
		"best_time_ms": mini(time_ms, best_time),
		"completed_at": Time.get_datetime_string_from_system(),
	}
	profile["progress"] = p
	# 全局统计
	var stats: Dictionary = profile.get("stats", {})
	stats["total_steps"] = int(stats.get("total_steps", 0)) + steps
	stats["total_time_ms"] = int(stats.get("total_time_ms", 0)) + time_ms
	if not was_completed:
		stats["completed_levels"] = int(stats.get("completed_levels", 0)) + 1
	profile["stats"] = stats
	save_profile()

func get_progress(level_id: String) -> Dictionary:
	var p: Dictionary = profile.get("progress", {})
	return p.get(level_id, {})

func is_completed(level_id: String) -> bool:
	return get_progress(level_id).has("stars")

func get_stars(level_id: String) -> int:
	return int(get_progress(level_id).get("stars", 0))

# --- Settings API ---

func get_setting(key: String, default_val: Variant = null) -> Variant:
	var s: Dictionary = profile.get("settings", {})
	if s.has(key):
		return s[key]
	return default_val

func set_setting(key: String, value: Variant, autosave: bool = true) -> void:
	var s: Dictionary = profile.get("settings", {})
	s[key] = value
	profile["settings"] = s
	settings_changed.emit(key, value)
	if autosave:
		save_profile()
