class_name BoardView
extends Node2D
## BoardView — 关卡渲染层。
##
## 地形：TileMapLayer（res://resources/tilesets/sokoban_tileset.tres，仅绘制，无物理层）
##   - 6 个 tile（atlas source 0）：3 种墙 + 3 种地面，按关卡 wall_theme/floor_theme 选用
##   - 每个关卡的墙、地各为同一种（不混用）
##
## 实体：箱子 / 玩家 / GOAL 上的 holder 仍用 Sprite2D（带平滑 Tween 动画）。
##
## 坐标：position = grid_pos * TILE_SIZE，原点为 BoardView 自身原点。

const TILE_SIZE := 64

const TILESET := preload("res://resources/tilesets/sokoban_tileset.tres")
const ATLAS_SOURCE_ID := 0

## 主题 → atlas 坐标
const WALL_ATLAS_BY_THEME: Dictionary = {
	"brick": Vector2i(6, 6),
	"stone": Vector2i(8, 6),
	"wood":  Vector2i(9, 6),
}
const FLOOR_ATLAS_BY_THEME: Dictionary = {
	"grass": Vector2i(10, 6),
	"stone": Vector2i(11, 6),
	"dirt":  Vector2i(12, 6),
}
const DEFAULT_WALL_ATLAS := Vector2i(6, 6)   # brick
const DEFAULT_FLOOR_ATLAS := Vector2i(10, 6) # grass

const PLAYER_TEX := preload("res://assets/sokoban_player.png")
const CRATE_COMPLETE_SHADER := preload("res://resources/shaders/crate_complete.gdshader")

## 5 色 crate / holder 贴图。color_id 1..5。
## v1.0 关卡默认所有箱子 color_id = 1；v1.1 彩色配对会读取 metadata.color_id。
const CRATE_TEXTURES := {
	1: preload("res://assets/crate/crate_1.png"),
	2: preload("res://assets/crate/crate_2.png"),
	3: preload("res://assets/crate/crate_3.png"),
	4: preload("res://assets/crate/crate_4.png"),
	5: preload("res://assets/crate/crate_5.png"),
}
const HOLDER_TEXTURES := {
	1: preload("res://assets/crate/crate_holder_1.png"),
	2: preload("res://assets/crate/crate_holder_2.png"),
	3: preload("res://assets/crate/crate_holder_3.png"),
	4: preload("res://assets/crate/crate_holder_4.png"),
	5: preload("res://assets/crate/crate_holder_5.png"),
}

## 中性槽（color_id = 0）：使用 holder_1 作为底图 + 灰度 modulate，便于一眼区分。
const NEUTRAL_HOLDER_TEXTURE: Texture2D = preload("res://assets/crate/crate_holder_1.png")
const NEUTRAL_HOLDER_MODULATE := Color(0.7, 0.7, 0.7, 1.0)

const COMPLETE_TWEEN_SEC := 0.18

# 玩家朝向 → sokoban_player.png 行号
# 行序（用户指定）：0=Up, 1=Down, 2=Left, 3=Right
const FACING_UP := 0
const FACING_DOWN := 1
const FACING_LEFT := 2
const FACING_RIGHT := 3
# 每行 3 帧（0/1/2），步行循环为 0→1→2→1
const WALK_FRAMES := [0, 1, 2, 1]

var _board: Board
var _tile_layer: TileMapLayer        # 地形：墙 + 地面，带物理层
var _terrain_overlay: Node2D         # GOAL 上的 holder Sprite2D 叠层
var _entity_layer: Node2D
var _player_sprite: Sprite2D
var _player_facing: int = FACING_DOWN
var _player_step_idx: int = 0
var _box_sprites: Dictionary = {}   ## key: Vector2i (current pos) -> Sprite2D

func _ready() -> void:
	_ensure_layers()
	_apply_high_contrast()
	# 监听 settings 变化（高对比度切换实时生效）
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_signal("settings_changed"):
		sm.settings_changed.connect(_on_settings_changed)

func _ensure_layers() -> void:
	if _tile_layer != null:
		return
	_tile_layer = TileMapLayer.new()
	_tile_layer.name = "Terrain"
	_tile_layer.tile_set = TILESET
	_tile_layer.z_index = 0
	add_child(_tile_layer)

	_terrain_overlay = Node2D.new()
	_terrain_overlay.name = "TerrainOverlay"
	_terrain_overlay.z_index = 1
	add_child(_terrain_overlay)

	_entity_layer = Node2D.new()
	_entity_layer.name = "Entities"
	_entity_layer.z_index = 10
	add_child(_entity_layer)

func bind(board: Board) -> void:
	_ensure_layers()
	_board = board
	_rebuild()
	_board.moved.connect(_on_board_moved)
	_board.undone.connect(_on_board_changed)
	_board.redone.connect(_on_board_changed)
	_board.reset_done.connect(_rebuild)

