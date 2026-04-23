extends Node2D
## EditorBoard — 编辑器画布。
##
## 自绘地形 + 实体；处理鼠标拖拽并把"目标格集合"提交给 EditorScene.apply_tool_action。
##
## 形状（current_shape）：
##   SINGLE: 拖拽时每次进入新格子都立即提交（流式）
##   RECT:   按下→拖动 → 释放时把 [start, end] 矩形所有格子作为一个命令提交
##   LINE:   按下→拖动 → 释放时把起点终点的 Bresenham 直线格子集合提交
##
## 鼠标右键拖拽：行为强制 = ERASER（无视当前工具）。

const TILE_SIZE := 48

var editor: Node                 # EditorScene
var model: EditorModel
var _origin: Vector2 = Vector2.ZERO
var _is_drawing: bool = false
var _draw_start: Vector2i = Vector2i(-1, -1)
var _draw_last: Vector2i = Vector2i(-1, -1)
var _draw_button: int = MOUSE_BUTTON_LEFT
var _shape_preview_cells: Array = []   # 用于 RECT/LINE 预览
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _streamed_changes: Array = []      # SINGLE 拖拽时的累计格集合（提交时会合并）

func set_model(m: EditorModel) -> void:
	model = m
	recenter()
	queue_redraw()

func _ready() -> void:
	recenter()
	# 监听父容器尺寸变化以重新居中
	var parent := get_parent()
	if parent != null and parent is Control:
		(parent as Control).resized.connect(recenter)

func recenter() -> void:
	if model == null: return
	var parent := get_parent() as Control
	if parent == null: return
	var ps := parent.size
	var bw := model.width * TILE_SIZE
	var bh := model.height * TILE_SIZE
	_origin = Vector2((ps.x - bw) * 0.5, (ps.y - bh) * 0.5)
	position = _origin
	queue_redraw()

func _gui_to_cell(local_pos: Vector2) -> Vector2i:
	# local_pos 是相对本节点的坐标（已减去 _origin）
	var x := int(floor(local_pos.x / TILE_SIZE))
	var y := int(floor(local_pos.y / TILE_SIZE))
	return Vector2i(x, y)

func _input(event: InputEvent) -> void:
	if model == null:
		return
	if editor != null and editor.has_method("has_blocking_overlay") and editor.has_blocking_overlay():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var local: Vector2 = get_local_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if not _hit_test(local):
					return
				_is_drawing = true
				_draw_button = mb.button_index
				_draw_start = _gui_to_cell(local)
				_draw_last = _draw_start
				_streamed_changes.clear()
				_shape_preview_cells.clear()
				_apply_or_preview(_draw_start, true)
				queue_redraw()
				get_viewport().set_input_as_handled()
			else:
				if _is_drawing and mb.button_index == _draw_button:
					_finish_drawing()
					queue_redraw()
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var local2: Vector2 = get_local_mouse_position()
		var c := _gui_to_cell(local2)
		_hover_cell = c if _hit_test(local2) else Vector2i(-1, -1)
		if _is_drawing:
			if c != _draw_last:
				_apply_or_preview(c, false)
				_draw_last = c
		queue_redraw()

func _hit_test(local: Vector2) -> bool:
	var c := _gui_to_cell(local)
	return c.x >= 0 and c.x < model.width and c.y >= 0 and c.y < model.height

## 在拖拽中：SINGLE → 流式应用；RECT/LINE → 计算预览集合
func _apply_or_preview(c: Vector2i, _is_first: bool) -> void:
	var is_right := (_draw_button == MOUSE_BUTTON_RIGHT)
	var shape: int = editor.current_shape
	if shape == editor.Shape.SINGLE:
		# 流式：每次进入新格立刻应用
		var cells := [c]
		_apply_now(cells, is_right)
	else:
		_shape_preview_cells = _compute_shape_cells(_draw_start, c, shape)

func _finish_drawing() -> void:
	var is_right := (_draw_button == MOUSE_BUTTON_RIGHT)
	var shape: int = editor.current_shape
	if shape != editor.Shape.SINGLE:
		_apply_now(_shape_preview_cells, is_right)
	_is_drawing = false
	_shape_preview_cells.clear()

## 把一组 cells 提交给 editor。右键强制 ERASER。
func _apply_now(cells: Array, force_eraser: bool) -> void:
	if cells.is_empty():
		return
	var saved_tool: int = editor.current_tool
	if force_eraser:
		editor.current_tool = editor.Tool.ERASER
	editor.apply_tool_action(cells)
	if force_eraser:
		editor.current_tool = saved_tool

# ---------------------------- 形状计算 ----------------------------

static func _compute_shape_cells(a: Vector2i, b: Vector2i, shape: int) -> Array:
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return []
	if shape == 1:  # RECT
		return _rect_cells(a, b)
	elif shape == 2:  # LINE
		return _line_cells(a, b)
	else:
		return [b]

static func _rect_cells(a: Vector2i, b: Vector2i) -> Array:
	var x0 := mini(a.x, b.x); var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y); var y1 := maxi(a.y, b.y)
	var out: Array = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out

