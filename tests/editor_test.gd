extends SceneTree
## EditorTest — Phase 4 编辑器自检脚本（无 GUT 依赖）。
##
## 运行：
##   godot --headless --script res://tests/editor_test.gd
##
## 覆盖：
##   - EditorModel ↔ Level 双向转换保真
##   - EditCommand apply/revert 可逆
##   - ShareCode 编解码（含 CRC 校验）
##   - 基于现有 W1-01 关卡的完整往返
##   - UserLevelStore make_new_id 唯一性

const W1_01 := "res://levels/official/w1/01.json"
const W1_06 := "res://levels/official/w1/06.json"

func _init() -> void:
	var failed := 0
	failed += _run("EditorModel roundtrip W1-01", _t_model_roundtrip_w1_01)
	failed += _run("EditorModel roundtrip W1-06 (multi-color)", _t_model_roundtrip_w1_06)
	failed += _run("EditCommand apply/revert", _t_edit_command_revert)
	failed += _run("ShareCode roundtrip W1-01", _t_share_w1_01)
	failed += _run("ShareCode roundtrip W1-06 (multi-color)", _t_share_w1_06)
	failed += _run("EditorModel preserves solver metadata", _t_model_preserves_solver_metadata)
	failed += _run("ShareCode tamper detection", _t_share_tamper)
	failed += _run("UserLevelStore.make_new_id unique", _t_make_id_unique)
	failed += _run("EditorModel resize preserves cells", _t_resize_preserve)
	failed += _run("EditorBoard pan works regardless of board size", _t_board_pan_unconditional)
	if failed > 0:
		printerr("[EditorTest] %d test(s) failed" % failed)
		quit(1)
	else:
		print("[EditorTest] all tests passed")
		quit(0)

func _run(test_name: String, fn: Callable) -> int:
	var ok: bool = fn.call()
	print("  [%s] %s" % ["OK" if ok else "FAIL", test_name])
	return 0 if ok else 1

# ------------------ Tests ------------------

func _t_model_roundtrip_w1_01() -> bool:
	return _model_roundtrip(W1_01)

func _t_model_roundtrip_w1_06() -> bool:
	return _model_roundtrip(W1_06)

func _model_roundtrip(path: String) -> bool:
	var src: Level = LevelLoader.load_json_file(path)
	if src == null:
		printerr("    cannot load: " + path); return false
	var model := EditorModel.new(src.width, src.height)
	model.load_from_level(src)
	var out: Level = model.to_level()
	if out.width != src.width or out.height != src.height:
		printerr("    size mismatch"); return false
	if out.player_start != src.player_start:
		printerr("    player mismatch"); return false
	# 比较 box / goal 集合（顺序无关）
	if not _set_eq_with_color(src.box_starts, src.box_colors, out.box_starts, out.box_colors):
		printerr("    box set mismatch"); return false
	if not _set_eq_with_color(src.goal_positions, src.goal_colors, out.goal_positions, out.goal_colors):
		printerr("    goal set mismatch"); return false
	# 地形完全一致
	for y in src.height:
		for x in src.width:
			if int(src.tiles[y][x]) != int(out.tiles[y][x]):
				printerr("    tile mismatch at %d,%d" % [x, y]); return false
	return true

static func _set_eq_with_color(pos_a: Array, col_a: Array, pos_b: Array, col_b: Array) -> bool:
	if pos_a.size() != pos_b.size():
		return false
	var dict_a: Dictionary = {}
	for i in pos_a.size():
		dict_a[pos_a[i]] = int(col_a[i])
	for i in pos_b.size():
		var p = pos_b[i]
		if not dict_a.has(p):
			return false
		if int(dict_a[p]) != int(col_b[i]):
			return false
	return true