func _rebuild() -> void:
	# 清空
	_tile_layer.clear()
	for c in _terrain_overlay.get_children():
		c.queue_free()
	for c in _entity_layer.get_children():
		c.queue_free()
	_box_sprites.clear()
	_player_sprite = null
	if _board == null:
		return

	# 地形：TileMapLayer
	# 网格对齐：tile (x,y) 占据世界 [(x*64, y*64), (x*64+64, y*64+64))，
	# 与 Sprite2D（centered=false, position=(x*64, y*64)) 一致。
	var lvl := _board.level
	var wall_atlas: Vector2i = WALL_ATLAS_BY_THEME.get(lvl.wall_theme, DEFAULT_WALL_ATLAS)
	var floor_atlas: Vector2i = FLOOR_ATLAS_BY_THEME.get(lvl.floor_theme, DEFAULT_FLOOR_ATLAS)
	for y in lvl.height:
		for x in lvl.width:
			var t := lvl.get_tile(x, y)
			var coord := Vector2i(x, y)
			match t:
				Cell.Type.OUTSIDE:
					pass  # 留空
				Cell.Type.WALL:
					_tile_layer.set_cell(coord, ATLAS_SOURCE_ID, wall_atlas)
				Cell.Type.FLOOR, Cell.Type.GOAL:
					_tile_layer.set_cell(coord, ATLAS_SOURCE_ID, floor_atlas)
			# GOAL 上的 holder 贴图叠层（按颜色 + 中性槽特殊调色）
			if t == Cell.Type.GOAL:
				var holder := Sprite2D.new()
				var hc: int = _board.holder_color(coord)
				if hc == Cell.NEUTRAL_COLOR:
					holder.texture = NEUTRAL_HOLDER_TEXTURE
					holder.modulate = NEUTRAL_HOLDER_MODULATE
				else:
					holder.texture = _get_holder_texture(hc)
				holder.centered = false
				holder.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				_terrain_overlay.add_child(holder)

	# 箱子
	for b in _board.boxes.keys():
		_spawn_box(b)
	# 玩家
	_player_sprite = _make_player_sprite()
	_player_sprite.position = _grid_to_world(_board.player_pos)
	_entity_layer.add_child(_player_sprite)

func _spawn_box(p: Vector2i) -> void:
	var s := Sprite2D.new()
	var color_id: int = _get_box_color_at(p)
	s.texture = _get_crate_texture(color_id)
	s.centered = false
	s.position = _grid_to_world(p)
	# 应用归位着色器：v2 用 Board 的 is_box_complete_at（含颜色匹配判定）
	var mat := ShaderMaterial.new()
	mat.shader = CRATE_COMPLETE_SHADER
	var complete: bool = _board.is_box_complete_at(p)
	mat.set_shader_parameter("complete", 1.0 if complete else 0.0)
	s.material = mat
	_entity_layer.add_child(s)
	_box_sprites[p] = s

## 从 Board 读取该位置箱子的颜色（v2）；不在则回落 DEFAULT_COLOR。
func _get_box_color_at(p: Vector2i) -> int:
	if _board != null and _board.boxes.has(p):
		return int(_board.boxes[p])
	return Cell.DEFAULT_COLOR

# 兼容旧调用：v1 时返回固定 1，v2 委托 _get_box_color_at。
func _get_color_id_at(pos: Vector2i) -> int:
	return _get_box_color_at(pos)

func _get_crate_texture(color_id: int) -> Texture2D:
	if CRATE_TEXTURES.has(color_id):
		return CRATE_TEXTURES[color_id]
	return CRATE_TEXTURES[1]

func _get_holder_texture(color_id: int) -> Texture2D:
	if HOLDER_TEXTURES.has(color_id):
		return HOLDER_TEXTURES[color_id]
	return HOLDER_TEXTURES[1]

func _make_player_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = PLAYER_TEX
	s.centered = false
	# 玩家 sheet 192x256 = 3 列 × 4 行；初始朝下、第 0 帧
	s.region_enabled = true
	_player_facing = FACING_DOWN
	_player_step_idx = 0
	s.region_rect = _frame_rect(_player_facing, WALK_FRAMES[_player_step_idx])
	return s

static func _frame_rect(row: int, col: int) -> Rect2:
	return Rect2(col * 64, row * 64, 64, 64)

func _grid_to_world(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE_SIZE, p.y * TILE_SIZE)

func _on_board_moved(cmd: BoardCommand) -> void:
	# 推动的箱子先动
	if cmd.pushed_box:
		var box: Sprite2D = _box_sprites.get(cmd.box_from)
		if box != null:
			_box_sprites.erase(cmd.box_from)
			_box_sprites[cmd.box_to] = box
			TweenMover.move(box, _grid_to_world(cmd.box_to))
			# 更新着色器 complete 参数（v2：考虑颜色匹配，含中性槽）
			var complete: bool = _board.is_box_complete_at(cmd.box_to)
			_tween_complete(box, 1.0 if complete else 0.0)
			# 归位特效：仅在本次推动使箱子从未完成 → 完成
			if cmd.became_complete() and A11y.particles_enabled():
				_emit_complete_burst(cmd.box_to, _get_box_color_at(cmd.box_to))
	# 玩家：朝向 + 行走帧 + 走步抖动
	_update_player_facing(cmd.direction)
	_advance_walk_frame()
	TweenMover.move_with_shake(_player_sprite, _grid_to_world(cmd.player_to))

