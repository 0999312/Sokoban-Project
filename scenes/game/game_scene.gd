extends Control
## GameScene — 关卡运行容器。
## 实际逻辑在子节点 GameController；本脚本只负责场景级输入回退。

func _unhandled_input(event: InputEvent) -> void:
	# 备用退出（GameController 也监听 pause；这里兜底）
	if event.is_action_pressed("ui_cancel"):
		# 不主动跳转，交给 GameController.pause 行为
		pass
