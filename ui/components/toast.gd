class_name Toast
extends Control
## Toast — 屏幕底部短暂提示。
## 用法：Toast.show_text(self.get_tree().current_scene, "已保存")

const DEFAULT_DURATION := 1.6

@onready var _label: Label = $Panel/Margin/Label
@onready var _panel: PanelContainer = $Panel

var _duration: float = DEFAULT_DURATION
var _text: String = ""

static func show_text(host: Node, text: String, duration: float = DEFAULT_DURATION) -> void:
	if host == null:
		return
	var t := load("res://ui/components/toast.tscn").instantiate() as Toast
	t._text = text
	t._duration = duration
	host.add_child(t)

func _ready() -> void:
	_label.text = _text
	_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(_duration)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.30)
	tw.tween_callback(queue_free)
