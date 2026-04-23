class_name SokobanSolver
extends RefCounted
## SokobanSolver — 推数最优 (push-optimal) 求解器（v2 多色版）。
##
## 算法：IDA* on push-graph
##   - 节点 = (boxes_with_color, player_normalized_pos)
##     player_normalized_pos = 玩家可达区域中字典序最小的格子（z-order: y*W+x）
##   - 边 = 一次推动（不计走步）；权 1。
##   - 启发式 h = 按颜色分组求每个箱子到"最近可接受 holder"的曼哈顿距离之和
##     （可接受 holder = 同色 holder ∪ 中性 holder；admissible 下界）。
##   - 颜色独立的静态死格表 + 简化冻结检测剪枝。
##   - Transposition table 用 Dictionary 缓存已访问 (state_key -> best_g)。
##
## 输出：
##   { "found": bool, "pushes": int, "nodes_expanded": int, "push_solution": Array, "cancelled": bool }
##   push_solution: 每项 { "box": Vector2i, "dir": Vector2i }
##   也可调用 expand_to_moves(level, push_solution) 还原玩家完整走法序列（含 BFS 寻路）。
##
## 取消：外部线程通过 set_cancel(true) 中止。

const _DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var max_pushes: int = 200          ## IDA* 上界，超过即放弃
var node_limit: int = 2_000_000    ## 总展开节点上限，防爆
var report_every: int = 50_000     ## 每展开 N 节点回调一次进度

signal progress(nodes_expanded: int, current_bound: int)

var _level: Level
var _walkable: Dictionary           # Vector2i -> true
## v2: 颜色相关结构
var _holders_by_color: Dictionary   # color_id (1..MAX) -> Array[Vector2i]   仅同色 holder
var _neutral_holders: Array[Vector2i] = []
var _holder_color_at: Dictionary    # Vector2i -> int(0..5)   每个 GOAL 格的 holder 颜色
var _dead_set_by_color: Dictionary  # color_id -> Dictionary[Vector2i -> true]
var _cancel: bool = false
var _nodes: int = 0
var _solution: Array = []           # Array of {box, dir}
var _found: bool = false

func set_cancel(v: bool) -> void:
	_cancel = v

## 主入口。返回结果 dict。
##
## 兼容性：
##   - initial_boxes 既可以是 Array[Vector2i]（v1 风格，默认全色 1）
##     也可以直接传 Dictionary[Vector2i -> color_id]（高级用法）。
##   - 推荐做法：传 Array[Vector2i]，颜色由 level.box_colors 自动配对。
func solve(level: Level, initial_boxes: Array, initial_player: Vector2i) -> Dictionary:
	_level = level
	_cancel = false
	_nodes = 0
	_solution.clear()
	_found = false

	# 颜色相关索引
	_holders_by_color = {}
	_neutral_holders = []
	_holder_color_at = {}
	for i in level.goal_positions.size():
		var p: Vector2i = level.goal_positions[i]
		var c: int = int(level.goal_colors[i]) if i < level.goal_colors.size() else Cell.DEFAULT_COLOR
		_holder_color_at[p] = c
		if c == Cell.NEUTRAL_COLOR:
			_neutral_holders.append(p)
		else:
			if not _holders_by_color.has(c):
				_holders_by_color[c] = []
			(_holders_by_color[c] as Array).append(p)

	_walkable = {}
	for y in level.height:
		for x in level.width:
			if Cell.is_walkable(level.get_tile(x, y)):
				_walkable[Vector2i(x, y)] = true
	_dead_set_by_color = DeadlockDetector.compute_static_dead_squares(level)

	# 构造 boxes: Vector2i -> color_id
	var boxes: Dictionary = {}
	for i in initial_boxes.size():
		var p: Vector2i = initial_boxes[i]
		var c: int = int(level.box_colors[i]) if i < level.box_colors.size() else Cell.DEFAULT_COLOR
		boxes[p] = c

	if _is_solved(boxes):
		return _result(true, 0)

	# 初始死格剪枝（每个箱子按自己的颜色查死格表）
	for b in boxes.keys():
		var bc: int = int(boxes[b])
		if _is_dead_for_color(b, bc):
			# 已经在 holder 上且匹配 → 已完成态，不算死；否则确实无解
			if not _is_box_complete(b, bc):
				return _result(false, -1)

	var h0: int = _heuristic(boxes)
	if h0 == -1:
		return _result(false, -1)

	# IDA* 迭代加深
	var bound: int = h0
	while bound <= max_pushes:
		progress.emit(_nodes, bound)
		var visited: Dictionary = {}
		var path: Array = []
		var t: int = _dfs(boxes, initial_player, 0, bound, visited, path)
		if _cancel:
			return _result(false, -1)
		if _nodes > node_limit:
			return _result(false, -1)
		if t == -1:
			return _result(true, _solution.size())
		if t == 9_999_999:
			return _result(false, -1)
		bound = t

	return _result(false, -1)

