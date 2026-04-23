class_name A11y
extends RefCounted
## A11y — 单点查询无障碍/视觉偏好。
##
## 读取 SaveManager.profile.settings 中的 reduce_motion / high_contrast。
## 用法：
##   if A11y.is_reduce_motion(): duration *= 0.3
##   var mod := A11y.high_contrast_modulate(base_color)

const DEFAULT_REDUCE_MOTION := false
const DEFAULT_HIGH_CONTRAST := false

# 减弱动画时，所有动画时长 / 粒子寿命 的乘数
const REDUCE_MOTION_FACTOR := 0.3

static func is_reduce_motion() -> bool:
	var sm := _save_manager()
	if sm == null: return DEFAULT_REDUCE_MOTION
	return bool(sm.get_setting("reduce_motion", DEFAULT_REDUCE_MOTION))

static func is_high_contrast() -> bool:
	var sm := _save_manager()
	if sm == null: return DEFAULT_HIGH_CONTRAST
	return bool(sm.get_setting("high_contrast", DEFAULT_HIGH_CONTRAST))

## 把任意时长按当前 reduce_motion 设置缩放
static func scale_duration(seconds: float) -> float:
	if is_reduce_motion():
		return seconds * REDUCE_MOTION_FACTOR
	return seconds

## 是否允许触发粒子（reduce_motion 时禁用）
static func particles_enabled() -> bool:
	return not is_reduce_motion()

## 高对比度下对实体颜色做提亮 + 饱和度增强（线性近似）
static func high_contrast_tint(base: Color) -> Color:
	if not is_high_contrast():
		return base
	# 提亮 + 推向纯色：每个通道向 0/1 极端偏移
	var r := base.r
	var g := base.g
	var b := base.b
	var avg := (r + g + b) / 3.0
	# 远离灰度
	r = lerpf(r, 1.0 if r > avg else 0.0, 0.35)
	g = lerpf(g, 1.0 if g > avg else 0.0, 0.35)
	b = lerpf(b, 1.0 if b > avg else 0.0, 0.35)
	# 整体提亮
	return Color(minf(r * 1.15, 1.0), minf(g * 1.15, 1.0), minf(b * 1.15, 1.0), base.a)

static func _save_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null: return null
	var tree := loop as SceneTree
	if tree == null: return null
	return tree.root.get_node_or_null("SaveManager")
