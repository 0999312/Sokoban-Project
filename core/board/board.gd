class_name Board
extends RefCounted
## Board — 关卡运行时状态机。
##
## 持有：
##   - level: Level 的引用（地形 + 颜色配置）
##   - player_pos: Vector2i
##   - boxes: Dictionary[Vector2i -> int(color_id)]   ## v2: 值由 bool 升级为颜色 id
##   - goal_color_at: Dictionary[Vector2i -> int(color_id 0..5)]   ## holder 颜色查表
##   - undo_stack: UndoStack
##   - move_count / push_count
##
## 信号（不接 EventBus，由 GameController 中转）：
##   moved(cmd)、undone(cmd)、redone(cmd)、reset()、won()
##
## 胜利判定（v2）：所有箱子位于 GOAL 上，且每个箱子颜色与 holder 颜色匹配
##   （holder 颜色 0 = 中性槽，可接受任意箱子颜色）。

signal moved(cmd: BoardCommand)
signal undone(cmd: BoardCommand)
signal redone(cmd: BoardCommand)
signal reset_done()
signal won()

var level: Level
var player_pos: Vector2i = Vector2i.ZERO
var boxes: Dictionary = {}             # Vector2i -> int(color_id)
var goal_color_at: Dictionary = {}     # Vector2i -> int(holder color_id)
var undo_stack: UndoStack
var move_count: int = 0
var push_count: int = 0
var _won: bool = false

func _init(p_level: Level) -> void:
	level = p_level
	undo_stack = UndoStack.new()
	_build_goal_color_table()
	_load_initial()

func _build_goal_color_table() -> void:
	goal_color_at.clear()
	for i in level.goal_positions.size():
		var p: Vector2i = level.goal_positions[i]
		var c: int = int(level.goal_colors[i]) if i < level.goal_colors.size() else Cell.DEFAULT_COLOR
		goal_color_at[p] = c

func _load_initial() -> void:
	player_pos = level.player_start
	boxes.clear()
	for i in level.box_starts.size():
		var p: Vector2i = level.box_starts[i]
		var c: int = int(level.box_colors[i]) if i < level.box_colors.size() else Cell.DEFAULT_COLOR
		boxes[p] = c
	move_count = 0
	push_count = 0
	_won = false
	undo_stack.clear()

## 重置到关卡初态。
func restart() -> void:
	_load_initial()
	reset_done.emit()

## 查 holder 颜色：返回 -1 表示该位置不是 GOAL，否则返回 0..5。
func holder_color(p: Vector2i) -> int:
	if not goal_color_at.has(p):
		return -1
	return int(goal_color_at[p])

## 尝试沿 dir 方向移动一步。返回是否成功。
func try_move(dir: Vector2i) -> bool:
	if _won:
		return false
	if dir == Vector2i.ZERO:
		return false
	var target: Vector2i = player_pos + dir
	if not level.is_in_bounds(target):
		return false
	var t_tile: int = level.get_tile(target.x, target.y)
	if not Cell.is_walkable(t_tile):
		return false

	var cmd := BoardCommand.new()
	cmd.direction = dir
	cmd.player_from = player_pos
	cmd.player_to = target

	if boxes.has(target):
		# 推箱：检查箱子之后的目标格
		var beyond: Vector2i = target + dir
		if not level.is_in_bounds(beyond):
			return false
		var b_tile: int = level.get_tile(beyond.x, beyond.y)
		if not Cell.is_walkable(b_tile):
			return false
		if boxes.has(beyond):
			return false
		# 推动
		var bc: int = int(boxes[target])
		boxes.erase(target)
		boxes[beyond] = bc
		cmd.pushed_box = true
		cmd.box_from = target
		cmd.box_to = beyond
		cmd.box_color = bc
		cmd.holder_color_from = holder_color(target)
		cmd.holder_color_to = holder_color(beyond)
		push_count += 1

	player_pos = target
	move_count += 1
	undo_stack.push(cmd)
	moved.emit(cmd)

	if _check_win():
		_won = true
		won.emit()
	return true

## 撤销一步。
func undo() -> bool:
	if not undo_stack.can_undo():
		return false
	var cmd: BoardCommand = undo_stack.pop_undo()
	if cmd == null:
		return false
	# 反向应用
	player_pos = cmd.player_from
	move_count = maxi(0, move_count - 1)
	if cmd.pushed_box:
		# 恢复箱子位置（保留颜色）
		var bc: int = int(boxes.get(cmd.box_to, cmd.box_color))
		boxes.erase(cmd.box_to)
		boxes[cmd.box_from] = bc
		push_count = maxi(0, push_count - 1)
	# 撤销后取消胜利锁
	if _won:
		_won = false
	undone.emit(cmd)
	return true

## 重做一步。
func redo() -> bool:
	if not undo_stack.can_redo():
		return false
	var cmd: BoardCommand = undo_stack.pop_redo()
	if cmd == null:
		return false
	player_pos = cmd.player_to
	move_count += 1
	if cmd.pushed_box:
		var bc: int = int(boxes.get(cmd.box_from, cmd.box_color))
		boxes.erase(cmd.box_from)
		boxes[cmd.box_to] = bc
		push_count += 1
	redone.emit(cmd)
	if _check_win():
		_won = true
		won.emit()
	return true

func is_won() -> bool:
	return _won

## 胜利：每个箱子都在 GOAL 上 且 颜色与 holder 匹配（中性槽接受任意色）。
func _check_win() -> bool:
	if boxes.is_empty():
		return false
	for b in boxes.keys():
		if level.get_tile(b.x, b.y) != Cell.Type.GOAL:
			return false
		var bc: int = int(boxes[b])
		var hc: int = holder_color(b)
		if hc == -1:  # 安全网
			return false
		if not Cell.color_matches(bc, hc):
			return false
	return true

## 该位置箱子是否处于"完成态"（在 GOAL 上且颜色匹配）。BoardView 用于着色器。
func is_box_complete_at(p: Vector2i) -> bool:
	if not boxes.has(p):
		return false
	var hc: int = holder_color(p)
	if hc == -1:
		return false
	return Cell.color_matches(int(boxes[p]), hc)
