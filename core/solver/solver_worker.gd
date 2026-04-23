class_name SolverWorker
extends Node
## SolverWorker — 在后台线程跑 SokobanSolver，避免阻塞主线程。
##
## 用法：
##   var worker := SolverWorker.new()
##   add_child(worker)
##   worker.finished.connect(_on_solver_finished)
##   worker.solve(level)               # 异步开始
##   ...
##   worker.cancel()                   # 任意时刻可取消
##
## 信号：
##   started()                          已下发任务
##   progress(nodes: int, bound: int)   每若干节点报告（非线程安全转主线程）
##   finished(result: Dictionary)       完成或取消时触发
##
## 实现：
##   - 用 WorkerThreadPool.add_task() 派发；
##   - 主线程每帧 _process() 中 poll is_task_completed；
##   - cancel() 通过 Mutex 设置 solver._cancel；
##   - 结果通过共享 Dictionary 回传，再以 call_deferred 走信号。

signal started()
signal progress(nodes: int, bound: int)
signal finished(result: Dictionary)

var _solver: SokobanSolver
var _task_id: int = -1
var _running: bool = false
var _result: Dictionary = {}
var _mutex: Mutex
var _last_reported_nodes: int = 0
var _last_bound: int = 0

func _ready() -> void:
	set_process(false)

## 启动求解。可选传入初始 boxes / player（不传则使用 level 起始状态）。
func solve(level: Level, initial_boxes: Array = [], initial_player: Vector2i = Vector2i(-1, -1)) -> void:
	if _running:
		push_warning("SolverWorker already running, ignored.")
		return
	_mutex = Mutex.new()
	_solver = SokobanSolver.new()
	_solver.progress.connect(_on_solver_progress)
	var boxes_in: Array = initial_boxes if not initial_boxes.is_empty() else level.box_starts.duplicate()
	var player_in: Vector2i = initial_player if initial_player != Vector2i(-1, -1) else level.player_start
	_result = {}
	_running = true
	_last_reported_nodes = 0
	_last_bound = 0
	# WorkerThreadPool 接受 Callable
	var task := func() -> void:
		var r: Dictionary = _solver.solve(level, boxes_in, player_in)
		_mutex.lock()
		_result = r
		_mutex.unlock()
	_task_id = WorkerThreadPool.add_task(task, true, "SokobanSolver")
	set_process(true)
	started.emit()

## 取消正在进行的求解。已完成时无效。
func cancel() -> void:
	if not _running or _solver == null:
		return
	_solver.set_cancel(true)

func is_running() -> bool:
	return _running

func _process(_delta: float) -> void:
	# 报告进度（线程内 emit 的 progress 也会被 Godot 队列到主线程，但额外冗余一次确保 UI 更新）
	if _solver != null:
		var n: int = _solver._nodes
		if n - _last_reported_nodes >= 10_000:
			_last_reported_nodes = n
			progress.emit(n, _last_bound)
	# 任务完成检测
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_running = false
		set_process(false)
		_mutex.lock()
		var r: Dictionary = _result.duplicate()
		_mutex.unlock()
		finished.emit(r)

func _on_solver_progress(nodes: int, bound: int) -> void:
	# 此回调可能在 worker 线程触发——只更新简单字段，不直接 emit。
	_last_reported_nodes = nodes
	_last_bound = bound

func _exit_tree() -> void:
	# 退出时若仍在跑，标记取消并等待回收。
	if _running and _solver != null:
		_solver.set_cancel(true)
		if _task_id != -1:
			WorkerThreadPool.wait_for_task_completion(_task_id)
			_task_id = -1
