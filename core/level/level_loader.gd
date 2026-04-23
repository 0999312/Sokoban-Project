class_name LevelLoader
extends RefCounted
## LevelLoader — 关卡数据 IO。
##
## 支持：
##   - JSON 文件 / 字符串 ↔ Level
##   - XSB 文本 ↔ Level
##
## XSB 字符表（v2 扩展多色）：
##   #=墙  空格=地板  -=外部空区  @=玩家  +=玩家在目标
##   .=目标(色1)   1=目标(色1) 2=目标(色2) 3=目标(色3) 4=目标(色4)   ,=目标(中性,色0)
##   $=箱(色1)     a=箱(色1)   b=箱(色2)   c=箱(色3)   d=箱(色4)
##   *=箱(色1)在目标(色1)   A=箱(色1)在目标(色1) B=箱(色2)在目标(色2) C=箱(色3)在目标(色3) D=箱(色4)在目标(色4)
##
## 颜色 5 与"箱子色 X 在目标色 Y（异色错位）"等复合状态由 JSON `color_overrides` 表达，
## XSB 仅提供常用快捷写法。
##
## v1 → v2 自动迁移：缺失 box_colors / goal_colors / color_overrides 时全部填 1（经典单色）。

const CHAR_WALL := "#"
const CHAR_FLOOR := " "
const CHAR_GOAL := "."
const CHAR_BOX := "$"
const CHAR_BOX_ON_GOAL := "*"
const CHAR_PLAYER := "@"
const CHAR_PLAYER_ON_GOAL := "+"
const CHAR_OUTSIDE := "-"
const CHAR_NEUTRAL_GOAL := ","

## XSB 颜色字符 → 颜色 id
const XSB_GOAL_COLOR_CHARS: Dictionary = {
	".": 1, "1": 1, "2": 2, "3": 3, "4": 4, ",": 0,
}
const XSB_BOX_COLOR_CHARS: Dictionary = {
	"$": 1, "a": 1, "b": 2, "c": 3, "d": 4,
}
## XSB "箱子在目标"字符 → (box_color, goal_color)
const XSB_BOX_ON_GOAL_CHARS: Dictionary = {
	"*": [1, 1], "A": [1, 1], "B": [2, 2], "C": [3, 3], "D": [4, 4],
}

# ========== JSON ↔ Level ==========

static func load_json_file(path: String) -> Level:
	if not FileAccess.file_exists(path):
		push_error("[LevelLoader] file not found: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[LevelLoader] cannot open: %s" % path)
		return null
	return parse_json(f.get_as_text())

static func parse_json(text: String) -> Level:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[LevelLoader] JSON parse failed")
		return null
	return _from_dict(data)

static func to_json(level: Level, pretty: bool = true) -> String:
	var d := _to_dict(level)
	return JSON.stringify(d, "\t" if pretty else "")

static func _from_dict(d: Dictionary) -> Level:
	var lvl := Level.new()
	lvl.id = d.get("id", "")
	# name：单字符串。兼容老格式 { "zh_CN": "...", "en": "..." } —— 退化为取 en/任一值。
	var raw_name: Variant = d.get("name", "")
	if typeof(raw_name) == TYPE_STRING:
		lvl.name = raw_name
	elif typeof(raw_name) == TYPE_DICTIONARY:
		var dict_name: Dictionary = raw_name
		if dict_name.has("en"):
			lvl.name = String(dict_name["en"])
		elif not dict_name.is_empty():
			lvl.name = String(dict_name.values()[0])
		else:
			lvl.name = lvl.id
	else:
		lvl.name = lvl.id
	lvl.author = d.get("author", "")
	lvl.width = int(d.get("width", 0))
	lvl.height = int(d.get("height", 0))
	lvl.format_version = int(d.get("format_version", 1))
	lvl.metadata = d.get("metadata", {})
	# 主题：从 metadata.theme 读取，缺失/非法值 → 默认 brick / grass
	var theme: Dictionary = lvl.metadata.get("theme", {}) if typeof(lvl.metadata.get("theme", {})) == TYPE_DICTIONARY else {}
	var w: String = String(theme.get("wall", "brick"))
	var f: String = String(theme.get("floor", "grass"))
	lvl.wall_theme = w if w in Level.ALLOWED_WALL_THEMES else "brick"
	lvl.floor_theme = f if f in Level.ALLOWED_FLOOR_THEMES else "grass"
	var tile_rows: Array = d.get("tiles", [])
	# 把字符行解码为类型矩阵 + 实体位置（含 XSB 颜色字符）
	var decoded := _decode_tile_rows(tile_rows, lvl.width, lvl.height)
	lvl.tiles = decoded.tiles
	lvl.player_start = decoded.player
	lvl.box_starts = decoded.boxes
	lvl.box_colors = decoded.box_colors
	lvl.goal_positions = decoded.goals
	lvl.goal_colors = decoded.goal_colors

	# 应用 color_overrides（位置 -> 颜色 id），覆盖 XSB 默认。
	# 格式：{ "crates": { "x,y": color_id }, "holders": { "x,y": color_id } }
	var overrides: Dictionary = d.get("color_overrides", {}) if typeof(d.get("color_overrides", {})) == TYPE_DICTIONARY else {}
	_apply_color_overrides(lvl, overrides)

	# 兼容 v1：若 box_colors / goal_colors 为空（极少见，因 _decode_tile_rows 总会填），保险补默认色。
	while lvl.box_colors.size() < lvl.box_starts.size():
		lvl.box_colors.append(Cell.DEFAULT_COLOR)
	while lvl.goal_colors.size() < lvl.goal_positions.size():
		lvl.goal_colors.append(Cell.DEFAULT_COLOR)

	return lvl

