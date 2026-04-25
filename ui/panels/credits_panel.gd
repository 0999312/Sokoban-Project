extends Control
## CreditsPanel — 制作人员面板（覆盖层）。
## 固定面板大小，过长内容在 ScrollContainer 内滚动。

@onready var dim: ColorRect = %Dim
@onready var lbl_title: Label = %LblTitle
@onready var btn_back: Button = %BtnBack
@onready var lbl_credits: Label = %LblCredits

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim.gui_input.connect(_on_dim_input)
	btn_back.pressed.connect(_close)
	_refresh_texts()
	if EventBus and EventBus.has_method("subscribe"):
		EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))
	Sfx.attach_ui(self)

func _exit_tree() -> void:
	if EventBus and EventBus.has_method("unsubscribe"):
		EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _on_lang_changed(_e) -> void:
	_refresh_texts()

func _refresh_texts() -> void:
	lbl_title.text = tr("credits.title")
	btn_back.text = tr("settings.back")
	lbl_credits.text = tr("credits.content")

func _close() -> void:
	queue_free()
