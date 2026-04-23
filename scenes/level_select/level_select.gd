extends Control
## LevelSelect — 关卡选择场景。
## 章节为 Tab，每个 Tab 内为关卡格栅；显示星级、最佳步数。

@onready var lbl_title: Label = %LblTitle
@onready var btn_back: Button = %BtnBack
@onready var tabs: TabContainer = %Tabs

const LEVEL_BTN_SIZE := Vector2(120, 120)

func _ready() -> void:
	btn_back.pressed.connect(GameState.goto_main_menu)
	_refresh_texts()
	_build_tabs()
	EventBus.subscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", Callable(self, "_on_lang_changed"))

func _on_lang_changed(_e) -> void:
	_refresh_texts()
	_rebuild_tab_titles()
	# 重建关卡标签
	for child in tabs.get_children():
		child.queue_free()
	_build_tabs()

func _refresh_texts() -> void:
	lbl_title.text = tr("level_select.title")
	btn_back.text = tr("level_select.back")

func _build_tabs() -> void:
	var chapters := LevelLibrary.get_chapters()
	for ch in chapters:
		var ch_name := _resolve_name(ch.get("name", ""), str(ch.get("id", "?")))
		var page := _build_chapter_page(ch)
		page.name = ch_name
		tabs.add_child(page)
	# 用户关卡（"我的关卡"）—— 始终显示
	var page_user := _build_user_page()
	page_user.name = tr("level_select.user_levels")
	tabs.add_child(page_user)
	# 全部按钮挂 ui_click
	Sfx.attach_ui(self)

func _build_user_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ids: Array = UserLevelStore.list_user_level_ids()
	var header := Label.new()
	header.text = tr("level_select.user_progress").format([ids.size()])
	header.modulate = Color(1, 1, 1, 0.75)
	page.add_child(header)
	if ids.is_empty():
		var hint := Label.new()
		hint.text = tr("level_select.user_empty_hint")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.modulate = Color(1, 1, 1, 0.6)
		page.add_child(hint)
		return page
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var idx := 0
	for id in ids:
		idx += 1
		# 给用户关卡也尝试读取关卡名（loadXSize 较小可接受）
		grid.add_child(_make_level_button(id, idx))
	return page

func _rebuild_tab_titles() -> void:
	pass  # 由 _on_lang_changed 整体重建

func _build_chapter_page(ch: Dictionary) -> Control:
	var root := ScrollContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)

	var ids: Array = ch.get("levels", [])
	var planned_total: int = int(ch.get("planned_total", ids.size()))
	# 计算已完成数
	var completed := 0
	for lid in ids:
		if SaveManager.is_completed(lid):
			completed += 1

	var header := Label.new()
	header.text = tr("level_select.chapter_progress").format([completed, planned_total])
	header.modulate = Color(1, 1, 1, 0.75)
	# 头部信息独立一行，添加到 ScrollContainer 之上反而麻烦——这里作为第一个 grid item 跨列简化处理
	# 改成在 root 之外加 VBox
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	page.add_child(header)
	page.add_child(root)

	var idx := 0
	for lid in ids:
		idx += 1
		var btn := _make_level_button(lid, idx)
		grid.add_child(btn)
	return page

func _make_level_button(level_id: String, display_idx: int) -> Control:
	var card := Button.new()
	card.custom_minimum_size = LEVEL_BTN_SIZE
	card.toggle_mode = false
	card.pressed.connect(func(): _on_level_picked(level_id))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var num := Label.new()
	num.text = "%02d" % display_idx
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 28)
	box.add_child(num)

	var stars := SaveManager.get_stars(level_id)
	var star_label := Label.new()
	star_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(star_label)

	var prog: Dictionary = SaveManager.get_progress(level_id)
	var sub := Label.new()
	if prog.has("best_steps"):
		sub.text = tr("level_select.best_steps").format([prog.best_steps])
	else:
		sub.text = tr("level_select.no_record")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(sub)
	return card

func _on_level_picked(level_id: String) -> void:
	GameState.goto_game(level_id)

## 解析名称：可能是 i18n key（"chapter_names.official-w1"）或字典（旧格式）或空。
## tr() 找不到 key 时返回原字符串，天然兼容用户自建关卡的原文场景。
static func _resolve_name(value: Variant, fallback_text: String) -> String:
	if typeof(value) == TYPE_STRING:
		var s: String = value
		if s.is_empty():
			return fallback_text
		return TranslationServer.translate(s)
	if typeof(value) == TYPE_DICTIONARY:
		# 兼容旧格式：{ "zh_CN": "...", "en": "..." }
		var d: Dictionary = value
		var locale := TranslationServer.get_locale()
		if d.has(locale):
			return d[locale]
		if d.has("en"):
			return d.en
		if not d.is_empty():
			return d.values()[0]
	return fallback_text