static func _apply_color_overrides(lvl: Level, overrides: Dictionary) -> void:
	if overrides.is_empty():
		return
	var crates: Dictionary = overrides.get("crates", {}) if typeof(overrides.get("crates", {})) == TYPE_DICTIONARY else {}
	var holders: Dictionary = overrides.get("holders", {}) if typeof(overrides.get("holders", {})) == TYPE_DICTIONARY else {}
	# 建索引：position -> i
	var box_index: Dictionary = {}
	for i in lvl.box_starts.size():
		box_index[lvl.box_starts[i]] = i
	var goal_index: Dictionary = {}
	for i in lvl.goal_positions.size():
		goal_index[lvl.goal_positions[i]] = i
	for k in crates.keys():
		var pos := _parse_pos_key(String(k))
		if pos == Vector2i(-1, -1): continue
		if box_index.has(pos):
			var c: int = Cell.sanitize_box_color(int(crates[k]))
			lvl.box_colors[box_index[pos]] = c
	for k in holders.keys():
		var pos := _parse_pos_key(String(k))
		if pos == Vector2i(-1, -1): continue
		if goal_index.has(pos):
			var c: int = Cell.sanitize_holder_color(int(holders[k]))
			lvl.goal_colors[goal_index[pos]] = c

static func _parse_pos_key(s: String) -> Vector2i:
	var parts: PackedStringArray = s.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

static func _to_dict(level: Level) -> Dictionary:
	var out: Dictionary = {
		"format_version": level.format_version,
		"id": level.id,
		"name": level.name,
		"author": level.author,
		"width": level.width,
		"height": level.height,
		"tiles": _encode_tile_rows(level),
		"metadata": level.metadata,
	}
	# 仅在出现非默认色时才写出 color_overrides，保持单色关卡紧凑。
	var overrides := _compute_color_overrides(level)
	if not (overrides.crates as Dictionary).is_empty() or not (overrides.holders as Dictionary).is_empty():
		out["color_overrides"] = overrides
	return out

static func _compute_color_overrides(level: Level) -> Dictionary:
	var crates: Dictionary = {}
	var holders: Dictionary = {}
	for i in level.box_starts.size():
		var c: int = int(level.box_colors[i]) if i < level.box_colors.size() else Cell.DEFAULT_COLOR
		# 非默认色 或 颜色 5（XSB 无快捷）需要写 override
		if c != Cell.DEFAULT_COLOR:
			var p: Vector2i = level.box_starts[i]
			crates["%d,%d" % [p.x, p.y]] = c
	for i in level.goal_positions.size():
		var c: int = int(level.goal_colors[i]) if i < level.goal_colors.size() else Cell.DEFAULT_COLOR
		if c != Cell.DEFAULT_COLOR:
			var p: Vector2i = level.goal_positions[i]
			holders["%d,%d" % [p.x, p.y]] = c
	return { "crates": crates, "holders": holders }

# ========== XSB ↔ Level ==========

static func parse_xsb(text: String, id: String = "user-level") -> Level:
	var lines: Array[String] = []
	for raw in text.split("\n"):
		var line := raw.rstrip("\r")
		# 跳过注释/元数据行
		if line.begins_with(";") or line.begins_with("'"):
			continue
		# 跳过纯空白前导（直到遇到关卡内容）
		if lines.is_empty() and line.strip_edges() == "":
			continue
		lines.append(line)
	# 去掉末尾空行
	while not lines.is_empty() and lines[lines.size() - 1].strip_edges() == "":
		lines.pop_back()
	if lines.is_empty():
		push_error("[LevelLoader] XSB empty")
		return null

	var width := 0
	for l in lines:
		width = maxi(width, l.length())
	var height := lines.size()

	var lvl := Level.new()
	lvl.id = id
	lvl.width = width
	lvl.height = height
	lvl.format_version = 2
	# 用字符行喂入解码器
	var rows: Array = []
	for l in lines:
		rows.append(l.rpad(width))
	var decoded := _decode_tile_rows(rows, width, height)
	lvl.tiles = decoded.tiles
	lvl.player_start = decoded.player
	lvl.box_starts = decoded.boxes
	lvl.box_colors = decoded.box_colors
	lvl.goal_positions = decoded.goals
	lvl.goal_colors = decoded.goal_colors
	return lvl