func _t_edit_command_revert() -> bool:
	var model := EditorModel.new(8, 6)
	# 初始化为一些可识别状态
	for y in range(1, 5):
		for x in range(1, 7):
			model.tiles[y][x] = Cell.Type.FLOOR
	for x in 8: model.tiles[0][x] = Cell.Type.WALL; model.tiles[5][x] = Cell.Type.WALL
	for y in 6: model.tiles[y][0] = Cell.Type.WALL; model.tiles[y][7] = Cell.Type.WALL
	model.player_pos = Vector2i(2, 2)
	# 拍快照
	var snap_before := _snapshot(model)
	# 写入：把 (3,3) 改成 GOAL，(4,3) 放红箱，移动玩家到 (5,3)
	var cmd := EditCommand.new()
	cmd.player_before = model.player_pos
	for tup in [
		[Vector2i(3,3), {"tile": Cell.Type.GOAL, "holder_color": 1}],
		[Vector2i(4,3), {"box": true, "box_color": 1}],
	]:
		var p: Vector2i = tup[0]
		var before := model.snapshot_cell(p)
		# 模拟 EditorScene 的 _apply_tool_to_cell（直接 write_cell）
		var payload: Dictionary = tup[1]
		if payload.has("tile"):
			model.tiles[p.y][p.x] = int(payload.tile)
			if int(payload.tile) == Cell.Type.GOAL and payload.has("holder_color"):
				model.holder_colors[p] = int(payload.holder_color)
		if payload.has("box") and bool(payload.box):
			model.boxes[p] = int(payload.get("box_color", 1))
		var after := model.snapshot_cell(p)
		cmd.add_change(p, before, after)
	# 玩家也算 change
	model.player_pos = Vector2i(5, 3)
	cmd.player_after = model.player_pos
	# revert
	cmd.revert_on(model)
	var snap_after := _snapshot(model)
	if not _snap_match(snap_before, snap_after):
		printerr("    state not restored after revert"); return false
	# redo via apply
	cmd.apply_to(model)
	if model.player_pos != Vector2i(5, 3):
		printerr("    redo player wrong"); return false
	if not model.boxes.has(Vector2i(4, 3)):
		printerr("    redo box missing"); return false
	if int(model.tiles[3][3]) != Cell.Type.GOAL:
		printerr("    redo goal missing"); return false
	return true

static func _snapshot(m: EditorModel) -> Dictionary:
	return {
		"player": m.player_pos,
		"boxes": m.boxes.duplicate(true),
		"holders": m.holder_colors.duplicate(true),
		"tiles": m.tiles.duplicate(true),
	}

static func _snap_match(a: Dictionary, b: Dictionary) -> bool:
	if a.player != b.player: return false
	if a.boxes.size() != b.boxes.size(): return false
	for k in a.boxes:
		if int(b.boxes.get(k, -1)) != int(a.boxes[k]): return false
	if a.holders.size() != b.holders.size(): return false
	for k in a.holders:
		if int(b.holders.get(k, -1)) != int(a.holders[k]): return false
	for y in a.tiles.size():
		var ra: Array = a.tiles[y]; var rb: Array = b.tiles[y]
		for x in ra.size():
			if int(ra[x]) != int(rb[x]): return false
	return true

func _t_share_w1_01() -> bool: return _share_roundtrip(W1_01)
func _t_share_w1_06() -> bool: return _share_roundtrip(W1_06)

func _share_roundtrip(path: String) -> bool:
	var lvl: Level = LevelLoader.load_json_file(path)
	if lvl == null:
		printerr("    cannot load " + path); return false
	var code := ShareCode.encode_level(lvl)
	var roundtrip: Level = ShareCode.decode_to_level(code)
	if roundtrip == null:
		printerr("    decode returned null"); return false
	if roundtrip.width != lvl.width or roundtrip.height != lvl.height:
		printerr("    size mismatch"); return false
	if roundtrip.player_start != lvl.player_start:
		printerr("    player mismatch"); return false
	if not _set_eq_with_color(lvl.box_starts, lvl.box_colors, roundtrip.box_starts, roundtrip.box_colors):
		printerr("    box mismatch"); return false
	if not _set_eq_with_color(lvl.goal_positions, lvl.goal_colors, roundtrip.goal_positions, roundtrip.goal_colors):
		printerr("    goal mismatch"); return false
	return true

