extends Control

const FADE_TIME := 0.45
const VP_W := 688
const VP_H := 768

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

var _past_rooms: Array = []
var _future_rooms: Array = []

var _boss_intro_played: bool = false
const BOSS_ROOM_INDEX := 3


func _ready() -> void:
	# Each viewport needs its own World2D for independent physics
	left_viewport.world_2d = World2D.new()
	right_viewport.world_2d = World2D.new()

	_define_rooms()
	_spawn_worlds()
	_spawn_players()
	_load_room("past", 0)
	_load_room("future", 0)
	past_player.position = current_past_room.get_center()
	future_player.position = current_future_room.get_center()
	_build_overlays()
	_connect_hud()
	_connect_signals()
	_fade_in_both()


func _define_rooms() -> void:
	_past_rooms = [
		{
			"doors": ["south"],
			"enemies": [],
			"npcs": [{"x": 176, "y": 100, "dialogue": "res://data/dialogue/guide_past.json"}],
			"floor_color": Color(0.82, 0.72, 0.52),
			"wall_color": Color(0.50, 0.42, 0.30),
		},
		{
			"doors": ["north", "south"],
			"enemies": [
				{"x": 120, "y": 180, "tint": Color(0.9, 0.35, 0.2), "hp": 3},
				{"x": 240, "y": 260, "tint": Color(0.9, 0.35, 0.2), "hp": 3},
			],
			"npcs": [],
			"floor_color": Color(0.78, 0.68, 0.48),
			"wall_color": Color(0.48, 0.40, 0.28),
		},
		{
			"doors": ["north", "south"],
			"enemies": [
				{"x": 100, "y": 140, "tint": Color(0.85, 0.3, 0.15), "hp": 3},
				{"x": 240, "y": 200, "tint": Color(0.85, 0.3, 0.15), "hp": 4},
				{"x": 170, "y": 300, "tint": Color(0.95, 0.4, 0.2), "hp": 3, "speed": 65.0, "chase_speed": 95.0},
			],
			"npcs": [],
			"floor_color": Color(0.75, 0.65, 0.45),
			"wall_color": Color(0.45, 0.38, 0.26),
		},
		{
			"doors": ["north"],
			"enemies": [
				{"x": 176, "y": 200, "tint": Color(0.85, 0.15, 0.1), "hp": 18, "speed": 45.0, "chase_speed": 70.0, "is_boss": true},
			],
			"npcs": [],
			"floor_color": Color(0.55, 0.40, 0.32),
			"wall_color": Color(0.32, 0.22, 0.18),
		},
	]

	_future_rooms = [
		{
			"doors": ["south"],
			"enemies": [],
			"npcs": [{"x": 176, "y": 100, "dialogue": "res://data/dialogue/guide_future.json"}],
			"floor_color": Color(0.28, 0.30, 0.38),
			"wall_color": Color(0.18, 0.20, 0.28),
		},
		{
			"doors": ["north", "south"],
			"enemies": [
				{"x": 130, "y": 190, "tint": Color(0.45, 0.2, 0.65), "hp": 3},
				{"x": 220, "y": 250, "tint": Color(0.45, 0.2, 0.65), "hp": 3},
			],
			"npcs": [],
			"floor_color": Color(0.24, 0.26, 0.34),
			"wall_color": Color(0.15, 0.17, 0.25),
		},
		{
			"doors": ["north", "south"],
			"enemies": [
				{"x": 110, "y": 150, "tint": Color(0.5, 0.15, 0.7), "hp": 4},
				{"x": 230, "y": 210, "tint": Color(0.4, 0.1, 0.6), "hp": 4},
				{"x": 170, "y": 310, "tint": Color(0.55, 0.2, 0.75), "hp": 3, "speed": 70.0, "chase_speed": 100.0},
			],
			"npcs": [],
			"floor_color": Color(0.22, 0.24, 0.32),
			"wall_color": Color(0.13, 0.15, 0.22),
		},
		{
			"doors": ["north"],
			"enemies": [
				{"x": 176, "y": 200, "tint": Color(0.55, 0.1, 0.85), "hp": 18, "speed": 45.0, "chase_speed": 70.0, "is_boss": true},
			],
			"npcs": [],
			"floor_color": Color(0.18, 0.10, 0.28),
			"wall_color": Color(0.10, 0.05, 0.18),
		},
	]


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


