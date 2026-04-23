class_name BoardCommand
extends RefCounted
## BoardCommand — Undo 单元。
## 一次玩家移动产生一条 MoveCommand：
##   - direction: 玩家移动方向
##   - pushed_box: 是否推动了一个箱子（用于回滚箱子位置）
##   - box_from / box_to: 若推动则箱子的旧/新位置
##   - box_color: 被推箱子的颜色（v2）
##   - holder_color_from / holder_color_to: 推动前/后箱子下方 holder 颜色，
##     -1 表示该位置不是 GOAL；0 = 中性槽，1..5 = 具体颜色
##     用于音效/粒子区分"归位/离位/换槽"。

var direction: Vector2i = Vector2i.ZERO
var player_from: Vector2i = Vector2i.ZERO
var player_to: Vector2i = Vector2i.ZERO
var pushed_box: bool = false
var box_from: Vector2i = Vector2i.ZERO
var box_to: Vector2i = Vector2i.ZERO
var box_color: int = Cell.DEFAULT_COLOR
var holder_color_from: int = -1   ## -1 = 非 GOAL；0 = 中性；1..5 = 具体色
var holder_color_to: int = -1

## 该次推动是否使箱子"完成归位"（推动前未完成 → 推动后完成）
func became_complete() -> bool:
	if not pushed_box:
		return false
	var was: bool = holder_color_from != -1 and Cell.color_matches(box_color, holder_color_from)
	var now: bool = holder_color_to != -1 and Cell.color_matches(box_color, holder_color_to)
	return now and not was

## 该次推动是否使箱子"脱离归位"
func became_incomplete() -> bool:
	if not pushed_box:
		return false
	var was: bool = holder_color_from != -1 and Cell.color_matches(box_color, holder_color_from)
	var now: bool = holder_color_to != -1 and Cell.color_matches(box_color, holder_color_to)
	return was and not now

func _to_string() -> String:
	if pushed_box:
		return "Move(%s push c%d %s->%s)" % [direction, box_color, box_from, box_to]
	return "Move(%s)" % direction
