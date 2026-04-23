class_name GameCamera
extends Camera2D

@export var follow_speed: float = 10.0

var _board_view: BoardView

func _ready() -> void:
	make_current()
	position_smoothing_enabled = false

func bind_board_view(board_view: BoardView) -> void:
	_board_view = board_view
	snap_to_target()

func snap_to_target() -> void:
	if _board_view == null:
		return
	global_position = _get_clamped_target_position()

func _process(delta: float) -> void:
	if _board_view == null:
		return
	var target := _get_clamped_target_position()
	global_position = global_position.lerp(target, minf(1.0, follow_speed * delta))

func _get_clamped_target_position() -> Vector2:
	var board_rect := _board_view.get_world_rect()
	if board_rect.size == Vector2.ZERO:
		return global_position

	var target := _board_view.get_player_visual_center()
	var visible_size := get_viewport_rect().size * zoom
	var half_visible := visible_size * 0.5

	var min_x := board_rect.position.x + board_rect.size.x * 0.5
	var max_x := min_x
	if board_rect.size.x > visible_size.x:
		min_x = board_rect.position.x + half_visible.x
		max_x = board_rect.position.x + board_rect.size.x - half_visible.x

	var min_y := board_rect.position.y + board_rect.size.y * 0.5
	var max_y := min_y
	if board_rect.size.y > visible_size.y:
		min_y = board_rect.position.y + half_visible.y
		max_y = board_rect.position.y + board_rect.size.y - half_visible.y

	return Vector2(
		clampf(target.x, min_x, max_x),
		clampf(target.y, min_y, max_y)
	)
