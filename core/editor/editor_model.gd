class_name EditorModel
extends RefCounted
## EditorModel — 关卡编辑器数据模型。
##
## 与 Level 类似但以"可写、可逐格更新"为目标，且把"实体层"（玩家/箱子/holder 颜色）
## 拆成独立字典，避免反复构造 Level 资源。
##
## 数据：
##   width / height
##   tiles[y][x] -> Cell.Type  （地形：OUTSIDE/FLOOR/WALL/GOAL）
##   player_pos: Vector2i (-1,-1 表示未放置)
##   boxes: Dictionary[Vector2i -> int(box color 1..5)]
##   holder_colors: Dictionary[Vector2i -> int(0..5)]   ## 仅当 tiles[p]==GOAL 时有效
##   meta:
##     id, name, author, wall_theme, floor_theme, difficulty, tags(Array[String])
##
## 操作：
##   set_cell(p, payload)     ## 单格写入；payload = {tile?, box?, box_color?, player?, holder_color?}
##   apply_command(cmd)       ## 由 EditCommand 携带 before/after，便于 Undo 复用
##   resize(new_w, new_h)
##   to_level() -> Level
##   load_from_level(lvl)
##
## 不发信号；调用方（EditorBoard）在每次写入后主动重绘对应格。

const Cell = preload("res://core/board/cell.gd")

const MIN_SIZE := 4
const MAX_SIZE := 32

var width: int = 8
var height: int = 6
var tiles: Array = []                  # Array[Array[int]]
var player_pos: Vector2i = Vector2i(-1, -1)
var boxes: Dictionary = {}             # Vector2i -> int(color 1..5)
var holder_colors: Dictionary = {}     # Vector2i -> int(0..5)

var meta: Dictionary = {
	"id": "",
	"name": "",
	"author": "",
	"wall_theme": "brick",
	"floor_theme": "grass",
	"difficulty": 1,
	"tags": [],
}

func _init(p_width: int = 8, p_height: int = 6) -> void:
	resize(p_width, p_height, true)

func clear_all() -> void:
	resize(width, height, true)
	player_pos = Vector2i(-1, -1)
	boxes.clear()
	holder_colors.clear()

## 重置到指定尺寸。new_grid=true 时所有格子初始化为 OUTSIDE（空白画布）。
## new_grid=false 时尽量保留旧内容（裁剪/填充）。
func resize(new_w: int, new_h: int, new_grid: bool = false) -> void:
	new_w = clampi(new_w, MIN_SIZE, MAX_SIZE)
	new_h = clampi(new_h, MIN_SIZE, MAX_SIZE)
	var old_tiles := tiles
	var old_w := width
	var old_h := height
	width = new_w
	height = new_h
	tiles = []
	tiles.resize(height)
	for y in height:
		var row: Array = []
		row.resize(width)
		for x in width:
			if not new_grid and y < old_h and x < old_w:
				row[x] = int(old_tiles[y][x])
			else:
				row[x] = Cell.Type.OUTSIDE
		tiles[y] = row
	# 裁剪超界实体
	if not new_grid:
		if not _in_bounds(player_pos):
			player_pos = Vector2i(-1, -1)
		var new_boxes: Dictionary = {}
		for p in boxes.keys():
			if _in_bounds(p):
				new_boxes[p] = boxes[p]
		boxes = new_boxes
		var new_holders: Dictionary = {}
		for p in holder_colors.keys():
			if _in_bounds(p):
				new_holders[p] = holder_colors[p]
		holder_colors = new_holders

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < width and p.y >= 0 and p.y < height

func get_tile(p: Vector2i) -> int:
	if not _in_bounds(p):
		return Cell.Type.OUTSIDE
	return int(tiles[p.y][p.x])

func has_box(p: Vector2i) -> bool:
	return boxes.has(p)

func box_color_at(p: Vector2i) -> int:
	return int(boxes.get(p, Cell.DEFAULT_COLOR))

func holder_color_at(p: Vector2i) -> int:
	return int(holder_colors.get(p, Cell.DEFAULT_COLOR))

## 捕获某格当前完整状态，供 EditCommand 当作 before/after 包。
## 返回 dict：{tile, box, box_color, holder_color, player}
func snapshot_cell(p: Vector2i) -> Dictionary:
	return {
		"tile": get_tile(p),
		"box": has_box(p),
		"box_color": box_color_at(p),
		"holder_color": holder_color_at(p),
		"player": player_pos == p,
	}

