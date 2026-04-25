extends SceneTree

const LEVEL_VALIDATOR := preload("res://core/level/level_validator.gd")
const SOKOBAN_SOLVER := preload("res://core/solver/sokoban_solver.gd")

func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if not args.has("input"):
		_print_usage()
		quit(1)
		return

	var input_path: String = String(args["input"])
	var write_back: bool = bool(args.get("write", false))
	var max_pushes: int = int(args.get("max-pushes", 800))
	var node_limit: int = int(args.get("node-limit", 5_000_000))
	var files: Array[String] = []
	_collect_json_files(input_path, files)
	if files.is_empty():
		printerr("[calculate_standard_scores] no json files found in %s" % input_path)
		quit(2)
		return

	files.sort()
	var solved_count: int = 0
	var unsolved_count: int = 0
	var invalid_count: int = 0

	for path: String in files:
		var level: Level = LevelLoader.load_json_file(path)
		if level == null:
			printerr("[calculate_standard_scores] load failed: %s" % path)
			invalid_count += 1
			continue

		var validation = LEVEL_VALIDATOR.validate(level)
		if not validation.ok:
			printerr("[calculate_standard_scores] invalid level: %s\n%s" % [path, validation.format_report()])
			invalid_count += 1
			continue

		var solver = SOKOBAN_SOLVER.new()
		solver.max_pushes = max_pushes
		solver.node_limit = node_limit
		var result: Dictionary = solver.solve(level, level.box_starts, level.player_start)
		if not bool(result.get("found", false)):
			print("[UNSOLVED] %s nodes=%d" % [path, int(result.get("nodes_expanded", 0))])
			unsolved_count += 1
			continue

		var pushes: int = int(result.get("pushes", -1))
		var moves: Array = SOKOBAN_SOLVER.expand_to_moves(level, level.box_starts, level.player_start, result.get("push_solution", []))
		var steps: int = moves.size()
		level.metadata["optimal_pushes"] = pushes
		level.metadata["optimal_steps"] = steps
		level.metadata["verified_by_solver"] = true
		print("[SOLVED] %s pushes=%d steps=%d nodes=%d" % [path, pushes, steps, int(result.get("nodes_expanded", 0))])
		solved_count += 1

		if write_back:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				printerr("[calculate_standard_scores] write failed: %s" % path)
				quit(3)
				return
			file.store_string(LevelLoader.to_json(level, true))

	print("[calculate_standard_scores] done solved=%d unsolved=%d invalid=%d write_back=%s" % [
		solved_count,
		unsolved_count,
		invalid_count,
		str(write_back),
	])
	quit(0)

func _collect_json_files(path: String, out: Array[String]) -> void:
	if FileAccess.file_exists(path):
		if path.ends_with(".json"):
			out.append(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child_path := path.path_join(name)
		if dir.current_is_dir():
			_collect_json_files(child_path, out)
		elif name.ends_with(".json") and name != "chapter.json":
			out.append(child_path)
		name = dir.get_next()
	dir.list_dir_end()

func _parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var parts := arg.substr(2).split("=", false, 1)
		if parts.size() == 2:
			out[parts[0]] = parts[1]
		else:
			out[parts[0]] = true
	return out

func _print_usage() -> void:
	print("Usage: godot4 --headless --script res://scripts/calculate_standard_scores.gd -- --input=<file-or-dir> [--write] [--max-pushes=200] [--node-limit=2000000]")
