extends AcceptDialog
## SolverDialog — 启动 SokobanSolver 验证关卡。
##
## - 启动 SolverWorker，显示进度（节点数 / 当前 bound）
## - Cancel 按钮请求中断
## - finished 时把结果通过 solved 信号回传

signal solved(result: Dictionary)

const SolverWorkerScript = preload("res://core/solver/solver_worker.gd")

var _worker: SolverWorker
var _label: Label
var _progress: ProgressBar
var _btn_cancel: Button
var _start_ms: int = 0

func _init() -> void:
	title = TranslationServer.translate("editor.dialog.verify")
	dialog_hide_on_ok = false
	exclusive = false
	min_size = Vector2i(420, 180)
	get_ok_button().visible = false
	var v := VBoxContainer.new()
	add_child(v)
	_label = Label.new(); _label.text = TranslationServer.translate("editor.dialog.solving")
	v.add_child(_label)
	_progress = ProgressBar.new()
	_progress.indeterminate = true
	v.add_child(_progress)
	_btn_cancel = Button.new(); _btn_cancel.text = TranslationServer.translate("common.cancel")
	_btn_cancel.pressed.connect(_on_cancel)
	v.add_child(_btn_cancel)

func start(level: Level) -> void:
	_start_ms = Time.get_ticks_msec()
	_worker = SolverWorkerScript.new()
	add_child(_worker)
	_worker.progress.connect(_on_progress)
	_worker.finished.connect(_on_finished)
	_worker.solve(level)
	popup_centered()

func _on_progress(nodes: int, bound: int) -> void:
	_label.text = TranslationServer.translate("editor.dialog.solving_progress").format([nodes, bound, Time.get_ticks_msec() - _start_ms])

func _on_cancel() -> void:
	if _worker != null:
		_worker.cancel()
	_label.text = TranslationServer.translate("editor.dialog.cancelling")

func _on_finished(result: Dictionary) -> void:
	# 先关闭并立即从树移除自己，避免与后续 _show_info 等弹窗的 exclusive 冲突
	hide()
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()
	solved.emit(result)
