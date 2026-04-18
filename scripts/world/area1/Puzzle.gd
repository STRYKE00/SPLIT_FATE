extends Node

const PLAYER_LAYER := 2

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

const GEAR_SCENE = {
	"heal": preload("res://scenes/gear_heal.tscn"),
	"damage": preload("res://scenes/gear_damage.tscn"),
	"default": preload("res://scenes/gear_base.tscn")
	
}

func setup(p_past_world: Node2D, p_future_world: Node2D, p_past_overlay: ColorRect, p_future_overlay: ColorRect) -> void:
	past_world = p_past_world
	future_world = p_future_world
	past_overlay = p_past_overlay
	future_overlay = p_future_overlay

	_define_gears()
	_spawn_gear_puzzle() 
	_spawn_gears()
	_spawn_broken_bridge()


# ── Gear definitions ──

func _define_gears() -> void:
	_past_gears = {
		0: [
			{"gear_id": "stone", "type": "puzzle", "x": 248, "y": 1016},
			{"gear_id": "log", "type": "puzzle", "x": -579, "y": 1920},
			{"gear_id": "damage", "type": "powerup", "x": 1221, "y": 1520},
		],
	}

	_future_gears = {
		0: [
			{"gear_id": "heal", "type": "powerup", "x": 0, "y": 1920},
		]
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
			var type_key:String = cfg.get("type", "default")
			var id_key:String = cfg.get("gear_id", "default")
			var gear_scene: PackedScene = GEAR_SCENE.get(id_key, GEAR_SCENE["default"])
			var gear: GearBase = gear_scene.instantiate()
			gear.position = Vector2(cfg["x"], cfg["y"])
			gear.gear_id = cfg.get("gear_id", "")
			gear.gear_type = type_key
			gear.z_index = 10
			world.add_child(gear)
			gear.setup()

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
