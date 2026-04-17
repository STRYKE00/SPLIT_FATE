extends Node
class_name GearPuzzleManager

const REQUIRED_GEARS := ["stone", "log"]

signal puzzle_state_changed(collected: int, required: int)
signal puzzle_completed

var _past_collected: Dictionary = {}
var _future_collected: Dictionary = {}
var _is_complete: bool = false


func _ready() -> void:
	TimelineManager.gear_collected.connect(_on_gear_collected)


func _on_gear_collected(gear_id: String, timeline: String) -> void:
	if gear_id not in REQUIRED_GEARS:
		return
	var collected: Dictionary = _past_collected if timeline == "past" else _future_collected
	if collected.has(gear_id):
		return
	collected[gear_id] = true
	GameState.set_flag("gear_%s_%s" % [timeline, gear_id], true)
	puzzle_state_changed.emit(total_collected(), REQUIRED_GEARS.size())


func total_collected() -> int:
	return _past_collected.size() + _future_collected.size()


func has_all_gears() -> bool:
	print("puzzles collected: ", _past_collected)
	for gid in REQUIRED_GEARS:
		if not _past_collected.has(gid):
			return false
	return true


func try_complete() -> bool:
	if _is_complete:
		return false
	if not has_all_gears():
		return false
	_is_complete = true
	GameState.set_flag("area1_complete", true)
	puzzle_completed.emit()
	TimelineManager.timeline_action.emit("area1_complete", "past")
	return true


func reset() -> void:
	_past_collected.clear()
	_future_collected.clear()
	_is_complete = false
	for gid in REQUIRED_GEARS:
		GameState.set_flag("gear_past_" + gid, false)
		GameState.set_flag("gear_future_" + gid, false)
	GameState.set_flag("area1_complete", false)
