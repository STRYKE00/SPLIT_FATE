extends Node2D

const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"
const OUTRO_DELAY := 2.0

@onready var solen: Node = $DemonKing

var _past_dead := false
var _future_dead := false
var _victory_fired := false
var _defeat_fired := false


func _ready() -> void:
	TimelineManager.player_died.connect(_on_player_died)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)


func _on_player_died(timeline: String) -> void:
	if timeline == "past":
		_past_dead = true
	elif timeline == "future":
		_future_dead = true
	if _past_dead and _future_dead and not _victory_fired and not _defeat_fired:
		_victory_fired = true
		if solen and is_instance_valid(solen) and solen.has_method("play_victory"):
			solen.play_victory()
		await get_tree().create_timer(OUTRO_DELAY).timeout
		get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_boss_defeated(_timeline: String) -> void:
	if _defeat_fired:
		return
	_defeat_fired = true
	await get_tree().create_timer(OUTRO_DELAY).timeout
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