func _result(found: bool, pushes: int) -> Dictionary:
	return {
		"found": found,
		"pushes": pushes if found else -1,
		"nodes_expanded": _nodes,
		"push_solution": _solution.duplicate() if found else [],
		"cancelled": _cancel,
	}

## DFS 返回值：-1 = 找到解；其他正数 = 该层超出 bound 时遇到的最小 (g+h)，作为下轮 bound。
func _dfs(boxes: Dictionary, player: Vector2i, g: int, bound: int, visited: Dictionary, path: Array) -> int:
	if (_nodes & 4095) == 0:
		if _cancel:
			return 0
		if _nodes > node_limit:
			return 0
	_nodes += 1
	if _nodes % report_every == 0:
		progress.emit(_nodes, bound)

	if _is_solved(boxes):
		_solution = path.duplicate()
		return -1

	var h: int = _heuristic(boxes)
	if h == -1:
		return 9_999_999
	var f: int = g + h
	if f > bound:
		return f

	# 标准化：玩家可达区域 + 区域内最小坐标
	var reach: Dictionary = _player_reach(boxes, player)
	var norm: Vector2i = _normalize(reach)
	var key: int = _state_key(boxes, norm)
	var prev_g: int = visited.get(key, -1)
	if prev_g != -1 and prev_g <= g:
		return 9_999_999
	visited[key] = g

	var min_next: int = 9_999_999

	for box in boxes.keys():
		var b: Vector2i = box
		var bc: int = int(boxes[b])
		for d in _DIRS:
			# 玩家须能站在 b - d 才能向 d 方向推 b 到 b+d
			var stand: Vector2i = b - d
			if not reach.has(stand):
				continue
			var dest: Vector2i = b + d
			if not _walkable.has(dest):
				continue
			if boxes.has(dest):
				continue
			# 静态死格剪枝（按推动后该箱子的颜色）
			if _is_dead_for_color(dest, bc) and not _is_box_complete(dest, bc):
				continue
			# 模拟推动
			boxes.erase(b)
			boxes[dest] = bc
			# 冻结剪枝（v2：考虑颜色匹配是否使其在 holder 上算"完成"）
			if DeadlockDetector.is_freeze_deadlock(_level, boxes, dest, _holder_color_at):
				boxes.erase(dest)
				boxes[b] = bc
				continue
			path.append({ "box": b, "dir": d })
			var t: int = _dfs(boxes, b, g + 1, bound, visited, path)
			path.pop_back()
			boxes.erase(dest)
			boxes[b] = bc
			if t == -1:
				return -1
			if _cancel or _nodes > node_limit:
				return 0
			if t < min_next:
				min_next = t
	return min_next

## 玩家在当前 boxes 布局下能走到的所有格子。
func _player_reach(boxes: Dictionary, start: Vector2i) -> Dictionary:
	var reached: Dictionary = {}
	reached[start] = true
	if not _walkable.has(start) or boxes.has(start):
		return reached
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in _DIRS:
			var nxt: Vector2i = cur + d
			if reached.has(nxt):
				continue
			if not _walkable.has(nxt):
				continue
			if boxes.has(nxt):
				continue
			reached[nxt] = true
			queue.append(nxt)
	return reached

