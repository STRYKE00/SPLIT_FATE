extends Node2D
class_name Room

const TILE := 32
const WALL_THICKNESS := 32
const DOOR_WIDTH := 64

var room_w: int = 11
var room_h: int = 12
var timeline: String = "past"
var room_id: int = 0
var is_cleared: bool = false

var floor_color := Color(0.82, 0.72, 0.52)
var wall_color  := Color(0.45, 0.38, 0.28)
var door_positions: Array = []
var enemy_configs: Array = []
var npc_configs: Array = []

var _live_enemies: int = 0
var _door_gates: Array = []
var _door_blockers: Array = []
var _entity_layer: Node2D
var _pixel_w: int
var _pixel_h: int


var SOLEN_SCENE: PackedScene = preload("res://scenes/characters/Solan.tscn")
const ENEMY_SCENES = {
	"orc": preload("res://scenes/characters/Enemies/Orc.tscn"),
	"default": preload("res://scenes/characters/EnemyBase.tscn")
}

func build() -> void:
	_pixel_w = room_w * TILE
	_pixel_h = room_h * TILE

	_draw_floor()
	_build_walls()
	_build_doors()

	_entity_layer = Node2D.new()
	_entity_layer.y_sort_enabled = true
	_entity_layer.z_index = 1
	add_child(_entity_layer)

	_spawn_npcs()
	_spawn_enemies()

	if _live_enemies == 0:
		is_cleared = true
		_set_doors_open(true)
	else:
		_set_doors_open(false)

	queue_redraw()


func _draw_floor() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.size = Vector2(_pixel_w, _pixel_h)
	floor_rect.color = floor_color
	floor_rect.z_index = -10
	add_child(floor_rect)

	var grid := Node2D.new()
	grid.z_index = -9
	add_child(grid)


func _draw() -> void:
	for x in range(TILE, _pixel_w, TILE):
		draw_line(Vector2(x, 0), Vector2(x, _pixel_h), floor_color.darkened(0.08), 1.0)
	for y in range(TILE, _pixel_h, TILE):
		draw_line(Vector2(0, y), Vector2(_pixel_w, y), floor_color.darkened(0.08), 1.0)


func _build_walls() -> void:
	var has_n := "north" in door_positions
	var has_s := "south" in door_positions
	var has_e := "east"  in door_positions
	var has_w := "west"  in door_positions
	var cx := _pixel_w / 2
	var cy := _pixel_h / 2
	var half_door := DOOR_WIDTH / 2

	if has_n:
		_wall(Vector2(0, 0), Vector2(cx - half_door, WALL_THICKNESS))
		_wall(Vector2(cx + half_door, 0), Vector2(_pixel_w - cx - half_door, WALL_THICKNESS))
	else:
		_wall(Vector2(0, 0), Vector2(_pixel_w, WALL_THICKNESS))

	if has_s:
		_wall(Vector2(0, _pixel_h - WALL_THICKNESS), Vector2(cx - half_door, WALL_THICKNESS))
		_wall(Vector2(cx + half_door, _pixel_h - WALL_THICKNESS), Vector2(_pixel_w - cx - half_door, WALL_THICKNESS))
	else:
		_wall(Vector2(0, _pixel_h - WALL_THICKNESS), Vector2(_pixel_w, WALL_THICKNESS))

	if has_w:
		_wall(Vector2(0, 0), Vector2(WALL_THICKNESS, cy - half_door))
		_wall(Vector2(0, cy + half_door), Vector2(WALL_THICKNESS, _pixel_h - cy - half_door))
	else:
		_wall(Vector2(0, 0), Vector2(WALL_THICKNESS, _pixel_h))

	if has_e:
		_wall(Vector2(_pixel_w - WALL_THICKNESS, 0), Vector2(WALL_THICKNESS, cy - half_door))
		_wall(Vector2(_pixel_w - WALL_THICKNESS, cy + half_door), Vector2(WALL_THICKNESS, _pixel_h - cy - half_door))
	else:
		_wall(Vector2(_pixel_w - WALL_THICKNESS, 0), Vector2(WALL_THICKNESS, _pixel_h))