func _load_room(timeline: String, room_idx: int) -> void:
	var room_data: Array = _past_rooms if timeline == "past" else _future_rooms
	if room_idx < 0 or room_idx >= room_data.size():
		return

	var world: Node2D = past_world if timeline == "past" else future_world

	var old_room: Room
	if timeline == "past":
		old_room = current_past_room
	else:
		old_room = current_future_room

	if old_room:
		old_room.queue_free()

	var cfg: Dictionary = room_data[room_idx]
	var room := Room.new()
	room.room_w = 11
	room.room_h = 12
	room.timeline = timeline
	room.room_id = room_idx
	room.door_positions = cfg.get("doors", [])
	room.enemy_configs = cfg.get("enemies", [])
	room.npc_configs = cfg.get("npcs", [])
	room.floor_color = cfg.get("floor_color", Color(0.5, 0.5, 0.5))
	room.wall_color = cfg.get("wall_color", Color(0.3, 0.3, 0.3))
	room.name = "Room_%s_%d" % [timeline, room_idx]

	world.add_child(room)
	room.build()

	if timeline == "past":
		current_past_room = room
		GameState.current_room_past = room_idx
	else:
		current_future_room = room
		GameState.current_room_future = room_idx


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
	TimelineManager.boss_defeated.connect(_on_boss_defeated)
	game_over_layer.restart_requested.connect(_on_restart_pressed)
	game_over_layer.menu_requested.connect(_on_menu_pressed)
	TimelineManager.reset_sync()


func _process(delta: float) -> void:
	if _game_over:
		return
	if GameState.is_dialogue_active or GameState.is_transitioning:
		return
	var both_in_same_room: bool = (
		GameState.current_room_past == GameState.current_room_future
	)
	TimelineManager.update_sync(both_in_same_room, delta)


func _on_boss_defeated(_tl: String) -> void:
	# Wait briefly then return to main menu (or you could trigger an ending)
	await get_tree().create_timer(2.0).timeout
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
	TimelineManager.reset_sync()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_menu_pressed() -> void:
	GameState.current_room_past = 0
	GameState.current_room_future = 0
	GameState.is_transitioning = false
	GameState.is_dialogue_active = false
	TimelineManager.reset_sync()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _fade_in_both() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(past_overlay, "color:a", 0.0, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(future_overlay, "color:a", 0.0, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _on_room_transition(timeline: String, direction: String) -> void:
	if GameState.is_transitioning:
		return
	GameState.is_transitioning = true

	var current_idx: int
	var rooms: Array
	var overlay: ColorRect
	var player: PlayerBase

	if timeline == "past":
		current_idx = GameState.current_room_past
		rooms = _past_rooms
		overlay = past_overlay
		player = past_player
	else:
		current_idx = GameState.current_room_future
		rooms = _future_rooms
		overlay = future_overlay
		player = future_player

	var next_idx := current_idx
	match direction:
		"south": next_idx += 1
		"north": next_idx -= 1
		"east":  next_idx += 1
		"west":  next_idx -= 1

	if next_idx < 0 or next_idx >= rooms.size():
		GameState.is_transitioning = false
		return

	var tw_out := create_tween()
	tw_out.tween_property(overlay, "color:a", 1.0, FADE_TIME)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tw_out.finished

	_load_room(timeline, next_idx)

	var entry_dir := "south" if direction == "north" else "north"
	if direction == "east":
		entry_dir = "west"
	elif direction == "west":
		entry_dir = "east"

	var room: Room = current_past_room if timeline == "past" else current_future_room
	player.position = room.get_spawn_point(entry_dir)
	player.velocity = Vector2.ZERO

	var tw_in := create_tween()
	tw_in.tween_property(overlay, "color:a", 0.0, FADE_TIME)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tw_in.finished

	GameState.is_transitioning = false

	if next_idx == BOSS_ROOM_INDEX and not _boss_intro_played:
		_boss_intro_played = true
		await get_tree().create_timer(0.4).timeout
		DialogueManager.start_dialogue("res://data/dialogue/boss_intro.json")
