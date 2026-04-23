extends Control
## HUD — Phase 2 完整版。
##
## 包含：
##   - 顶部状态栏（关卡名 / 步数 / 推数 / 时间）
##   - 操作按钮栏（Undo / Redo / Restart / Pause）
##   - PauseDialog（覆盖层）
##   - CompleteDialog（覆盖层，星级动画）
##
## API：
##   update_stats(stats: Dictionary)   ## 由 GameController 每步调用
##   show_win(stats: Dictionary)        ## 胜利时
##   show_pause()                       ## Pause 键
##
## 信号：
##   undo_pressed / redo_pressed / restart_pressed / resume_pressed

signal undo_pressed()
signal redo_pressed()
signal restart_pressed()
signal resume_pressed()

@onready var lbl_name: Label = %LblName
@onready var lbl_moves: Label = %LblMoves
@onready var lbl_pushes: Label = %LblPushes
@onready var lbl_time: Label = %LblTime
@onready var btn_undo: Button = %BtnUndo
@onready var btn_redo: Button = %BtnRedo
@onready var btn_restart: Button = %BtnRestart
@onready var btn_pause: Button = %BtnPause
@onready var lbl_help: Label = %LblHelp

# Win
@onready var win_panel: Control = %WinPanel
@onready var win_dim: ColorRect = %WinDim
@onready var win_card: Panel = %WinCard
@onready var win_title: Label = %WinTitle
@onready var win_stars: Label = %WinStars
@onready var win_stats: Label = %WinStats
@onready var btn_win_retry: Button = %BtnWinRetry
@onready var btn_win_next: Button = %BtnWinNext
@onready var btn_win_menu: Button = %BtnWinMenu

# Pause
@onready var pause_panel: Control = %PausePanel
@onready var pause_title: Label = %PauseTitle
@onready var btn_pause_resume: Button = %BtnPauseResume
@onready var btn_pause_restart: Button = %BtnPauseRestart
@onready var btn_pause_settings: Button = %BtnPauseSettings
@onready var btn_pause_menu: Button = %BtnPauseMenu

const SETTINGS_PANEL_SCENE := preload("res://ui/panels/settings_panel.tscn")

var _last_stats: Dictionary = {}
var _settings_open: bool = false

func _ready() -> void:
	win_panel.hide()
	pause_panel.hide()
	# 顶部按钮
	btn_undo.pressed.connect(func(): undo_pressed.emit())
	btn_redo.pressed.connect(func(): redo_pressed.emit())
	btn_restart.pressed.connect(func(): restart_pressed.emit())
	btn_pause.pressed.connect(_on_pause_pressed)
	# Win 弹窗
	btn_win_retry.pressed.connect(_on_retry)
	btn_win_next.pressed.connect(_on_next)
	btn_win_menu.pressed.connect(_on_menu)
	# Pause 弹窗
	btn_pause_resume.pressed.connect(_on_resume)
	btn_pause_restart.pressed.connect(func():
		_close_pause()
		restart_pressed.emit()
	)
	btn_pause_settings.pressed.connect(_on_pause_settings)
	btn_pause_menu.pressed.connect(_on_menu)

	_refresh_texts()
	EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))
	# 设备切换时刷新键位提示文本
	if InputManager.has_signal("device_changed"):
		InputManager.device_changed.connect(_on_device_changed)

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _on_lang_changed(_e) -> void:
	_refresh_texts()

func _on_device_changed(_dev: int) -> void:
	# 仅刷新与键位相关的 tooltip
	if btn_undo == null: return
	btn_undo.tooltip_text    = InputHint.with_label("hud.undo",    "undo")
	btn_redo.tooltip_text    = InputHint.with_label("hud.redo",    "redo")
	btn_restart.tooltip_text = InputHint.with_label("hud.restart", "restart")
	btn_pause.tooltip_text   = InputHint.with_label("hud.pause",   "pause")