func _wall(pos: Vector2, sz: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos + sz * 0.5
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = sz
	col.shape = rect
	body.add_child(col)

	var vis := ColorRect.new()
	vis.size = sz
	vis.position = -sz * 0.5
	vis.color = wall_color
	body.add_child(vis)

	add_child(body)


func _build_doors() -> void:
	var cx := _pixel_w / 2
	var cy := _pixel_h / 2

	for dir in door_positions:
		var door_area := Area2D.new()
		door_area.collision_layer = 0
		door_area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()

		var gate := ColorRect.new()
		gate.color = Color(0.35, 0.25, 0.15)

		var blocker := StaticBody2D.new()
		blocker.collision_layer = 1
		blocker.collision_mask = 0
		var blocker_shape := CollisionShape2D.new()
		var blocker_rect := RectangleShape2D.new()

		match dir:
			"north":
				door_area.position = Vector2(cx, WALL_THICKNESS * 0.25)
				rect.size = Vector2(DOOR_WIDTH - 8, 16)
				gate.size = Vector2(DOOR_WIDTH, WALL_THICKNESS)
				gate.position = Vector2(cx - DOOR_WIDTH / 2, 0)
				blocker.position = Vector2(cx, WALL_THICKNESS * 0.5)
				blocker_rect.size = Vector2(DOOR_WIDTH, WALL_THICKNESS)
			"south":
				door_area.position = Vector2(cx, _pixel_h - WALL_THICKNESS * 0.25)
				rect.size = Vector2(DOOR_WIDTH - 8, 16)
				gate.size = Vector2(DOOR_WIDTH, WALL_THICKNESS)
				gate.position = Vector2(cx - DOOR_WIDTH / 2, _pixel_h - WALL_THICKNESS)
				blocker.position = Vector2(cx, _pixel_h - WALL_THICKNESS * 0.5)
				blocker_rect.size = Vector2(DOOR_WIDTH, WALL_THICKNESS)
			"east":
				door_area.position = Vector2(_pixel_w - WALL_THICKNESS * 0.25, cy)
				rect.size = Vector2(16, DOOR_WIDTH - 8)
				gate.size = Vector2(WALL_THICKNESS, DOOR_WIDTH)
				gate.position = Vector2(_pixel_w - WALL_THICKNESS, cy - DOOR_WIDTH / 2)
				blocker.position = Vector2(_pixel_w - WALL_THICKNESS * 0.5, cy)
				blocker_rect.size = Vector2(WALL_THICKNESS, DOOR_WIDTH)
			"west":
				door_area.position = Vector2(WALL_THICKNESS * 0.25, cy)
				rect.size = Vector2(16, DOOR_WIDTH - 8)
				gate.size = Vector2(WALL_THICKNESS, DOOR_WIDTH)
				gate.position = Vector2(0, cy - DOOR_WIDTH / 2)
				blocker.position = Vector2(WALL_THICKNESS * 0.5, cy)
				blocker_rect.size = Vector2(WALL_THICKNESS, DOOR_WIDTH)

		shape.shape = rect
		door_area.add_child(shape)

		var dir_captured: String = dir
		door_area.body_entered.connect(func(body: Node2D):
			if body.is_in_group("players") and is_cleared:
				TimelineManager.room_transition_requested.emit(timeline, dir_captured)
		)
		add_child(door_area)

		gate.z_index = 5
		add_child(gate)
		_door_gates.append(gate)

		blocker_shape.shape = blocker_rect
		blocker.add_child(blocker_shape)
		add_child(blocker)
		_door_blockers.append(blocker_shape)


func _set_doors_open(open: bool) -> void:
	for gate in _door_gates:
		gate.visible = not open
	for blocker_shape in _door_blockers:
		blocker_shape.set_deferred("disabled", open)


func _spawn_enemies() -> void:
	for cfg in enemy_configs:
		var type_key = cfg.get("type", "default")
		var scene_to_spawn = ENEMY_SCENES.get(type_key, ENEMY_SCENES["default"])
		var enemy = scene_to_spawn.instantiate()
		enemy.position = Vector2(cfg["x"], cfg["y"])
		enemy.timeline = timeline
		enemy.tint = cfg.get("tint", Color(0.9, 0.3, 0.2))
		enemy.hp = cfg.get("hp", 3)
		enemy.speed = cfg.get("speed", 55.0)
		enemy.chase_speed = cfg.get("chase_speed", 85.0)
		enemy.is_boss = cfg.get("is_boss", false)
		_entity_layer.add_child(enemy)
		_live_enemies += 1

	if _live_enemies > 0:
		TimelineManager.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(tl: String) -> void:
	if tl != timeline:
		return
	_live_enemies -= 1
	if _live_enemies <= 0:
		is_cleared = true
		_set_doors_open(true)
		TimelineManager.room_cleared.emit(timeline)


func _spawn_npcs() -> void:
	for cfg in npc_configs:
		var npc_pos := Vector2(cfg["x"], cfg["y"])
		var dialogue_path: String = cfg["dialogue"]
		var npc_type: String = cfg["type"]
		
		var npc_node = SOLEN_SCENE.instantiate()
		npc_node.position = npc_pos
		_entity_layer.add_child(npc_node)
		
		var solen = npc_node as Solen
		match npc_type:
			"past":
				solen.set_state(Solen.STATE.IDLE_PAST)
			"future":
				solen.set_state(Solen.STATE.IDLE_FUTURE)

		var trigger := Area2D.new()
		trigger.position = npc_pos
		trigger.collision_layer = 0
		trigger.collision_mask = 2
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 40.0
		shape.shape = circle
		trigger.add_child(shape)
		trigger.body_entered.connect(func(body: Node2D):
			if body.is_in_group("players") and not DialogueManager.is_active():
				trigger.set_deferred("monitoring", false)
				DialogueManager.start_dialogue(dialogue_path)
		)
		add_child(trigger)


func get_spawn_point(from_dir: String) -> Vector2:
	var cx := float(_pixel_w) / 2.0
	var cy := float(_pixel_h) / 2.0
	match from_dir:
		"north": return Vector2(cx, WALL_THICKNESS + 24)
		"south": return Vector2(cx, _pixel_h - WALL_THICKNESS - 24)
		"east":  return Vector2(_pixel_w - WALL_THICKNESS - 24, cy)
		"west":  return Vector2(WALL_THICKNESS + 24, cy)
	return Vector2(cx, cy)


func get_center() -> Vector2:
	return Vector2(float(_pixel_w) / 2.0, float(_pixel_h) / 2.0)
