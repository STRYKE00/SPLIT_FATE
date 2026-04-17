extends Control

const FADE_TIME := 0.45
const VP_W := 688
const VP_H := 768
const ROOM_W := 1376
const ROOM_H := 768
const ROOM_COUNT := 4
const ROOM_TRANSITION_TIME := 0.6

# --- Node references (set up in Main.tscn) ---
@onready var left_viewport: SubViewport  = $SplitContainer/LeftContainer/LeftViewport
@onready var right_viewport: SubViewport = $SplitContainer/RightContainer/RightViewport
@onready var hud_layer: Node             = $HUD
@onready var dialogue_layer: Node        = $DialogueBox
@onready var game_over_layer: Node       = $GameOver

var past_world: Node2D
var future_world: Node2D
var past_player: PlayerBase
var future_player: PlayerBase
var past_overlay: ColorRect
var future_overlay: ColorRect
var current_past_room: Room
var current_future_room: Room

var _puzzle: Node


func _ready() -> void:
	# Clear any stale state left over from previous scenes (dialogue, transitions)
	GameState.is_dialogue_active = false
	GameState.is_transitioning   = false

	# Each viewport needs its own World2D for independent physics
	left_viewport.world_2d = World2D.new()
	right_viewport.world_2d = World2D.new()

	_spawn_worlds()
	_spawn_players()
	_load_past_map()
	_load_future_map()
	_build_overlays()
	_setup_puzzle()
	_connect_hud()
	_connect_signals()
	_fade_in_both()


func _setup_puzzle() -> void:
	var puzzle_script := preload("res://scripts/world/area1/Puzzle.gd")
	_puzzle = Node.new()
	_puzzle.set_script(puzzle_script)
	_puzzle.name = "Puzzle"
	add_child(_puzzle)
	_puzzle.setup(past_world, future_world, past_overlay, future_overlay)


func _load_past_map() -> void:
	var map := preload("res://scenes/Past_map_1.tscn").instantiate()
	map.name = "PastMap"
	past_world.add_child(map)
	past_player.position = Vector2(540.0, 384.0)
	GameState.current_room_past = 0


func _load_future_map() -> void:
	var map := preload("res://scenes/Future_map_1.tscn").instantiate()
	map.name = "FutureMap"
	future_world.add_child(map)
	future_player.position = Vector2(688.0, 384.0)
	GameState.current_room_future = 0


func _spawn_worlds() -> void:
	past_world = Node2D.new()
	past_world.name = "PastWorld"
	left_viewport.add_child(past_world)

	future_world = Node2D.new()
	future_world.name = "FutureWorld"
	right_viewport.add_child(future_world)


func _spawn_players() -> void:
	past_player = preload("res://scenes/characters/PlayerPast.tscn").instantiate()
	past_player.name = "PlayerPast"

	future_player = preload("res://scenes/characters/PlayerFuture.tscn").instantiate()
	future_player.name = "PlayerFuture"

	past_world.add_child(past_player)
	future_world.add_child(future_player)


func _build_overlays() -> void:
	var past_canvas := CanvasLayer.new()
	past_canvas.layer = 50
	left_viewport.add_child(past_canvas)
	past_overlay = ColorRect.new()
	past_overlay.size = Vector2(VP_W, VP_H)
	past_overlay.color = Color(0, 0, 0, 1)
	past_canvas.add_child(past_overlay)

	var future_canvas := CanvasLayer.new()
	future_canvas.layer = 50
	right_viewport.add_child(future_canvas)
	future_overlay = ColorRect.new()
	future_overlay.size = Vector2(VP_W, VP_H)
	future_overlay.color = Color(0, 0, 0, 1)
	future_canvas.add_child(future_overlay)


func _connect_hud() -> void:
	await get_tree().process_frame
	hud_layer.connect_player_past(past_player)
	hud_layer.connect_player_future(future_player)


func _connect_signals() -> void:
	TimelineManager.room_transition_requested.connect(_on_room_transition)
	TimelineManager.player_died.connect(_on_player_died)
	TimelineManager.timeline_action.connect(_on_timeline_action)
	game_over_layer.restart_requested.connect(_on_restart_pressed)
	game_over_layer.menu_requested.connect(_on_menu_pressed)
	TimelineManager.reset_sync()


func get_live_enemies() -> int:
	if _puzzle and _puzzle.has_method("get_live_enemies"):
		return _puzzle.get_live_enemies()
	return 0


func get_live_past_enemies() -> int:
	if _puzzle and _puzzle.has_method("get_live_past_enemies"):
		return _puzzle.get_live_past_enemies()
	return 0


func _process(delta: float) -> void:
	if _game_over:
		return
	if GameState.is_dialogue_active or GameState.is_transitioning:
		return
	var both_in_same_room: bool = (
		GameState.current_room_past == GameState.current_room_future
	)
	TimelineManager.update_sync(both_in_same_room, delta)


func _on_timeline_action(action_id: String, _source_timeline: String) -> void:
	if action_id == "area1_complete":
		await get_tree().create_timer(3.5).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


var _game_over: bool = false

func _on_player_died(_tl: String) -> void:
	if _game_over:
		return
	_game_over = true
	GameState.is_transitioning = true

	var tw := create_tween().set_parallel(true)
	tw.tween_property(past_overlay, "color:a", 0.55, FADE_TIME)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_property(future_overlay, "color:a", 0.55, FADE_TIME)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tw.finished

	game_over_layer.show_game_over()


func _on_restart_pressed() -> void:
	GameState.current_room_past = 0
	GameState.current_room_future = 0
	GameState.is_transitioning = false
	GameState.is_dialogue_active = false
	GameState.reset_area1()
	TimelineManager.reset_sync()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_menu_pressed() -> void:
	GameState.current_room_past = 0
	GameState.current_room_future = 0
	GameState.is_transitioning = false
	GameState.is_dialogue_active = false
	GameState.reset_area1()
	TimelineManager.reset_sync()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _fade_in_both() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(past_overlay, "color:a", 0.0, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(future_overlay, "color:a", 0.0, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _on_room_transition(_timeline: String, _direction: String) -> void:
	pass  # Maps are open TileMap scenes — no room transitions
