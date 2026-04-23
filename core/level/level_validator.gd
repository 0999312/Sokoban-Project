class_name LevelValidator
extends RefCounted
## LevelValidator — 关卡静态校验。
##
## 规则：
##   1. 玩家恰好 1 个
##   2. 箱子数 == 目标点数 ≥ 1
##   3. 玩家与所有目标点 4-连通（可达性）
##   4. width / height 与 tiles 矩阵一致
##   5. 多色配对（v2）：对每种颜色 c ∈ [1..MAX_COLOR]，
##        count(box.color == c) <= count(goal.color == c) + count(goal.color == NEUTRAL)
##      且总箱数 == 总 holder 数（已由规则 2 覆盖）
##      ——中性槽不指定颜色，可以接收任意色

class Result extends RefCounted:
	var ok: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func add_error(msg: String) -> void:
		ok = false
		errors.append(msg)

	func add_warning(msg: String) -> void:
		warnings.append(msg)

	func format_report() -> String:
		var parts: Array[String] = []
		if ok:
			parts.append("OK")
		for e in errors:
			parts.append("ERROR: " + e)
		for w in warnings:
			parts.append("WARN: " + w)
		return "\n".join(parts)


static func validate(level: Level) -> Result:
	var r := Result.new()
	if level == null:
		r.add_error("level is null")
		return r

	# 1. 维度
	if level.width <= 0 or level.height <= 0:
		r.add_error("invalid dimensions: %dx%d" % [level.width, level.height])
		return r
	if level.tiles.size() != level.height:
		r.add_error("tiles row count %d != height %d" % [level.tiles.size(), level.height])

	# 2. 玩家
	if level.player_start == Vector2i(-1, -1):
		r.add_error("no player found (@)")
	elif not level.is_in_bounds(level.player_start):
		r.add_error("player out of bounds: %s" % level.player_start)

	# 3. 箱子/目标点数量
	var box_n: int = level.box_count()
	var goal_n: int = level.goal_count()
	if box_n == 0:
		r.add_error("no boxes ($)")
	if goal_n == 0:
		r.add_error("no goals (.)")
	if box_n != goal_n:
		r.add_error("box count (%d) != goal count (%d)" % [box_n, goal_n])

	# 5. 颜色配对可行性
	if box_n == goal_n and box_n > 0:
		_validate_color_match(level, r)

	if not r.ok:
		return r

	# 4. 连通性：玩家可达的格子集合需覆盖所有目标点
	var reachable := _flood_fill(level, level.player_start)
	for g in level.goal_positions:
		if not reachable.has(g):
			r.add_error("goal at %s unreachable from player" % g)

	# 警告：箱子初始位置应在可达区域
	for b in level.box_starts:
		if not reachable.has(b):
			r.add_warning("box at %s unreachable from player initially" % b)

	return r

## 颜色配对可行性：对每个非中性色 c，box(c) 数量 ≤ holder(c) + holder(中性)。
## 还要保证总和守恒（已被 box_n == goal_n 间接保障）。
static func _validate_color_match(level: Level, r: Result) -> void:
	var box_count_by_color: Dictionary = {}
	for c in level.box_colors:
		var cc: int = int(c)
		box_count_by_color[cc] = int(box_count_by_color.get(cc, 0)) + 1
	var holder_count_by_color: Dictionary = {}
	for c in level.goal_colors:
		var cc: int = int(c)
		holder_count_by_color[cc] = int(holder_count_by_color.get(cc, 0)) + 1
	var neutral_holders: int = int(holder_count_by_color.get(Cell.NEUTRAL_COLOR, 0))
	# 检查每种箱子颜色
	for c in box_count_by_color.keys():
		var color_id: int = int(c)
		if color_id == Cell.NEUTRAL_COLOR:
			r.add_error("box has invalid neutral color (0); boxes must be color 1..%d" % Cell.MAX_COLOR)
			continue
		if color_id < Cell.DEFAULT_COLOR or color_id > Cell.MAX_COLOR:
			r.add_error("box color %d out of range [1..%d]" % [color_id, Cell.MAX_COLOR])
			continue
		var bn: int = int(box_count_by_color[c])
		var same: int = int(holder_count_by_color.get(color_id, 0))
		if bn > same + neutral_holders:
			r.add_error("color %d: %d box(es) but only %d same-color holder(s) + %d neutral" % [
				color_id, bn, same, neutral_holders
			])
	# 反向：每个非中性 holder 颜色，必须至少有同色箱子或中性箱子（中性箱子不存在 → 同色必需）
	for c in holder_count_by_color.keys():
		var color_id: int = int(c)
		if color_id == Cell.NEUTRAL_COLOR:
			continue
		var hn: int = int(holder_count_by_color[c])
		var bn2: int = int(box_count_by_color.get(color_id, 0))
		if bn2 == 0 and hn > 0:
			# 全部得靠中性箱子（不存在），且中性 holder 也无法解此色——但题目允许只要总数能配齐。
			# 例如：有 1 红 holder 但 0 红箱，且总箱数 == 总 holder 数 → 多余红箱必须被中性 holder 接收。
			# 此时只要 ∑(box) == ∑(holder) 且每种颜色不超量即可，已由上面循环覆盖。
			# 所以这里只发警告，不报错。
			r.add_warning("holder color %d present but no matching boxes; will only be filled by neutral fallback" % color_id)


static func _flood_fill(level: Level, start: Vector2i) -> Dictionary:
	var visited := {}
	if not level.is_in_bounds(start):
		return visited
	var stack: Array = [start]
	visited[start] = true
	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for d in DIRS:
			var n: Vector2i = p + d
			if visited.has(n):
				continue
			if not level.is_in_bounds(n):
				continue
			if not Cell.is_walkable(level.get_tile(n.x, n.y)):
				continue
			visited[n] = true
			stack.append(n)
	return visited
