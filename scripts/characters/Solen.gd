class_name Solen
extends CharacterBody2D

enum STATE {
	IDLE_PAST,
	IDLE_FUTURE,
	TALK,
	FOLLOW,
	TURN_AWAY,
	URGENT_BOSS
}

enum TYPE {
	PAST,
	FUTURE
}

var state: STATE = STATE.IDLE_PAST
var type: TYPE = TYPE.PAST
var target: Node2D = null
var _player_inside: Node2D = null
var talked: bool = false
var facing: Vector2 = Vector2.DOWN
@export var follow_speed: float = 60.0
@onready var detection: Area2D            = $Detection
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready()->void:
	detection.body_entered.connect(_on_player_detected)
	detection.body_exited.connect(_on_player_lost)
	update_animation()

func _on_player_detected(body: Node2D) -> void:
	if body.is_in_group("players"):
		target = body
		
func _on_player_lost(body: Node2D) -> void:
	if body == target:
		target = null

func _physics_process(delta: float) -> void:
	if target==null:
		return
	var interact_action: String = "past_interact" if target.timeline == "past" else "future_interact"
	if Input.is_action_just_pressed(interact_action):
		DialogueManager.start_dialogue("res://data/dialogue/guide_past.json")
		DialogueManager.dialogue_ended.connect(func():
			talked = true
			state=STATE.FOLLOW
		, CONNECT_ONE_SHOT)
	

	match state:
		STATE.FOLLOW:
			_state_follow(delta)

	move_and_slide()

func update_animation()->void:
	match state:
		STATE.IDLE_PAST:
			sprite.play("idle_before")
		STATE.IDLE_FUTURE:
			sprite.play("idle_after")
		STATE.FOLLOW:
			sprite.play("idle_after")
		STATE.TALK:
			sprite.play("talk")
		STATE.TURN_AWAY:
			sprite.play("turn_away")
		STATE.URGENT_BOSS:
			sprite.play("urgent_boss")

func set_state(new_state: STATE)-> void:
	if state==new_state:
		return

	state = new_state
	update_animation()
	
func set_type(new_type: TYPE) -> void:
	if type==new_type:
		return
	type = new_type
	update_animation()

func get_idle_state(t: TYPE)-> STATE:
	if t==TYPE.FUTURE:
		return STATE.IDLE_FUTURE
	else:
		return STATE.IDLE_PAST

func _update_flip() -> void:
	if abs(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0
		
func _state_follow(delta: float) -> void:
	if target == null:
		return

	var dist: float = global_position.distance_to(target.global_position)
	if dist < 32.0:
		velocity = Vector2.ZERO
		sprite.play("idle_before" if type == TYPE.PAST else "idle_after")
		return

	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	velocity = velocity.lerp(dir * follow_speed, 8.0 * delta)
	_update_flip()
