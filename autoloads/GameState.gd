extends Node

var completed_puzzles: Dictionary = {}
var current_room_past: int = 0
var current_room_future: int = 0
var is_dialogue_active: bool = false
var is_transitioning: bool = false

enum INPUT_SCHEMES{
	KEYBOARD_AND_MOUSE,
	CONTROLLER,
}

static var current_input_scheme: INPUT_SCHEMES = INPUT_SCHEMES.KEYBOARD_AND_MOUSE

func _ready() -> void:
	_set_input_scheme()

func _set_input_scheme()->void:
	current_input_scheme = INPUT_SCHEMES.KEYBOARD_AND_MOUSE

func mark_puzzle(puzzle_id: String) -> void:
	completed_puzzles[puzzle_id] = true


func is_puzzle_done(puzzle_id: String) -> bool:
	return completed_puzzles.get(puzzle_id, false)
