extends Node

signal timeline_action(action_id: String, source_timeline: String)
signal bridge_state_changed(bridge_id: String, is_built: bool)
signal room_transition_requested(timeline: String, door_direction: String)
signal dialogue_requested(dialogue_path: String)
signal room_cleared(timeline: String)
signal player_died(timeline: String)
signal enemy_killed(timeline: String)
signal sync_changed(value: float)
signal boss_spawned(boss: Node)
signal boss_defeated(timeline: String)
signal warden_hp_changed(current_hp: int, max_hp: int)
signal warden_phase_changed(phase: int)
signal gear_collected(piece_id: String)
signal communicator_found(timeline: String)

const SYNC_MAX := 100.0
const WARDEN_MAX_HP := 300
const SYNC_GAIN_PER_SEC := 28.0
const SYNC_DECAY_PER_SEC := 18.0
const SYNC_THRESHOLD := 80.0

var sync_value: float = 0.0


func update_sync(both_in_same_room: bool, delta: float) -> void:
	var prev := sync_value
	if both_in_same_room:
		sync_value = min(SYNC_MAX, sync_value + SYNC_GAIN_PER_SEC * delta)
	else:
		sync_value = max(0.0, sync_value - SYNC_DECAY_PER_SEC * delta)
	if abs(sync_value - prev) > 0.01:
		sync_changed.emit(sync_value)


func is_synced() -> bool:
	return sync_value >= SYNC_THRESHOLD


func reset_sync() -> void:
	sync_value = 0.0
	sync_changed.emit(sync_value)


func init_warden_hp() -> void:
	GameState.set_flag("warden_hp", WARDEN_MAX_HP)
	warden_hp_changed.emit(WARDEN_MAX_HP, WARDEN_MAX_HP)

func damage_warden(amount: int, source_timeline: String) -> int:
	var hp: int = GameState.get_flag("warden_hp", WARDEN_MAX_HP)
	hp = max(0, hp - amount)
	GameState.set_flag("warden_hp", hp)
	warden_hp_changed.emit(hp, WARDEN_MAX_HP)
	if hp <= WARDEN_MAX_HP / 2 and hp + amount > WARDEN_MAX_HP / 2:
		warden_phase_changed.emit(2)
	return hp
