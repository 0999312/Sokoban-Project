extends Node
## InputManager — 全局输入动作 Autoload（Phase 5 重写：以 GUIDE 为后端）。
##
## 职责：
##   1. 启动时构建 8 个 GUIDEAction（move_up/down/left/right/undo/redo/restart/pause）
##   2. 构建 gameplay GUIDEMappingContext，每动作绑定键鼠 + 手柄两套
##   3. 设备检测：监听原生 InputEvent → KEYBOARD / GAMEPAD，emit device_changed
##   4. 兼容旧 API：is_action_just_pressed(action) / get_move_dir()
##
## 重绑（P5-F）：在 SettingsPanel 中调用 InputManager.set_binding(action, slot, event)，
## 持久化由 SaveManager 负责；本类只暴露 API。
##
## 设计取舍：
##   - GUIDE 资源用代码构建而非 .tres，避免编辑器依赖；
##   - 仍保留 Godot 原生 InputMap 的 ui_accept/ui_cancel 用于 Godot Control 内置导航；
##   - move 走 GUIDE，方向键 + WASD + DPad + 左摇杆全部映射到对应 move_* action。

signal device_changed(device: int)  ## DEVICE_KEYBOARD / DEVICE_GAMEPAD

# Action 名常量（与历史调用兼容；同时是 GUIDEAction.name）
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const UNDO := "undo"
const REDO := "redo"
const RESTART := "restart"
const PAUSE := "pause"

const ALL_ACTIONS := [
	MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT,
	UNDO, REDO, RESTART, PAUSE,
]

# 设备
enum { DEVICE_KEYBOARD = 0, DEVICE_GAMEPAD = 1 }

var current_device: int = DEVICE_KEYBOARD

# action_name -> GUIDEAction 实例
var _actions: Dictionary = {}
# 当前生效的 mapping context
var _ctx: GUIDEMappingContext = null

func _ready() -> void:
	_build_actions_and_context()
	_apply_default_bindings()
	if Engine.has_singleton("GUIDE") or has_node("/root/GUIDE"):
		var guide: Node = get_node_or_null("/root/GUIDE")
		if guide != null and guide.has_method("enable_mapping_context"):
			guide.enable_mapping_context(_ctx)
			print("[InputManager] GUIDE gameplay context enabled")

func _input(event: InputEvent) -> void:
	# 设备来源检测
	var new_device := current_device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_device = DEVICE_GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		new_device = DEVICE_KEYBOARD
	if new_device != current_device:
		current_device = new_device
		device_changed.emit(current_device)

# --- Public API ---

func get_move_dir() -> Vector2i:
	if is_action_just_pressed(MOVE_UP):    return Vector2i(0, -1)
	if is_action_just_pressed(MOVE_DOWN):  return Vector2i(0, 1)
	if is_action_just_pressed(MOVE_LEFT):  return Vector2i(-1, 0)
	if is_action_just_pressed(MOVE_RIGHT): return Vector2i(1, 0)
	return Vector2i.ZERO

func is_action_just_pressed(action_name: String) -> bool:
	# Pressed trigger 是边沿信号；GUIDEAction.is_triggered() 在单帧返回 true。
	var a: GUIDEAction = _actions.get(action_name)
	if a != null and a.is_triggered():
		return true
	# 兼容回退：项目 project.godot 中可能仍存在同名原生 InputMap action（Phase 0-4 历史）
	if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
		return true
	return false

func get_action(action_name: String) -> GUIDEAction:
	return _actions.get(action_name)

func get_context() -> GUIDEMappingContext:
	return _ctx

