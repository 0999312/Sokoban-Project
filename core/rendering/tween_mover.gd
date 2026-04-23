class_name TweenMover
extends RefCounted
## TweenMover — 节点格子位移动画工具。
##
## 使用方式：
##   var t = TweenMover.move(node, target_pos)            # 普通位移
##   var t = TweenMover.move_with_shake(node, target_pos) # 位移 + ±2px 落地抖动（玩家走步）
##   await t.finished
##
## reduce_motion 偏好：所有动画时长按 A11y.scale_duration 缩放；shake 在减弱动画时禁用。

const DEFAULT_DURATION := 0.12
const SHAKE_AMPLITUDE := 2.0   # 像素
const SHAKE_DURATION := 0.06   # 落地抖动时长

static func move(node: Node2D, to_pos: Vector2, duration: float = DEFAULT_DURATION) -> Tween:
	var d := A11y.scale_duration(duration)
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", to_pos, d)
	return tween

## 走步：先位移到目标，再做一次极短的 ±2px 横向抖动，给"踩稳"一种重量感。
## reduce_motion 开启时退化为普通 move。
static func move_with_shake(node: Node2D, to_pos: Vector2, duration: float = DEFAULT_DURATION) -> Tween:
	if A11y.is_reduce_motion():
		return move(node, to_pos, duration)
	var d := A11y.scale_duration(duration)
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", to_pos, d)
	# 落地抖动：朝随机方向 1px 偏移再回正（不影响最终对位）
	var jitter := Vector2(randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE), 0.0)
	tween.tween_property(node, "position", to_pos + jitter, SHAKE_DURATION * 0.5)
	tween.tween_property(node, "position", to_pos, SHAKE_DURATION * 0.5)
	return tween
