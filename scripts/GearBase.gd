extends Area2D
class_name GearBase

const PLAYER_LAYER := 2

var gear_id: String = ""
var gear_type: String = ""
var trigger_size: Vector2 = Vector2(48, 48)
var after_clear: bool = false
var _player_inside: Node2D = null
var locked: bool = false

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER

	var rect_shape := RectangleShape2D.new()
	rect_shape.size = trigger_size
	_shape.shape = rect_shape

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	_player_inside = body


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	_player_inside = null


func setup() -> void:
	if gear_type == "puzzle":
		locked = true
		TimelineManager.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_timeline: String) -> void:
	var main = get_tree().current_scene
	if main.has_method("get_live_past_enemies") and main.get_live_past_enemies() <= 0 && gear_type=="puzzle":
		locked = false
		TimelineManager.enemy_killed.disconnect(_on_enemy_killed)


func _process(_delta: float) -> void:
	if _player_inside == null:
		return
	if locked:
		return
	var interact_action: String = "past_interact" if _player_inside.timeline == "past" else "future_interact"
	if Input.is_action_just_pressed(interact_action):
		_collect()


func _collect() -> void:
	TimelineManager.gear_collected.emit(gear_id, _player_inside.timeline)
	# Remove the interactive tiles from the TileMap so the sprite disappears
	_erase_interactive_tiles()
	queue_free()


func _erase_interactive_tiles() -> void:
	var world: Node2D = get_parent()
	if world == null:
		return
	# Find the map node (PastMap or FutureMap) which contains the Interactive item layer
	for child in world.get_children():
		var layer: TileMapLayer = child.find_child("Interactive item", true, false) as TileMapLayer
		if layer == null:
			continue
		# Erase tiles near this pickup's position (convert to tile coords)
		var local_pos: Vector2 = layer.to_local(global_position)
		var center_tile: Vector2i = layer.local_to_map(local_pos)
		# Erase a small area around the center to cover the full item sprite
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var tile_pos := Vector2i(center_tile.x + dx, center_tile.y + dy)
				if layer.get_cell_source_id(tile_pos) != -1:
					layer.erase_cell(tile_pos)
		break
