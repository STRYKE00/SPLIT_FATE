extends Area2D
class_name GearBase

const PLAYER_LAYER := 2

var gear_id: String = ""
var gear_type: String = ""
var trigger_size: Vector2 = Vector2(32, 32)
var after_clear: bool = false
var _player_inside: Node2D = null

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $ColorRect
@onready var _label: Label = $Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER

	var rect_shape := RectangleShape2D.new()
	rect_shape.size = trigger_size
	_shape.shape = rect_shape

	_visual.size = trigger_size
	_visual.position = -trigger_size * 0.5
	_visual.color = Color(0.85, 0.65, 0.2)
	_visual.z_index = 2

	_label.text = "G"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = trigger_size
	_label.position = -trigger_size * 0.5
	_label.add_theme_font_size_override("font_size", 16)
	_label.z_index = 3
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


func _process(_delta: float) -> void:
	if _player_inside == null:
		return
	var interact_action: String = "past_interact" if _player_inside.timeline == "past" else "future_interact"
	if Input.is_action_just_pressed(interact_action):
		TimelineManager.gear_collected.emit(gear_id, _player_inside.timeline)
		queue_free()
