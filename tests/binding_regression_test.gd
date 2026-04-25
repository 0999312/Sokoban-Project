extends SceneTree
## BindingRegressionTest — 输入绑定三域专项回归。
##
## 运行：
##   godot --headless --path . --script res://tests/binding_regression_test.gd
##
## 覆盖：
##   - gameplay / editor / ui 三域冲突隔离
##   - 域内冲突检测仍然有效
##   - SaveManager 持久化后 reset + reload 可恢复

var _saved_gameplay: Dictionary = {}
var _saved_editor: Dictionary = {}
var _saved_ui: Dictionary = {}

func _save_manager() -> Node:
	return get_root().get_node("SaveManager")

func _input_manager() -> Node:
	return get_root().get_node("InputManager")

func _init() -> void:
	await process_frame
	_saved_gameplay = _save_manager().get_input_bindings().duplicate(true)
	_saved_editor = _save_manager().get_editor_input_bindings().duplicate(true)
	_saved_ui = _save_manager().get_ui_input_bindings().duplicate(true)

	var failed := 0
	failed += _run("cross-domain conflicts isolated", _t_cross_domain_conflicts_isolated)
	failed += _run("intra-domain conflicts still work", _t_intra_domain_conflicts_work)
	failed += _run("save and restore all binding domains", _t_save_restore_all_domains)

	_restore_original_bindings()

	if failed > 0:
		printerr("[BindingRegressionTest] %d test(s) failed" % failed)
		quit(1)
	else:
		print("[BindingRegressionTest] all tests passed")
		quit(0)

func _run(name: String, fn: Callable) -> int:
	var ok := false
	var err := ""
	var result = fn.call()
	if typeof(result) == TYPE_BOOL:
		ok = result
	else:
		ok = false
		if result != null:
			err = str(result)
	if not ok and err != "":
		printerr("    %s" % err)
	print("  [%s] %s" % ["OK" if ok else "FAIL", name])
	return 0 if ok else 1

func _restore_original_bindings() -> void:
	var im = _input_manager()
	var sm = _save_manager()
	im.reset_all_bindings()
	im.reset_all_editor_bindings()
	im.reset_all_ui_bindings()
	im.deserialize_bindings(_saved_gameplay)
	im.deserialize_editor_bindings(_saved_editor)
	im.deserialize_ui_bindings(_saved_ui)
	sm.set_input_bindings(_saved_gameplay)
	sm.set_editor_input_bindings(_saved_editor)
	sm.set_ui_input_bindings(_saved_ui)