## 写入单格。payload 任一字段缺省即不修改。
##   tile: int (Cell.Type)
##   box: bool (false 移除箱子；true 放置箱子，需配合 box_color)
##   box_color: int 1..5
##   holder_color: int 0..5（仅当 tile==GOAL 才生效；tile 改为非 GOAL 时自动清除 holder_color 与 box）
##   player: bool (true=放置玩家于此；false=若此处是玩家则清除)
##
## 注意：若 tile 改为 OUTSIDE / WALL，会强制清掉该格的 box / player / holder。
func write_cell(p: Vector2i, payload: Dictionary) -> void:
	if not _in_bounds(p):
		return
	# tile
	if payload.has("tile"):
		var t: int = int(payload.tile)
		tiles[p.y][p.x] = t
		if t == Cell.Type.OUTSIDE or t == Cell.Type.WALL:
			boxes.erase(p)
			holder_colors.erase(p)
			if player_pos == p:
				player_pos = Vector2i(-1, -1)
		if t == Cell.Type.GOAL and not holder_colors.has(p):
			# 默认填默认色
			holder_colors[p] = Cell.DEFAULT_COLOR
		if t != Cell.Type.GOAL:
			holder_colors.erase(p)
	# holder color
	if payload.has("holder_color") and get_tile(p) == Cell.Type.GOAL:
		holder_colors[p] = Cell.sanitize_holder_color(int(payload.holder_color))
	# box
	if payload.has("box"):
		if bool(payload.box):
			# 仅在可走格放置
			var t: int = get_tile(p)
			if t == Cell.Type.FLOOR or t == Cell.Type.GOAL:
				var c: int = Cell.sanitize_box_color(int(payload.get("box_color", Cell.DEFAULT_COLOR)))
				boxes[p] = c
				# 同格不能既是玩家又是箱子
				if player_pos == p:
					player_pos = Vector2i(-1, -1)
		else:
			boxes.erase(p)
	elif payload.has("box_color") and boxes.has(p):
		boxes[p] = Cell.sanitize_box_color(int(payload.box_color))
	# player
	if payload.has("player"):
		if bool(payload.player):
			var t: int = get_tile(p)
			if t == Cell.Type.FLOOR or t == Cell.Type.GOAL:
				# 玩家全局唯一
				player_pos = p
				boxes.erase(p)
		else:
			if player_pos == p:
				player_pos = Vector2i(-1, -1)

# ---------- Level 互转 ----------

func to_level() -> Level:
	var lvl := Level.new()
	lvl.id = String(meta.get("id", ""))
	lvl.name = String(meta.get("name", ""))
	lvl.author = String(meta.get("author", ""))
	lvl.width = width
	lvl.height = height
	lvl.format_version = 2
	lvl.wall_theme = String(meta.get("wall_theme", "brick"))
	lvl.floor_theme = String(meta.get("floor_theme", "grass"))
	# tiles 深拷贝
	var t_out: Array = []
	t_out.resize(height)
	for y in height:
		var row: Array = []
		row.resize(width)
		for x in width:
			row[x] = int(tiles[y][x])
		t_out[y] = row
	lvl.tiles = t_out
	lvl.player_start = player_pos
	# 实体（按字典遍历顺序导出；Level 不要求顺序）
	var box_starts: Array = []
	var box_colors: Array = []
	for p in boxes.keys():
		box_starts.append(p)
		box_colors.append(int(boxes[p]))
	lvl.box_starts = box_starts
	lvl.box_colors = box_colors
	var goals: Array = []
	var goal_colors: Array = []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if int(tiles[y][x]) == Cell.Type.GOAL:
				goals.append(p)
				goal_colors.append(int(holder_colors.get(p, Cell.DEFAULT_COLOR)))
	lvl.goal_positions = goals
	lvl.goal_colors = goal_colors
	# metadata
	var md: Dictionary = {
		"difficulty": int(meta.get("difficulty", 1)),
		"tags": (meta.get("tags", []) as Array).duplicate(),
		"theme": {
			"wall": lvl.wall_theme,
			"floor": lvl.floor_theme,
		},
	}
	if meta.has("optimal_steps"):
		md["optimal_steps"] = int(meta.get("optimal_steps", 0))
	if meta.has("optimal_pushes"):
		md["optimal_pushes"] = int(meta.get("optimal_pushes", 0))
	if meta.has("verified_by_solver"):
		md["verified_by_solver"] = bool(meta.get("verified_by_solver", false))
	# 颜色统计
	var seen: Dictionary = {}
	for c in box_colors:
		seen[int(c)] = true
	for c in goal_colors:
		seen[int(c)] = true
	md["color_count"] = seen.size()
	lvl.metadata = md
	return lvl

func load_from_level(lvl: Level) -> void:
	width = lvl.width
	height = lvl.height
	tiles = []
	tiles.resize(height)
	for y in height:
		var row: Array = []
		row.resize(width)
		for x in width:
			row[x] = int(lvl.get_tile(x, y))
		tiles[y] = row
	player_pos = lvl.player_start
	boxes.clear()
	for i in lvl.box_starts.size():
		var p: Vector2i = lvl.box_starts[i]
		var c: int = int(lvl.box_colors[i]) if i < lvl.box_colors.size() else Cell.DEFAULT_COLOR
		boxes[p] = c
	holder_colors.clear()
	for i in lvl.goal_positions.size():
		var p: Vector2i = lvl.goal_positions[i]
		var c: int = int(lvl.goal_colors[i]) if i < lvl.goal_colors.size() else Cell.DEFAULT_COLOR
		holder_colors[p] = c
	meta = {
		"id": lvl.id,
		"name": lvl.name,
		"author": lvl.author,
		"wall_theme": lvl.wall_theme,
		"floor_theme": lvl.floor_theme,
		"difficulty": int(lvl.metadata.get("difficulty", 1)),
		"tags": (lvl.metadata.get("tags", []) as Array).duplicate(),
	}
	if lvl.metadata.has("optimal_steps"):
		meta["optimal_steps"] = int(lvl.metadata.get("optimal_steps", 0))
	if lvl.metadata.has("optimal_pushes"):
		meta["optimal_pushes"] = int(lvl.metadata.get("optimal_pushes", 0))
	if lvl.metadata.has("verified_by_solver"):
		meta["verified_by_solver"] = bool(lvl.metadata.get("verified_by_solver", false))

## 统计（用于 Meta 面板显示）
func count_boxes() -> int:
	return boxes.size()

func count_goals() -> int:
	var n := 0
	for y in height:
		for x in width:
			if int(tiles[y][x]) == Cell.Type.GOAL:
				n += 1
	return n
