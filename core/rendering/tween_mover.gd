class_name TweenMover
extends RefCounted
## TweenMover — 节点格子位移动画工具。
## 使用方式：var t = TweenMover.move(node, target_pos, 0.12)
##           await t.finished

const DEFAULT_DURATION := 0.12

static func move(node: Node2D, to_pos: Vector2, duration: float = DEFAULT_DURATION) -> Tween:
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", to_pos, duration)
	return tween