static func _line_cells(a: Vector2i, b: Vector2i) -> Array:
	# Bresenham
	var out: Array = []
	var x0 := a.x; var y0 := a.y; var x1 := b.x; var y1 := b.y
	var dx := absi(x1 - x0); var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		out.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1: break
		var e2 := 2 * err
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy
	return out

# ---------------------------- 渲染 ----------------------------

const COLOR_BG := Color(0.1, 0.1, 0.12, 1)
const COLOR_OUTSIDE := Color(0.18, 0.18, 0.22, 1)
const COLOR_FLOOR := Color(0.85, 0.78, 0.55, 1)
const COLOR_FLOOR_ALT := Color(0.78, 0.72, 0.50, 1)
const COLOR_WALL := Color(0.40, 0.30, 0.22, 1)
const COLOR_GOAL_TINT := Color(0.95, 0.85, 0.30, 0.30)
const COLOR_GRID := Color(1, 1, 1, 0.07)
const COLOR_HOVER := Color(1, 1, 1, 0.18)
const COLOR_PREVIEW := Color(0.4, 0.9, 1.0, 0.30)
const COLOR_PLAYER := Color(0.30, 0.60, 0.95)
const COLOR_PLAYER_BORDER := Color(0.10, 0.30, 0.55)

const SWATCH_BY_COLOR := {
	0: Color(0.55, 0.55, 0.55),
	1: Color(0.85, 0.30, 0.30),
	2: Color(0.85, 0.70, 0.30),
	3: Color(0.30, 0.65, 0.85),
	4: Color(0.55, 0.80, 0.40),
	5: Color(0.75, 0.45, 0.85),
}

func _draw() -> void:
	if model == null: return
	var ts := TILE_SIZE
	# Tiles
	for y in model.height:
		for x in model.width:
			var t: int = int(model.tiles[y][x])
			var rect := Rect2(x * ts, y * ts, ts, ts)
			var base: Color = COLOR_OUTSIDE
			match t:
				Cell.Type.OUTSIDE: base = COLOR_OUTSIDE
				Cell.Type.WALL: base = COLOR_WALL
				Cell.Type.FLOOR:
					base = COLOR_FLOOR if (x + y) % 2 == 0 else COLOR_FLOOR_ALT
				Cell.Type.GOAL:
					base = COLOR_FLOOR if (x + y) % 2 == 0 else COLOR_FLOOR_ALT
			draw_rect(rect, base, true)
			if t == Cell.Type.GOAL:
				# 中央 holder 颜色环
				var hc: int = int(model.holder_colors.get(Vector2i(x, y), Cell.DEFAULT_COLOR))
				var ring_col: Color = SWATCH_BY_COLOR.get(hc, Color.WHITE)
				draw_rect(Rect2(x * ts + 8, y * ts + 8, ts - 16, ts - 16), Color(ring_col.r, ring_col.g, ring_col.b, 0.30), true)
				draw_rect(Rect2(x * ts + 8, y * ts + 8, ts - 16, ts - 16), ring_col, false, 3.0)
				if hc == 0:
					draw_string(ThemeDB.fallback_font, Vector2(x * ts + ts/2 - 4, y * ts + ts/2 + 5), "·", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, ring_col)
	# Grid
	for x in range(model.width + 1):
		draw_line(Vector2(x * ts, 0), Vector2(x * ts, model.height * ts), COLOR_GRID, 1.0)
	for y in range(model.height + 1):
		draw_line(Vector2(0, y * ts), Vector2(model.width * ts, y * ts), COLOR_GRID, 1.0)

	# Boxes
	for p in model.boxes.keys():
		var bc: int = int(model.boxes[p])
		var col: Color = SWATCH_BY_COLOR.get(bc, Color.WHITE)
		var r := Rect2(p.x * ts + 8, p.y * ts + 8, ts - 16, ts - 16)
		draw_rect(r, col, true)
		draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
		# 标号
		draw_string(ThemeDB.fallback_font, Vector2(p.x * ts + ts/2 - 6, p.y * ts + ts/2 + 7), str(bc), HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0, 0, 0, 0.9))

	# Player
	if model.player_pos != Vector2i(-1, -1):
		var p: Vector2i = model.player_pos
		var center := Vector2(p.x * ts + ts/2, p.y * ts + ts/2)
		draw_circle(center, ts * 0.32, COLOR_PLAYER)
		draw_arc(center, ts * 0.32, 0, TAU, 24, COLOR_PLAYER_BORDER, 2.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 6), "P", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)

	# Hover & preview
	if _hover_cell != Vector2i(-1, -1):
		draw_rect(Rect2(_hover_cell.x * ts, _hover_cell.y * ts, ts, ts), COLOR_HOVER, true)
	if _is_drawing and not _shape_preview_cells.is_empty():
		for c in _shape_preview_cells:
			draw_rect(Rect2(c.x * ts, c.y * ts, ts, ts), COLOR_PREVIEW, true)

	# Border
	draw_rect(Rect2(0, 0, model.width * ts, model.height * ts), Color(1, 1, 1, 0.4), false, 2.0)
