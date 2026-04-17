extends PlayerBase

class_name PlayerFuture

# --- suppression config ---
var SUPPRESS_INTERVAL_MIN := 0.0 
var SUPPRESS_INTERVAL_MAX := 0.0
var SUPPRESS_DURATION_MIN := 0.0
var SUPPRESS_DURATION_MAX := 0.0
var SUPPRESS_CHANCE      := 0.00   

var _suppress_input := false
var _suppress_timer := 0.0
var _suppress_cooldown := 0.0  

func _ready() -> void:
	timeline        = "future"
	action_left     = "future_left"
	action_right    = "future_right"
	action_up       = "future_up"
	action_down     = "future_down"
	action_attack   = "future_attack"
	action_heavy    = "future_heavy"
	action_interact = "future_interact"
	action_dash     = "future_dash"
	slash_color     = Color(0.7, 0.5, 1.0)
	sprite.play("idle")
	_connect_signals()	
	_reset_cooldown()

func _process(delta: float) -> void:
	if _suppress_input:
		_suppress_timer -= delta
		if _suppress_timer <= 0.0:
			_suppress_input = false
			_reset_cooldown()
	else:
		_suppress_cooldown -= delta
		if _suppress_cooldown <= 0.0:
			if randf() < SUPPRESS_CHANCE:
				_suppress_input = true
				_suppress_timer = randf_range(SUPPRESS_DURATION_MIN, SUPPRESS_DURATION_MAX)
			else:
				_reset_cooldown()   # rolled against suppression, wait again

func _reset_cooldown() -> void:
	_suppress_cooldown = randf_range(SUPPRESS_INTERVAL_MIN, SUPPRESS_INTERVAL_MAX)

func _play_dash_animation() -> void:
	_play("roll")

func _get_dash_duration() -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	var frame_count: int = frames.get_frame_count("roll")
	var fps: float = frames.get_animation_speed("roll")
	return frame_count / fps

# --- overridden input helpers ---

func _input_dir() -> Vector2:
	if _suppress_input:
		return Vector2.ZERO
	return Vector2(
		Input.get_action_strength(action_right) - Input.get_action_strength(action_left),
		Input.get_action_strength(action_down)  - Input.get_action_strength(action_up)
	)

func _attack_pressed() -> bool:
	return Input.is_action_just_pressed(action_attack)   # attacks still register

func _heavy_pressed() -> bool:
	return action_heavy != "" and Input.is_action_just_pressed(action_heavy)

func _update_sprite_flip() -> void:
	if abs(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0

func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