func _refresh_texts() -> void:
	if lbl_help == null: return
	btn_undo.text = tr("hud.undo")
	btn_redo.text = tr("hud.redo")
	btn_restart.text = tr("hud.restart")
	btn_pause.text = tr("hud.pause")
	# 按钮 tooltip 显示当前设备的键位提示（P5-F）
	btn_undo.tooltip_text    = InputHint.with_label("hud.undo",    "undo")
	btn_redo.tooltip_text    = InputHint.with_label("hud.redo",    "redo")
	btn_restart.tooltip_text = InputHint.with_label("hud.restart", "restart")
	btn_pause.tooltip_text   = InputHint.with_label("hud.pause",   "pause")
	lbl_help.text = tr("hud.help")
	pause_title.text = tr("pause.title")
	btn_pause_resume.text = tr("pause.resume")
	btn_pause_restart.text = tr("pause.restart")
	btn_pause_settings.text = tr("pause.settings")
	btn_pause_menu.text = tr("pause.menu")
	win_title.text = tr("complete.title")
	btn_win_retry.text = tr("complete.retry")
	btn_win_next.text = tr("complete.next")
	btn_win_menu.text = tr("complete.menu")
	# 重新刷统计文案
	if not _last_stats.is_empty():
		update_stats(_last_stats)

func update_stats(stats: Dictionary) -> void:
	if lbl_name == null:
		call_deferred("update_stats", stats)
		return
	_last_stats = stats
	lbl_name.text = str(stats.get("level_name", ""))
	lbl_moves.text = tr("hud.moves").format([stats.get("moves", 0)])
	lbl_pushes.text = tr("hud.pushes").format([stats.get("pushes", 0)])
	var ms: int = stats.get("time_ms", 0)
	lbl_time.text = tr("hud.time").format(["%d.%02ds" % [ms / 1000, (ms % 1000) / 10]])
	btn_undo.disabled = not bool(stats.get("can_undo", false))
	btn_redo.disabled = not bool(stats.get("can_redo", false))

func show_win(stats: Dictionary) -> void:
	if win_panel == null:
		call_deferred("show_win", stats)
		return
	# 关闭 Pause 弹窗（如有）
	pause_panel.hide()
	var stars: int = stats.get("stars", 1)
	win_stats.text = tr("complete.stats").format([
		stats.get("moves", 0),
		stats.get("pushes", 0),
		"%.2fs" % (stats.get("time_ms", 0) / 1000.0),
	])
	win_stars.text = ""
	win_panel.show()
	# 星级逐颗弹出动画
	_animate_stars(stars)

func _animate_stars(stars: int) -> void:
	win_stars.scale = Vector2(0.6, 0.6)
	win_stars.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(win_stars, "modulate:a", 1.0, 0.18)
	for i in 3:
		tw.tween_callback(func():
			var filled := i + 1
			var full := mini(filled, stars)
			win_stars.text = "★".repeat(full) + "☆".repeat(3 - full)
		)
		tw.tween_interval(0.18)
	tw.parallel().tween_property(win_stars, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Pause ---

func show_pause() -> void:
	if pause_panel.visible:
		_close_pause()
		return
	if win_panel.visible:
		return
	pause_panel.show()
	get_tree().paused = true

func _close_pause() -> void:
	pause_panel.hide()
	get_tree().paused = false

func _on_pause_pressed() -> void:
	show_pause()

func _on_resume() -> void:
	_close_pause()
	resume_pressed.emit()

func _on_pause_settings() -> void:
	if _settings_open:
		return
	_settings_open = true
	var p := SETTINGS_PANEL_SCENE.instantiate()
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍可操作
	Sfx.attach_ui(p)
	p.tree_exited.connect(func(): _settings_open = false)

# --- Win buttons ---

func _on_retry() -> void:
	get_tree().paused = false
	GameState.goto_game(GameState.current_level_id)

func _on_next() -> void:
	get_tree().paused = false
	var nxt := LevelLibrary.get_next_level_id(GameState.current_level_id)
	if nxt == "":
		GameState.goto_level_select()
	else:
		GameState.goto_game(nxt)

func _on_menu() -> void:
	get_tree().paused = false
	GameState.goto_main_menu()
