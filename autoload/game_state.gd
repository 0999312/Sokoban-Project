extends Node
## GameState — 全局游戏状态 Autoload。
##
## 职责：
##   - 持有当前选中的关卡 ID / 关卡数据
##   - 缓存设置（音量、语言、键位）的运行时副本
##   - 协调场景跳转（封装 SceneTree.change_scene_to_*)
##
## 依赖：EventBus / SaveManager / I18NManager
##
## Phase 0 占位：仅暴露最小 API，待 Phase 1/2 填充。

signal current_level_changed(level_id: String)

const SCENE_BOOT := "res://scenes/boot/Boot.tscn"
const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/level_select/LevelSelect.tscn"
const SCENE_GAME := "res://scenes/game/GameScene.tscn"
const SCENE_EDITOR := "res://scenes/editor/EditorScene.tscn"

var current_level_id: String = ""

func _ready() -> void:
	print("[GameState] ready")

func set_current_level(level_id: String) -> void:
	if current_level_id == level_id:
		return
	current_level_id = level_id
	current_level_changed.emit(level_id)

func goto_main_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func goto_level_select() -> void:
	get_tree().change_scene_to_file(SCENE_LEVEL_SELECT)

func goto_game(level_id: String) -> void:
	set_current_level(level_id)
	get_tree().change_scene_to_file(SCENE_GAME)

func goto_editor() -> void:
	get_tree().change_scene_to_file(SCENE_EDITOR)

func quit_game() -> void:
	get_tree().quit()
