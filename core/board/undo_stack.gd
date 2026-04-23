class_name UndoStack
extends RefCounted
## UndoStack — 通用撤销/重做栈。
## 不依赖具体命令类型，只要存对象引用即可。
## 由 Board 在 try_move 成功后 push；undo() 与 redo() 由 GameController 触发。

var _undo: Array = []
var _redo: Array = []

signal changed()

func push(cmd: Variant) -> void:
	_undo.append(cmd)
	_redo.clear()
	changed.emit()

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func pop_undo() -> Variant:
	if _undo.is_empty():
		return null
	var c: Variant = _undo.pop_back()
	_redo.append(c)
	changed.emit()
	return c

func pop_redo() -> Variant:
	if _redo.is_empty():
		return null
	var c: Variant = _redo.pop_back()
	_undo.append(c)
	changed.emit()
	return c

func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()

func undo_count() -> int:
	return _undo.size()

func redo_count() -> int:
	return _redo.size()