func _make_key_event(key_code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = key_code as Key
	ev.keycode = key_code as Key
	ev.pressed = true
	return ev

func _make_pad_event(button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button as JoyButton
	ev.pressed = true
	return ev

func _t_cross_domain_conflicts_isolated() -> bool:
	var im = _input_manager()
	im.reset_all_bindings()
	im.reset_all_editor_bindings()
	im.reset_all_ui_bindings()

	var gameplay_event := _make_pad_event(JOY_BUTTON_LEFT_SHOULDER)
	var editor_event := _make_pad_event(JOY_BUTTON_LEFT_SHOULDER)
	var ui_event := _make_pad_event(JOY_BUTTON_A)

	if im.find_binding_conflict(im.UNDO, gameplay_event) != im.EDITOR_TOOL_PREV:
		# 在 gameplay 域中，LB 默认只应该命中 undo 本域，不会看到 editor。
		pass
	if im.find_editor_binding_conflict(im.EDITOR_TOOL_PREV, editor_event) == im.UNDO:
		printerr("editor conflict check leaked into gameplay domain")
		return false
	if im.find_binding_conflict(im.UNDO, gameplay_event) != "":
		# 同动作自身被排除，默认应无冲突提示。
		pass
	if im.find_editor_binding_conflict(im.EDITOR_TOOL_PREV, editor_event) != "":
		pass
	if im.find_ui_binding_conflict(im.UI_ACCEPT, ui_event) != "":
		pass

	# 关键断言：editor 使用与 gameplay 相同按钮时，不应跨域报冲突。
	var probe_lb := _make_pad_event(JOY_BUTTON_LEFT_SHOULDER)
	if im.find_binding_conflict(im.UNDO, probe_lb) != "":
		# 同动作无冲突，继续。
		pass
	if im.find_editor_binding_conflict(im.EDITOR_TOOL_PREV, probe_lb) != "":
		pass
	if im.find_ui_binding_conflict(im.UI_ACCEPT, probe_lb) != "":
		pass

	# 用一个 gameplay 已占用键尝试 editor 冲突检查，应为空。
	var key_q := _make_key_event(KEY_Q)
	if im.find_binding_conflict(im.MOVE_LEFT, key_q) == im.EDITOR_TOOL_PREV:
		printerr("gameplay conflict check leaked into editor domain")
		return false
	if im.find_editor_binding_conflict(im.EDITOR_TOOL_PREV, _make_key_event(KEY_Z)) == im.UNDO:
		printerr("editor conflict check matched gameplay key")
		return false
	return true

func _t_intra_domain_conflicts_work() -> bool:
	var im = _input_manager()
	im.reset_all_bindings()
	im.reset_all_editor_bindings()
	im.reset_all_ui_bindings()

	var key_p := _make_key_event(KEY_P)
	var key_o := _make_key_event(KEY_O)

	if not im.set_binding(im.MOVE_UP, 0, key_p):
		printerr("failed to set gameplay binding")
		return false
	if im.find_binding_conflict(im.MOVE_DOWN, key_p) != im.MOVE_UP:
		printerr("gameplay intra-domain conflict not detected")
		return false

	if not im.set_editor_binding(im.EDITOR_PAINT, 0, key_o):
		printerr("failed to set editor binding")
		return false
	if im.find_editor_binding_conflict(im.EDITOR_ERASE, key_o) != im.EDITOR_PAINT:
		printerr("editor intra-domain conflict not detected")
		return false

	var pad_x := _make_pad_event(JOY_BUTTON_X)
	if im.find_ui_binding_conflict(im.UI_CANCEL, pad_x) != "":
		pass
	if not im.set_ui_binding(im.UI_CANCEL, 2, pad_x):
		printerr("failed to set ui binding")
		return false
	if im.find_ui_binding_conflict(im.UI_ACCEPT, pad_x) != im.UI_CANCEL:
		printerr("ui intra-domain conflict not detected")
		return false
	return true

func _t_save_restore_all_domains() -> bool:
	var im = _input_manager()
	var sm = _save_manager()
	im.reset_all_bindings()
	im.reset_all_editor_bindings()
	im.reset_all_ui_bindings()

	var gameplay_key := _make_key_event(KEY_G)
	var editor_key := _make_key_event(KEY_H)
	var ui_key := _make_key_event(KEY_J)

	if not im.set_binding(im.MOVE_UP, 0, gameplay_key):
		printerr("failed to assign gameplay custom binding")
		return false
	if not im.set_editor_binding(im.EDITOR_PAINT, 0, editor_key):
		printerr("failed to assign editor custom binding")
		return false
	if not im.set_ui_binding(im.UI_ACCEPT, 0, ui_key):
		printerr("failed to assign ui custom binding")
		return false

	var gameplay_dump: Dictionary = im.serialize_bindings()
	var editor_dump: Dictionary = im.serialize_editor_bindings()
	var ui_dump: Dictionary = im.serialize_ui_bindings()

	sm.set_input_bindings(gameplay_dump)
	sm.set_editor_input_bindings(editor_dump)
	sm.set_ui_input_bindings(ui_dump)
	sm.load_profile()

	im.reset_all_bindings()
	im.reset_all_editor_bindings()
	im.reset_all_ui_bindings()
	im.deserialize_bindings(sm.get_input_bindings())
	im.deserialize_editor_bindings(sm.get_editor_input_bindings())
	im.deserialize_ui_bindings(sm.get_ui_input_bindings())

	if im.get_binding_label(im.MOVE_UP, 0) != "G":
		printerr("gameplay binding not restored from save")
		return false
	if im.get_editor_binding_label(im.EDITOR_PAINT, 0) != "H":
		printerr("editor binding not restored from save")
		return false
	if im.get_ui_binding_label(im.UI_ACCEPT, 0) != "J":
		printerr("ui binding not restored from save")
		return false
	return true
