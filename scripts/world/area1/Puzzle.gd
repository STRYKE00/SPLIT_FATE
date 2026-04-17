extends Node

const PLAYER_LAYER := 2

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

var past_world: Node2D
var future_world: Node2D
var past_overlay: ColorRect
var future_overlay: ColorRect

var _live_enemies: int = 0
var _live_past_enemies: int = 0
var _past_enemies: Dictionary = {}
var _future_enemies: Dictionary = {}

var _past_gears: Dictionary = {}
var _future_gears: Dictionary = {}

var _gear_puzzle: GearPuzzleManager


func setup(p_past_world: Node2D, p_future_world: Node2D, p_past_overlay: ColorRect, p_future_overlay: ColorRect) -> void:
	past_world = p_past_world
	future_world = p_future_world
	past_overlay = p_past_overlay
	future_overlay = p_future_overlay

	_define_enemies()
	_define_gears()
	_spawn_gear_puzzle()
	_spawn_enemies()
	_spawn_gears()
	_spawn_broken_bridge()
	_spawn_npcs()


# ── Gear definitions ──

func _define_gears() -> void:
	_past_gears = {
		0: [
			{"gear_id": "stone", "type": "puzzle", "x": 248, "y": 1016},
			{"gear_id": "log", "type": "puzzle", "x": -579, "y": 1920},
		],
	}

	_future_gears = {
	}


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
			gear.gear_id = cfg.get("gear_id", "")
			gear.gear_type = cfg.get("type", "")
			gear.z_index = 10
			world.add_child(gear)
			gear.setup()


# ── Enemy definitions ──

