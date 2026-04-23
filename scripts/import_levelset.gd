extends SceneTree

const LEVELSET_IMPORTER := preload("res://core/level/level_set_importer.gd")
const LEVEL_LOADER := preload("res://core/level/level_loader.gd")
const LEVEL_VALIDATOR := preload("res://core/level/level_validator.gd")

func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if args.is_empty() or not args.has("input") or not args.has("output"):
		_print_usage()
		quit(1)
		return

	var input_path: String = String(args["input"])
	var output_dir: String = String(args["output"])
	var chapter_id: String = String(args.get("chapter", "official-import"))
	var id_prefix: String = String(args.get("prefix", chapter_id))
	var name_prefix: String = String(args.get("name-prefix", ""))
	var chapter_name: String = String(args.get("chapter-name", chapter_id))
	var chapter_description: String = String(args.get("chapter-description", "Imported level set"))
	var world_index: int = int(args.get("world", 0))
	var start_index: int = int(args.get("start", 1))
	var source_skip: int = int(args.get("skip", 0))
	var source_count: int = int(args.get("count", -1))
	var source_type: String = String(args.get("source-type", "auto"))

	var entries: Array = _load_entries(input_path, source_type)
	entries = _slice_entries(entries, source_skip, source_count)
	if entries.is_empty():
		printerr("[import_levelset] no levels found in %s" % input_path)
		quit(2)
		return

	if not DirAccess.dir_exists_absolute(output_dir):
		var mk_err := DirAccess.make_dir_recursive_absolute(output_dir)
		if mk_err != OK:
			printerr("[import_levelset] failed to create output dir %s (%d)" % [output_dir, mk_err])
			quit(3)
			return

	var generated_ids: Array[String] = []
	var report_lines: Array[String] = []
	for i in entries.size():
		var entry = entries[i]
		var number: int = start_index + i
		var padded := _pad_level_number(number)
		var level_id := "%s-%s" % [id_prefix, padded]
		var level := LEVEL_LOADER.parse_xsb(String(entry.xsb_text), level_id)
		if level == null:
			printerr("[import_levelset] failed to parse level %s" % level_id)
			quit(4)
			return

		level.id = level_id
		level.name = _build_level_name(entry, name_prefix, padded, level_id)
		level.author = String(entry.author)
		level.metadata = {
			"world": world_index,
			"index": number,
			"source_title": String(entry.title),
			"source_index": int(entry.index),
			"import_source": input_path,
			"verified_by_solver": false,
		}

		var validation = LEVEL_VALIDATOR.validate(level)
		if not validation.ok:
			level.metadata["import_validation"] = {
				"ok": validation.ok,
				"errors": validation.errors,
				"warnings": validation.warnings,
			}
			printerr("[import_levelset] kept level %s with validation issues\n%s" % [level_id, validation.format_report()])
		elif not validation.warnings.is_empty():
			level.metadata["import_validation"] = {
				"ok": validation.ok,
				"errors": validation.errors,
				"warnings": validation.warnings,
			}

		var json_path := "%s/%s.json" % [output_dir, padded]
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		if file == null:
			printerr("[import_levelset] failed to write %s" % json_path)
			quit(6)
			return
		file.store_string(LEVEL_LOADER.to_json(level, true))
		generated_ids.append(level_id)
		report_lines.append("%s <= %s" % [level_id, String(entry.title)])

	var chapter_path := "%s/chapter.json" % output_dir
	var chapter_file := FileAccess.open(chapter_path, FileAccess.WRITE)
	if chapter_file == null:
		printerr("[import_levelset] failed to write %s" % chapter_path)
		quit(7)
		return
	chapter_file.store_string(JSON.stringify({
		"format_version": 1,
		"id": chapter_id,
		"name": chapter_name,
		"description": chapter_description,
		"order": world_index,
		"levels": generated_ids,
		"planned_total": generated_ids.size(),
	}, "  "))
	chapter_file.flush()

	print("[import_levelset] generated %d level(s)" % generated_ids.size())
	for line: String in report_lines:
		print(line)
	quit()


func _load_entries(input_path: String, source_type: String) -> Array:
	if source_type == "dir" or (source_type == "auto" and DirAccess.dir_exists_absolute(input_path)):
		return _load_entries_from_directory(input_path)

	var file := FileAccess.open(input_path, FileAccess.READ)
	if file == null:
		return []
	return LEVELSET_IMPORTER.parse_text_levelset(file.get_as_text())


func _load_entries_from_directory(input_dir: String) -> Array:
	var entries: Array = []
	var dir := DirAccess.open(input_dir)
	if dir == null:
		return entries
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and not name.begins_with("."):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort_custom(func(a: String, b: String) -> bool: return _natural_sort_key(a) < _natural_sort_key(b))
	for i in names.size():
		var path := "%s/%s" % [input_dir, names[i]]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var entry := LEVELSET_IMPORTER.LevelEntry.new()
		entry.index = i + 1
		entry.title = names[i]
		entry.xsb_text = file.get_as_text().replace("\r\n", "\n").replace("\r", "\n")
		entries.append(entry)
	return entries


func _natural_sort_key(name: String) -> String:
	var prefix := name
	var suffix := ""
	var dot := name.rfind(".")
	if dot != -1:
		prefix = name.substr(0, dot)
		suffix = name.substr(dot + 1)
	if suffix.is_valid_int():
		return "%s.%05d" % [prefix, int(suffix)]
	return name


func _pad_level_number(number: int) -> String:
	if number < 10:
		return "0%d" % number
	return str(number)


func _build_level_name(entry, name_prefix: String, padded: String, level_id: String) -> String:
	if not name_prefix.is_empty():
		return "%s-%s" % [name_prefix, padded]
	var source_title: String = String(entry.title).strip_edges()
	if not source_title.is_empty():
		return source_title
	return level_id


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


func _slice_entries(entries: Array, source_skip: int, source_count: int) -> Array:
	var skip: int = maxi(source_skip, 0)
	if skip >= entries.size():
		return []
	var result: Array = []
	var upper_bound: int = entries.size()
	if source_count >= 0:
		upper_bound = mini(entries.size(), skip + source_count)
	for i in range(skip, upper_bound):
		result.append(entries[i])
	return result


func _print_usage() -> void:
	print("Usage: godot4 --headless --script res://scripts/import_levelset.gd -- --input=<file-or-dir> --output=<dir> [--chapter=official-w2] [--prefix=official-w2] [--name-prefix=level_names.official-w2] [--chapter-name=Microban] [--chapter-description=Imported level set] [--world=2] [--start=1] [--skip=0] [--count=-1] [--source-type=auto|file|dir]")
