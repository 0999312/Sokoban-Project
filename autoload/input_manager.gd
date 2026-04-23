extends Node
## InputManager — 全局输入动作 Autoload。
##
## Phase 0 占位：使用 Godot 原生 InputMap（在 project.godot 中预定义）。
## Phase 1 起：迁移到 addons/guide 的 GuideMappingContext，支持运行时重绑。

# Action 名常量（与 project.godot input section 对齐）
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const UNDO := "undo"
const REDO := "redo"
const RESTART := "restart"
const PAUSE := "pause"

func _ready() -> void:
	print("[InputManager] ready (using native InputMap; Guide migration pending)")

func get_move_dir() -> Vector2i:
	if Input.is_action_just_pressed(MOVE_UP):
		return Vector2i(0, -1)
	if Input.is_action_just_pressed(MOVE_DOWN):
		return Vector2i(0, 1)
	if Input.is_action_just_pressed(MOVE_LEFT):
		return Vector2i(-1, 0)
	if Input.is_action_just_pressed(MOVE_RIGHT):
		return Vector2i(1, 0)
	return Vector2i.ZERO
