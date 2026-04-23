extends Control
## EditorScene — 关卡编辑器主控（Phase 4）。
##
## 节点结构：
##   EditorScene (Control, FULL_RECT)
##     VBoxContainer
##       TopBar (HBoxContainer)            ## 新建/打开/保存/导入/导出/测试/验证/退出
##       HSplitContainer
##         VBoxContainer (left, 200px)
##           PaletteHeader (Label)
##           PaletteTools (GridContainer)  ## 选择/橡皮/墙/地板/目标/箱子/玩家
##           PaletteShape (HBoxContainer)  ## 单格 / 矩形 / 直线
##           PaletteColor (GridContainer)  ## 0..5 颜色
##           PaletteSize (Container)       ## width/height SpinBox
##           PaletteTheme (Container)      ## wall / floor 主题
##         HSplitContainer
##           BoardHost (Center)            ## 内含 Camera2D + EditorBoard
##           VBoxContainer (right, 280px)
##             MetaPanel                   ## id/name/author/difficulty/tags
##             StatsPanel                  ## 箱子/目标/玩家计数
##     StatusBar (Label)
##     CanvasLayer DialogLayer            ## Import/Export/Solver/Toast 弹层
##     CanvasLayer PlaytestLayer          ## Playtest 子场景容器
##
## 由代码动态构建（避免维护复杂 .tscn）。
##
## 颜色调色板：
##   工具是"墙/地板/目标/箱子"时，颜色面板对应 holder 颜色（0..5）或箱子颜色（1..5）。
##   - 选择箱子：颜色 1..5 决定放下的箱子颜色
##   - 选择目标：颜色 0..5 决定 holder 颜色（0=中性槽）
##   - 其他工具：颜色面板灰显

const EditorBoardScript = preload("res://scenes/editor/editor_board.gd")
const ImportDialogScene = preload("res://scenes/editor/dialogs/import_dialog.tscn")
const ExportDialogScene = preload("res://scenes/editor/dialogs/export_dialog.tscn")
const SolverDialogScript = preload("res://scenes/editor/dialogs/solver_dialog.gd")
const PlaytestScript = preload("res://scenes/editor/playtest.gd")

enum Tool { SELECT, ERASER, WALL, FLOOR, GOAL, BOX, PLAYER }
enum Shape { SINGLE, RECT, LINE }

const TOOL_LABELS := {
	Tool.SELECT: "editor.tool.select",
	Tool.ERASER: "editor.tool.eraser",
	Tool.WALL: "editor.tool.wall",
	Tool.FLOOR: "editor.tool.floor",
	Tool.GOAL: "editor.tool.goal",
	Tool.BOX: "editor.tool.box",
	Tool.PLAYER: "editor.tool.player",
}
const SHAPE_LABELS := {
	Shape.SINGLE: "editor.shape.single",
	Shape.RECT: "editor.shape.rect",
	Shape.LINE: "editor.shape.line",
}

var model: EditorModel
var undo_stack: UndoStack
var dirty: bool = false

var current_tool: int = Tool.WALL
var current_shape: int = Shape.SINGLE
var current_color: int = Cell.DEFAULT_COLOR    # 0..5
var _suppress_size_signal: bool = false        # 加载关卡时临时屏蔽 SpinBox 反向触发 resize

# UI refs
var board: Node2D                  # EditorBoard
var status_label: Label
var dialog_layer: CanvasLayer
var playtest_layer: CanvasLayer
var tool_buttons: Dictionary = {}
var shape_buttons: Dictionary = {}
var color_buttons: Dictionary = {}
var meta_name_edit: LineEdit
var meta_author_edit: LineEdit
var meta_difficulty_spin: SpinBox
var meta_tags_edit: LineEdit
var size_w_spin: SpinBox
var size_h_spin: SpinBox
var theme_wall_btn: OptionButton
var theme_floor_btn: OptionButton
var stats_label: Label
var btn_save: Button
var btn_test: Button
var btn_verify: Button

func _ready() -> void:
	model = EditorModel.new(8, 6)
	undo_stack = UndoStack.new()
	# 默认草图：四周墙
	_apply_starter_template()
	_build_ui()
	_refresh_all()
	EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))
	# UI 点击音效（_build_ui 已构建完按钮树）
	Sfx.attach_ui(self)

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _on_lang_changed(_e) -> void:
	_refresh_texts()