static func to_xsb(level: Level) -> String:
	var rows := _encode_tile_rows(level)
	return "\n".join(rows)

# ========== 内部：字符 ↔ 矩阵 ==========

static func _decode_tile_rows(rows: Array, width: int, height: int) -> Dictionary:
	var tiles: Array = []
	tiles.resize(height)
	var player := Vector2i(-1, -1)
	var boxes: Array = []
	var box_colors: Array = []
	var goals: Array = []
	var goal_colors: Array = []
	for y in height:
		var line: String = rows[y] if y < rows.size() else ""
		var row: Array = []
		row.resize(width)
		for x in width:
			var ch := " " if x >= line.length() else line.substr(x, 1)
			var p := Vector2i(x, y)
			# 优先识别"箱在目标"复合字符
			if XSB_BOX_ON_GOAL_CHARS.has(ch):
				var pair: Array = XSB_BOX_ON_GOAL_CHARS[ch]
				row[x] = Cell.Type.GOAL
				boxes.append(p); box_colors.append(int(pair[0]))
				goals.append(p); goal_colors.append(int(pair[1]))
				continue
			# goal 字符（含中性槽）
			if XSB_GOAL_COLOR_CHARS.has(ch):
				row[x] = Cell.Type.GOAL
				goals.append(p); goal_colors.append(int(XSB_GOAL_COLOR_CHARS[ch]))
				continue
			# box 字符
			if XSB_BOX_COLOR_CHARS.has(ch):
				row[x] = Cell.Type.FLOOR
				boxes.append(p); box_colors.append(int(XSB_BOX_COLOR_CHARS[ch]))
				continue
			match ch:
				CHAR_WALL:
					row[x] = Cell.Type.WALL
				CHAR_OUTSIDE:
					row[x] = Cell.Type.OUTSIDE
				CHAR_FLOOR:
					row[x] = Cell.Type.FLOOR
				CHAR_PLAYER:
					row[x] = Cell.Type.FLOOR
					player = p
				CHAR_PLAYER_ON_GOAL:
					row[x] = Cell.Type.GOAL
					goals.append(p); goal_colors.append(Cell.DEFAULT_COLOR)
					player = p
				_:
					# 未知字符当成外部空区
					row[x] = Cell.Type.OUTSIDE
		tiles[y] = row
	return {
		"tiles": tiles,
		"player": player,
		"boxes": boxes,
		"box_colors": box_colors,
		"goals": goals,
		"goal_colors": goal_colors,
	}

static func _encode_tile_rows(level: Level) -> Array:
	# 索引：位置 -> 颜色
	var box_color_at: Dictionary = {}
	for i in level.box_starts.size():
		var c: int = int(level.box_colors[i]) if i < level.box_colors.size() else Cell.DEFAULT_COLOR
		box_color_at[level.box_starts[i]] = c
	var goal_color_at: Dictionary = {}
	for i in level.goal_positions.size():
		var c: int = int(level.goal_colors[i]) if i < level.goal_colors.size() else Cell.DEFAULT_COLOR
		goal_color_at[level.goal_positions[i]] = c

	# 反查表
	var box_char_by_color: Dictionary = { 1: "$", 2: "b", 3: "c", 4: "d" }       # 5 -> JSON override
	var goal_char_by_color: Dictionary = { 0: ",", 1: ".", 2: "2", 3: "3", 4: "4" }  # 5 -> JSON override
	var box_on_goal_char_by_color: Dictionary = { 1: "*", 2: "B", 3: "C", 4: "D" }   # 同色才有复合字符

	var rows: Array = []
	rows.resize(level.height)
	for y in level.height:
		var s := ""
		for x in level.width:
			var p := Vector2i(x, y)
			var t: int = level.get_tile(x, y)
			var is_player: bool = (p == level.player_start)
			var is_box: bool = box_color_at.has(p)
			var on_goal: bool = (t == Cell.Type.GOAL)
			if is_player and on_goal:
				s += CHAR_PLAYER_ON_GOAL
			elif is_player:
				s += CHAR_PLAYER
			elif is_box and on_goal:
				var bc: int = int(box_color_at[p])
				var gc: int = int(goal_color_at[p])
				if bc == gc and box_on_goal_char_by_color.has(bc):
					s += box_on_goal_char_by_color[bc]
				else:
					# 异色 / 颜色 5：用 box 字符（goal 信息走 color_overrides）
					s += box_char_by_color.get(bc, "$")
			elif is_box:
				var bc2: int = int(box_color_at[p])
				s += box_char_by_color.get(bc2, "$")
			elif on_goal:
				var gc2: int = int(goal_color_at[p])
				s += goal_char_by_color.get(gc2, ".")
			else:
				match t:
					Cell.Type.WALL: s += CHAR_WALL
					Cell.Type.OUTSIDE: s += CHAR_OUTSIDE
					_: s += CHAR_FLOOR
		rows[y] = s
	return rows