# --- Construction ---

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
	# 清空（本函数也用于 Reset to Defaults）
	_ctx.mappings = []
	# 每个 action 一个 ActionMapping，包含 key 与 joypad 两个 input mapping
	_add_mapping(MOVE_UP,    KEY_W,     KEY_UP,    JOY_BUTTON_DPAD_UP)
	_add_mapping(MOVE_DOWN,  KEY_S,     KEY_DOWN,  JOY_BUTTON_DPAD_DOWN)
	_add_mapping(MOVE_LEFT,  KEY_A,     KEY_LEFT,  JOY_BUTTON_DPAD_LEFT)
	_add_mapping(MOVE_RIGHT, KEY_D,     KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	_add_mapping(UNDO,       KEY_Z,     KEY_NONE,  JOY_BUTTON_LEFT_SHOULDER)
	_add_mapping(REDO,       KEY_Y,     KEY_NONE,  JOY_BUTTON_RIGHT_SHOULDER)
	_add_mapping(RESTART,    KEY_R,     KEY_NONE,  JOY_BUTTON_BACK)
	_add_mapping(PAUSE,      KEY_ESCAPE, KEY_NONE, JOY_BUTTON_START)

func _add_mapping(action_name: String, primary_key: int, secondary_key: int, joy_button: int) -> void:
	var action: GUIDEAction = _actions.get(action_name)
	if action == null: return
	var am := GUIDEActionMapping.new()
	am.action = action
	# Slot 0: 主键
	if primary_key != KEY_NONE:
		am.input_mappings.append(_make_key_mapping(primary_key))
	# Slot 1 (额外): 副键（仅方向键有，让 WASD 与方向键同时可用）
	if secondary_key != KEY_NONE:
		am.input_mappings.append(_make_key_mapping(secondary_key))
	# Slot 2: 手柄
	if joy_button >= 0:
		am.input_mappings.append(_make_joy_mapping(joy_button))
	_ctx.mappings.append(am)

func _make_key_mapping(key: int) -> GUIDEInputMapping:
	var im := GUIDEInputMapping.new()
	im.is_remappable = true
	var input := GUIDEInputKey.new()
	input.key = key
	im.input = input
	im.triggers.append(GUIDETriggerPressed.new())
	return im

func _make_joy_mapping(joy_button: int) -> GUIDEInputMapping:
	var im := GUIDEInputMapping.new()
	im.is_remappable = true
	var input := GUIDEInputJoyButton.new()
	input.button = joy_button
	im.input = input
	im.triggers.append(GUIDETriggerPressed.new())
	return im

# --- Rebinding API (P5-F 使用) ---

## 替换某动作某 slot 的绑定。slot=0 主键鼠，slot=1 副键鼠，slot=2 手柄。
## event 必须是 InputEventKey / InputEventMouseButton / InputEventJoypadButton。
## 返回 true 表示成功。
func set_binding(action_name: String, slot: int, event: InputEvent) -> bool:
	var am := _find_action_mapping(action_name)
	if am == null: return false
	# 扩容 slot
	while am.input_mappings.size() <= slot:
		am.input_mappings.append(_make_key_mapping(KEY_NONE))
	var im: GUIDEInputMapping = _event_to_input_mapping(event)
	if im == null: return false
	am.input_mappings[slot] = im
	# 通知 GUIDE 重新构建缓存
	var guide: Node = get_node_or_null("/root/GUIDE")
	if guide != null and guide.has_signal("input_mappings_changed"):
		guide.input_mappings_changed.emit()
	return true

func clear_binding(action_name: String, slot: int) -> void:
	var am := _find_action_mapping(action_name)
	if am == null: return
	if slot >= 0 and slot < am.input_mappings.size():
		am.input_mappings[slot] = _make_key_mapping(KEY_NONE)
		var guide: Node = get_node_or_null("/root/GUIDE")
		if guide != null and guide.has_signal("input_mappings_changed"):
			guide.input_mappings_changed.emit()

func reset_all_bindings() -> void:
	_apply_default_bindings()
	var guide: Node = get_node_or_null("/root/GUIDE")
	if guide != null and guide.has_signal("input_mappings_changed"):
		guide.input_mappings_changed.emit()

## 查询某 action 某 slot 的绑定文本（供 InputHint 使用）
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

# --- Helpers ---

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
	# 鼠标暂不绑定（避免误绑左键）
	return null

func _joy_button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_DPAD_UP: return "↑"
		JOY_BUTTON_DPAD_DOWN: return "↓"
		JOY_BUTTON_DPAD_LEFT: return "←"
		JOY_BUTTON_DPAD_RIGHT: return "→"
		_:
			return "Btn%d" % b

# --- Persistence (用于 SaveManager 存档) ---

## 序列化绑定到字典：{ action_name: { 0: {key=K}, 1: {key=K}, 2: {joy=B} } }
func serialize_bindings() -> Dictionary:
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

## 从存档字典恢复绑定。未提及的 action 维持默认。
func deserialize_bindings(data: Dictionary) -> void:
	if data == null or data.is_empty(): return
	for action_name in data.keys():
		var ent: Dictionary = data[action_name]
		var am := _find_action_mapping(action_name)
		if am == null: continue
		for slot_str in ent.keys():
			var slot := int(slot_str)
			var spec: Dictionary = ent[slot_str]
			# 扩容
			while am.input_mappings.size() <= slot:
				am.input_mappings.append(_make_key_mapping(KEY_NONE))
			if spec.has("key"):
				am.input_mappings[slot] = _make_key_mapping(int(spec.key))
			elif spec.has("joy"):
				am.input_mappings[slot] = _make_joy_mapping(int(spec.joy))
	var guide: Node = get_node_or_null("/root/GUIDE")
	if guide != null and guide.has_signal("input_mappings_changed"):
		guide.input_mappings_changed.emit()

## 检查给定 InputEvent 是否已被其他 action 占用，返回占用它的 action 名（或 ""）
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

func _input_equal(a: GUIDEInput, b: GUIDEInput) -> bool:
	if a is GUIDEInputKey and b is GUIDEInputKey:
		return (a as GUIDEInputKey).key == (b as GUIDEInputKey).key
	if a is GUIDEInputJoyButton and b is GUIDEInputJoyButton:
		return (a as GUIDEInputJoyButton).button == (b as GUIDEInputJoyButton).button
	return false

## 当冲突时强行清除其他 action 该绑定槽
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
