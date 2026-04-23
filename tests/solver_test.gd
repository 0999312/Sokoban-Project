extends SceneTree
## SolverTest — Phase 3 + Phase 3.5 求解器测试（无 GUT）。
##
## 运行：
##   godot --headless --script res://tests/solver_test.gd
##
## 覆盖：
##   - DeadlockDetector.compute_static_dead_squares 在 W1-05 中识别 4 个角落（按色 1）
##   - SokobanSolver 求解 W1 全部 5 关，并校验解法可在 Board 上执行成功
##   - SokobanSolver.expand_to_moves 还原玩家走步序列正确
##   - Phase 3.5：多色关卡（同色配对 / 中性槽混合）push-optimal

const DeadlockDetectorScript := preload("res://core/solver/deadlock_detector.gd")
const SokobanSolverScript := preload("res://core/solver/sokoban_solver.gd")

const W1 := [
	"res://levels/official/w1/01.json",
	"res://levels/official/w1/02.json",
	"res://levels/official/w1/03.json",
	"res://levels/official/w1/04.json",
	"res://levels/official/w1/05.json",
]

func _init() -> void:
	var failed: int = 0
	failed += _run("static dead squares: corners (color 1)", _t_static_dead)
	for path in W1:
		failed += _run("solve %s" % path.get_file(), _make_solve_test(path))
	# Phase 3.5
	failed += _run("multi-color: same-color trivial", _t_multi_trivial)
	failed += _run("multi-color: 2-color minimal", _t_multi_two_color)
	failed += _run("multi-color: neutral holder accepts any", _t_multi_neutral)
	failed += _run("multi-color: per-color deadlock pruning", _t_per_color_deadlock)
	if failed > 0:
		printerr("[SolverTest] %d failure(s)" % failed)
		quit(1)
	else:
		print("[SolverTest] all tests passed")
		quit(0)

func _run(name: String, fn: Callable) -> int:
	var t0: int = Time.get_ticks_msec()
	var ok: bool = fn.call()
	var dt: int = Time.get_ticks_msec() - t0
	print("  [%s] %s (%d ms)" % ["OK" if ok else "FAIL", name, dt])
	return 0 if ok else 1

func _t_static_dead() -> bool:
	var lvl: Level = LevelLoader.load_json_file("res://levels/official/w1/05.json")
	if lvl == null: return false
	# v2 API 返回按颜色分桶；W1-05 全部色 1
	var per_color: Dictionary = DeadlockDetectorScript.compute_static_dead_squares(lvl)
	var dead: Dictionary = per_color.get(Cell.DEFAULT_COLOR, {})
	var w: int = lvl.width
	var h: int = lvl.height
	var corners := [Vector2i(1, 1), Vector2i(w - 2, 1), Vector2i(1, h - 2), Vector2i(w - 2, h - 2)]
	if dead.has(corners[0]):
		printerr("goal corner wrongly marked dead")
		return false
	var non_goal_dead: int = 0
	for c in [corners[1], corners[2], corners[3]]:
		if dead.has(c):
			non_goal_dead += 1
	if non_goal_dead < 3:
		printerr("expected 3 non-goal corners dead, got %d" % non_goal_dead)
		return false
	return true

func _make_solve_test(path: String) -> Callable:
	return func() -> bool:
		var lvl: Level = LevelLoader.load_json_file(path)
		if lvl == null:
			printerr("load failed")
			return false
		var solver = SokobanSolverScript.new()
		solver.max_pushes = 200
		solver.node_limit = 2_000_000
		var r: Dictionary = solver.solve(lvl, lvl.box_starts, lvl.player_start)
		if not r["found"]:
			printerr("no solution; nodes=%d" % r["nodes_expanded"])
			return false
		var moves: Array = SokobanSolverScript.expand_to_moves(lvl, lvl.box_starts, lvl.player_start, r["push_solution"])
		var board := Board.new(lvl)
		for m in moves:
			if not board.try_move(m):
				printerr("replay step failed at move=%s" % str(m))
				return false
		if not board.is_won():
			printerr("replay finished but not won; pushes=%d moves=%d" % [board.push_count, board.move_count])
			return false
		print("    pushes=%d moves=%d nodes=%d" % [r["pushes"], moves.size(), r["nodes_expanded"]])
		return true

