extends PlayerBase


func _ready() -> void:
	timeline = "past"
	action_left    = "past_left"
	action_right   = "past_right"
	action_up      = "past_up"
	action_down    = "past_down"
	action_attack  = "past_attack"
	action_heavy   = "past_heavy"
	action_interact = "past_interact"
	action_dash    = "past_dash"
	slash_color = Color(0.2, 0.85, 0.7)
	sprite.play("idle")
	_connect_signals()

func _begin_heavy() -> void:
	if heavy_cooldown_timer > 0.0:
		return
	state = State.ATTACK
	is_heavy = true
	combo_stage = 0
	combo_queued = false
	combo_window_timer = 0.0

	attack_timer = HEAVY_DURATION
	attack_windup_timer = 0.0
	attack_hit_timer = 0.0
	heavy_cooldown_timer = 10

	hitbox.monitoring = false
	velocity = velocity * 0.2
	stats.heal(1)
	_play("heal")
	shake_amount = 1.5

func _play_dash_animation() -> void:
	_play("roll")

func _get_dash_duration() -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	var frame_count: int = frames.get_frame_count("roll")
	var fps: float = frames.get_animation_speed("roll")
	return frame_count / fps
