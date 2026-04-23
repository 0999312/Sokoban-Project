class_name Cell
extends RefCounted
## Cell — 关卡格子类型枚举（地形层）。
## 实体（玩家、箱子）独立存放在 Board 的 entities 字典中。
##
## v2 新增：颜色配对（5 种颜色 + 1 种中性槽）。
##   - 箱子 color_id ∈ [1..MAX_COLOR]
##   - holder color_id ∈ [0..MAX_COLOR]，0 = 中性槽（接受任意颜色）

enum Type {
	OUTSIDE = 0,  ## 外部空区（透明，不可达）
	FLOOR = 1,    ## 普通地板
	WALL = 2,     ## 墙
	GOAL = 3,     ## 目标点（属于地形层）
}

## 颜色相关常量
const NEUTRAL_COLOR: int = 0
const DEFAULT_COLOR: int = 1
const MAX_COLOR: int = 5

## 是否可走（玩家或箱子可踏入）。
static func is_walkable(t: int) -> bool:
	return t == Type.FLOOR or t == Type.GOAL

static func to_string_short(t: int) -> String:
	match t:
		Type.OUTSIDE: return "-"
		Type.FLOOR: return " "
		Type.WALL: return "#"
		Type.GOAL: return "."
		_: return "?"

## 箱子颜色 c 是否能"完成"在 holder 颜色 hc 上。
## 中性槽 (hc == 0) 接受任何颜色；否则需要严格相等。
static func color_matches(box_color: int, holder_color: int) -> bool:
	if holder_color == NEUTRAL_COLOR:
		return true
	return box_color == holder_color

## 把 color_id 限制到合法范围；非法值回落到 DEFAULT_COLOR。
static func sanitize_box_color(c: int) -> int:
	if c < DEFAULT_COLOR or c > MAX_COLOR:
		return DEFAULT_COLOR
	return c

static func sanitize_holder_color(c: int) -> int:
	if c < NEUTRAL_COLOR or c > MAX_COLOR:
		return NEUTRAL_COLOR
	return c