func _apply_starter_template() -> void:
	# 全部 OUTSIDE → 中央 6x4 floor + 四周一圈墙
	for y in model.height:
		for x in model.width:
			model.tiles[y][x] = Cell.Type.OUTSIDE
	for y in range(1, model.height - 1):
		for x in range(1, model.width - 1):
			model.tiles[y][x] = Cell.Type.FLOOR
	for x in model.width:
		model.tiles[0][x] = Cell.Type.WALL
		model.tiles[model.height - 1][x] = Cell.Type.WALL
	for y in model.height:
		model.tiles[y][0] = Cell.Type.WALL
		model.tiles[y][model.width - 1] = Cell.Type.WALL

# ---------------------------- UI 构建 ----------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root_v := VBoxContainer.new()
	root_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_v)

	# Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.custom_minimum_size = Vector2(0, 40)
	root_v.add_child(top)
	var btn_new := Button.new(); btn_new.pressed.connect(_on_new); top.add_child(btn_new); _label_keyed(btn_new, "editor.top.new")
	var btn_open := Button.new(); btn_open.pressed.connect(_on_open); top.add_child(btn_open); _label_keyed(btn_open, "editor.top.open")
	btn_save = Button.new(); btn_save.pressed.connect(_on_save); top.add_child(btn_save); _label_keyed(btn_save, "editor.top.save")
	top.add_child(VSeparator.new())
	var btn_import := Button.new(); btn_import.pressed.connect(_on_import); top.add_child(btn_import); _label_keyed(btn_import, "editor.top.import")
	var btn_export := Button.new(); btn_export.pressed.connect(_on_export); top.add_child(btn_export); _label_keyed(btn_export, "editor.top.export")
	top.add_child(VSeparator.new())
	btn_test = Button.new(); btn_test.pressed.connect(_on_test_play); top.add_child(btn_test); _label_keyed(btn_test, "editor.top.test")
	btn_verify = Button.new(); btn_verify.pressed.connect(_on_verify); top.add_child(btn_verify); _label_keyed(btn_verify, "editor.top.verify")
	# spacer
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	var btn_undo := Button.new(); btn_undo.pressed.connect(_on_undo); top.add_child(btn_undo); _label_keyed(btn_undo, "editor.top.undo")
	var btn_redo := Button.new(); btn_redo.pressed.connect(_on_redo); top.add_child(btn_redo); _label_keyed(btn_redo, "editor.top.redo")
	top.add_child(VSeparator.new())
	var btn_quit := Button.new(); btn_quit.pressed.connect(_on_quit); top.add_child(btn_quit); _label_keyed(btn_quit, "editor.top.quit")

	# Mid HSplit
	var mid := HBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	root_v.add_child(mid)

	# Left palette (放进 ScrollContainer 防止小窗口下被裁切)
	var left_inner := _build_palette()
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(230, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_inner)
	mid.add_child(left_scroll)

	# Center board host
	var board_host := Panel.new()
	board_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_host.clip_contents = true
	mid.add_child(board_host)
	board = EditorBoardScript.new()
	board.editor = self
	board.set_model(model)
	board_host.add_child(board)

	# Right meta（同样放进 ScrollContainer）
	var right_inner := _build_meta_panel()
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(290, 0)
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_inner)
	mid.add_child(right_scroll)

	# Status bar
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 24)
	root_v.add_child(status_label)

	dialog_layer = CanvasLayer.new()
	add_child(dialog_layer)
	playtest_layer = CanvasLayer.new()
	playtest_layer.layer = 5
	add_child(playtest_layer)

func _label_keyed(b: Button, key: String) -> void:
	b.set_meta("i18n_key", key)

