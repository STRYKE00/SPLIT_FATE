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
var future_player: PlayerFuture
var past_overlay: ColorRect
var future_overlay: ColorRect
var current_past_room: Room
var current_future_room: Room

var _live_enemies: int = 0
var _total_enemies: int = 0
var _past_enemies: Dictionary = {}
var _future_enemies: Dictionary = {}

var _past_gears: Dictionary = {}
var _future_gears: Dictionary = {}

var _haze_layer   : CanvasLayer
var _haze_rect    : ColorRect
var _haze_material: ShaderMaterial

var _gear_puzzle: GearPuzzleManager
const BOSS_ROOM_INDEX := 4

const ENEMY_SCENES = {
	"archer": preload("res://scenes/characters/Enemies/archer.tscn"),
	"orc": preload("res://scenes/characters/Enemies/Orc.tscn"),
	"armored_orc": preload("res://scenes/characters/Enemies/armored_orc.tscn"),
	"elite_orc": preload("res://scenes/characters/Enemies/elite_orc.tscn"),
	"orc_rider": preload("res://scenes/characters/Enemies/orc_rider.tscn"),
	"soldier": preload("res://scenes/characters/Enemies/soldier.tscn"),
	"knight": preload("res://scenes/characters/Enemies/knight.tscn"),
	"skeleton": preload("res://scenes/characters/Enemies/skeleton.tscn"),
	"armored_skeleton": preload("res://scenes/characters/Enemies/armored_skeleton.tscn"),
	"skeleton_archer": preload("res://scenes/characters/Enemies/skeleton_archer.tscn"),
	"greatsword_skeleton": preload("res://scenes/characters/Enemies/greatsword_skeleton.tscn"),
	"werewolf": preload("res://scenes/characters/Enemies/werewolf.tscn"),
	"werebear": preload("res://scenes/characters/Enemies/werebear.tscn"),
	"default": preload("res://scenes/characters/EnemyBase.tscn")
}


func _ready() -> void:
	# Clear any stale state left over from previous scenes (dialogue, transitions)
	GameState.is_dialogue_active = false
	GameState.is_transitioning   = false

	# Each viewport needs its own World2D for independent physics
	left_viewport.world_2d = World2D.new()
	right_viewport.world_2d = World2D.new()

	_define_enemies()
	_define_gears()
	_spawn_worlds()
	_spawn_players()
	_spawn_gear_puzzle()
	_load_past_map()
	_load_future_map()
	_spawn_npcs()
	_spawn_enemies()
	_spawn_gears()
	_build_overlays()
	_connect_hud()
	_connect_signals()
	_fade_in_both()

func _define_gears() -> void:
	_past_gears = {
		0: [{"type": "puzzle","x": 450, "y": 210}],
	}
	
	_future_gears = {
	}
	
func _define_enemies() -> void:
	_past_enemies = {
		0: [
			{"type": "orc", "x": 632, "y": 904, "hp": 3},
			{"type": "orc", "x": 616, "y": 1088, "hp": 3},
			{"type": "orc", "x": 950, "y": 800, "hp": 3},
			{"type": "orc", "x": 856, "y": 928, "hp": 3},
		],
		1: [
			{"type": "orc", "x": 1136, "y": 1920, "hp": 3},
			{"type": "archer", "x": 768, "y": 2088, "hp": 3},
			{"type": "armored_orc", "x": 1200, "y": 1728, "hp": 3},
			{"type": "archer", "x": 688, "y": 1816, "hp": 3},
		],
		2: [
			{"type": "orc", "x": -736, "y": 1778, "hp": 3},
			{"type": "orc", "x": -760, "y": 1950, "hp": 3},
			{"type": "orc", "x": -368, "y": 2000, "hp": 3},
			{"type": "archer", "x": -360, "y": 1728, "hp": 3},
			{"type": "armored_orc", "x": -900, "y": 2000, "hp": 3},
			{"type": "archer", "x": -96, "y": 1720, "hp": 3},
		]
	}
	_future_enemies = {
		0: [
			{"type": "skeleton", "x": 358, "y": 1029, "hp": 3},
			{"type": "skeleton", "x": 1017, "y": 1019, "hp": 3},
			{"type": "skeleton", "x": 309, "y": 1292, "hp": 3},
			{"type": "skeleton", "x": 1062, "y": 1316, "hp": 3},
		],
		1: [
			{"type": "skeleton", "x": 356, "y": 1811, "hp": 3},
			{"type": "skeleton_archer", "x": 1038, "y": 1776, "hp": 3},
			{"type": "armored_skeleton", "x": 356, "y": 2014, "hp": 3},
			{"type": "skeleton_archer", "x": 1062, "y": 2070, "hp": 3},
		],
		2: [
			{"type": "skeleton", "x": -331, "y": 1735, "hp": 3},
			{"type": "skeleton", "x": -426, "y": 1924, "hp": 3},
			{"type": "skeleton", "x": -368, "y": 2135, "hp": 3},
			{"type": "skeleton_archer", "x": -900, "y": 2100, "hp": 3},
			{"type": "armored_skeleton", "x": -665, "y": 1902, "hp": 3},
			{"type": "skeleton_archer", "x": -900, "y": 1735, "hp": 3},
		]
	}

