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

var _past_rooms: Dictionary = {}
var _future_rooms: Dictionary = {}
var _past_connections: Dictionary = {}
var _future_connections: Dictionary = {}

var _gear_puzzle: GearPuzzleManager


func _ready() -> void:
	# Each viewport needs its own World2D for independent physics
	left_viewport.world_2d = World2D.new()
	right_viewport.world_2d = World2D.new()

	_define_rooms()
	_spawn_worlds()
	_spawn_players()
	_spawn_gear_puzzle()
	_load_room("past", 0)
	_load_room("future", 0)
	past_player.position = current_past_room.get_center()
	future_player.position = current_future_room.get_center()
	_build_overlays()
	_connect_hud()
	_connect_signals()
	_fade_in_both()


func _define_rooms() -> void:
	# Area 1: 4 rooms per timeline, identical layout + enemy positions,
	# differing only in floor/wall colors and enemy roster.
	_past_rooms = {
		0: {
			"doors": ["south"],
			"enemies": [],
			"npcs": [{"x": 176, "y": 100, "dialogue": "res://data/dialogue/guide_past.json", "type": "past"}],
			"floor_color": Color(0.82, 0.72, 0.52),
			"wall_color": Color(0.50, 0.42, 0.30),
		},
		1: {
			"doors": ["north", "south"],
			"enemies": [
				{"x": 120, "y": 180, "hp": 3, "type": "orc"},
				{"x": 240, "y": 260, "hp": 3, "type": "orc"},
			],
			"triggers": [
				{"type": "gear_pickup", "gear_id": "gear_a", "position": Vector2(176, 220), "size": Vector2(32, 32), "after_clear": true, "id": "GearA"},
			],
			"npcs": [],
			"floor_color": Color(0.78, 0.68, 0.48),
			"wall_color": Color(0.48, 0.40, 0.28),
		},
		2: {
			"doors": ["north", "south"],
			"enemies": [
				{"x": 120, "y": 180, "hp": 3, "type": "orc"},
				{"x": 240, "y": 200, "hp": 2, "type": "archer"},
			],
			"triggers": [
				{"type": "gear_pickup", "gear_id": "gear_b", "position": Vector2(176, 220), "size": Vector2(32, 32), "after_clear": true, "id": "GearB"},
			],
			"npcs": [],
			"floor_color": Color(0.75, 0.65, 0.45),
			"wall_color": Color(0.45, 0.38, 0.26),
		},
		3: {
			"doors": ["north"],
			"enemies": [],
			"props": [
				{"position": Vector2(176, 180), "size": Vector2(40, 40), "color": Color(0.6, 0.5, 0.3), "collides": true, "label": "Gear Console"},
			],
			"triggers": [
				{"type": "gear_pickup", "gear_id": "gear_c", "position": Vector2(176, 220), "size": Vector2(32, 32), "id": "GearC"},
			],
			"npcs": [],
			"floor_color": Color(0.55, 0.40, 0.32),
			"wall_color": Color(0.32, 0.22, 0.18),
		},
	}

	_future_rooms = {
		0: {
			"doors": ["south"],
			"enemies": [],
			"npcs": [{"x": 176, "y": 100, "dialogue": "res://data/dialogue/guide_future.json", "type": "future"}],
			"floor_color": Color(0.28, 0.30, 0.38),
			"wall_color": Color(0.18, 0.20, 0.28),
		},
		1: {
			"doors": ["north", "south"],
			"enemies": [
				{"x": 120, "y": 180, "hp": 3, "type": "skeleton"},
				{"x": 240, "y": 260, "hp": 3, "type": "skeleton"},
			],
			"triggers": [
				{"type": "gear_pickup", "gear_id": "gear_a", "position": Vector2(176, 220), "size": Vector2(32, 32), "after_clear": true, "id": "GearA"},
			],
			"npcs": [],
			"floor_color": Color(0.24, 0.26, 0.34),
			"wall_color": Color(0.15, 0.17, 0.25),
		},
		2: {
			"doors": ["north", "south"],
			"enemies": [
				{"x": 120, "y": 180, "hp": 3, "type": "skeleton"},
				{"x": 240, "y": 200, "hp": 2, "type": "skeleton_archer"},
			],
			"triggers": [
				{"type": "gear_pickup", "gear_id": "gear_b", "position": Vector2(176, 220), "size": Vector2(32, 32), "after_clear": true, "id": "GearB"},
			],
			"npcs": [],
			"floor_color": Color(0.22, 0.24, 0.32),
			"wall_color": Color(0.13, 0.15, 0.22),
		},
		3: {
			"doors": ["north"],
			"enemies": [],
			"props": [
				{"position": Vector2(176, 180), "size": Vector2(40, 40), "color": Color(0.3, 0.4, 0.6), "collides": true, "label": "Gear Console"},
			],
			"triggers": [
				{"type": "gear_pickup", "gear_id": "gear_c", "position": Vector2(176, 220), "size": Vector2(32, 32), "id": "GearC"},
			],
			"npcs": [],
			"floor_color": Color(0.18, 0.10, 0.28),
			"wall_color": Color(0.10, 0.05, 0.18),
		},
	}

	_past_connections = {
		0: {"south": 1},
		1: {"north": 0, "south": 2},
		2: {"north": 1, "south": 3},
		3: {"north": 2},
	}
	_future_connections = {
		0: {"south": 1},
		1: {"north": 0, "south": 2},
		2: {"north": 1, "south": 3},
		3: {"north": 2},
	}


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
	var room_data: Dictionary = _past_rooms if timeline == "past" else _future_rooms
	if not room_data.has(room_idx):
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
	room.room_w = cfg.get("room_w", 11)
	room.room_h = cfg.get("room_h", 12)
	room.timeline = timeline
	room.room_id = room_idx
	room.door_positions = cfg.get("doors", [])
	room.enemy_configs = cfg.get("enemies", [])
	room.npc_configs = cfg.get("npcs", [])
	room.prop_configs = cfg.get("props", [])
	room.trigger_configs = cfg.get("triggers", [])
	room.locked_doors = cfg.get("locked_doors", {})
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
	TimelineManager.timeline_action.connect(_on_timeline_action)
	game_over_layer.restart_requested.connect(_on_restart_pressed)
	game_over_layer.menu_requested.connect(_on_menu_pressed)
	TimelineManager.reset_sync()


func _spawn_gear_puzzle() -> void:
	_gear_puzzle = GearPuzzleManager.new()
	_gear_puzzle.name = "GearPuzzleManager"
	add_child(_gear_puzzle)


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
	var connections: Dictionary
	var overlay: ColorRect
	var player: PlayerBase

	if timeline == "past":
		current_idx = GameState.current_room_past
		connections = _past_connections
		overlay = past_overlay
		player = past_player
	else:
		current_idx = GameState.current_room_future
		connections = _future_connections
		overlay = future_overlay
		player = future_player

	var room_conns: Dictionary = connections.get(current_idx, {})
	if not room_conns.has(direction):
		GameState.is_transitioning = false
		return

	var next_idx: int = room_conns[direction]

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