func _build_palette() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	# Tools
	var lbl_tools := Label.new(); lbl_tools.set_meta("i18n_key", "editor.palette.tools"); v.add_child(lbl_tools)
	var grid_tools := GridContainer.new(); grid_tools.columns = 4
	grid_tools.add_theme_constant_override("h_separation", 4)
	grid_tools.add_theme_constant_override("v_separation", 4)
	v.add_child(grid_tools)
	for t in [Tool.SELECT, Tool.ERASER, Tool.WALL, Tool.FLOOR, Tool.GOAL, Tool.BOX, Tool.PLAYER]:
		var b := Button.new()
		b.toggle_mode = true
		b.set_meta("i18n_key", TOOL_LABELS[t])
		b.custom_minimum_size = Vector2(50, 36)
		b.pressed.connect(func(): _set_tool(t))
		grid_tools.add_child(b)
		tool_buttons[t] = b
	# Shapes
	var lbl_shapes := Label.new(); lbl_shapes.set_meta("i18n_key", "editor.palette.shapes"); v.add_child(lbl_shapes)
	var hb_shape := HBoxContainer.new(); v.add_child(hb_shape)
	for s in [Shape.SINGLE, Shape.RECT, Shape.LINE]:
		var b := Button.new()
		b.toggle_mode = true
		b.set_meta("i18n_key", SHAPE_LABELS[s])
		b.custom_minimum_size = Vector2(60, 28)
		b.pressed.connect(func(): _set_shape(s))
		hb_shape.add_child(b)
		shape_buttons[s] = b
	# Colors
	var lbl_color := Label.new(); lbl_color.set_meta("i18n_key", "editor.palette.colors"); v.add_child(lbl_color)
	var grid_color := GridContainer.new(); grid_color.columns = 6
	v.add_child(grid_color)
	var color_swatches := [
		Color(0.55, 0.55, 0.55), # neutral
		Color(0.85, 0.30, 0.30), # red
		Color(0.85, 0.70, 0.30), # yellow
		Color(0.30, 0.65, 0.85), # blue
		Color(0.55, 0.80, 0.40), # green
		Color(0.75, 0.45, 0.85), # purple
	]
	for c in range(0, Cell.MAX_COLOR + 1):
		var b := Button.new()
		b.toggle_mode = true
		b.text = str(c) if c > 0 else "·"
		# 通过 meta 标记 tooltip i18n key（在 _refresh_texts 中应用）
		b.set_meta("i18n_tooltip_key", "editor.color.neutral" if c == 0 else "editor.color.colored")
		b.set_meta("i18n_tooltip_args", [c])
		b.custom_minimum_size = Vector2(28, 28)
		b.modulate = color_swatches[c]
		b.pressed.connect(func(): _set_color(c))
		grid_color.add_child(b)
		color_buttons[c] = b
	# Size
	var lbl_size := Label.new(); lbl_size.set_meta("i18n_key", "editor.palette.size"); v.add_child(lbl_size)
	var hb_size := HBoxContainer.new(); v.add_child(hb_size)
	size_w_spin = SpinBox.new()
	size_w_spin.min_value = EditorModel.MIN_SIZE
	size_w_spin.max_value = EditorModel.MAX_SIZE
	size_w_spin.value = model.width
	size_w_spin.value_changed.connect(func(v): _on_size_changed())
	hb_size.add_child(size_w_spin)
	var lblx := Label.new(); lblx.text = "x"; hb_size.add_child(lblx)
	size_h_spin = SpinBox.new()
	size_h_spin.min_value = EditorModel.MIN_SIZE
	size_h_spin.max_value = EditorModel.MAX_SIZE
	size_h_spin.value = model.height
	size_h_spin.value_changed.connect(func(v): _on_size_changed())
	hb_size.add_child(size_h_spin)
	# Theme
	var lbl_theme := Label.new(); lbl_theme.set_meta("i18n_key", "editor.palette.theme"); v.add_child(lbl_theme)
	theme_wall_btn = OptionButton.new()
	for w in Level.ALLOWED_WALL_THEMES:
		theme_wall_btn.add_item(w)
	theme_wall_btn.item_selected.connect(func(i): model.meta["wall_theme"] = Level.ALLOWED_WALL_THEMES[i]; _mark_dirty(); board.queue_redraw())
	v.add_child(theme_wall_btn)
	theme_floor_btn = OptionButton.new()
	for f in Level.ALLOWED_FLOOR_THEMES:
		theme_floor_btn.add_item(f)
	theme_floor_btn.item_selected.connect(func(i): model.meta["floor_theme"] = Level.ALLOWED_FLOOR_THEMES[i]; _mark_dirty(); board.queue_redraw())
	v.add_child(theme_floor_btn)

	return v

