class_name GameController
extends Node
## GameController — 游戏关卡运行时控制器（Phase 2）。

signal level_loaded(level: Level)
signal level_won(stats: Dictionary)

@export var board_view_path: NodePath
@export var hud_path: NodePath

var board: Board
var level: Level
var view: BoardView
var hud: Node

var _start_time_ms: int = 0
var _accum_time_ms: int = 0   ## 暂停前累计时长
var _input_locked: bool = false
const MOVE_LOCK_MS := 60

func _ready() -> void:
	view = get_node_or_null(board_view_path) as BoardView
	hud = get_node_or_null(hud_path)
	await get_tree().process_frame
	_load_current_level()
	_connect_hud()

func _connect_hud() -> void:
	if hud == null:
		return
	if hud.has_signal("undo_pressed"):
		hud.undo_pressed.connect(_on_undo)
	if hud.has_signal("redo_pressed"):
		hud.redo_pressed.connect(_on_redo)
	if hud.has_signal("restart_pressed"):
		hud.restart_pressed.connect(_on_restart)

func _load_current_level() -> void:
	var lvl_id := GameState.current_level_id
	if lvl_id == "":
		push_warning("[GameController] no current level id; defaulting to W1-01")
		lvl_id = "official-w1-01"
	var path := LevelLibrary.get_level_path(lvl_id)
	if path == "":
		push_error("[GameController] level not found in library: %s" % lvl_id)
		return
	level = LevelLoader.load_json_file(path)
	if level == null:
		push_error("[GameController] failed to load level: %s" % path)
		return
	var v := LevelValidator.validate(level)
	if not v.ok:
		push_error("[GameController] invalid level:\n%s" % v.format_report())
		return
	board = Board.new(level)
	board.won.connect(_on_won)
	if view != null:
		view.bind(board)
		_center_view()
	_start_time_ms = Time.get_ticks_msec()
	_accum_time_ms = 0
	_emit_hud_update()
	level_loaded.emit(level)
	print("[GameController] loaded %s (%dx%d, %d boxes)" % [level.id, level.width, level.height, level.box_count()])

func _center_view() -> void:
	if view == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var board_size := view.get_pixel_size()
	view.position = (vp_size - board_size) * 0.5

func _process(_dt: float) -> void:
	if _input_locked or board == null:
		return
	# 暂停或胜利时禁用键盘输入
	if get_tree().paused or board.is_won():
		return
	var dir := InputManager.get_move_dir()
	if dir != Vector2i.ZERO:
		_try_move(dir)
		return
	if Input.is_action_just_pressed(InputManager.UNDO):
		_on_undo()
	elif Input.is_action_just_pressed(InputManager.REDO):
		_on_redo()
	elif Input.is_action_just_pressed(InputManager.RESTART):
		_on_restart()
	elif Input.is_action_just_pressed(InputManager.PAUSE):
		if hud != null and hud.has_method("show_pause"):
			hud.show_pause()

func _try_move(dir: Vector2i) -> void:
	var ok := board.try_move(dir)
	if ok:
		_input_locked = true
		_emit_hud_update()
		await get_tree().create_timer(MOVE_LOCK_MS / 1000.0).timeout
		_input_locked = false

func _on_undo() -> void:
	if board == null: return
	board.undo()
	_emit_hud_update()

func _on_redo() -> void:
	if board == null: return
	board.redo()
	_emit_hud_update()

func _on_restart() -> void:
	if board == null: return
	board.restart()
	_start_time_ms = Time.get_ticks_msec()
	_accum_time_ms = 0
	# 恢复世界可见（若由 win_panel 隐藏）
	var world := get_node_or_null("../World")
	if world != null:
		world.visible = true
	_emit_hud_update()

func _emit_hud_update() -> void:
	if hud == null:
		return
	if hud.has_method("update_stats"):
		var lvl_name := level.get_display_name()
		hud.update_stats({
			"level_name": lvl_name,
			"moves": board.move_count,
			"pushes": board.push_count,
			"time_ms": Time.get_ticks_msec() - _start_time_ms,
			"can_undo": board.undo_stack.can_undo(),
			"can_redo": board.undo_stack.can_redo(),
		})

func _on_won() -> void:
	var time_ms := Time.get_ticks_msec() - _start_time_ms
	var optimal_raw: Variant = level.metadata.get("optimal_steps", 0)
	var optimal: int = int(optimal_raw) if optimal_raw != null else 0
	var stars: int = _calc_stars(board.move_count, optimal)
	var stats = {
		"level_id": level.id,
		"moves": board.move_count,
		"pushes": board.push_count,
		"time_ms": time_ms,
		"stars": stars,
	}
	SaveManager.record_level_complete(level.id, stars, board.move_count, time_ms)
	print("[GameController] WON %s in %d moves / %d pushes / %d ms (stars=%d)" % [
		level.id, board.move_count, board.push_count, time_ms, stars
	])
	level_won.emit(stats)
	if hud != null and hud.has_method("show_win"):
		hud.show_win(stats)

func _calc_stars(moves: int, optimal: int) -> int:
	if optimal <= 0:
		return 1
	if moves <= optimal:
		return 3
	if moves <= int(ceil(optimal * 1.25)):
		return 2
	return 1
