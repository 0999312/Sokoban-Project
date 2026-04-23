class_name EditCommand
extends RefCounted
## EditCommand — 编辑器单步命令，可与 UndoStack 共用。
##
## 一次编辑通常涉及一组格子：每个格子记录 before/after 完整快照，
## apply / revert 时直接覆盖即可（无需关心增量类型）。
##
## changes: Array[{ pos: Vector2i, before: Dictionary, after: Dictionary }]
##   before/after 由 EditorModel.snapshot_cell(pos) 生成
##
## 还支持额外快照"全局玩家位置"，用于 player 唯一性约束（放置玩家会清除原位置）。

var changes: Array = []
var player_before: Vector2i = Vector2i(-2, -2)   # -2 = 未记录
var player_after: Vector2i = Vector2i(-2, -2)

func add_change(pos: Vector2i, before: Dictionary, after: Dictionary) -> void:
	changes.append({ "pos": pos, "before": before, "after": after })

func is_empty() -> bool:
	return changes.is_empty() and player_before == Vector2i(-2, -2)

func apply_to(model: EditorModel) -> void:
	for ch in changes:
		_write_snapshot(model, ch.pos, ch.after)
	if player_after != Vector2i(-2, -2):
		model.player_pos = player_after

func revert_on(model: EditorModel) -> void:
	for ch in changes:
		_write_snapshot(model, ch.pos, ch.before)
	if player_before != Vector2i(-2, -2):
		model.player_pos = player_before

## 把 snapshot dict 直接写入模型（不走 write_cell 的派生逻辑），保证可逆。
static func _write_snapshot(model: EditorModel, p: Vector2i, snap: Dictionary) -> void:
	if not model._in_bounds(p):
		return
	model.tiles[p.y][p.x] = int(snap.get("tile", model.get_tile(p)))
	# box
	if bool(snap.get("box", false)):
		model.boxes[p] = int(snap.get("box_color", 1))
	else:
		model.boxes.erase(p)
	# holder
	if int(snap.get("tile", 0)) == 3:  # GOAL
		model.holder_colors[p] = int(snap.get("holder_color", 1))
	else:
		model.holder_colors.erase(p)
	# player handled at command level
