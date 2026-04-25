extends Node
## InputManager — 全局输入动作 Autoload。
##
## 两套独立的 input context：
##
##   gameplay (GUIDE 后端)
##     move_up / move_down / move_left / move_right
##     undo / redo / restart / pause
##
##   ui (原生 InputMap 后端，让 Godot Control 内置导航生效)
##     ui_up / ui_down / ui_left / ui_right
##     ui_accept / ui_cancel
##
## 设计取舍：
##   - gameplay 走 GUIDE：方便后续接入复杂触发器、context 切换
##   - ui 走原生 InputMap：Control / Button 默认监听 ui_*，无须额外胶水代码
##   - 两套 context 都允许玩家在设置面板中重绑（gameplay 调 set_binding；ui 调 set_ui_binding）
##   - 两套绑定都通过 SaveManager 持久化（gameplay → input_bindings；ui → ui_input_bindings）
##
## 重绑 API：在 SettingsPanel 中调用：
##   InputManager.set_binding(action, slot, event)        # gameplay
##   InputManager.set_ui_binding(action, slot, event)     # ui

signal device_changed(device: int)  ## DEVICE_KEYBOARD / DEVICE_GAMEPAD
signal last_input_changed(device: int, event_kind: String)

# --- Gameplay action 名 ---
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const UNDO := "undo"
const REDO := "redo"
const RESTART := "restart"
const PAUSE := "pause"
const EDITOR_TOGGLE_BOARD_MODE := "editor_toggle_board_mode"
const EDITOR_PAINT := "editor_paint"
const EDITOR_ERASE := "editor_erase"
const EDITOR_TOOL_PREV := "editor_tool_prev"
const EDITOR_TOOL_NEXT := "editor_tool_next"
const EDITOR_COLOR_PREV := "editor_color_prev"
const EDITOR_COLOR_NEXT := "editor_color_next"
const EDITOR_SHAPE_CYCLE := "editor_shape_cycle"
const EDITOR_PAN_MOD := "editor_pan_modifier"
const EDITOR_TEST := "editor_test_play"

const ALL_ACTIONS := [
	MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT,
	UNDO, REDO, RESTART, PAUSE,
	]

const ALL_EDITOR_ACTIONS := [
	EDITOR_TOGGLE_BOARD_MODE,
	EDITOR_PAINT,
	EDITOR_ERASE,
	EDITOR_TOOL_PREV,
	EDITOR_TOOL_NEXT,
	EDITOR_COLOR_PREV,
	EDITOR_COLOR_NEXT,
	EDITOR_SHAPE_CYCLE,
	EDITOR_PAN_MOD,
	EDITOR_TEST,
]

# --- UI action 名（与 Godot 内置 ui_* 完全一致）---
const UI_ACCEPT := "ui_accept"
const UI_CANCEL := "ui_cancel"
const UI_UP := "ui_up"
const UI_DOWN := "ui_down"
const UI_LEFT := "ui_left"
const UI_RIGHT := "ui_right"

const ALL_UI_ACTIONS := [
	UI_UP, UI_DOWN, UI_LEFT, UI_RIGHT,
	UI_ACCEPT, UI_CANCEL,
]

const UI_SLOT_PRIMARY := 0
const UI_SLOT_SECONDARY := 1
const UI_SLOT_GAMEPAD := 2

# 设备
enum { DEVICE_KEYBOARD = 0, DEVICE_GAMEPAD = 1 }

var current_device: int = DEVICE_KEYBOARD
var last_input_kind: String = "keyboard"

# action_name -> GUIDEAction 实例
var _actions: Dictionary = {}
# 当前生效的 mapping context
var _ctx: GUIDEMappingContext = null

# UI 绑定本地缓存：{ action_name: { slot: { "key"/"joy": int } } }
# 与原生 InputMap 同步
var _ui_bindings: Dictionary = {}
var _editor_bindings: Dictionary = {}

func _ready() -> void:
	_build_actions_and_context()
	_apply_default_bindings()
	_apply_default_editor_bindings()
	_apply_default_ui_bindings()
	if DisplayServer.get_name() == "headless":
		return
	_enable_context.call_deferred()

func _enable_context() -> void:
	var guide: Node = get_node_or_null("/root/GUIDE")
	if guide == null:
		push_warning("[InputManager] /root/GUIDE autoload missing; skipping context activation")
		return
	if not guide.has_method("enable_mapping_context"):
		push_warning("[InputManager] /root/GUIDE has no enable_mapping_context; addon mismatch")
		return
	if not guide.is_node_ready():
		await guide.ready
	guide.enable_mapping_context(_ctx)
	print("[InputManager] GUIDE gameplay context enabled")