func _build_meta_panel() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)

	var lbl_title := Label.new(); lbl_title.set_meta("i18n_key", "editor.meta.title"); v.add_child(lbl_title)

	var lbl_name := Label.new(); lbl_name.set_meta("i18n_key", "editor.meta.name"); v.add_child(lbl_name)
	meta_name_edit = LineEdit.new(); meta_name_edit.text = String(model.meta.get("name", ""))
	meta_name_edit.text_changed.connect(func(t): model.meta["name"] = t; _mark_dirty())
	v.add_child(meta_name_edit)

	var lbl_author := Label.new(); lbl_author.set_meta("i18n_key", "editor.meta.author"); v.add_child(lbl_author)
	meta_author_edit = LineEdit.new(); meta_author_edit.text = String(model.meta.get("author", ""))
	meta_author_edit.text_changed.connect(func(t): model.meta["author"] = t; _mark_dirty())
	v.add_child(meta_author_edit)

	var lbl_diff := Label.new(); lbl_diff.set_meta("i18n_key", "editor.meta.difficulty"); v.add_child(lbl_diff)
	meta_difficulty_spin = SpinBox.new()
	meta_difficulty_spin.min_value = 1; meta_difficulty_spin.max_value = 5; meta_difficulty_spin.value = int(model.meta.get("difficulty", 1))
	meta_difficulty_spin.value_changed.connect(func(v): model.meta["difficulty"] = int(v); _mark_dirty())
	v.add_child(meta_difficulty_spin)

	var lbl_tags := Label.new(); lbl_tags.set_meta("i18n_key", "editor.meta.tags"); v.add_child(lbl_tags)
	meta_tags_edit = LineEdit.new()
	meta_tags_edit.set_meta("i18n_placeholder_key", "editor.meta.tags_placeholder")
	meta_tags_edit.text = ",".join(model.meta.get("tags", []) as Array)
	meta_tags_edit.text_changed.connect(_on_tags_changed)
	v.add_child(meta_tags_edit)

	v.add_child(HSeparator.new())
	var lbl_stats := Label.new(); lbl_stats.set_meta("i18n_key", "editor.meta.stats"); v.add_child(lbl_stats)
	stats_label = Label.new(); stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stats_label)

	return v

func _on_tags_changed(t: String) -> void:
	var parts: Array = []
	for s in t.split(","):
		var x := s.strip_edges()
		if x != "": parts.append(x)
	model.meta["tags"] = parts
	_mark_dirty()

# ---------------------------- 状态/刷新 ----------------------------

func _set_tool(t: int) -> void:
	current_tool = t
	for k in tool_buttons.keys():
		tool_buttons[k].button_pressed = (k == t)
	_refresh_color_panel()

func _set_shape(s: int) -> void:
	current_shape = s
	for k in shape_buttons.keys():
		shape_buttons[k].button_pressed = (k == s)

func _set_color(c: int) -> void:
	current_color = c
	for k in color_buttons.keys():
		color_buttons[k].button_pressed = (k == c)

func _refresh_color_panel() -> void:
	# 颜色 0 仅在工具=GOAL 时启用
	var enable_neutral: bool = (current_tool == Tool.GOAL)
	var enable_any: bool = (current_tool in [Tool.GOAL, Tool.BOX])
	for k in color_buttons.keys():
		var b: Button = color_buttons[k]
		if k == 0:
			b.disabled = not enable_neutral
		else:
			b.disabled = not enable_any
	# 若当前色被禁用，自动跳到 1
	if current_color == 0 and not enable_neutral:
		_set_color(Cell.DEFAULT_COLOR)
	if not enable_any:
		# 颜色面板灰显，无强制选中需要
		pass

func _refresh_all() -> void:
	_set_tool(current_tool)
	_set_shape(current_shape)
	_set_color(current_color)
	_refresh_color_panel()
	# Theme dropdowns
	theme_wall_btn.select(Level.ALLOWED_WALL_THEMES.find(String(model.meta.get("wall_theme", "brick"))))
	theme_floor_btn.select(Level.ALLOWED_FLOOR_THEMES.find(String(model.meta.get("floor_theme", "grass"))))
	board.set_model(model)
	board.queue_redraw()
	_refresh_stats()
	_refresh_texts()

func _refresh_texts() -> void:
	# Walk children, replace text for nodes carrying i18n_key meta
	_apply_i18n_recursive(self)
	if status_label != null:
		status_label.text = tr("editor.status.idle")