func _load_past_map() -> void:
	var map := preload("res://scenes/Past_map_1.tscn").instantiate()
	map.name = "PastMap"
	past_world.add_child(map)
	past_player.position = Vector2(540.0, 384.0)
	GameState.current_room_past = 0
	_setup_past_haze()


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


func _spawn_gear_puzzle() -> void:
	_gear_puzzle = GearPuzzleManager.new()
	_gear_puzzle.name = "GearPuzzleManager"
	add_child(_gear_puzzle)

func _spawn_gears() -> void:
	_spawn_gears_from_dict(_past_gears, past_world)
	_spawn_gears_from_dict(_future_gears, future_world)
				

func _spawn_gears_from_dict(gear_dict: Dictionary, world: Node2D) -> void:
	for gear_idx in gear_dict:
		for cfg in gear_dict[gear_idx]:
			var gear_scene: PackedScene = preload("res://scenes/gear_base.tscn")
			var gear: GearBase = gear_scene.instantiate()
			gear.position = Vector2(cfg["x"], cfg["y"])
			gear.gear_type = cfg["type"]
			world.add_child(gear)
			gear.setup()
	

func _spawn_enemies() -> void:
	_spawn_enemies_from_dict(_past_enemies, "past", past_world)
	_spawn_enemies_from_dict(_future_enemies, "future", future_world)
	_total_enemies = _live_enemies
	if _live_enemies > 0:
		TimelineManager.enemy_killed.connect(_on_enemy_killed)


func _spawn_enemies_from_dict(enemy_dict: Dictionary, timeline: String, world: Node2D) -> void:
	for room_idx in enemy_dict:
		for cfg in enemy_dict[room_idx]:
			var type_key: String = cfg.get("type", "default")
			var enemy_scene: PackedScene = ENEMY_SCENES.get(type_key, ENEMY_SCENES["default"])
			var enemy: EnemyBase = enemy_scene.instantiate()
			enemy.position = Vector2(cfg["x"], cfg["y"])
			enemy.timeline = timeline
			enemy.tint = cfg.get("tint", Color.WHITE)
			enemy.hp = cfg.get("hp", 3)
			enemy.speed = cfg.get("speed", 55.0)
			enemy.chase_speed = cfg.get("chase_speed", 85.0)
			enemy.is_boss = cfg.get("is_boss", false)
			enemy.attack_damage = cfg.get("attack_damage", 1)
			enemy.attack_cooldown = cfg.get("attack_cooldown", 1.2)
			enemy.detection_radius = cfg.get("detection_radius", 120.0)
			enemy.z_index = 10
			_live_enemies+=1
			world.add_child(enemy)

func _on_enemy_killed(_timeline: String) -> void:
	_live_enemies -= 1
	_update_future_suppression()
	_update_past_haze()

