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
var type_str: String = "past"
var keyboard_roll_action: String = "Shift"
var keyboard_light_attack_action: String = "Space"
var keyboard_heavy_attack_action: String = "Q"
var keyboard_interact_action: String = "E"
var heavy_attack_action: String = "healing effect"
var target: Node2D = null
var _player_inside: Node2D = null
var talked: bool = false
var is_tutorial_interact: bool = false
var is_tutorial_light_attack: bool = false
var is_tutorial_heavy_attack: bool = false
var is_tutorial_roll: bool = false
var facing: Vector2 = Vector2.DOWN

var _tutorial_queue: Array[String] = []
var _tutorial_timer: float = 0.0
var _tutorial_interval: float = 5.0

@export var follow_speed: float = 95.0
@onready var detection: Area2D            = $Detection
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready()->void:
	detection.body_entered.connect(_on_player_detected)
	update_animation()

func _on_player_detected(body: Node2D) -> void:
	if body.is_in_group("players"):
		target = body

func _physics_process(delta: float) -> void:
	if target == null:
		return

	if type == TYPE.FUTURE:
		type_str = "future"
		keyboard_roll_action = "' / '"
		keyboard_light_attack_action = "Enter"
		keyboard_heavy_attack_action = "','"
		keyboard_interact_action = "'.'"
		heavy_attack_action = "heavy attack"

	if not is_tutorial_interact:
		is_tutorial_interact = true
		TimelineManager.tutorial_text.emit("Press %s/Cross to interact" % keyboard_interact_action, type_str)

	_process_tutorial_queue(delta)

	if not DialogueManager.is_active():
		var interact_action: String = "past_interact" if target.timeline == "past" else "future_interact"
		if Input.is_action_just_pressed(interact_action):
			if not talked:
				if type == TYPE.FUTURE:
					DialogueManager.start_dialogue("res://data/dialogue/guide_future.json")
				else:
					DialogueManager.start_dialogue("res://data/dialogue/guide_past.json")

				DialogueManager.dialogue_ended.connect(func():
					talked = true
					state = STATE.FOLLOW
				, CONNECT_ONE_SHOT)

	match state:
		STATE.FOLLOW:
			_state_follow(delta)

	move_and_slide()
func _unhandled_input(event: InputEvent) -> void:
	if not DialogueManager.is_active():
		return

	if not event.is_action_pressed("dialogue_advance"):
		return

	get_viewport().set_input_as_handled()
	DialogueManager.next_line()

func _process_tutorial_queue(delta: float) -> void:
	if _tutorial_queue.is_empty():
		return
	_tutorial_timer -= delta
	if _tutorial_timer <= 0.0:
		TimelineManager.tutorial_text.emit(_tutorial_queue.pop_front(), type_str)
		_tutorial_timer = _tutorial_interval

func _queue_tutorial(text: String) -> void:
	_tutorial_queue.append(text)


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
	var _type: String

	var dist: float = global_position.distance_to(target.global_position)
	if dist < 96.0:
		velocity = Vector2.ZERO
		sprite.play("idle_before" if type == TYPE.PAST else "idle_after")
		return

	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	velocity = velocity.lerp(dir * follow_speed, 8.0 * delta)
	_update_flip()
	
	if not is_tutorial_light_attack:
		is_tutorial_light_attack = true
		_queue_tutorial("Press %s/Square for light attack" % keyboard_light_attack_action)
		_queue_tutorial("Press %s/Triangle for %s" % [keyboard_heavy_attack_action, heavy_attack_action])
		_queue_tutorial("Press %s/Circle to roll" % keyboard_roll_action)