func _t_model_preserves_solver_metadata() -> bool:
	var src: Level = LevelLoader.load_json_file(W1_01)
	if src == null:
		printerr("    cannot load: " + W1_01)
		return false
	var model := EditorModel.new(src.width, src.height)
	model.load_from_level(src)
	model.meta["optimal_steps"] = 12
	model.meta["optimal_pushes"] = 4
	model.meta["verified_by_solver"] = true
	var out: Level = model.to_level()
	if int(out.metadata.get("optimal_steps", -1)) != 12:
		printerr("    optimal_steps missing from metadata")
		return false
	if int(out.metadata.get("optimal_pushes", -1)) != 4:
		printerr("    optimal_pushes missing from metadata")
		return false
	if not bool(out.metadata.get("verified_by_solver", false)):
		printerr("    verified_by_solver missing from metadata")
		return false
	var model2 := EditorModel.new(out.width, out.height)
	model2.load_from_level(out)
	if int(model2.meta.get("optimal_steps", -1)) != 12:
		printerr("    optimal_steps missing after reload")
		return false
	if int(model2.meta.get("optimal_pushes", -1)) != 4:
		printerr("    optimal_pushes missing after reload")
		return false
	if not bool(model2.meta.get("verified_by_solver", false)):
		printerr("    verified_by_solver missing after reload")
		return false
	return true

func _t_share_tamper() -> bool:
	var lvl := LevelLoader.load_json_file(W1_01)
	var code := ShareCode.encode_level(lvl)
	# 篡改尾部 CRC
	var tampered := code.substr(0, code.length() - 1) + ("0" if code.right(1) != "0" else "1")
	var r := ShareCode.decode(tampered)
	if bool(r.get("ok", false)):
		printerr("    tampered code accepted!"); return false
	return true

func _t_make_id_unique() -> bool:
	var ids: Dictionary = {}
	for i in 50:
		var id := UserLevelStore.make_new_id("test")
		if ids.has(id):
			printerr("    duplicate id: " + id); return false
		ids[id] = true
	return true

func _t_resize_preserve() -> bool:
	var m := EditorModel.new(8, 6)
	m.tiles[2][3] = Cell.Type.WALL
	m.player_pos = Vector2i(4, 4)
	m.boxes[Vector2i(5, 4)] = 2
	m.resize(10, 8, false)
	if int(m.tiles[2][3]) != Cell.Type.WALL:
		printerr("    wall lost on enlarge"); return false
	if m.player_pos != Vector2i(4, 4):
		printerr("    player lost"); return false
	if not m.boxes.has(Vector2i(5, 4)) or int(m.boxes[Vector2i(5, 4)]) != 2:
		printerr("    box lost or color changed"); return false
	# 再缩回会裁掉超界
	m.resize(5, 5, false)
	if m.boxes.has(Vector2i(5, 4)):
		printerr("    out-of-bounds box not pruned"); return false
	return true

func _t_board_pan_unconditional() -> bool:
	var host := Control.new()
	host.size = Vector2(400, 300)
	var board: Node2D = load("res://scenes/editor/editor_board.gd").new()
	host.add_child(board)
	var model := EditorModel.new(4, 3)
	board.set_model(model)
	var before: Vector2 = board.position
	board.pan_by_pixels(Vector2(40, 20))
	var after_small: Vector2 = board.position
	if after_small == before:
		printerr("    board did not pan for small board")
		return false
	model.resize(20, 16, false)
	board.set_model(model)
	board.pan_by_pixels(Vector2(-1000, -1000))
	if board.position.x > 0.0 or board.position.y > 0.0:
		printerr("    board pan was not clamped inside host")
		return false
	return true