func _apply_i18n_recursive(n: Node) -> void:
	if n.has_meta("i18n_key"):
		var k: String = String(n.get_meta("i18n_key"))
		if n is Button or n is Label or n is CheckBox:
			n.text = tr(k)
	if n.has_meta("i18n_tooltip_key") and n is Control:
		var tk: String = String(n.get_meta("i18n_tooltip_key"))
		var s: String = tr(tk)
		if n.has_meta("i18n_tooltip_args"):
			var args: Array = n.get_meta("i18n_tooltip_args")
			s = s.format(args)
		(n as Control).tooltip_text = s
	if n.has_meta("i18n_placeholder_key") and n is LineEdit:
		(n as LineEdit).placeholder_text = tr(String(n.get_meta("i18n_placeholder_key")))
	for c in n.get_children():
		_apply_i18n_recursive(c)

func _refresh_stats() -> void:
	if stats_label == null: return
	var n_box := model.count_boxes()
	var n_goal := model.count_goals()
	var has_player := (model.player_pos != Vector2i(-1, -1))
	stats_label.text = tr("editor.meta.stats_fmt").format([n_box, n_goal, "Yes" if has_player else "No"])

func _mark_dirty() -> void:
	dirty = true
	_refresh_stats()

func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

# ---------------------------- 工具应用 ----------------------------

## 由 EditorBoard 在拖拽/点击时调用：
##   action_kind = "drag"|"commit"
##   shape_path  = Array[Vector2i] （需要应用的格子集合）
##
## 这里把所有"待修改格"按 current_tool 转换为 EditCommand 的 changes，
## 然后 push 到 undo_stack。
func apply_tool_action(cells: Array) -> void:
	if cells.is_empty():
		return
	var cmd := EditCommand.new()
	# 玩家全局唯一：若工具是 PLAYER，先记录全局 player_before
	if current_tool == Tool.PLAYER:
		cmd.player_before = model.player_pos
	# 处理 selectable / unique cells
	var seen: Dictionary = {}
	for p in cells:
		if seen.has(p): continue
		seen[p] = true
		if not model._in_bounds(p):
			continue
		var before := model.snapshot_cell(p)
		_apply_tool_to_cell(p)
		var after := model.snapshot_cell(p)
		if not _snap_equal(before, after):
			cmd.add_change(p, before, after)
	if current_tool == Tool.PLAYER:
		cmd.player_after = model.player_pos
		# 若旧位置有玩家，BoardEditor 视作 same change set；player_pos 已经被 model.write_cell 更新
	if cmd.is_empty():
		return
	undo_stack.push(cmd)
	_mark_dirty()
	board.queue_redraw()

static func _snap_equal(a: Dictionary, b: Dictionary) -> bool:
	for k in ["tile", "box", "box_color", "holder_color", "player"]:
		if a.get(k) != b.get(k):
			return false
	return true

func _apply_tool_to_cell(p: Vector2i) -> void:
	match current_tool:
		Tool.SELECT:
			pass
		Tool.ERASER:
			# 清回 OUTSIDE，自动清除 box/holder/player
			model.write_cell(p, { "tile": Cell.Type.OUTSIDE })
		Tool.WALL:
			model.write_cell(p, { "tile": Cell.Type.WALL })
		Tool.FLOOR:
			# 不擦除已有箱子/玩家
			model.tiles[p.y][p.x] = Cell.Type.FLOOR
			model.holder_colors.erase(p)
		Tool.GOAL:
			model.tiles[p.y][p.x] = Cell.Type.GOAL
			model.holder_colors[p] = Cell.sanitize_holder_color(current_color)
		Tool.BOX:
			# 需要先有可走地形
			var t: int = model.get_tile(p)
			if t != Cell.Type.FLOOR and t != Cell.Type.GOAL:
				model.tiles[p.y][p.x] = Cell.Type.FLOOR
			model.write_cell(p, { "box": true, "box_color": Cell.sanitize_box_color(maxi(current_color, 1)) })
		Tool.PLAYER:
			# 先确保地形
			var t2: int = model.get_tile(p)
			if t2 != Cell.Type.FLOOR and t2 != Cell.Type.GOAL:
				model.tiles[p.y][p.x] = Cell.Type.FLOOR
			model.write_cell(p, { "player": true })

