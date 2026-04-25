extends Control
## Playtest — 在编辑器内嵌入运行关卡。
##
## 简化版 GameController：
##   - 自带 BoardView + Board，监听键盘 move/undo/redo/restart
##   - 顶部一排按钮：Restart / Exit
##   - 胜利后顶部显示 You Won! + 步数推数
##   - ESC / Exit 按钮 → editor.close_playtest()

const BoardViewScript = preload("res://core/rendering/board_view.gd")

var editor: Node                  # EditorScene
var board: Board
var level: Level
var view: BoardView

var board_host: Control
var status_label: Label

func start_level(p_level: Level) -> void:
	level = p_level
	# 必须等节点已加入树后再构建 UI / 初始化 board（_init_board 内有 await get_tree().process_frame）
	if is_inside_tree():
		_build_ui()
		_init_board()
		_disable_editor_ui()
	# 否则等待 _ready 触发 _do_start

func _ready() -> void:
	if level != null and board == null:
		_build_ui()
		_init_board()
	_disable_editor_ui()

func _disable_editor_ui() -> void:
	if editor != null and editor.has_method("set_ui_enabled"):
		editor.set_ui_enabled(false)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 暗背景遮罩
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	add_child(dim)
	# 顶栏
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 12; top.offset_left = 12; top.offset_right = -12
	top.custom_minimum_size = Vector2(0, 36)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var lbl_title := Label.new()
	var lvl_label := level.get_display_name() if level.name != "" else level.id
	lbl_title.text = tr("editor.playtest.title").format([lvl_label])
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lbl_title)
	status_label = Label.new()
	status_label.text = ""
	top.add_child(status_label)
	var btn_restart := Button.new()
	btn_restart.text = tr("hud.restart")
	btn_restart.pressed.connect(_on_restart)
	top.add_child(btn_restart)
	var btn_exit := Button.new()
	btn_exit.text = tr("editor.playtest.exit")
	btn_exit.pressed.connect(_exit)
	top.add_child(btn_exit)
	btn_restart.grab_focus.call_deferred()

	# Board host (中央)
	board_host = Control.new()
	board_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_host.offset_top = 60
	board_host.clip_contents = true
	add_child(board_host)

func _init_board() -> void:
	board = Board.new(level)
	board.won.connect(_on_won)
	view = BoardViewScript.new()
	board_host.add_child(view)
	view.bind(board)
	await get_tree().process_frame
	_snap_camera_to_player()

func _center() -> void:
	if view == null: return
	var sz := board_host.size
	var bs := view.get_pixel_size()
	view.position = (sz - bs) * 0.5

func _snap_camera_to_player() -> void:
	if view == null or board == null: return
	var target := _calc_camera_target()
	view.position = target

func _follow_player() -> void:
	if view == null or board == null: return
	var target := _calc_camera_target()
	view.position = view.position.lerp(target, minf(1.0, 10.0 * get_process_delta_time()))

func _calc_camera_target() -> Vector2:
	var board_size := view.get_pixel_size()
	var host_size := board_host.size
	if board_size.x <= host_size.x and board_size.y <= host_size.y:
		return (host_size - board_size) * 0.5
	var player_grid := board.player_pos
	var player_center := Vector2(
		player_grid.x * BoardViewScript.TILE_SIZE + BoardViewScript.TILE_SIZE * 0.5,
		player_grid.y * BoardViewScript.TILE_SIZE + BoardViewScript.TILE_SIZE * 0.5
	)
	var desired := host_size * 0.5 - player_center
	desired.x = clampf(desired.x, host_size.x - board_size.x, 0.0)
	desired.y = clampf(desired.y, host_size.y - board_size.y, 0.0)
	return desired

func _on_restart() -> void:
	board.restart()
	status_label.text = ""
	_snap_camera_to_player.call_deferred()

func _on_won() -> void:
	status_label.text = tr("editor.playtest.won").format([board.move_count, board.push_count])

func _process(_dt: float) -> void:
	if board == null or board.is_won():
		return
	var dir := InputManager.get_move_dir()
	if dir != Vector2i.ZERO:
		board.try_move(dir)
		_snap_camera_to_player()
		return
	if InputManager.is_action_just_pressed(InputManager.UNDO):
		board.undo()
		_snap_camera_to_player()
	elif InputManager.is_action_just_pressed(InputManager.REDO):
		board.redo()
		_snap_camera_to_player()
	elif InputManager.is_action_just_pressed(InputManager.RESTART):
		_on_restart()
		_snap_camera_to_player()
	else:
		_follow_player()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_exit()
			get_viewport().set_input_as_handled()

func _exit() -> void:
	if editor != null and editor.has_method("set_ui_enabled"):
		editor.set_ui_enabled(true)
	if editor != null and editor.has_method("close_playtest"):
		editor.close_playtest()