func _tween_complete(box: Sprite2D, target: float) -> void:
	var mat := box.material as ShaderMaterial
	if mat == null:
		return
	var from: float = float(mat.get_shader_parameter("complete"))
	var t := box.create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(
		func(v: float): mat.set_shader_parameter("complete", v),
		from,
		target,
		COMPLETE_TWEEN_SEC
	)

func _on_board_changed(_cmd: BoardCommand) -> void:
	# Undo / Redo：重建实体位置，简单可靠
	# （Phase 1 不要求精细动画的反向播放）
	_sync_from_board()

func _sync_from_board() -> void:
	# 刷新玩家
	if _player_sprite != null:
		_player_sprite.position = _grid_to_world(_board.player_pos)
	# 刷新箱子集合
	for s in _box_sprites.values():
		s.queue_free()
	_box_sprites.clear()
	for b in _board.boxes.keys():
		_spawn_box(b)

# 切玩家朝向（基于 sokoban_player.png 192x256 = 3列x4行）
# 行序（用户指定）：0=Up, 1=Down, 2=Left, 3=Right
func _update_player_facing(dir: Vector2i) -> void:
	if _player_sprite == null:
		return
	if dir == Vector2i(0, -1): _player_facing = FACING_UP
	elif dir == Vector2i(0, 1): _player_facing = FACING_DOWN
	elif dir == Vector2i(-1, 0): _player_facing = FACING_LEFT
	elif dir == Vector2i(1, 0): _player_facing = FACING_RIGHT
	_player_sprite.region_rect = _frame_rect(_player_facing, WALK_FRAMES[_player_step_idx])

func _advance_walk_frame() -> void:
	if _player_sprite == null:
		return
	_player_step_idx = (_player_step_idx + 1) % WALK_FRAMES.size()
	_player_sprite.region_rect = _frame_rect(_player_facing, WALK_FRAMES[_player_step_idx])

## 计算棋盘像素尺寸，便于父节点居中。
func get_pixel_size() -> Vector2:
	if _board == null:
		return Vector2.ZERO
	return Vector2(_board.level.width * TILE_SIZE, _board.level.height * TILE_SIZE)

func get_world_rect() -> Rect2:
	return Rect2(global_position, get_pixel_size())

func get_player_visual_center() -> Vector2:
	if _player_sprite != null:
		return to_global(_player_sprite.position + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5))
	if _board != null:
		return to_global(_grid_to_world(_board.player_pos) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5))
	return global_position

# --- Phase 5 P5-C: accessibility ---

func _on_settings_changed(key: String, _value) -> void:
	if key == "high_contrast":
		_apply_high_contrast()

func _apply_high_contrast() -> void:
	# 最简实现：开启时整体提亮 + 微饱和，让墙/箱/地板对比更强
	if A11y.is_high_contrast():
		modulate = Color(1.15, 1.15, 1.15, 1.0)
	else:
		modulate = Color.WHITE

# --- Phase 5 P5-C: 归位粒子特效 ---

## 各 color_id 的粒子色相
const _COMPLETE_BURST_COLORS := {
	0: Color(1.0, 1.0, 1.0),      # 中性槽 → 白
	1: Color(1.0, 0.85, 0.4),     # crate_1 暖黄
	2: Color(0.55, 0.85, 1.0),    # crate_2 蓝
	3: Color(0.7, 1.0, 0.55),     # crate_3 绿
	4: Color(1.0, 0.55, 0.55),    # crate_4 红
	5: Color(0.85, 0.6, 1.0),     # crate_5 紫
}

## 在指定格子中心一次性发射 8-10 个上升小颗粒，0.6s 后自动 free。
func _emit_complete_burst(grid_pos: Vector2i, color_id: int) -> void:
	var p := GPUParticles2D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.6
	p.explosiveness = 0.95   # 一次性炸开
	p.position = _grid_to_world(grid_pos) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	p.z_index = 50

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.gravity = Vector3(0, 200.0, 0)   # 微重力使粒子先升后落
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 160.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	# 粒子颜色随时间淡出
	var tint: Color = _COMPLETE_BURST_COLORS.get(color_id, Color.WHITE)
	mat.color = tint
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(tint.r, tint.g, tint.b, 1.0))
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 1.0))
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = ramp
	mat.color_ramp = grad_tex
	p.process_material = mat

	add_child(p)
	p.emitting = true
	# 自销毁
	var t := get_tree().create_timer(p.lifetime + 0.15)
	t.timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