func _define_enemies() -> void:
	_past_enemies = {
		0: [
			{"type": "orc", "x": 632, "y": 904, "hp": 3},
			#{"type": "orc", "x": 616, "y": 1088, "hp": 3},
			#{"type": "orc", "x": 950, "y": 800, "hp": 3},
			#{"type": "orc", "x": 856, "y": 928, "hp": 3},
		],
		1: [
			#{"type": "orc", "x": 1136, "y": 1920, "hp": 3},
			#{"type": "archer", "x": 768, "y": 2088, "hp": 3},
			#{"type": "armored_orc", "x": 1200, "y": 1728, "hp": 3},
			#{"type": "archer", "x": 688, "y": 1816, "hp": 3},
		],
		2: [
			#{"type": "orc", "x": -736, "y": 1778, "hp": 3},
			#{"type": "orc", "x": -760, "y": 1950, "hp": 3},
			#{"type": "orc", "x": -368, "y": 2000, "hp": 3},
			#{"type": "archer", "x": -360, "y": 1728, "hp": 3},
			#{"type": "armored_orc", "x": -900, "y": 2000, "hp": 3},
			#{"type": "archer", "x": -96, "y": 1720, "hp": 3},
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


func _spawn_enemies() -> void:
	_spawn_enemies_from_dict(_past_enemies, "past", past_world)
	_spawn_enemies_from_dict(_future_enemies, "future", future_world)
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
			_live_enemies += 1
			if timeline == "past":
				_live_past_enemies += 1
			world.add_child(enemy)


func _on_enemy_killed(timeline: String) -> void:
	_live_enemies -= 1
	if timeline == "past":
		_live_past_enemies -= 1


func get_live_enemies() -> int:
	return _live_enemies


func get_live_past_enemies() -> int:
	return _live_past_enemies


# ── Broken bridge ──

func _spawn_broken_bridge() -> void:
	var bridge_x := -1000.0
	var bridge_y := 1856.0
	var block_w := 64.0
	var block_h := 64.0
	var wall_center := Vector2(bridge_x + block_w * 0.5, bridge_y + block_h * 0.5)

	# Collision wall blocking the past bridge
	var past_wall := StaticBody2D.new()
	past_wall.name = "BrokenBridgeWall"
	past_wall.position = wall_center
	past_wall.collision_layer = 1
	past_wall.collision_mask = 0
	var pw_shape := CollisionShape2D.new()
	var pw_rect := RectangleShape2D.new()
	pw_rect.size = Vector2(block_w, block_h)
	pw_shape.shape = pw_rect
	past_wall.add_child(pw_shape)
	past_world.add_child(past_wall)

	# Collision wall blocking the future bridge
	var future_wall := StaticBody2D.new()
	future_wall.name = "BrokenBridgeWall"
	future_wall.position = Vector2(-1045, 1938)
	future_wall.collision_layer = 1
	future_wall.collision_mask = 0
	var fw_shape := CollisionShape2D.new()
	var fw_rect := RectangleShape2D.new()
	fw_rect.size = Vector2(block_w, block_h)
	fw_shape.shape = fw_rect
	future_wall.add_child(fw_shape)
	future_world.add_child(future_wall)

	# Future interaction trigger — Ren's dialogue at the broken bridge
	var future_trigger := Area2D.new()
	future_trigger.name = "BrokenBridgeTriggerFuture"
	future_trigger.position = Vector2(-1045, 1938)
	future_trigger.collision_layer = 0
	future_trigger.collision_mask = PLAYER_LAYER
	var ft_shape := CollisionShape2D.new()
	var ft_rect := RectangleShape2D.new()
	ft_rect.size = Vector2(block_w + 16, block_h + 16)
	ft_shape.shape = ft_rect
	future_trigger.add_child(ft_shape)
	var future_bridge_fired := [false]
	future_trigger.body_entered.connect(func(body: Node2D):
		if future_bridge_fired[0] or not body.is_in_group("players"):
			return
		if DialogueManager.is_active():
			return
		future_bridge_fired[0] = true
		future_trigger.monitoring = false
		DialogueManager.start_dialogue("res://data/dialogue/broken_bridge_future.json")
	)
	future_world.add_child(future_trigger)

	# Interaction trigger (past — Mira initiates the repair)
	var trigger := Area2D.new()
	trigger.name = "BrokenBridgeTrigger"
	trigger.position = wall_center
	trigger.collision_layer = 0
	trigger.collision_mask = PLAYER_LAYER
	var trigger_shape := CollisionShape2D.new()
	var trigger_rect := RectangleShape2D.new()
	trigger_rect.size = Vector2(block_w + 16, block_h + 16)
	trigger_shape.shape = trigger_rect
	trigger.add_child(trigger_shape)

	var bridge_phase := [0]  # 0 = broken, 1 = items collected (ready to repair)
	trigger.body_entered.connect(func(body: Node2D):
		if not body.is_in_group("players"):
			return
		if DialogueManager.is_active():
			return

		if bridge_phase[0] == 0:
			# First visit — broken bridge dialogue
			trigger.monitoring = false
			DialogueManager.start_dialogue("res://data/dialogue/broken_bridge.json")
			DialogueManager.dialogue_ended.connect(func():
				if _gear_puzzle.has_all_gears():
					bridge_phase[0] = 1
				trigger.monitoring = true
			, CONNECT_ONE_SHOT)

		elif bridge_phase[0] == 1:
			# All items collected — repair the bridge
			bridge_phase[0] = 2
			trigger.monitoring = false
			DialogueManager.start_dialogue("res://data/dialogue/bridge_repair.json")
			DialogueManager.dialogue_ended.connect(func():
				_repair_bridge(past_wall, future_wall, trigger, future_trigger)
			, CONNECT_ONE_SHOT)
	)
	past_world.add_child(trigger)


func _repair_bridge(past_wall: StaticBody2D, future_wall: StaticBody2D, trigger: Area2D, future_trigger: Area2D) -> void:
	GameState.is_transitioning = true

	# Fade both viewports to black simultaneously
	var tw := create_tween().set_parallel(true)
	tw.tween_property(past_overlay, "color:a", 1.0, 0.6)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_property(future_overlay, "color:a", 1.0, 0.6)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tw.finished

	# Toggle bridge layers in both timelines
	for map_node in [past_world.get_node("PastMap"), future_world.get_node("FutureMap")]:
		var bridge_broken: Node = map_node.find_child("Bridge", false)
		var bridge_completed: Node = map_node.find_child("BridgeCompleted", false)
		if bridge_broken:
			bridge_broken.visible = false
		if bridge_completed:
			bridge_completed.visible = true

	# Remove collision walls and triggers
	past_wall.queue_free()
	future_wall.queue_free()
	trigger.queue_free()
	if is_instance_valid(future_trigger):
		future_trigger.queue_free()

	# Fade both viewports back in simultaneously
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(past_overlay, "color:a", 0.0, 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(future_overlay, "color:a", 0.0, 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tw2.finished

	GameState.is_transitioning = false


# ── NPCs ──

func _spawn_npcs() -> void:
	const SOLAN_SCENE := preload("res://scenes/characters/Solan.tscn")

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
