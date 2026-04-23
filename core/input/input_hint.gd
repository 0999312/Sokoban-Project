class_name InputHint
extends RefCounted
## InputHint — 当前设备 + 当前 GUIDE 绑定 → 友好按键文本。
##
## 用法：
##   var hint := InputHint.format("undo")    # "[Z]" 或 "[LB]"
##   btn.tooltip_text = tr("hud.undo") + " " + hint
##
## 监听 InputManager.device_changed 自动刷新 UI。
##
## v1.0：以纯文本/简写呈现（[Z] [LB] [Esc]）。后续如引入 Kenney Input Prompts 图标集，
## 可改为返回 BBCode `[img]res://...[/img]` 给 RichTextLabel 渲染（接口保持不变）。

const KEYBOARD_FALLBACK_SLOTS := [0, 1]   # 主键 / 副键
const GAMEPAD_SLOT := 2
const _HELP_ACTIONS := ["move_up", "move_down", "move_left", "move_right", "undo", "redo", "restart", "pause"]
const _UI_HELP_MAIN_MENU := ["ui_up", "ui_down", "ui_accept", "ui_cancel"]
const _UI_HELP_LEVEL_SELECT := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]
const _UI_HELP_PAUSE := ["ui_up", "ui_down", "ui_accept", "ui_cancel"]

## 返回当前设备对应绑定的简短文本，用方括号包裹，如 "[Z]" / "[LB]"。
## 未绑定返回空串。
static func format(action_name: String) -> String:
	var im: Node = _input_manager()
	if im == null: return ""
	var device: int = im.current_device
	return _format_for_device(im, action_name, device, true)

static func format_plain(action_name: String) -> String:
	var im: Node = _input_manager()
	if im == null: return ""
	var device: int = im.current_device
	return _format_for_device(im, action_name, device, false)

static func gameplay_help_text() -> String:
	var im: Node = _input_manager()
	if im == null:
		return TranslationServer.translate("hud.help")
	var values: Array = []
	for action_name in _HELP_ACTIONS:
		var label := _format_for_device(im, action_name, im.current_device, true)
		values.append(label if label != "" else "[?]")
	return TranslationServer.translate("hud.help_dynamic").format(values)

static func main_menu_help_text() -> String:
	return _ui_help_text("menu.help_dynamic", _UI_HELP_MAIN_MENU)

static func level_select_help_text() -> String:
	return _ui_help_text("level_select.help_dynamic", _UI_HELP_LEVEL_SELECT)

static func pause_menu_help_text() -> String:
	return _ui_help_text("pause.help_dynamic", _UI_HELP_PAUSE)

## 返回完整说明文本：tr(label_key) + " " + 提示
static func with_label(label_key: String, action_name: String) -> String:
	var hint := format(action_name)
	if hint == "":
		return TranslationServer.translate(label_key)
	return "%s %s" % [TranslationServer.translate(label_key), hint]

static func _format_for_device(im: Node, action_name: String, device: int, with_brackets: bool) -> String:
	var label: String = ""
	if action_name.begins_with("ui_"):
		if device == im.DEVICE_GAMEPAD:
			label = im.get_ui_binding_label(action_name, GAMEPAD_SLOT)
		else:
			label = _first_ui_keyboard_label(im, action_name)
	else:
		if device == im.DEVICE_GAMEPAD:
			label = im.get_binding_label(action_name, GAMEPAD_SLOT)
		else:
			label = _first_gameplay_keyboard_label(im, action_name)
	if label == "":
		return ""
	if with_brackets:
		return "[%s]" % label
	return label

static func _ui_help_text(i18n_key: String, actions: Array) -> String:
	var im: Node = _input_manager()
	if im == null:
		return TranslationServer.translate(i18n_key)
	var values: Array = []
	for action_name in actions:
		var label := _format_for_device(im, String(action_name), im.current_device, true)
		values.append(label if label != "" else "[?]")
	return TranslationServer.translate(i18n_key).format(values)

static func _first_gameplay_keyboard_label(im: Node, action_name: String) -> String:
	for slot in KEYBOARD_FALLBACK_SLOTS:
		var label: String = im.get_binding_label(action_name, slot)
		if label != "":
			return label
	return ""

static func _first_ui_keyboard_label(im: Node, action_name: String) -> String:
	for slot in KEYBOARD_FALLBACK_SLOTS:
		var label: String = im.get_ui_binding_label(action_name, slot)
		if label != "":
			return label
	return ""

static func _input_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null: return null
	var tree := loop as SceneTree
	if tree == null: return null
	return tree.root.get_node_or_null("InputManager")
