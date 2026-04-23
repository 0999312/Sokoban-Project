extends Control
## ExportDialog — 关卡导出面板（场景：res://scenes/editor/dialogs/export_dialog.tscn）。
##
## 节点结构（在 .tscn 中静态定义，便于人工检查）：
##   ExportDialog (Control, FULL_RECT)
##     Dim (ColorRect, 半透明遮罩)
##     Card (PanelContainer, 560x460, 居中)
##       Margin / Body (VBox)
##         LblTitle / HSep1
##         Tabs (TabContainer, 520x320)
##           JSON: EditJson (TextEdit, 固定 240px 高) + [Copy | Save]
##           XSB:  EditXsb (TextEdit, 固定 240px 高) + [Copy | Save]
##           Code: LblHintCode + EditCode (TextEdit, 固定 200px 高) + [Copy]
##           Thumb: LblHintThumb + [Save PNG]
##         HSep2 / ButtonRow [Spacer | BtnClose]
##
## 所有 TextEdit 都带固定 custom_minimum_size，自身内置滚动条；
## 长文本不会撑大对话框（Card 固定 560×460）。
##
## 使用方式：
##   var dlg := preload(".tscn").instantiate()
##   dlg.set_level(level, board_node)
##   dialog_layer.add_child(dlg)

@onready var lbl_title: Label = %LblTitle
@onready var tabs: TabContainer = %Tabs
@onready var edit_json: TextEdit = %EditJson
@onready var edit_xsb: TextEdit = %EditXsb
@onready var edit_code: TextEdit = %EditCode
@onready var lbl_hint_code: Label = %LblHintCode
@onready var lbl_hint_thumb: Label = %LblHintThumb
@onready var btn_copy_json: Button = %BtnCopyJson
@onready var btn_save_json: Button = %BtnSaveJson
@onready var btn_copy_xsb: Button = %BtnCopyXsb
@onready var btn_save_xsb: Button = %BtnSaveXsb
@onready var btn_copy_code: Button = %BtnCopyCode
@onready var btn_save_thumb: Button = %BtnSaveThumb
@onready var btn_close: Button = %BtnClose
@onready var dim: ColorRect = $Dim

var _level: Level
var _board_node: Node2D    # 用于截图的源（EditorBoard，可空 → 缩略图按钮禁用）
var _file_dialog: FileDialog

func set_level(level: Level, source_board: Node2D = null) -> void:
	_level = level
	_board_node = source_board

func _ready() -> void:
	_refresh_texts()
	_populate_contents()

	btn_copy_json.pressed.connect(func(): DisplayServer.clipboard_set(edit_json.text))
	btn_save_json.pressed.connect(func(): _save_text_dialog(edit_json.text, "level.json", "*.json"))
	btn_copy_xsb.pressed.connect(func(): DisplayServer.clipboard_set(edit_xsb.text))
	btn_save_xsb.pressed.connect(func(): _save_text_dialog(edit_xsb.text, "level.xsb", "*.xsb"))
	btn_copy_code.pressed.connect(func(): DisplayServer.clipboard_set(edit_code.text))
	btn_save_thumb.pressed.connect(_on_save_thumbnail)
	btn_close.pressed.connect(_on_close)
	dim.gui_input.connect(_on_dim_input)
	btn_close.grab_focus.call_deferred()

	if _board_node == null:
		btn_save_thumb.disabled = true

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()

func _refresh_texts() -> void:
	lbl_title.text = tr("editor.dialog.export")
	lbl_hint_code.text = tr("editor.export.share_hint")
	lbl_hint_thumb.text = tr("editor.export.thumbnail_hint")
	btn_copy_json.text = tr("editor.export.copy")
	btn_copy_xsb.text = tr("editor.export.copy")
	btn_copy_code.text = tr("editor.export.copy")
	btn_save_json.text = tr("editor.export.save_file")
	btn_save_xsb.text = tr("editor.export.save_file")
	btn_save_thumb.text = tr("editor.export.save_thumbnail")
	btn_close.text = tr("common.close")
	if tabs.get_tab_count() >= 4:
		tabs.set_tab_title(0, "JSON")
		tabs.set_tab_title(1, "XSB")
		tabs.set_tab_title(2, tr("editor.export.share"))
		tabs.set_tab_title(3, tr("editor.export.thumbnail"))

func _populate_contents() -> void:
	if _level == null:
		return
	edit_json.text = LevelLoader.to_json(_level, true)
	edit_xsb.text = LevelLoader.to_xsb(_level)
	edit_code.text = ShareCode.encode_level(_level)

func _on_close() -> void:
	queue_free()

# ---------------------------- 文件保存 ----------------------------

func _save_text_dialog(content: String, default_name: String, filter: String) -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		return
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.exclusive = false
	_file_dialog.current_file = default_name
	_file_dialog.add_filter(filter)
	_file_dialog.file_selected.connect(func(p):
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_string(content)
			f.close()
		_close_file_dialog()
	)
	_file_dialog.canceled.connect(_close_file_dialog)
	add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)

func _close_file_dialog() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
	_file_dialog = null

# ---------------------------- 缩略图导出 ----------------------------

func _on_save_thumbnail() -> void:
	if _board_node == null:
		return
	var img: Image = await _render_board_to_image()
	if img == null:
		return
	if _file_dialog != null and is_instance_valid(_file_dialog):
		return
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.exclusive = false
	_file_dialog.current_file = "thumbnail.png"
	_file_dialog.add_filter("*.png", "PNG Image")
	_file_dialog.file_selected.connect(func(p):
		img.save_png(p)
		_close_file_dialog()
	)
	_file_dialog.canceled.connect(_close_file_dialog)
	add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)

func _render_board_to_image() -> Image:
	const TILE := 48
	var w: int = _level.width * TILE
	var h: int = _level.height * TILE
	# SubViewport 必须挂在 SubViewportContainer 内才能保持稳定的渲染目标关系。
	# 直接挂到 Control 下会出现 ViewportTexture 解析失败 / "Path to node is invalid" 报错。
	var container := SubViewportContainer.new()
	container.stretch = false
	container.visible = false   # 不要显示在导出对话框里
	container.size = Vector2(w, h)
	add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	const EditorBoardScript = preload("res://scenes/editor/editor_board.gd")
	var model := EditorModel.new(_level.width, _level.height)
	model.load_from_level(_level)
	var brd := EditorBoardScript.new()
	brd.editor = null
	brd.model = model
	brd.position = Vector2.ZERO
	vp.add_child(brd)
	# 等待两帧确保渲染完成
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	var img: Image = tex.get_image()
	container.queue_free()
	return img
