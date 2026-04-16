extends Node

var completed_puzzles: Dictionary = {}
var current_room_past: int = 0
var current_room_future: int = 0
var is_dialogue_active: bool = false
var is_transitioning: bool = false

var flags: Dictionary = {}

func set_flag(key: String, value: Variant) -> void:
	flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)

func reset_area1() -> void:
	flags.erase("gear_gear_a")
	flags.erase("gear_gear_b")
	flags.erase("gear_gear_c")
	flags.erase("area1_complete")

enum INPUT_SCHEMES{
	KEYBOARD_AND_MOUSE,
	CONTROLLER,
}

static var current_input_scheme: INPUT_SCHEMES = INPUT_SCHEMES.KEYBOARD_AND_MOUSE

func _ready() -> void:
	_set_input_scheme()

func _set_input_scheme()->void:
	var joypads = Input.get_connected_joypads()
	if joypads.size() ==2:
		current_input_scheme = INPUT_SCHEMES.CONTROLLER
	else:
		current_input_scheme = INPUT_SCHEMES.KEYBOARD_AND_MOUSE

func mark_puzzle(puzzle_id: String) -> void:
	completed_puzzles[puzzle_id] = true


func is_puzzle_done(puzzle_id: String) -> bool:
	return completed_puzzles.get(puzzle_id, false)
