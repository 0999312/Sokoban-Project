extends SceneTree
## DialogSmoke — 检查 ImportDialog / ExportDialog 实例化 + _ready 无错误。

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var failed := 0
	failed += await _run_one("ImportDialog instantiate", "res://scenes/editor/dialogs/import_dialog.tscn")
	failed += await _run_one("ExportDialog instantiate", "res://scenes/editor/dialogs/export_dialog.tscn", true)
	if failed > 0:
		printerr("[DialogSmoke] %d failure(s)" % failed); quit(1)
	else:
		print("[DialogSmoke] all dialogs instantiated cleanly"); quit(0)

func _run_one(label: String, scene_path: String, needs_level: bool = false) -> int:
	var ps: PackedScene = load(scene_path)
	if ps == null:
		printerr("  [FAIL] %s: load failed" % label); return 1
	var node = ps.instantiate()
	if needs_level:
		var lvl := LevelLoader.load_json_file("res://levels/official/w1/01.json")
		if node.has_method("set_level"):
			node.set_level(lvl, null)
	get_root().add_child(node)
	# 给一帧让 _ready 跑完
	await process_frame
	# 检查关键节点
	var ok := true
	if scene_path.ends_with("import_dialog.tscn"):
		ok = node.has_node("%LblTitle") and node.has_node("%BtnCancel") and node.has_node("%BtnOk") and node.has_node("%Tabs")
	elif scene_path.ends_with("export_dialog.tscn"):
		ok = node.has_node("%EditJson") and node.has_node("%EditXsb") and node.has_node("%EditCode") and node.has_node("%BtnClose")
	node.queue_free()
	await process_frame
	print("  [%s] %s" % ["OK" if ok else "FAIL", label])
	return 0 if ok else 1