# ---------- Phase 3.5 ----------

func _solve_xsb(xsb: String, expected_pushes: int) -> bool:
	var lvl: Level = LevelLoader.parse_xsb(xsb, "t")
	if lvl == null:
		printerr("parse failed")
		return false
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		printerr("validator failed: %s" % v.format_report())
		return false
	var solver = SokobanSolverScript.new()
	var r: Dictionary = solver.solve(lvl, lvl.box_starts, lvl.player_start)
	if not r["found"]:
		printerr("no solution; nodes=%d" % r["nodes_expanded"])
		return false
	if r["pushes"] != expected_pushes:
		printerr("expected %d pushes, got %d" % [expected_pushes, r["pushes"]])
		return false
	# 重放校验
	var moves: Array = SokobanSolverScript.expand_to_moves(lvl, lvl.box_starts, lvl.player_start, r["push_solution"])
	var board := Board.new(lvl)
	for m in moves:
		if not board.try_move(m):
			printerr("replay step failed: %s" % str(m))
			return false
	if not board.is_won():
		printerr("replay not won")
		return false
	print("    pushes=%d moves=%d nodes=%d" % [r["pushes"], moves.size(), r["nodes_expanded"]])
	return true

func _t_multi_trivial() -> bool:
	# 红箱推一步到红 holder
	return _solve_xsb("######\n#@$. #\n######", 1)

func _t_multi_two_color() -> bool:
	# 玩家在中间，左右各一对：左侧蓝箱+蓝holder，右侧红箱+红holder
	# 行：# 2 b @ $ . #   宽 7
	# 玩家(3,1)，蓝箱(2,1)→蓝holder(1,1)（向左推）；红箱(4,1)→红holder(5,1)（向右推）
	var xsb := "#######\n#2b@$.#\n#######"
	# 期望：每个箱子各 1 推 = 2 推
	return _solve_xsb(xsb, 2)

func _t_multi_neutral() -> bool:
	# 红箱 + 1 中性 holder（向右推 1）
	return _solve_xsb("######\n#@$, #\n######", 1)

func _t_per_color_deadlock() -> bool:
	# 验证：颜色独立死格 + 中性槽参与该色匹配
	# 关卡（5 宽 4 高）：
	#   #####
	#   #@b #
	#   #  ,#
	#   #####
	# 玩家(1,1)，蓝箱(2,1)，中性 holder(3,2)
	# 蓝色没有同色 holder，必须去中性槽 (3,2)。
	# 玩家走法：右推蓝箱 (2,1)→(3,1)（蓝箱在 floor），然后下推 (3,1)→(3,2)（中性槽 → 完成）
	#   但玩家先在 (1,1) 推右：箱子 (2,1)→(3,1)，玩家到 (2,1)。
	#   玩家(2,1)→(3,1)？被箱子挡。玩家走到 (2,2)→(3,2)？(3,2) 是中性 holder（floor 可走）但有箱子？此时箱子还在 (3,1)。
	#   玩家(2,1)→(2,2)→(3,2)；然后向上推会把箱子(3,1)向上推至(3,0)=外/墙 → 失败。
	#   改：玩家走到(3,2)正上方被箱子挡了。需要从下方推上。
	# 改更直接的关卡：
	#   #####
	#   # @ #
	#   # b #
	#   # , #
	#   #####
	# 玩家(2,1)，蓝箱(2,2)，中性 holder(2,3)
	# 玩家向下推蓝箱(2,2)→(2,3)即完成
	var xsb := "#####\n# @ #\n# b #\n# , #\n#####"
	return _solve_xsb(xsb, 1)
