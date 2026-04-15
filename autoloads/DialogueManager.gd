extends Node

signal dialogue_started()
signal line_ready(speaker: String, text: String)
signal dialogue_ended()

var _lines: Array = []
var _index: int = 0
var _active: bool = false


func start_dialogue(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: cannot open " + path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("DialogueManager: parse error in " + path)
		return
	_lines = json.data
	_index = 0
	_active = true
	GameState.is_dialogue_active = true
	dialogue_started.emit()
	next_line()


func next_line() -> void:
	if _index >= _lines.size():
		end_dialogue()
		return
	var entry: Dictionary = _lines[_index]
	_index += 1
	line_ready.emit(entry.get("speaker", ""), entry.get("text", ""))


func end_dialogue() -> void:
	_active = false
	GameState.is_dialogue_active = false
	dialogue_ended.emit()


func is_active() -> bool:
	return _active
