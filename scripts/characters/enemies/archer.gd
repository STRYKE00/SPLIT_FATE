extends EnemyBase

const KITE_MIN := 80.0
const KITE_MAX := 140.0
const RANGED_COOLDOWN_SCALE := 2.5
const RANGED_COLOR := Color(1.0, 0.5, 0.2)  # orange arrow

var _ranged_cooldown: float = 0.0


func _ready() -> void:
	sprite.play("idle")
	_init_configs()


func _state_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		state = State.IDLE
		idle_timer = 1.0
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	var dist := global_position.distance_to(target.global_position)

	if dist < KITE_MIN:
		velocity = velocity.lerp(-dir * speed, 6.0 * delta)
	elif dist > KITE_MAX:
		velocity = velocity.lerp(dir * speed * 0.5, 6.0 * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)

	_update_flip()
	_play("walk")

	_ranged_cooldown -= delta
	if _ranged_cooldown <= 0.0 and dist < detection_radius:
		_ranged_cooldown = attack_cooldown * RANGED_COOLDOWN_SCALE
		_play("attack")
		_fire_projectile(RANGED_COLOR)
