extends Node
class_name GearPuzzleManager

const REQUIRED_GEARS := ["gear_a", "gear_b", "gear_c"]

signal puzzle_state_changed(collected: int, required: int)
signal puzzle_completed

var _collected: Dictionary = {}
var _is_complete: bool = false


func _ready() -> void:
	TimelineManager.gear_collected.connect(_on_gear_collected)


func _on_gear_collected(gear_id: String) -> void:
	if _collected.has(gear_id):
		return
	if gear_id not in REQUIRED_GEARS:
		return
	_collected[gear_id] = true
	GameState.set_flag("gear_" + gear_id, true)
	puzzle_state_changed.emit(_collected.size(), REQUIRED_GEARS.size())
	if has_all_gears():
		try_complete()


func collected_count() -> int:
	return _collected.size()


func has_all_gears() -> bool:
	for gid in REQUIRED_GEARS:
		if not _collected.has(gid):
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
	_collected.clear()
	_is_complete = false
	for gid in REQUIRED_GEARS:
		GameState.set_flag("gear_" + gid, false)
	GameState.set_flag("area1_complete", false)
