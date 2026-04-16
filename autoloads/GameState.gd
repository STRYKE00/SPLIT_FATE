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
	flags.erase("area1_started")
	flags.erase("gear_pieces_found")
	flags.erase("gear2_placed")
	flags.erase("area1_bridge_built")
	flags.erase("mira_has_communicator")
	flags.erase("ren_has_communicator")
	flags.erase("echo_communicator_active")
	flags.erase("warden_past_dead")
	flags.erase("warden_future_dead")
	flags.erase("area1_complete")
	flags.erase("warden_hp")


func _ready() -> void:
	_setup_input_map()


func _setup_input_map() -> void:
	_add_key("past_left", KEY_A)
	_add_key("past_right", KEY_D)
	_add_key("past_up", KEY_W)
	_add_key("past_down", KEY_S)
	_add_key("past_attack", KEY_SPACE)
	_add_key("past_heavy", KEY_Q)
	_add_key("past_interact", KEY_E)
	_add_key("past_dash", KEY_SHIFT)

	_add_key("future_left", KEY_LEFT)
	_add_key("future_right", KEY_RIGHT)
	_add_key("future_up", KEY_UP)
	_add_key("future_down", KEY_DOWN)
	_add_key("future_attack", KEY_ENTER)
	_add_key("future_heavy", KEY_COMMA)
	_add_key("future_interact", KEY_PERIOD)
	_add_key("future_dash", KEY_SLASH)

	_add_key("dialogue_advance", KEY_SPACE)
	_add_key("dialogue_advance", KEY_ENTER)


func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)


func mark_puzzle(puzzle_id: String) -> void:
	completed_puzzles[puzzle_id] = true


func is_puzzle_done(puzzle_id: String) -> bool:
	return completed_puzzles.get(puzzle_id, false)