## 玩家区域内字典序最小的格子（行优先：y 小优先，再 x 小优先）。
func _normalize(reach: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(2_000_000, 2_000_000)
	var best_idx: int = 1 << 60
	var w: int = _level.width
	for p in reach.keys():
		var pp: Vector2i = p
		var idx: int = pp.y * w + pp.x
		if idx < best_idx:
			best_idx = idx
			best = pp
	return best

## 状态 key：玩家归一化坐标 + 箱子(坐标, 颜色) 排序后拼接的复合 hash（v2 加入颜色维度）。
func _state_key(boxes: Dictionary, norm: Vector2i) -> int:
	var w: int = _level.width
	var entries: Array[int] = []
	entries.resize(boxes.size())
	var i: int = 0
	for b in boxes.keys():
		var bb: Vector2i = b
		var bc: int = int(boxes[b])
		# 把 (color, idx) 编码为单个 int：高位放 color，低位放位置索引
		entries[i] = (bc * 1_000_003) ^ (bb.y * w + bb.x)
		i += 1
	entries.sort()
	var h: int = norm.y * w + norm.x
	for v in entries:
		h = (h * 1_000_003) ^ v
	return h

## 启发式：按颜色分组求 sum_min_distance(box -> 该色可接受 holder)。
## 可接受 holder = 同色 holder ∪ 中性 holder。
## 已完成（在可接受 holder 上）的箱子贡献 0。
## 单色优化：若该色没有任何可接受 holder（即同色 holder 集合 + 中性 holder 集合都空）→ -1（不可解）。
func _heuristic(boxes: Dictionary) -> int:
	var sum: int = 0
	for b in boxes.keys():
		var bb: Vector2i = b
		var bc: int = int(boxes[b])
		# 已完成？
		if _is_box_complete(bb, bc):
			continue
		# 找 (同色 holder ∪ 中性 holder) 中的最近距离
		var best: int = -1
		var same: Array = _holders_by_color.get(bc, [])
		for g in same:
			var gg: Vector2i = g
			var d: int = absi(bb.x - gg.x) + absi(bb.y - gg.y)
			if best == -1 or d < best:
				best = d
		for g in _neutral_holders:
			var gg2: Vector2i = g
			var d2: int = absi(bb.x - gg2.x) + absi(bb.y - gg2.y)
			if best == -1 or d2 < best:
				best = d2
		if best == -1:
			return -1
		sum += best
	return sum

func _is_solved(boxes: Dictionary) -> bool:
	if boxes.is_empty():
		return false
	for b in boxes.keys():
		var bc: int = int(boxes[b])
		if not _is_box_complete(b, bc):
			return false
	return true

func _is_box_complete(p: Vector2i, color: int) -> bool:
	if not _holder_color_at.has(p):
		return false
	var hc: int = int(_holder_color_at[p])
	return Cell.color_matches(color, hc)

func _is_dead_for_color(p: Vector2i, color: int) -> bool:
	var d: Dictionary = _dead_set_by_color.get(color, {})
	return d.has(p)

## 把 push 序列展开为玩家完整 move 序列（每步 Vector2i）。
## 用 BFS 在每次推动前找最短走路路径。
static func expand_to_moves(level: Level, initial_boxes: Array, initial_player: Vector2i, push_solution: Array) -> Array:
	var walkable: Dictionary = {}
	for y in level.height:
		for x in level.width:
			if Cell.is_walkable(level.get_tile(x, y)):
				walkable[Vector2i(x, y)] = true
	var boxes: Dictionary = {}
	for b in initial_boxes:
		boxes[b] = true
	var player: Vector2i = initial_player
	var moves: Array = []
	for push in push_solution:
		var b: Vector2i = push["box"]
		var d: Vector2i = push["dir"]
		var stand: Vector2i = b - d
		var path: Array = _bfs_path(walkable, boxes, player, stand)
		for step in path:
			moves.append(step)
		# 推动这一步
		moves.append(d)
		boxes.erase(b)
		boxes[b + d] = true
		player = b
	return moves

static func _bfs_path(walkable: Dictionary, boxes: Dictionary, src: Vector2i, dst: Vector2i) -> Array:
	if src == dst:
		return []
	var came: Dictionary = {}
	came[src] = Vector2i.ZERO
	var queue: Array[Vector2i] = [src]
	var found: bool = false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == dst:
			found = true
			break
		for d in _DIRS:
			var nxt: Vector2i = cur + d
			if came.has(nxt):
				continue
			if not walkable.has(nxt):
				continue
			if boxes.has(nxt):
				continue
			came[nxt] = d
			queue.append(nxt)
	if not found:
		return []
	var rev: Array = []
	var cur2: Vector2i = dst
	while cur2 != src:
		var d: Vector2i = came[cur2]
		rev.append(d)
		cur2 = cur2 - d
	rev.reverse()
	return rev
