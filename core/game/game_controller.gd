class_name GameController
extends Node
## GameController — 游戏关卡运行时控制器（Phase 2）。

signal level_loaded(level: Level)
signal level_won(stats: Dictionary)

@export var board_view_path: NodePath
@export var hud_path: NodePath
@export var camera_path: NodePath

var board: Board
var level: Level
var view: BoardView
var hud: Node
var camera: GameCamera

var _start_time_ms: int = 0
var _accum_time_ms: int = 0   ## 暂停前累计时长
var _input_locked: bool = false
var _game_state: Node
var _level_library: Node
var _input_manager: Node
var _save_manager: Node
var _sfx: Node
var _undo_action: String = ""
var _redo_action: String = ""
var _restart_action: String = ""
var _pause_action: String = ""
const MOVE_LOCK_MS := 60

func _autoload(name: String) -> Node:
	return get_node_or_null("/root/%s" % name)

func _ready() -> void:
	_game_state = _autoload("GameState")
	_level_library = _autoload("LevelLibrary")
	_input_manager = _autoload("InputManager")
	_save_manager = _autoload("SaveManager")
	_sfx = _autoload("Sfx")
	if _input_manager != null:
		_undo_action = _input_manager.get("UNDO")
		_redo_action = _input_manager.get("REDO")
		_restart_action = _input_manager.get("RESTART")
		_pause_action = _input_manager.get("PAUSE")
	view = get_node_or_null(board_view_path) as BoardView
	hud = get_node_or_null(hud_path)
	camera = get_node_or_null(camera_path) as GameCamera
	get_viewport().size_changed.connect(_layout_world)
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
	if _game_state == null:
		_game_state = _autoload("GameState")
	if _game_state == null:
		push_error("[GameController] GameState autoload not found")
		return
	if _level_library == null:
		_level_library = _autoload("LevelLibrary")
	if _level_library == null:
		push_error("[GameController] LevelLibrary autoload not found")
		return
	var lvl_id_var: Variant = _game_state.get("current_level_id")
	var lvl_id: String = lvl_id_var if typeof(lvl_id_var) == TYPE_STRING else ""
	if lvl_id == "":
		push_warning("[GameController] no current level id; defaulting to W1-01")
		lvl_id = "official-w1-01"
	var path := String(_level_library.call("get_level_path", lvl_id))
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
	board.moved.connect(_on_board_moved)
	board.undone.connect(_on_board_undone)
	board.redone.connect(_on_board_redone)
	if view != null:
		view.bind(board)
		_layout_world()
		if camera != null:
			camera.bind_board_view(view)
	_start_time_ms = Time.get_ticks_msec()
	_accum_time_ms = 0
	_emit_hud_update()
	level_loaded.emit(level)
	print("[GameController] loaded %s (%dx%d, %d boxes)" % [level.id, level.width, level.height, level.box_count()])

func _layout_world() -> void:
	if view == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var board_size := view.get_pixel_size()
	view.position = Vector2(
		maxf((vp_size.x - board_size.x) * 0.5, 0.0),
		maxf((vp_size.y - board_size.y) * 0.5, 0.0)
	)
	if camera != null:
		camera.snap_to_target()

func _process(_dt: float) -> void:
	if _input_locked or board == null:
		return
	# 暂停或胜利时禁用键盘输入
	if get_tree().paused or board.is_won():
		return
	if _input_manager == null:
		_input_manager = _autoload("InputManager")
	if _input_manager == null:
		return
	var dir: Vector2i = _input_manager.call("get_move_dir")
	if dir != Vector2i.ZERO:
		_try_move(dir)
		return
	if _undo_action == "":
		_undo_action = _input_manager.get("UNDO")
		_redo_action = _input_manager.get("REDO")
		_restart_action = _input_manager.get("RESTART")
		_pause_action = _input_manager.get("PAUSE")
	if _input_manager.call("is_action_just_pressed", _undo_action):
		_on_undo()
	elif _input_manager.call("is_action_just_pressed", _redo_action):
		_on_redo()
	elif _input_manager.call("is_action_just_pressed", _restart_action):
		_on_restart()
	elif _input_manager.call("is_action_just_pressed", _pause_action):
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
	if camera != null:
		camera.snap_to_target()
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
	if _save_manager == null:
		_save_manager = _autoload("SaveManager")
	if _save_manager != null:
		_save_manager.call("record_level_complete", level.id, stars, board.move_count, time_ms)
	print("[GameController] WON %s in %d moves / %d pushes / %d ms (stars=%d)" % [
		level.id, board.move_count, board.push_count, time_ms, stars
	])
	_play_sfx("level_complete")
	level_won.emit(stats)
	if hud != null and hud.has_method("show_win"):
		hud.show_win(stats)

# --- SFX hooks ---

func _on_board_moved(cmd: BoardCommand) -> void:
	if cmd == null:
		return
	if cmd.pushed_box:
		_play_sfx("push")
		if cmd.became_complete():
			_play_sfx("crate_done")
	else:
		_play_sfx("step")

func _on_board_undone(_cmd: BoardCommand) -> void:
	_play_sfx("undo")

func _on_board_redone(cmd: BoardCommand) -> void:
	# Redo 复用 step/push 让玩家清楚知道发生了真实移动；不再触发 crate_done 避免吵
	if cmd != null and cmd.pushed_box:
		_play_sfx("push")
	else:
		_play_sfx("step")

func _play_sfx(name: String) -> void:
	if _sfx == null:
		_sfx = _autoload("Sfx")
	if _sfx != null:
		_sfx.call("play", name)

func _calc_stars(moves: int, optimal: int) -> int:
	if optimal <= 0:
		return 3
	if moves <= optimal:
		return 3
	if moves <= int(ceil(optimal * 1.25)):
		return 2
	return 1
