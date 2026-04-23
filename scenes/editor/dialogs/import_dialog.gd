extends Control
## ImportDialog — 关卡导入面板（场景：res://scenes/editor/dialogs/import_dialog.tscn）。
##
## 节点结构（在 .tscn 中静态定义，便于人工检查）：
##   ImportDialog (Control, FULL_RECT)
##     Dim (ColorRect, 半透明遮罩)
##     Card (PanelContainer, 480x300, 居中)
##       Margin / Body (VBox)
##         LblTitle
##         Tabs (TabContainer, 440x150)
##           File:
##             PickRow [LblPath (LineEdit readonly) | BtnBrowse]
##             LblHint
##           Code:
##             LblHintCode
##             EditCode (LineEdit)
##         ButtonRow [BtnCancel | BtnOk]
##
## 行为：
##   - File Tab：BtnBrowse 弹 FileDialog（.json / .xsb / .txt），选中后路径回填到 LblPath
##   - Code Tab：粘贴 share code 到 EditCode
##   - BtnOk：根据当前 Tab 解析为 Level，emit imported(level)
##   - BtnCancel：emit imported(null) 并销毁
##
## 信号：
##   imported(level: Level)  — level 为 null 表示用户取消或解析失败

signal imported(level: Level)

@onready var lbl_title: Label = %LblTitle
@onready var tabs: TabContainer = %Tabs
@onready var lbl_path: LineEdit = %LblPath
@onready var btn_browse: Button = %BtnBrowse
@onready var lbl_hint: Label = %LblHint
@onready var lbl_hint_code: Label = %LblHintCode
@onready var edit_code: LineEdit = %EditCode
@onready var btn_cancel: Button = %BtnCancel
@onready var btn_ok: Button = %BtnOk

var _file_dialog: FileDialog

func _ready() -> void:
	_refresh_texts()

	btn_browse.pressed.connect(_on_browse)
	btn_ok.pressed.connect(_on_ok)
	btn_cancel.pressed.connect(_on_cancel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_cancel()
			get_viewport().set_input_as_handled()

func _refresh_texts() -> void:
	lbl_title.text = tr("editor.dialog.import")
	lbl_hint.text = tr("editor.import.file_hint")
	lbl_hint_code.text = tr("editor.import.code_hint")
	lbl_path.placeholder_text = tr("editor.import.file_path_placeholder")
	btn_browse.text = tr("editor.import.browse")
	btn_ok.text = tr("common.ok")
	btn_cancel.text = tr("common.cancel")
	# Tab 标题（TabContainer 用子节点 name 作为 tab title）
	# 注意：set_tab_title 通过 tab 索引设置，更稳妥
	if tabs.get_tab_count() >= 2:
		tabs.set_tab_title(0, tr("editor.import.file"))
		tabs.set_tab_title(1, tr("editor.import.code"))

func _on_browse() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		return
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.exclusive = false
	_file_dialog.add_filter("*.json", "Sokoban Level (JSON)")
	_file_dialog.add_filter("*.xsb,*.txt", "Sokoban XSB")
	_file_dialog.file_selected.connect(_on_file_picked)
	_file_dialog.canceled.connect(_close_file_dialog)
	add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)

func _on_file_picked(p: String) -> void:
	lbl_path.text = p
	_close_file_dialog()

func _close_file_dialog() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
	_file_dialog = null

func _on_ok() -> void:
	var lvl: Level = _parse_current_tab()
	imported.emit(lvl)
	queue_free()

func _on_cancel() -> void:
	imported.emit(null)
	queue_free()

func _parse_current_tab() -> Level:
	var current := tabs.current_tab
	match current:
		0:  # File
			var p := lbl_path.text.strip_edges()
			if p == "":
				return null
			if p.to_lower().ends_with(".json"):
				return LevelLoader.load_json_file(p)
			# .xsb / .txt
			var f := FileAccess.open(p, FileAccess.READ)
			if f == null:
				return null
			return LevelLoader.parse_xsb(f.get_as_text())
		1:  # Share code
			var c := edit_code.text.strip_edges()
			if c == "":
				return null
			return ShareCode.decode_to_level(c)
	return null