func _update_future_suppression() -> void:
	if not future_player:
		return
	
	var progress := 0.0
	if _total_enemies > 0:
		progress = 1.0 - (float(_live_enemies)/float(_total_enemies))
		
	var t := ease(progress, -2.0)
	future_player.SUPPRESS_CHANCE        = lerp(0.2,  0.95, t)
	future_player.SUPPRESS_INTERVAL_MIN  = lerp(5.0,  0.4,  t)
	future_player.SUPPRESS_INTERVAL_MAX  = lerp(10.0, 1.2,  t)
	future_player.SUPPRESS_DURATION_MIN  = lerp(0.3,  0.8,  t)
	future_player.SUPPRESS_DURATION_MAX  = lerp(0.8,  2.5,  t)
	

func _setup_past_haze() -> void:
	_haze_layer          = CanvasLayer.new()
	
	_haze_layer.layer    = 10         
	past_world.add_child(_haze_layer)

	_haze_rect           = ColorRect.new()
	_haze_rect.anchor_right  = 1.0
	_haze_rect.anchor_bottom = 1.0
	_haze_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	_haze_material        = ShaderMaterial.new()
	_haze_material.shader = preload("res://scripts/shaders/haze_shader.gdshader")
	_haze_rect.material   = _haze_material

	_haze_layer.add_child(_haze_rect)
	_update_past_haze()   


func _update_past_haze() -> void:
	if not _haze_material:
		return

	var progress := 0.0
	if _total_enemies > 0:
		progress = 1.0 - (float(_live_enemies) / float(_total_enemies))

	var t := ease(progress, -2.0)
	_haze_material.set_shader_parameter("progress", t)
	

func get_live_enemies() -> int:
	return _live_enemies


func _spawn_npcs() -> void:
	const SOLAN_SCENE := preload("res://scenes/characters/Solan.tscn")
	const PLAYER_LAYER := 2
	
	# Past Solan
	var past_solan := SOLAN_SCENE.instantiate()
	past_solan.position = Vector2(540, 200)
	past_solan.z_index = 10
	past_world.add_child(past_solan)
	(past_solan as Solen).set_state(Solen.STATE.IDLE_PAST)

	var past_trigger := Area2D.new()
	past_trigger.position = Vector2(540, 200)
	past_trigger.collision_layer = 0
	past_trigger.collision_mask = PLAYER_LAYER
	var ps := CollisionShape2D.new()
	var pc := CircleShape2D.new()
	pc.radius = 40.0
	ps.shape = pc
	past_trigger.add_child(ps)
	var past_fired := [false]
	past_trigger.body_entered.connect(func(body: Node2D):
		if past_fired[0] or not body.is_in_group("players"):
			return
		if DialogueManager.is_active():
			return
		past_fired[0] = true
		past_trigger.monitoring = false
		(past_solan as Solen).set_state(Solen.STATE.TALK)
		DialogueManager.start_dialogue("res://data/dialogue/guide_past.json")
		DialogueManager.dialogue_ended.connect(func():
			(past_solan as Solen).set_state(Solen.STATE.IDLE_PAST)
		, CONNECT_ONE_SHOT)
	)
	past_world.add_child(past_trigger)

	# Future Solan
	var future_solan := SOLAN_SCENE.instantiate()
	future_solan.position = Vector2(688, 200)
	future_solan.z_index = 10
	future_world.add_child(future_solan)
	(future_solan as Solen).set_state(Solen.STATE.IDLE_FUTURE)

	var future_trigger := Area2D.new()
	future_trigger.position = Vector2(688, 200)
	future_trigger.collision_layer = 0
	future_trigger.collision_mask = PLAYER_LAYER
	var fs := CollisionShape2D.new()
	var fc := CircleShape2D.new()
	fc.radius = 40.0
	fs.shape = fc
	future_trigger.add_child(fs)
	var future_fired := [false]
	future_trigger.body_entered.connect(func(body: Node2D):
		if future_fired[0] or not body.is_in_group("players"):
			return
		if DialogueManager.is_active():
			return
		future_fired[0] = true
		future_trigger.monitoring = false
		(future_solan as Solen).set_state(Solen.STATE.TALK)
		DialogueManager.start_dialogue("res://data/dialogue/guide_future.json")
		DialogueManager.dialogue_ended.connect(func():
			(future_solan as Solen).set_state(Solen.STATE.IDLE_FUTURE)
		, CONNECT_ONE_SHOT)
	)
	future_world.add_child(future_trigger)


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
