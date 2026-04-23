class_name LevelSetImporter
extends RefCounted

const LINE_AUTHOR := "Author:"
const LINE_TITLE := "Title:"

class LevelEntry extends RefCounted:
	var index: int = 0
	var title: String = ""
	var author: String = ""
	var xsb_text: String = ""


static func parse_text_levelset(text: String) -> Array[LevelEntry]:
	var lines: Array[String] = []
	for raw_line in text.split("\n"):
		lines.append(raw_line.rstrip("\r"))

	var entries: Array[LevelEntry] = []
	var pending_title: String = ""
	var pending_author: String = ""
	var current_index: int = -1
	var current_grid: Array[String] = []

	for raw_line: String in lines:
		var trimmed := raw_line.strip_edges()
		if trimmed.is_empty():
			continue

		if _is_metadata_line(trimmed):
			if trimmed.begins_with(LINE_TITLE):
				pending_title = trimmed.trim_prefix(LINE_TITLE).strip_edges()
			elif trimmed.begins_with(LINE_AUTHOR):
				pending_author = trimmed.trim_prefix(LINE_AUTHOR).strip_edges()
				_try_finish_entry(entries, current_index, current_grid, pending_title, pending_author)
				current_index = -1
				current_grid = []
				pending_title = ""
				pending_author = ""
			continue

		if _is_comment_line(trimmed):
			continue

		if _looks_like_level_header(trimmed):
			if current_index != -1 and not current_grid.is_empty():
				_try_finish_entry(entries, current_index, current_grid, pending_title, pending_author)
				pending_title = ""
				pending_author = ""
				current_grid = []
			current_index = int(trimmed.trim_prefix(";").strip_edges())
			continue

		if _looks_like_grid_line(raw_line):
			if current_index == -1:
				current_index = entries.size() + 1
			current_grid.append(raw_line.rstrip("\r"))

	if current_index != -1 and not current_grid.is_empty():
		_try_finish_entry(entries, current_index, current_grid, pending_title, pending_author)

	return entries


static func _try_finish_entry(entries: Array[LevelEntry], index: int, grid: Array[String], title: String, author: String) -> void:
	if index == -1 or grid.is_empty():
		return
	var entry := LevelEntry.new()
	entry.index = index
	entry.title = title
	entry.author = author
	entry.xsb_text = "\n".join(grid)
	entries.append(entry)


static func _is_metadata_line(line: String) -> bool:
	return line.begins_with(LINE_TITLE) or line.begins_with(LINE_AUTHOR)


static func _is_comment_line(line: String) -> bool:
	if line.begins_with(";"):
		return not _looks_like_level_header(line)
	if line.begins_with("::"):
		return true
	if line.begins_with("'"):
		return true
	if line.begins_with("Set:") or line.begins_with("Copyright:"):
		return true
	if line.begins_with("Email:") or line.begins_with("Homepage:"):
		return true
	if line.begins_with("Date of Last Change:"):
		return true
	if line.begins_with("This ") or line.begins_with("For "):
		return true
	if line.begins_with("Enjoy") or line.begins_with("SOKOBAN Project"):
		return true
	if line.begins_with("Sokoban WIKI"):
		return true
	if line.find(":") != -1 and not line.begins_with(";"):
		return true
	return false


static func _looks_like_level_header(line: String) -> bool:
	var normalized := line.trim_prefix(";").strip_edges()
	if normalized.is_empty():
		return false
	return normalized.is_valid_int()


static func _looks_like_grid_line(line: String) -> bool:
	if line.strip_edges().is_empty():
		return false
	for i in line.length():
		var ch := line.substr(i, 1)
		if ch not in ["#", " ", "-", ".", "$", "*", "@", "+", ",", "1", "2", "3", "4", "a", "b", "c", "d", "A", "B", "C", "D"]:
			return false
	return true
