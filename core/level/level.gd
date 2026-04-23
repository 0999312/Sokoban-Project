class_name Level
extends Resource
## Level — 关卡数据 Resource。
## 由 LevelLoader 产生（从 JSON 或 XSB），是 Board 的初始化输入。
##
## 坐标系：(0,0) 为左上角；x 向右，y 向下。
##
## v2 新增：多色配对
##   - box_colors[i]   = box_starts[i] 对应箱子的颜色（1..5）
##   - goal_colors[i]  = goal_positions[i] 对应 holder 颜色（0=中性 / 1..5）
##   - 旧 v1 关卡：缺省时全部填 DEFAULT_COLOR(1) 或 NEUTRAL_COLOR(0)，按下方约定
##     v1 兼容：所有箱子=1、所有 goal=1（行为=经典单色）

@export var id: String = ""
## 关卡名。可以是：
##   - i18n key（如 "level_names.official-w1-01"）：tr() 会返回对应语言文本
##   - 或直接是用户原文（如 "我的关卡"）：tr() 找不到 key 时返回原字符串
## 因此 get_display_name() 既兼容官方关卡（走 i18n）又兼容用户自建关卡（直显原文）。
@export var name: String = ""
@export var author: String = ""
@export var width: int = 0
@export var height: int = 0
@export var format_version: int = 2
@export var metadata: Dictionary = {}

## 主题（影响 BoardView 选用的 atlas tile，不影响逻辑）。
## wall_theme  ∈ {"brick", "stone", "wood"}，默认 "brick"
## floor_theme ∈ {"grass", "stone", "dirt"}，默认 "grass"
@export var wall_theme: String = "brick"
@export var floor_theme: String = "grass"

const ALLOWED_WALL_THEMES: Array[String] = ["brick", "stone", "wood"]
const ALLOWED_FLOOR_THEMES: Array[String] = ["grass", "stone", "dirt"]

## 二维地形数组：tiles[y][x] -> Cell.Type
@export var tiles: Array = []

## 玩家初始位置
@export var player_start: Vector2i = Vector2i(-1, -1)

## 箱子初始位置数组（Vector2i）
@export var box_starts: Array = []

## 箱子颜色数组（int），与 box_starts 一一对应，长度需相同。
## 旧 v1 关卡加载时由 LevelLoader 填默认值（全 DEFAULT_COLOR）。
@export var box_colors: Array = []

## 目标点位置数组（Vector2i），冗余字段，便于胜利判定与渲染
@export var goal_positions: Array = []

## 目标点颜色数组（int），与 goal_positions 一一对应。
## 旧 v1 关卡加载时由 LevelLoader 填默认值（全 DEFAULT_COLOR）。
@export var goal_colors: Array = []

## 返回当前语言下的显示名。优先尝试 tr(name)；找不到 key 时 tr() 返回原文，
## 这天然兼容官方关卡（i18n key）和用户关卡（直接原文）两种情况。
func get_display_name() -> String:
	if name.is_empty():
		return id
	return TranslationServer.translate(name)

## 兼容旧调用：保留同名方法（locale 参数不再使用，由 TranslationServer 自动处理）。
func get_localized_name(_locale: String = "", _fallback: String = "") -> String:
	return get_display_name()

func get_tile(x: int, y: int) -> int:
	if y < 0 or y >= tiles.size():
		return Cell.Type.OUTSIDE
	var row: Array = tiles[y]
	if x < 0 or x >= row.size():
		return Cell.Type.OUTSIDE
	return row[x]

func is_in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < width and p.y >= 0 and p.y < height

func box_count() -> int:
	return box_starts.size()

func goal_count() -> int:
	return goal_positions.size()

## 关卡里实际出现过的颜色集合（含中性 0），用于元数据/分析。
func used_colors() -> Array[int]:
	var seen: Dictionary = {}
	for c in box_colors:
		seen[int(c)] = true
	for c in goal_colors:
		seen[int(c)] = true
	var out: Array[int] = []
	for k in seen.keys():
		out.append(int(k))
	out.sort()
	return out

## 是否使用了多色机制（除单一非中性色外还有别的颜色）。
func is_multi_color() -> bool:
	var non_neutral: Dictionary = {}
	for c in box_colors:
		non_neutral[int(c)] = true
	for c in goal_colors:
		var v: int = int(c)
		if v != Cell.NEUTRAL_COLOR:
			non_neutral[v] = true
	return non_neutral.size() > 1
