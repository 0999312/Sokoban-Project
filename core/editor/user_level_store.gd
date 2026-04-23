class_name UserLevelStore
extends RefCounted
## UserLevelStore — 用户关卡的本地存储。
##
## 路径：user://levels/<id>.json （与 GDD §11 user_levels_index 配合）
##
## 提供：
##   list_user_level_ids() -> Array[String]
##   load_level(id) -> Level
##   save_level(level) -> bool   ## 写入并把 id 加入 SaveManager.profile["user_levels_index"]
##   delete_level(id) -> bool
##   make_new_id(prefix="user") -> String

const USER_DIR := "user://levels"

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(USER_DIR):
		DirAccess.make_dir_recursive_absolute(USER_DIR)

static func _path_for(id: String) -> String:
	return "%s/%s.json" % [USER_DIR, id]

static func make_new_id(prefix: String = "user") -> String:
	# 时间戳 + 4 位随机
	var ts := Time.get_ticks_msec()
	var rnd := randi() % 0x10000
	return "%s-%d-%04x" % [prefix, ts, rnd]

static func list_user_level_ids() -> Array:
	_ensure_dir()
	var out: Array = []
	var d := DirAccess.open(USER_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.ends_with(".json"):
			out.append(n.get_basename())
		n = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

static func load_level(id: String) -> Level:
	var p := _path_for(id)
	if not FileAccess.file_exists(p):
		return null
	return LevelLoader.load_json_file(p)

## 写入 user 关卡。强制 id 非空；若 level.id 为空，自动分配一个。
## 同时把 id 追加到 SaveManager.profile["user_levels_index"] 并保存。
static func save_level(level: Level) -> bool:
	if level == null:
		return false
	_ensure_dir()
	if level.id.strip_edges() == "":
		level.id = make_new_id()
	var p := _path_for(level.id)
	var json := LevelLoader.to_json(level, true)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_error("[UserLevelStore] cannot open: %s" % p)
		return false
	f.store_string(json)
	f.close()
	# 更新 profile 索引
	var sm := Engine.get_singleton("SaveManager") if Engine.has_singleton("SaveManager") else null
	# 在 Godot 中 autoload 不通过 Engine.get_singleton 暴露——回退到通过 SceneTree
	# 这里直接用全局名（自动加载脚本会在所有脚本上下文可见）。
	if Engine.has_singleton("SaveManager"):
		pass
	# 通过显式名访问
	var save_mgr = Engine.get_main_loop().root.get_node_or_null("SaveManager")
	if save_mgr != null:
		var idx: Array = save_mgr.profile.get("user_levels_index", [])
		if not idx.has(level.id):
			idx.append(level.id)
			save_mgr.profile["user_levels_index"] = idx
			save_mgr.save_profile()
	return true

static func delete_level(id: String) -> bool:
	var p := _path_for(id)
	if not FileAccess.file_exists(p):
		return false
	var d := DirAccess.open(USER_DIR)
	if d == null:
		return false
	d.remove(p.get_file())
	var save_mgr = Engine.get_main_loop().root.get_node_or_null("SaveManager")
	if save_mgr != null:
		var idx: Array = save_mgr.profile.get("user_levels_index", [])
		idx.erase(id)
		save_mgr.profile["user_levels_index"] = idx
		save_mgr.save_profile()
	return true
