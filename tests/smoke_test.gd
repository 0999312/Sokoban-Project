extends SceneTree
## SmokeTest — Phase 1 + Phase 3.5 自检脚本（无 GUT 依赖）。
##
## 运行方式（若 godot 在 PATH）：
##   godot --headless --script res://tests/smoke_test.gd
##
## 覆盖：
##   - LevelLoader JSON 加载 + XSB 互转（含多色字符）
##   - LevelValidator 通过（含颜色配对约束）
##   - Board 基本移动 / 推箱 / 撤销 / 胜利
##   - 多色配对：同色匹配胜利、异色不胜利、中性槽接受任意色
##
## 任意失败 -> 退出码 1。

const W1_01 := "res://levels/official/w1/01.json"
const W1_12 := "res://levels/official/w1/12.json"
const GameControllerScript := preload("res://core/game/game_controller.gd")

func _init() -> void:
	var failed := 0
	failed += _run("load + validate W1-01", _t_load_validate)
	failed += _run("board push to win", _t_board_win)
	failed += _run("undo restores state", _t_undo)
	failed += _run("xsb roundtrip", _t_xsb_roundtrip)
	failed += _run("stars without optimal defaults to 3", _t_stars_without_optimal)
	failed += _run("W1-12 is solvable", _t_w1_12_solvable)
	# Phase 3.5
	failed += _run("xsb short row pads outside", _t_xsb_short_row_outside)
	failed += _run("xsb multi-color roundtrip", _t_xsb_multi_color_roundtrip)
	failed += _run("multi-color: same-color wins", _t_multi_same_color_win)
	failed += _run("multi-color: mismatch does not win", _t_multi_mismatch_no_win)
	failed += _run("multi-color: neutral holder accepts any", _t_neutral_holder)
	failed += _run("validator: color count enforced", _t_validator_color_count)
	failed += _run("BoardCommand carries color info", _t_command_color_info)
	# Phase 5 P5-A — audio bus sanity
	failed += _run("audio buses: Master/Music/SFX/UI exist", _t_audio_buses)
	failed += _run("SettingsApplier.apply_volume tolerates missing bus", _t_applier_safe)
	if failed > 0:
		printerr("[SmokeTest] %d test(s) failed" % failed)
		quit(1)
	else:
		print("[SmokeTest] all tests passed")
		quit(0)

func _run(name: String, fn: Callable) -> int:
	var ok: bool = fn.call()
	print("  [%s] %s" % ["OK" if ok else "FAIL", name])
	return 0 if ok else 1

func _t_load_validate() -> bool:
	var lvl: Level = LevelLoader.load_json_file(W1_01)
	if lvl == null:
		return false
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		printerr(v.format_report())
		return false
	# v1 关卡兜底：所有箱子色 = 1，所有 holder 色 = 1
	for c in lvl.box_colors:
		if int(c) != Cell.DEFAULT_COLOR: return false
	for c in lvl.goal_colors:
		if int(c) != Cell.DEFAULT_COLOR: return false
	return lvl.box_count() == lvl.goal_count() and lvl.box_count() > 0

func _t_board_win() -> bool:
	var lvl: Level = LevelLoader.load_json_file(W1_01)
	if lvl == null: return false
	var board := Board.new(lvl)
	var won_signal_fired := [false]
	board.won.connect(func(): won_signal_fired[0] = true)
	var ok := board.try_move(Vector2i(1, 0))
	if not ok: return false
	if not board.is_won(): return false
	if not won_signal_fired[0]: return false
	if board.move_count != 1 or board.push_count != 1: return false
	return true

func _t_undo() -> bool:
	var lvl: Level = LevelLoader.load_json_file(W1_01)
	if lvl == null: return false
	var board := Board.new(lvl)
	var p0 := board.player_pos
	board.try_move(Vector2i(1, 0))
	if board.player_pos == p0: return false
	board.undo()
	if board.player_pos != p0: return false
	if board.move_count != 0 or board.push_count != 0: return false
	return true

