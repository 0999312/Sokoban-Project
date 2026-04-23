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

## 返回当前设备对应绑定的简短文本，用方括号包裹，如 "[Z]" / "[LB]"。
## 未绑定返回空串。
static func format(action_name: String) -> String:
	var im: Node = _input_manager()
	if im == null: return ""
	var device: int = im.current_device
	var label := ""
	if device == im.DEVICE_GAMEPAD:
		label = im.get_binding_label(action_name, GAMEPAD_SLOT)
	else:
		# 优先主键，缺失时退副键
		for slot in KEYBOARD_FALLBACK_SLOTS:
			label = im.get_binding_label(action_name, slot)
			if label != "":
				break
	if label == "":
		return ""
	return "[%s]" % label

## 返回完整说明文本：tr(label_key) + " " + 提示
static func with_label(label_key: String, action_name: String) -> String:
	var hint := format(action_name)
	if hint == "":
		return TranslationServer.translate(label_key)
	return "%s %s" % [TranslationServer.translate(label_key), hint]

static func _input_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null: return null
	var tree := loop as SceneTree
	if tree == null: return null
	return tree.root.get_node_or_null("InputManager")