func _input(event: InputEvent) -> void:
	var probe := _classify_input_event(event)
	if probe.is_empty():
		return
	var new_device: int = int(probe["device"])
	var new_kind: String = String(probe["kind"])
	if new_device != current_device:
		current_device = new_device
		device_changed.emit(current_device)
	last_input_kind = new_kind
	last_input_changed.emit(current_device, last_input_kind)

func is_using_gamepad() -> bool:
	return current_device == DEVICE_GAMEPAD

func is_using_keyboard_mouse() -> bool:
	return current_device == DEVICE_KEYBOARD

func _classify_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return {}
		return { "device": DEVICE_GAMEPAD, "kind": "joy_button" }
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if absf(jm.axis_value) < 0.45:
			return {}
		return { "device": DEVICE_GAMEPAD, "kind": "joy_motion" }
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return {}
		return { "device": DEVICE_KEYBOARD, "kind": "keyboard" }
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return {}
		return { "device": DEVICE_KEYBOARD, "kind": "mouse_button" }
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.relative.length_squared() <= 0.0:
			return {}
		return { "device": DEVICE_KEYBOARD, "kind": "mouse_motion" }
	return {}

# ============================================================
# Gameplay API
# ============================================================

func get_move_dir() -> Vector2i:
	if is_action_just_pressed(MOVE_UP):    return Vector2i(0, -1)
	if is_action_just_pressed(MOVE_DOWN):  return Vector2i(0, 1)
	if is_action_just_pressed(MOVE_LEFT):  return Vector2i(-1, 0)
	if is_action_just_pressed(MOVE_RIGHT): return Vector2i(1, 0)
	return Vector2i.ZERO

func is_action_just_pressed(action_name: String) -> bool:
	# 优先 GUIDE
	var a: GUIDEAction = _actions.get(action_name)
	if a != null and a.is_triggered():
		return true
	# 回退原生 InputMap（gameplay action 也在 project.godot 占位过）
	if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
		return true
	return false

func get_action(action_name: String) -> GUIDEAction:
	return _actions.get(action_name)

func get_context() -> GUIDEMappingContext:
	return _ctx

# ============================================================
# Gameplay context construction
# ============================================================

func _build_actions_and_context() -> void:
	for n in ALL_ACTIONS:
		var a := GUIDEAction.new()
		a.name = n
		a.action_value_type = GUIDEAction.GUIDEActionValueType.BOOL
		a.is_remappable = true
		a.display_name = n
		_actions[n] = a
	_ctx = GUIDEMappingContext.new()
	_ctx.display_name = "Gameplay"