func _t_xsb_roundtrip() -> bool:
	var lvl: Level = LevelLoader.load_json_file(W1_01)
	if lvl == null: return false
	var xsb: String = LevelLoader.to_xsb(lvl)
	var lvl2: Level = LevelLoader.parse_xsb(xsb, lvl.id)
	if lvl2 == null: return false
	if lvl2.width != lvl.width or lvl2.height != lvl.height: return false
	if lvl2.player_start != lvl.player_start: return false
	if lvl2.box_count() != lvl.box_count(): return false
	if lvl2.goal_count() != lvl.goal_count(): return false
	return true

func _t_stars_without_optimal() -> bool:
	var gc = GameControllerScript.new()
	return gc._calc_stars(999, 0) == 3

func _t_w1_12_solvable() -> bool:
	var lvl: Level = LevelLoader.load_json_file(W1_12)
	if lvl == null:
		return false
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		printerr(v.format_report())
		return false
	var board := Board.new(lvl)
	var moves := [
		Vector2i(0, 1),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(1, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(0, -1),
	]
	for move in moves:
		if not board.try_move(move):
			printerr("W1-12 replay step failed: %s" % str(move))
			return false
	if not board.is_won():
		printerr("W1-12 replay finished but not won")
		return false
	return board.push_count == 3

func _t_xsb_short_row_outside() -> bool:
	var lvl: Level = LevelLoader.parse_xsb("#####\n#@  #\n###", "short-row")
	if lvl == null:
		return false
	if lvl.width != 5 or lvl.height != 3:
		return false
	# 第 3 行缺失的两格应视为 OUTSIDE，而不是可走地板。
	if lvl.get_tile(3, 2) != Cell.Type.OUTSIDE:
		printerr("expected short-row padding at (3,2) to be OUTSIDE")
		return false
	if lvl.get_tile(4, 2) != Cell.Type.OUTSIDE:
		printerr("expected short-row padding at (4,2) to be OUTSIDE")
		return false
	var board := Board.new(lvl)
	board.player_pos = Vector2i(3, 1)
	if board.try_move(Vector2i(0, 1)):
		printerr("player should not move into short-row OUTSIDE padding")
		return false
	return true

# ---------- Phase 3.5 ----------

# 直接构造一个含 2 色 + 中性槽的关卡：
#   ########
#   #@$.b2,#
#   ########
#   位置：玩家(1,1)  红箱(2,1)在红holder(3,1)旁；蓝箱(4,1)需推到蓝holder(5,1)；中性槽在(6,1)
# 由于有中性槽但只有 2 个箱子 / 3 个 holder（红/蓝/中性）→ 数量不等。改：
#   ########
#   #@$.b2 #
#   ########
# 含 1 红箱+1 红 holder, 1 蓝箱+1 蓝 holder。
const _XSB_MULTI := \
	"########\n" + \
	"#@$.b2 #\n" + \
	"########"

func _t_xsb_multi_color_roundtrip() -> bool:
	var lvl: Level = LevelLoader.parse_xsb(_XSB_MULTI, "test-multi")
	if lvl == null: return false
	# 期望：2 箱 2 holder
	if lvl.box_count() != 2 or lvl.goal_count() != 2: return false
	# 颜色：箱(2,1)=1，箱(4,1)=2；holder(3,1)=1, holder(5,1)=2
	var box_color_at: Dictionary = {}
	for i in lvl.box_starts.size():
		box_color_at[lvl.box_starts[i]] = int(lvl.box_colors[i])
	var goal_color_at: Dictionary = {}
	for i in lvl.goal_positions.size():
		goal_color_at[lvl.goal_positions[i]] = int(lvl.goal_colors[i])
	if int(box_color_at.get(Vector2i(2, 1), -1)) != 1: return false
	if int(box_color_at.get(Vector2i(4, 1), -1)) != 2: return false
	if int(goal_color_at.get(Vector2i(3, 1), -1)) != 1: return false
	if int(goal_color_at.get(Vector2i(5, 1), -1)) != 2: return false
	# 往返
	var xsb2 := LevelLoader.to_xsb(lvl)
	var lvl2: Level = LevelLoader.parse_xsb(xsb2, "test-multi-rt")
	if lvl2 == null: return false
	if lvl2.box_count() != 2 or lvl2.goal_count() != 2: return false
	# 颜色应保持
	for i in lvl.box_starts.size():
		var p: Vector2i = lvl.box_starts[i]
		var found_color := -1
		for j in lvl2.box_starts.size():
			if lvl2.box_starts[j] == p:
				found_color = int(lvl2.box_colors[j])
				break
		if found_color != int(lvl.box_colors[i]):
			printerr("box color mismatch at %s: was %d, got %d" % [p, int(lvl.box_colors[i]), found_color])
			return false
	for i in lvl.goal_positions.size():
		var p: Vector2i = lvl.goal_positions[i]
		var found_color := -1
		for j in lvl2.goal_positions.size():
			if lvl2.goal_positions[j] == p:
				found_color = int(lvl2.goal_colors[j])
				break
		if found_color != int(lvl.goal_colors[i]):
			printerr("goal color mismatch at %s: was %d, got %d" % [p, int(lvl.goal_colors[i]), found_color])
			return false
	return true

func _t_multi_same_color_win() -> bool:
	# 玩家(1,1)；红箱(2,1)→红 holder(3,1)；蓝箱(4,1)→蓝 holder(5,1)
	# 玩家先右推红箱归位（蓝箱挡路？没有，红箱 (2,1) 推到 (3,1)，玩家走到 (2,1)）
	# 接着继续右走，会推蓝箱(4,1)→(5,1) 归位 → 胜利
	var lvl := LevelLoader.parse_xsb(_XSB_MULTI, "t1")
	var board := Board.new(lvl)
	# 步 1: 推红箱
	if not board.try_move(Vector2i(1, 0)): return false
	if board.is_won(): return false  # 此时蓝箱还没归位
	# 步 2: 玩家右走（无推动，只是行走到 (2,1)）—— 但 (3,1) 有红箱，所以是推红箱再推一格吗？
	# 推完后红箱在 (3,1)，玩家在 (2,1)。再向右：玩家(2,1)→(3,1)？ (3,1) 是红箱，再推到 (4,1)，但 (4,1) 是蓝箱 → 阻挡，推不动。
	# 因此红箱归位后不能再向右推。重新设计走法：
	# 不要走那一步——直接验证"两次推动各自胜利"：reset 后只推蓝箱，看是否单纯推蓝箱不会胜利。
	board.restart()
	# 推红箱归位
	board.try_move(Vector2i(1, 0))
	# 此时红箱归位但蓝箱未归位 → 未胜利
	if board.is_won():
		printerr("won prematurely after red only")
		return false
	# 已经没办法只用方向键推蓝箱了（红箱挡在 (3,1)）。
	# 改为构造另一关卡：箱子和 holder 同列前后排布更易测试。用 JSON 直接构造。
	return _multi_color_two_box_test()

func _multi_color_two_box_test() -> bool:
	# 9 宽 5 高：玩家两侧各一对 (color, holder)
	# 行 2: # @ $ . b 2 # # #
	#       0 1 2 3 4 5 6 7 8
	# 玩家(1,2)，红箱(2,2)→红 holder(3,2)，蓝箱(4,2)→蓝 holder(5,2)
	# 但红箱推到 (3,2) 后挡住玩家继续右走推蓝箱，所以分两关分别测试归位。
	# 改为：玩家在中间，两边各一对相向。
	# 行 2: # b 2 . $ @ . $ . #  这种太复杂；直接每个关卡只测 1 箱 1 holder（颜色对/错）。
	# 以下 3 个微关卡足以：
	#   A) 红箱→红 holder：胜利
	#   A2) 蓝箱→蓝 holder：胜利
	#   B) 红箱→蓝 holder：不胜利
	#   C) 红箱→中性 holder：胜利
	# A 和 A2 在 _t_multi_same_color_win 内一并验证；B/C 在其它测试。
	var xsb_a := "######\n#@b2 #\n######"   # 蓝箱(2,1)→蓝 holder(3,1)
	var lvl_a := LevelLoader.parse_xsb(xsb_a, "ta")
	var b_a := Board.new(lvl_a)
	if not b_a.try_move(Vector2i(1, 0)): return false
	if not b_a.is_won():
		printerr("blue same color failed to win")
		return false
	var xsb_red := "######\n#@$. #\n######"
	var lvl_r := Board.new(LevelLoader.parse_xsb(xsb_red, "tr"))
	if not lvl_r.try_move(Vector2i(1, 0)): return false
	if not lvl_r.is_won():
		printerr("red same color failed to win")
		return false
	return true

func _t_multi_mismatch_no_win() -> bool:
	# 红箱($) 推入蓝 holder(2)：不应胜利
	var xsb := "######\n#@$2 #\n######"
	var lvl := LevelLoader.parse_xsb(xsb, "tm")
	if lvl == null: return false
	var v := LevelValidator.validate(lvl)
	# 此处 1 红箱 + 0 红 holder + 0 中性 holder + 1 蓝 holder → validator 报错（红箱无可去处）
	if v.ok:
		printerr("validator should reject mismatched single-pair level")
		return false
	# 直接测 Board 行为：构造跳过 validator 的等效场景——把 holder 也是蓝色，再放一个蓝色中性 holder
	# 更简单：手工构造 Board 并 try_move，绕过 validator
	var board := Board.new(lvl)
	board.try_move(Vector2i(1, 0))
	# 推动后红箱在 (2,1)（蓝 holder 上）；颜色不匹配，不应胜利
	if board.is_won():
		printerr("should not win when colors mismatch")
		return false
	return true

func _t_neutral_holder() -> bool:
	# 红箱($) 推入中性 holder(,)：应胜利
	var xsb := "######\n#@$, #\n######"
	var lvl := LevelLoader.parse_xsb(xsb, "tn")
	if lvl == null: return false
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		printerr("neutral level should validate: %s" % v.format_report())
		return false
	var board := Board.new(lvl)
	if not board.try_move(Vector2i(1, 0)): return false
	if not board.is_won():
		printerr("neutral holder should accept any color")
		return false
	return true

func _t_validator_color_count() -> bool:
	# 1 红箱 + 1 蓝 holder + 0 中性 → validator 报错
	var xsb := "######\n#@$2 #\n######"
	var lvl := LevelLoader.parse_xsb(xsb, "tv")
	var v := LevelValidator.validate(lvl)
	if v.ok:
		printerr("expected color-count error, got OK")
		return false
	# 加一个中性 holder 后应通过（1 红箱 + 1 蓝 holder + 1 中性 → 数量配齐：1==2? 不；1 != 2 → 数量错）
	# 改：1 红箱 + 1 中性 holder → 通过
	var xsb2 := "######\n#@$, #\n######"
	var lvl2 := LevelLoader.parse_xsb(xsb2, "tv2")
	var v2 := LevelValidator.validate(lvl2)
	if not v2.ok:
		printerr("expected OK for box+neutral, got: %s" % v2.format_report())
		return false
	return true

func _t_command_color_info() -> bool:
	# 推一个红箱到中性 holder：cmd 应携带 box_color=1, holder_color_to=0, became_complete=true
	var xsb := "######\n#@$, #\n######"
	var lvl := LevelLoader.parse_xsb(xsb, "tc")
	var board := Board.new(lvl)
	var captured: Array = [null]
	board.moved.connect(func(c): captured[0] = c)
	board.try_move(Vector2i(1, 0))
	var cmd: BoardCommand = captured[0]
	if cmd == null: return false
	if not cmd.pushed_box: return false
	if cmd.box_color != 1: return false
	if cmd.holder_color_from != -1: return false  # (2,1) 是 floor
	if cmd.holder_color_to != Cell.NEUTRAL_COLOR: return false
	if not cmd.became_complete():
		printerr("expected became_complete=true")
		return false
	return true

# --- Phase 5 P5-A: audio bus sanity ---

func _t_audio_buses() -> bool:
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			printerr("audio bus '%s' not found" % bus_name)
			return false
	return true

func _t_applier_safe() -> bool:
	# 已存在的总线：不应抛错
	SettingsApplier.apply_volume("Music", 0.5)
	# 不存在的总线：必须静默忽略
	SettingsApplier.apply_volume("__nonexistent_bus__", 0.5)
	return true
