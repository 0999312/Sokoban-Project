class_name DeadlockDetector
extends RefCounted
## DeadlockDetector — 推箱子求解器的死格 / 冻结检测。
##
## v2 更新：按箱子颜色独立构建死格表。
##   - 颜色 c 的箱子的"活格"= 从 (任何 c 色 holder) ∪ (任何中性 holder) 反向 BFS 可达的格
##   - 颜色 c 的死格 = walkable - alive(c)
##   - is_freeze_deadlock 同样要求"在 GOAL 上且颜色匹配"才算"非死"，否则按未在目标处理
##
## API：
##   compute_static_dead_squares(level)         -> Dictionary[color_id -> Dictionary[Vector2i -> true]]
##   compute_static_dead_squares_legacy(level)  -> Dictionary[Vector2i -> true]   (单色合并视图，向后兼容)
##   is_freeze_deadlock(level, boxes_with_color, last_pushed) -> bool

const _DIRS: Array = [
	Vector2i(0, -1),  # up
	Vector2i(1, 0),   # right
	Vector2i(0, 1),   # down
	Vector2i(-1, 0),  # left
]

## 按颜色构建静态死格表。
## 返回：{ color_id(int 1..MAX) -> Dictionary[Vector2i -> true] }
## 关卡未出现的颜色不会出现在结果里。
static func compute_static_dead_squares(level: Level) -> Dictionary:
	var walkable: Dictionary = _walkable_set(level)
	# 收集每种颜色对应的"接受集合"= 同色 holder + 所有中性 holder
	var holders_by_color: Dictionary = {}        # color_id -> Array[Vector2i]
	var neutral_holders: Array[Vector2i] = []
	for i in level.goal_positions.size():
		var p: Vector2i = level.goal_positions[i]
		var c: int = int(level.goal_colors[i]) if i < level.goal_colors.size() else Cell.DEFAULT_COLOR
		if c == Cell.NEUTRAL_COLOR:
			neutral_holders.append(p)
		else:
			if not holders_by_color.has(c):
				holders_by_color[c] = []
			(holders_by_color[c] as Array).append(p)
	# 关卡里出现的箱子颜色集合（决定要算哪些）
	var box_colors_present: Dictionary = {}
	for c in level.box_colors:
		box_colors_present[int(c)] = true
	# 还要保留没出现箱子但有 holder 的颜色（防止编辑器测试空场景）
	for c in holders_by_color.keys():
		box_colors_present[int(c)] = true

	var result: Dictionary = {}
	for color in box_colors_present.keys():
		var seeds: Array[Vector2i] = []
		if holders_by_color.has(color):
			for p in (holders_by_color[color] as Array):
				seeds.append(p)
		for p in neutral_holders:
			seeds.append(p)
		result[color] = _dead_for_seeds(walkable, seeds)
	return result

## 兼容旧接口：合并所有颜色的 dead 视图（取交集 = 对所有颜色都 dead 的格）。
## 注意：交集偏保守，只有全部颜色都死才算。仅供调试与回归测试使用。
static func compute_static_dead_squares_legacy(level: Level) -> Dictionary:
	var per_color: Dictionary = compute_static_dead_squares(level)
	if per_color.is_empty():
		return {}
	var iter: Array = per_color.values()
	var inter: Dictionary = (iter[0] as Dictionary).duplicate()
	for i in range(1, iter.size()):
		var d: Dictionary = iter[i]
		for k in inter.keys():
			if not d.has(k):
				inter.erase(k)
	return inter

static func _walkable_set(level: Level) -> Dictionary:
	var w: Dictionary = {}
	for y in level.height:
		for x in level.width:
			if Cell.is_walkable(level.get_tile(x, y)):
				w[Vector2i(x, y)] = true
	return w

## 反向 BFS：从所有 seeds 出发，每步要求 (cur+d) 与 (cur+2d) 都 walkable。
## 返回 dead = walkable - alive。
static func _dead_for_seeds(walkable: Dictionary, seeds: Array) -> Dictionary:
	var alive: Dictionary = {}
	var queue: Array[Vector2i] = []
	for s in seeds:
		var sp: Vector2i = s
		if walkable.has(sp) and not alive.has(sp):
			alive[sp] = true
			queue.append(sp)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in _DIRS:
			var nxt: Vector2i = cur + d
			var puller: Vector2i = cur + d * 2
			if not walkable.has(nxt): continue
			if not walkable.has(puller): continue
			if alive.has(nxt): continue
			alive[nxt] = true
			queue.append(nxt)
	var dead: Dictionary = {}
	for p in walkable.keys():
		if not alive.has(p):
			dead[p] = true
	return dead

## 推动后的简易冻结检测（v2 版）。
## boxes: Dictionary[Vector2i -> int(color_id)]
## moved: 刚被推到的箱子坐标
## holder_color_at: Dictionary[Vector2i -> int]   ## Board.goal_color_at（含中性）
##
## "在 GOAL 上"不再无条件视为非死——必须 颜色匹配（含中性槽）才算非死。
## 否则与普通 floor 上的箱子一样判冻结。
static func is_freeze_deadlock(level: Level, boxes: Dictionary, moved: Vector2i, holder_color_at: Dictionary = {}) -> bool:
	var moved_color: int = int(boxes.get(moved, Cell.DEFAULT_COLOR))
	# 在 GOAL 上且颜色匹配 → 视为完成态，不算死
	if level.get_tile(moved.x, moved.y) == Cell.Type.GOAL:
		var hc: int = int(holder_color_at.get(moved, Cell.DEFAULT_COLOR)) if not holder_color_at.is_empty() else Cell.DEFAULT_COLOR
		if Cell.color_matches(moved_color, hc):
			return false
	return _frozen_axis(level, boxes, moved, true) and _frozen_axis(level, boxes, moved, false)

## 判断给定箱子在某轴向上是否被"锁死"——两侧不可走或邻居也是被锁箱子。
static func _frozen_axis(level: Level, boxes: Dictionary, p: Vector2i, horizontal: bool) -> bool:
	var d: Vector2i = Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var a: Vector2i = p + d
	var b: Vector2i = p - d
	var ta: int = level.get_tile(a.x, a.y)
	var tb: int = level.get_tile(b.x, b.y)
	var a_blocked: bool = (ta == Cell.Type.WALL or ta == Cell.Type.OUTSIDE) or boxes.has(a)
	var b_blocked: bool = (tb == Cell.Type.WALL or tb == Cell.Type.OUTSIDE) or boxes.has(b)
	if not a_blocked or not b_blocked:
		var a_wall: bool = (ta == Cell.Type.WALL or ta == Cell.Type.OUTSIDE)
		var b_wall: bool = (tb == Cell.Type.WALL or tb == Cell.Type.OUTSIDE)
		var a_box: bool = boxes.has(a)
		var b_box: bool = boxes.has(b)
		if (a_wall or a_box) and (b_wall or b_box):
			return true
		return false
	return true
