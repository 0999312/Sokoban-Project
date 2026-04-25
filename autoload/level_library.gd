extends Node
## LevelLibrary — 官方与用户关卡索引 Autoload。
##
## 职责：
##   - 启动时扫描 res://levels/official/ 与 user://levels/
##   - 维护 chapter / level 元数据索引
##   - 提供按 ID 查询、按章节列表的 API
##
## Phase 0 占位：仅扫描官方目录，构造索引数据结构。
## Phase 1 起：返回完整的 Level 资源（依赖 LevelLoader）。

const OFFICIAL_ROOT := "res://levels/official"
const USER_ROOT := "user://levels"

var _chapters: Dictionary = {}   # chapter_id -> chapter dict
var _levels: Dictionary = {}     # level_id -> { path, source: "official"|"user" }

func _ready() -> void:
	_scan_official()
	_scan_user()
	print("[LevelLibrary] %d chapters, %d levels indexed" % [_chapters.size(), _levels.size()])

## 扫描 user://levels/*.json，把每个用户关卡注册为可用关卡（来源 user）。
## 不进入 chapter 系统；由 LevelSelect 的"我的关卡"页直接读 list_user_level_ids()。
func _scan_user() -> void:
	if not DirAccess.dir_exists_absolute(UserLevelStore.USER_DIR):
		return
	for id in UserLevelStore.list_user_level_ids():
		_levels[id] = {
			"path": "%s/%s.json" % [UserLevelStore.USER_DIR, id],
			"source": "user",
		}

## 重新扫描用户关卡（编辑器保存后调用）。
func refresh_user_levels() -> void:
	# 清掉旧的 user 条目
	for k in _levels.keys():
		if _levels[k].get("source", "") == "user":
			_levels.erase(k)
	_scan_user()

func _scan_official() -> void:
	var dir := DirAccess.open(OFFICIAL_ROOT)
	if dir == null:
		push_warning("[LevelLibrary] official root not found: %s" % OFFICIAL_ROOT)
		return
	dir.list_dir_begin()
	var _name : String = dir.get_next()
	while _name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_scan_chapter("%s/%s" % [OFFICIAL_ROOT, _name])
		_name = dir.get_next()
	dir.list_dir_end()

func _scan_chapter(chapter_dir: String) -> void:
	var chapter_path := "%s/chapter.json" % chapter_dir
	if not FileAccess.file_exists(chapter_path):
		return
	var f := FileAccess.open(chapter_path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	_chapters[data.get("id", chapter_dir)] = data
	for level_id in data.get("levels", []):
		var lvl_path := "%s/%s.json" % [chapter_dir, _level_id_to_filename(level_id)]
		if FileAccess.file_exists(lvl_path):
			_levels[level_id] = { "path": lvl_path, "source": "official" }

# official-w1-01 -> 01
func _level_id_to_filename(level_id: String) -> String:
	var parts := level_id.split("-")
	if parts.size() == 0:
		return level_id
	return parts[parts.size() - 1]

func get_chapters() -> Array:
	# 按 chapter.order 排序
	var arr: Array = _chapters.values()
	arr.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return arr

func get_chapter(chapter_id: String) -> Dictionary:
	return _chapters.get(chapter_id, {})

## 返回章节里的关卡 ID 序列（已根据 chapter.json 中 levels 顺序）。
func get_chapter_level_ids(chapter_id: String) -> Array:
	var ch: Dictionary = _chapters.get(chapter_id, {})
	return ch.get("levels", [])

func get_level_path(level_id: String) -> String:
	if _levels.has(level_id):
		return _levels[level_id].path
	return ""

func has_level(level_id: String) -> bool:
	return _levels.has(level_id)

func get_level_count() -> int:
	return _levels.size()

## 给定 level_id，返回章节内下一个 level_id（无下一关返回 ""）。
func get_next_level_id(level_id: String) -> String:
	for ch in _chapters.values():
		var ids: Array = ch.get("levels", [])
		var idx := ids.find(level_id)
		if idx >= 0 and idx + 1 < ids.size():
			return ids[idx + 1]
	return ""