func _apply_default_bindings() -> void:
	_ctx.mappings = []
	_add_mapping(MOVE_UP,    KEY_W,     KEY_UP,    JOY_BUTTON_DPAD_UP)
	_add_mapping(MOVE_DOWN,  KEY_S,     KEY_DOWN,  JOY_BUTTON_DPAD_DOWN)
	_add_mapping(MOVE_LEFT,  KEY_A,     KEY_LEFT,  JOY_BUTTON_DPAD_LEFT)
	_add_mapping(MOVE_RIGHT, KEY_D,     KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	_add_mapping(UNDO,       KEY_Z,     KEY_NONE,  JOY_BUTTON_LEFT_SHOULDER)
	_add_mapping(REDO,       KEY_Y,     KEY_NONE,  JOY_BUTTON_RIGHT_SHOULDER)
	_add_mapping(RESTART,    KEY_R,     KEY_NONE,  JOY_BUTTON_BACK)
	_add_mapping(PAUSE,      KEY_ESCAPE, KEY_NONE, JOY_BUTTON_START)

func _apply_default_editor_bindings() -> void:
	_editor_bindings = {
		EDITOR_TOGGLE_BOARD_MODE: { "0": { "key": KEY_TAB }, "2": { "joy": JOY_BUTTON_X } },
		EDITOR_PAINT: { "0": { "key": KEY_ENTER }, "2": { "joy": JOY_BUTTON_A } },
		EDITOR_ERASE: { "0": { "key": KEY_BACKSPACE }, "2": { "joy": JOY_BUTTON_B } },
		EDITOR_TOOL_PREV: { "0": { "key": KEY_Q }, "2": { "joy": JOY_BUTTON_LEFT_SHOULDER } },
		EDITOR_TOOL_NEXT: { "0": { "key": KEY_E }, "2": { "joy": JOY_BUTTON_RIGHT_SHOULDER } },
		EDITOR_COLOR_PREV: { "0": { "key": KEY_BRACKETLEFT }, "2": { "joy": JOY_BUTTON_LEFT_STICK } },
		EDITOR_COLOR_NEXT: { "0": { "key": KEY_BRACKETRIGHT }, "2": { "joy": JOY_BUTTON_RIGHT_STICK } },
		EDITOR_SHAPE_CYCLE: { "0": { "key": KEY_C }, "2": { "joy": JOY_BUTTON_BACK } },
		EDITOR_PAN_MOD: { "0": { "key": KEY_SPACE }, "2": { "joy": JOY_BUTTON_Y } },
		EDITOR_TEST: { "0": { "key": KEY_T }, "2": { "joy": JOY_BUTTON_START } },
	}
	_apply_editor_bindings_to_input_map()

func _add_mapping(action_name: String, primary_key: int, secondary_key: int, joy_button: int) -> void:
	var action: GUIDEAction = _actions.get(action_name)
	if action == null: return
	var am := GUIDEActionMapping.new()
	am.action = action
	if primary_key != KEY_NONE:
		am.input_mappings.append(_make_key_mapping(primary_key))
	if secondary_key != KEY_NONE:
		am.input_mappings.append(_make_key_mapping(secondary_key))
	if joy_button >= 0:
		am.input_mappings.append(_make_joy_mapping(joy_button))
	_ctx.mappings.append(am)

func _make_key_mapping(key: int) -> GUIDEInputMapping:
	var im := GUIDEInputMapping.new()
	im.is_remappable = true
	var input := GUIDEInputKey.new()
	input.key = key as Key
	im.input = input
	im.triggers.append(GUIDETriggerPressed.new())
	return im

func _make_joy_mapping(joy_button: int) -> GUIDEInputMapping:
	var im := GUIDEInputMapping.new()
	im.is_remappable = true
	var input := GUIDEInputJoyButton.new()
	input.button = joy_button as JoyButton
	im.input = input
	im.triggers.append(GUIDETriggerPressed.new())
	return im

# ============================================================
# Gameplay rebinding (slot=0 主键, slot=1 副键, slot=2 手柄)
# ============================================================

func set_binding(action_name: String, slot: int, event: InputEvent) -> bool:
	var am := _find_action_mapping(action_name)
	if am == null: return false
	while am.input_mappings.size() <= slot:
		am.input_mappings.append(_make_key_mapping(KEY_NONE))
	var im: GUIDEInputMapping = _event_to_input_mapping(event)
	if im == null: return false
	am.input_mappings[slot] = im
	_notify_guide_changed()
	return true

func clear_binding(action_name: String, slot: int) -> void:
	var am := _find_action_mapping(action_name)
	if am == null: return
	if slot >= 0 and slot < am.input_mappings.size():
		am.input_mappings[slot] = _make_key_mapping(KEY_NONE)
		_notify_guide_changed()

func reset_all_bindings() -> void:
	_apply_default_bindings()
	_notify_guide_changed()

func get_binding_label(action_name: String, slot: int) -> String:
	var am := _find_action_mapping(action_name)
	if am == null: return ""
	if slot < 0 or slot >= am.input_mappings.size(): return ""
	var im: GUIDEInputMapping = am.input_mappings[slot]
	if im == null or im.input == null: return ""
	if im.input is GUIDEInputKey:
		var k := (im.input as GUIDEInputKey).key
		if k == KEY_NONE: return ""
		return OS.get_keycode_string(k)
	if im.input is GUIDEInputJoyButton:
		var b := (im.input as GUIDEInputJoyButton).button
		return _joy_button_name(b)
	return ""

func find_binding_conflict(action_name: String, event: InputEvent) -> String:
	var probe := _event_to_input_mapping(event)
	if probe == null: return ""
	for am in _ctx.mappings:
		if am.action == null: continue
		var other := String(am.action.name)
		if other == action_name: continue
		for im in am.input_mappings:
			if im == null or im.input == null: continue
			if _input_equal(im.input, probe.input):
				return other
	return ""

func clear_event_from_other(action_name: String, event: InputEvent) -> void:
	var probe := _event_to_input_mapping(event)
	if probe == null: return
	for am in _ctx.mappings:
		if am.action == null: continue
		if String(am.action.name) == action_name: continue
		for slot in am.input_mappings.size():
			var im: GUIDEInputMapping = am.input_mappings[slot]
			if im == null or im.input == null: continue
			if _input_equal(im.input, probe.input):
				am.input_mappings[slot] = _make_key_mapping(KEY_NONE)

func _find_action_mapping(action_name: String) -> GUIDEActionMapping:
	for am in _ctx.mappings:
		if am.action != null and String(am.action.name) == action_name:
			return am
	return null

func _event_to_input_mapping(event: InputEvent) -> GUIDEInputMapping:
	if event is InputEventKey:
		var ke: InputEventKey = event
		var key_code: int = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
		return _make_key_mapping(key_code)
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		return _make_joy_mapping(jb.button_index)
	return null

func _input_equal(a: GUIDEInput, b: GUIDEInput) -> bool:
	if a is GUIDEInputKey and b is GUIDEInputKey:
		return (a as GUIDEInputKey).key == (b as GUIDEInputKey).key
	if a is GUIDEInputJoyButton and b is GUIDEInputJoyButton:
		return (a as GUIDEInputJoyButton).button == (b as GUIDEInputJoyButton).button
	return false

func _notify_guide_changed() -> void:
	var guide: Node = get_node_or_null("/root/GUIDE")
	if guide != null and guide.has_signal("input_mappings_changed"):
		guide.input_mappings_changed.emit()

# ============================================================
# Gameplay binding persistence
# ============================================================

func serialize_bindings() -> Dictionary:
	if _ctx == null:
		return {}
	var out: Dictionary = {}
	for am in _ctx.mappings:
		if am.action == null: continue
		var ent: Dictionary = {}
		for slot in am.input_mappings.size():
			var im: GUIDEInputMapping = am.input_mappings[slot]
			if im == null or im.input == null: continue
			if im.input is GUIDEInputKey:
				var k := (im.input as GUIDEInputKey).key
				if k == KEY_NONE: continue
				ent[str(slot)] = { "key": int(k) }
			elif im.input is GUIDEInputJoyButton:
				var b := (im.input as GUIDEInputJoyButton).button
				ent[str(slot)] = { "joy": int(b) }
		if not ent.is_empty():
			out[String(am.action.name)] = ent
	return out

func deserialize_bindings(data: Dictionary) -> void:
	if _ctx == null:
		return
	if data == null or data.is_empty(): return
	for action_name in data.keys():
		var ent: Dictionary = data[action_name]
		var am := _find_action_mapping(action_name)
		if am == null: continue
		for slot_str in ent.keys():
			var slot := int(slot_str)
			var spec: Dictionary = ent[slot_str]
			while am.input_mappings.size() <= slot:
				am.input_mappings.append(_make_key_mapping(KEY_NONE))
			if spec.has("key"):
				am.input_mappings[slot] = _make_key_mapping(int(spec.key))
			elif spec.has("joy"):
				am.input_mappings[slot] = _make_joy_mapping(int(spec.joy))
	_notify_guide_changed()

# ============================================================
# Editor bindings (走 Godot 原生 InputMap，独立于 gameplay 冲突域)
# ============================================================

func _apply_editor_bindings_to_input_map() -> void:
	for action_name in ALL_EDITOR_ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		else:
			InputMap.action_erase_events(action_name)
		var slots: Dictionary = _editor_bindings.get(action_name, {})
		for slot_str in slots.keys():
			var spec: Dictionary = slots[slot_str]
			var ev: InputEvent = _spec_to_input_event(spec)
			if ev != null:
				InputMap.action_add_event(action_name, ev)

func set_editor_binding(action_name: String, slot: int, event: InputEvent) -> bool:
	if not action_name in ALL_EDITOR_ACTIONS:
		return false
	var slots: Dictionary = _editor_bindings.get(action_name, {})
	if event is InputEventKey:
		var ke: InputEventKey = event
		var key_code: int = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
		slots[str(slot)] = { "key": int(key_code) }
	elif event is InputEventJoypadButton:
		slots[str(slot)] = { "joy": int((event as InputEventJoypadButton).button_index) }
	else:
		return false
	_editor_bindings[action_name] = slots
	_apply_editor_bindings_to_input_map()
	return true

func clear_editor_binding(action_name: String, slot: int) -> void:
	var slots: Dictionary = _editor_bindings.get(action_name, {})
	slots.erase(str(slot))
	_editor_bindings[action_name] = slots
	_apply_editor_bindings_to_input_map()

func reset_all_editor_bindings() -> void:
	_apply_default_editor_bindings()

func get_editor_binding_label(action_name: String, slot: int) -> String:
	var slots: Dictionary = _editor_bindings.get(action_name, {})
	if not slots.has(str(slot)):
		return ""
	var spec: Dictionary = slots[str(slot)]
	if spec.has("key"):
		var k := int(spec["key"])
		if k == KEY_NONE: return ""
		return OS.get_keycode_string(k)
	if spec.has("joy"):
		return _joy_button_name(int(spec["joy"]))
	return ""

func find_editor_binding_conflict(action_name: String, event: InputEvent) -> String:
	var probe_key := -1
	var probe_joy := -1
	if event is InputEventKey:
		var ke: InputEventKey = event
		probe_key = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
	elif event is InputEventJoypadButton:
		probe_joy = (event as InputEventJoypadButton).button_index
	else:
		return ""
	for other_action in ALL_EDITOR_ACTIONS:
		if other_action == action_name: continue
		var slots: Dictionary = _editor_bindings.get(other_action, {})
		for slot_str in slots.keys():
			var spec: Dictionary = slots[slot_str]
			if spec.has("key") and probe_key != -1 and int(spec["key"]) == probe_key:
				return other_action
			if spec.has("joy") and probe_joy != -1 and int(spec["joy"]) == probe_joy:
				return other_action
	return ""

func clear_editor_event_from_other(action_name: String, event: InputEvent) -> void:
	for other_action in ALL_EDITOR_ACTIONS:
		if other_action == action_name: continue
		var slots: Dictionary = _editor_bindings.get(other_action, {})
		var to_remove: Array = []
		for slot_str in slots.keys():
			var spec: Dictionary = slots[slot_str]
			if event is InputEventKey:
				var ke: InputEventKey = event
				var key_code: int = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
				if spec.has("key") and int(spec["key"]) == key_code:
					to_remove.append(slot_str)
			elif event is InputEventJoypadButton:
				if spec.has("joy") and int(spec["joy"]) == int((event as InputEventJoypadButton).button_index):
					to_remove.append(slot_str)
		for s in to_remove:
			slots.erase(s)
		_editor_bindings[other_action] = slots
	_apply_editor_bindings_to_input_map()

func serialize_editor_bindings() -> Dictionary:
	return _editor_bindings.duplicate(true)

func deserialize_editor_bindings(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	for action_name in ALL_EDITOR_ACTIONS:
		if data.has(action_name):
			_editor_bindings[action_name] = data[action_name].duplicate(true)
	_apply_editor_bindings_to_input_map()

# ============================================================
# UI context (走 Godot 原生 InputMap)
# ============================================================

func _apply_default_ui_bindings() -> void:
	_ui_bindings = {
		UI_UP:     { "0": { "key": KEY_UP    }, "1": { "key": KEY_W }, "2": { "joy": JOY_BUTTON_DPAD_UP    } },
		UI_DOWN:   { "0": { "key": KEY_DOWN  }, "1": { "key": KEY_S }, "2": { "joy": JOY_BUTTON_DPAD_DOWN  } },
		UI_LEFT:   { "0": { "key": KEY_LEFT  }, "1": { "key": KEY_A }, "2": { "joy": JOY_BUTTON_DPAD_LEFT  } },
		UI_RIGHT:  { "0": { "key": KEY_RIGHT }, "1": { "key": KEY_D }, "2": { "joy": JOY_BUTTON_DPAD_RIGHT } },
		UI_ACCEPT: { "0": { "key": KEY_ENTER }, "1": { "key": KEY_SPACE }, "2": { "joy": JOY_BUTTON_A } },
		UI_CANCEL: { "0": { "key": KEY_ESCAPE }, "2": { "joy": JOY_BUTTON_B } },
	}
	_apply_ui_bindings_to_input_map()

## 把 _ui_bindings 写回 Godot 的 InputMap，覆盖任何已有的 ui_* 绑定。
func _apply_ui_bindings_to_input_map() -> void:
	for action_name in ALL_UI_ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		else:
			InputMap.action_erase_events(action_name)
		var slots: Dictionary = _ui_bindings.get(action_name, {})
		for slot_str in slots.keys():
			var spec: Dictionary = slots[slot_str]
			var ev: InputEvent = _spec_to_input_event(spec)
			if ev != null:
				InputMap.action_add_event(action_name, ev)

func _spec_to_input_event(spec: Dictionary) -> InputEvent:
	if spec.has("key"):
		var key_code: int = int(spec["key"])
		if key_code == KEY_NONE: return null
		var ke := InputEventKey.new()
		ke.physical_keycode = key_code as Key
		return ke
	if spec.has("joy"):
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(spec["joy"]) as JoyButton
		return jb
	return null

func set_ui_binding(action_name: String, slot: int, event: InputEvent) -> bool:
	if not action_name in ALL_UI_ACTIONS:
		return false
	var slots: Dictionary = _ui_bindings.get(action_name, {})
	if event is InputEventKey:
		var ke: InputEventKey = event
		var key_code: int = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
		slots[str(slot)] = { "key": int(key_code) }
	elif event is InputEventJoypadButton:
		slots[str(slot)] = { "joy": int((event as InputEventJoypadButton).button_index) }
	else:
		return false
	_ui_bindings[action_name] = slots
	_apply_ui_bindings_to_input_map()
	return true

func clear_ui_binding(action_name: String, slot: int) -> void:
	var slots: Dictionary = _ui_bindings.get(action_name, {})
	slots.erase(str(slot))
	_ui_bindings[action_name] = slots
	_apply_ui_bindings_to_input_map()

func reset_all_ui_bindings() -> void:
	_apply_default_ui_bindings()

func get_ui_binding_label(action_name: String, slot: int) -> String:
	var slots: Dictionary = _ui_bindings.get(action_name, {})
	if not slots.has(str(slot)):
		return ""
	var spec: Dictionary = slots[str(slot)]
	if spec.has("key"):
		var k := int(spec["key"])
		if k == KEY_NONE: return ""
		return OS.get_keycode_string(k)
	if spec.has("joy"):
		return _joy_button_name(int(spec["joy"]))
	return ""

func find_ui_binding_conflict(action_name: String, event: InputEvent) -> String:
	var probe_key := -1
	var probe_joy := -1
	if event is InputEventKey:
		var ke: InputEventKey = event
		probe_key = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
	elif event is InputEventJoypadButton:
		probe_joy = (event as InputEventJoypadButton).button_index
	else:
		return ""
	for other_action in ALL_UI_ACTIONS:
		if other_action == action_name: continue
		var slots: Dictionary = _ui_bindings.get(other_action, {})
		for slot_str in slots.keys():
			var spec: Dictionary = slots[slot_str]
			if spec.has("key") and probe_key != -1 and int(spec["key"]) == probe_key:
				return other_action
			if spec.has("joy") and probe_joy != -1 and int(spec["joy"]) == probe_joy:
				return other_action
	return ""

func clear_ui_event_from_other(action_name: String, event: InputEvent) -> void:
	for other_action in ALL_UI_ACTIONS:
		if other_action == action_name: continue
		var slots: Dictionary = _ui_bindings.get(other_action, {})
		var to_remove: Array = []
		for slot_str in slots.keys():
			var spec: Dictionary = slots[slot_str]
			if event is InputEventKey:
				var ke: InputEventKey = event
				var key_code: int = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
				if spec.has("key") and int(spec["key"]) == key_code:
					to_remove.append(slot_str)
			elif event is InputEventJoypadButton:
				if spec.has("joy") and int(spec["joy"]) == int((event as InputEventJoypadButton).button_index):
					to_remove.append(slot_str)
		for s in to_remove:
			slots.erase(s)
		_ui_bindings[other_action] = slots
	_apply_ui_bindings_to_input_map()

# ============================================================
# UI binding persistence
# ============================================================

func serialize_ui_bindings() -> Dictionary:
	# 直接落盘 _ui_bindings 即可（已是字典 of 字典 of 字典）
	return _ui_bindings.duplicate(true)

func deserialize_ui_bindings(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	# 合并：缺失项使用默认绑定
	for action_name in ALL_UI_ACTIONS:
		if data.has(action_name):
			_ui_bindings[action_name] = data[action_name].duplicate(true)
	_apply_ui_bindings_to_input_map()

# ============================================================
# Helpers
# ============================================================

func _joy_button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_LEFT_STICK: return "LS"
		JOY_BUTTON_RIGHT_STICK: return "RS"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_DPAD_UP: return "↑"
		JOY_BUTTON_DPAD_DOWN: return "↓"
		JOY_BUTTON_DPAD_LEFT: return "←"
		JOY_BUTTON_DPAD_RIGHT: return "→"
		_:
			return "Btn%d" % b