# ---------------------------- 顶部按钮 ----------------------------

func _on_undo() -> void:
	var cmd: EditCommand = undo_stack.pop_undo()
	if cmd == null: return
	cmd.revert_on(model)
	_mark_dirty()
	board.queue_redraw()
	set_status(tr("editor.status.undone"))

func _on_redo() -> void:
	var cmd: EditCommand = undo_stack.pop_redo()
	if cmd == null: return
	cmd.apply_to(model)
	_mark_dirty()
	board.queue_redraw()
	set_status(tr("editor.status.redone"))

func _on_new() -> void:
	# 直接重置；如有未保存修改，请先 Ctrl+S
	model = EditorModel.new(8, 6)
	undo_stack = UndoStack.new()
	_apply_starter_template()
	dirty = false
	_sync_size_spins_from_model()
	meta_name_edit.text = ""
	meta_author_edit.text = ""
	meta_difficulty_spin.value = 1
	meta_tags_edit.text = ""
	_refresh_all()
	set_status(tr("editor.status.new"))

func _on_open() -> void:
	# 弹出 user 关卡列表
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = tr("editor.dialog.open")
	dlg.dialog_hide_on_ok = false
	var v := VBoxContainer.new()
	dlg.add_child(v)
	var lbl := Label.new(); lbl.text = tr("editor.dialog.open_hint"); v.add_child(lbl)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(360, 240)
	v.add_child(list)
	var ids := UserLevelStore.list_user_level_ids()
	for id in ids:
		list.add_item(id)
	dlg.confirmed.connect(func():
		var sel := list.get_selected_items()
		if sel.is_empty(): return
		var id: String = ids[sel[0]]
		var lvl := UserLevelStore.load_level(id)
		if lvl == null:
			set_status(tr("editor.status.load_failed"))
			dlg.queue_free()
			return
		model.load_from_level(lvl)
		undo_stack = UndoStack.new()
		dirty = false
		_sync_size_spins_from_model()
		meta_name_edit.text = String(model.meta.get("name", ""))
		meta_author_edit.text = String(model.meta.get("author", ""))
		meta_difficulty_spin.value = int(model.meta.get("difficulty", 1))
		meta_tags_edit.text = ",".join(model.meta.get("tags", []) as Array)
		_refresh_all()
		set_status(tr("editor.status.loaded").format([id]))
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dialog_layer.add_child(dlg)
	dlg.popup_centered()

func _on_save() -> void:
	# 校验
	var lvl := model.to_level()
	if lvl.id == "":
		lvl.id = UserLevelStore.make_new_id()
		model.meta["id"] = lvl.id
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		_show_error(tr("editor.error.invalid") + "\n" + v.format_report())
		return
	if UserLevelStore.save_level(lvl):
		dirty = false
		LevelLibrary.refresh_user_levels()
		set_status(tr("editor.status.saved").format([lvl.id]))
		_show_info(tr("editor.dialog.saved_hint").format([lvl.id]))
	else:
		_show_error(tr("editor.error.save_failed"))

func _on_import() -> void:
	var dlg := ImportDialogScene.instantiate()
	dlg.imported.connect(func(level: Level):
		if level == null:
			# 用户取消或解析失败：不修改当前编辑内容
			return
		model.load_from_level(level)
		undo_stack = UndoStack.new()
		dirty = true
		_sync_size_spins_from_model()
		meta_name_edit.text = String(model.meta.get("name", ""))
		meta_author_edit.text = String(model.meta.get("author", ""))
		meta_difficulty_spin.value = int(model.meta.get("difficulty", 1))
		meta_tags_edit.text = ",".join(model.meta.get("tags", []) as Array)
		_refresh_all()
		set_status(tr("editor.status.imported"))
	)
	dialog_layer.add_child(dlg)
	Sfx.attach_ui(dlg)

func _on_export() -> void:
	var lvl := model.to_level()
	var dlg := ExportDialogScene.instantiate()
	dlg.set_level(lvl, board)
	dialog_layer.add_child(dlg)
	Sfx.attach_ui(dlg)

func _on_test_play() -> void:
	# 验证关卡（玩家+箱目数+连通），通过则进入嵌入 Playtest
	var lvl := model.to_level()
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		_show_error(tr("editor.error.invalid") + "\n" + v.format_report())
		return
	var pt := PlaytestScript.new()
	pt.editor = self
	pt.start_level(lvl)
	playtest_layer.add_child(pt)
	set_status(tr("editor.status.playtest"))

func _on_verify() -> void:
	var lvl := model.to_level()
	var v := LevelValidator.validate(lvl)
	if not v.ok:
		_show_error(tr("editor.error.invalid") + "\n" + v.format_report())
		return
	var dlg := SolverDialogScript.new()
	dlg.solved.connect(func(result: Dictionary):
		if bool(result.get("found", false)):
			var pushes: int = int(result.pushes)
			# 估计步数：用 expand_to_moves 复算 moves
			var moves: Array = SokobanSolver.expand_to_moves(lvl, lvl.box_starts, lvl.player_start, result.push_solution)
			var moves_n: int = moves.size()
			model.meta["optimal_pushes"] = pushes
			model.meta["optimal_steps"] = moves_n
			model.meta["verified_by_solver"] = true
			# 把这些写回 metadata（保存时会带出去）
			set_status(tr("editor.status.verified").format([pushes, moves_n]))
			_show_info(tr("editor.dialog.verified").format([pushes, moves_n, int(result.nodes_expanded)]))
		elif bool(result.get("cancelled", false)):
			set_status(tr("editor.status.cancelled"))
		else:
			set_status(tr("editor.status.unsolvable"))
			_show_error(tr("editor.dialog.unsolvable"))
	)
	dialog_layer.add_child(dlg)
	dlg.start(lvl)
	Sfx.attach_ui(dlg)

func _on_quit() -> void:
	# 直接返回主菜单（按用户要求；如有未保存修改，请先手动 Ctrl+S）
	GameState.goto_main_menu()

func _on_size_changed() -> void:
	if _suppress_size_signal:
		return
	model.resize(int(size_w_spin.value), int(size_h_spin.value), false)
	undo_stack = UndoStack.new()  # resize 后 undo 历史失效
	_mark_dirty()
	board.queue_redraw()
	board.recenter()

## 把模型的 width/height 同步到 SpinBox，但不触发 _on_size_changed（避免反向 resize 把刚加载的关卡再裁掉）。
func _sync_size_spins_from_model() -> void:
	_suppress_size_signal = true
	size_w_spin.value = model.width
	size_h_spin.value = model.height
	_suppress_size_signal = false

# ---------------------------- 对话工具 ----------------------------

func _show_error(msg: String) -> void:
	_show_message_dialog(tr("common.error"), msg)

func _show_info(msg: String) -> void:
	_show_message_dialog(tr("common.info"), msg)

## 通用消息对话框：固定 480x300，长文本自动滚动，避免 AcceptDialog 按内容撑大。
func _show_message_dialog(title_text: String, msg: String) -> void:
	const DLG_W := 480
	const DLG_H := 300
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = title_text
	# 用自定义内容替换 dialog_text（避免 AcceptDialog 根据文本自动撑大）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(DLG_W - 32, DLG_H - 80)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var label := Label.new()
	label.text = msg
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(DLG_W - 48, 0)
	scroll.add_child(label)
	dlg.add_child(scroll)
	dialog_layer.add_child(dlg)
	dlg.min_size = Vector2i(DLG_W, DLG_H)
	dlg.size = Vector2i(DLG_W, DLG_H)
	dlg.popup_centered(Vector2i(DLG_W, DLG_H))
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())

# ---------------------------- Playtest 回调 ----------------------------

func close_playtest() -> void:
	for c in playtest_layer.get_children():
		c.queue_free()
	set_status(tr("editor.status.idle"))

func _unhandled_input(event: InputEvent) -> void:
	# 全局快捷键：ctrl-z / ctrl-y
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.ctrl_pressed and k.keycode == KEY_Z:
			if k.shift_pressed:
				_on_redo()
			else:
				_on_undo()
			get_viewport().set_input_as_handled()
		elif k.ctrl_pressed and k.keycode == KEY_Y:
			_on_redo()
			get_viewport().set_input_as_handled()
		elif k.ctrl_pressed and k.keycode == KEY_S:
			_on_save()
			get_viewport().set_input_as_handled()
