extends Control
## GameScene — 关卡运行容器。
## 实际逻辑在子节点 GameController；本脚本只负责场景级输入回退与 BGM 切歌。

func _ready() -> void:
	# 切到游戏 BGM
	Sfx.play_bgm("game", 1.0)
	# UI 点击音效（HUD 内全部按钮）
	Sfx.attach_ui(self)

func _unhandled_input(event: InputEvent) -> void:
	# 备用退出（GameController 也监听 pause；这里兜底）
	if event.is_action_pressed("ui_cancel"):
		# 不主动跳转，交给 GameController.pause 行为
		pass
