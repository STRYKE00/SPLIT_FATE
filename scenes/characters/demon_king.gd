extends EnemyBase

const MAX_HP := 20
const PHASE_2_HP := 10
const WALK_SPEED := 70.0
const CHASE_SPEED := 110.0

const LIGHT_RANGE := 36.0
const LIGHT_DAMAGE := 1
const HEAVY_TELEGRAPH := 1.0
const HEAVY_RADIUS := 112.0
const HEAVY_DAMAGE := 3
const ROLL_SPEED := 260.0
const ROLL_DURATION := 0.35
const ATTACK_COOLDOWN := 1.4
const HURT_DURATION := 0.25

enum SolenState { IDLE, WALK, LIGHT_ATTACK, HEAVY_ATTACK, ROLL, HURT, DEAD, VICTORY }

var _s: int = SolenState.IDLE
var _cooldown: float = 0.0
var _state_timer: float = 0.0
var _invulnerable: bool = false


func _ready() -> void:
	is_boss = true
	hp = MAX_HP
	super._ready()
	_s = SolenState.WALK
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if GameState.is_dialogue_active or GameState.is_transitioning:
		velocity = velocity.lerp(Vector2.ZERO, 12.0 * delta)
		move_and_slide()
		return

	_cooldown = max(0.0, _cooldown - delta)
	_state_timer = max(0.0, _state_timer - delta)

	match _s:
		SolenState.IDLE:          _tick_idle(delta)
		SolenState.WALK:          _tick_walk(delta)
		SolenState.LIGHT_ATTACK:  _tick_light(delta)
		SolenState.HEAVY_ATTACK:  _tick_heavy(delta)
		SolenState.ROLL:          _tick_roll(delta)
		SolenState.HURT:          _tick_hurt(delta)
		SolenState.VICTORY:       velocity = Vector2.ZERO
		SolenState.DEAD:          velocity = Vector2.ZERO

	move_and_slide()


func _tick_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	_play_anim("idle")
	_s = SolenState.WALK


func _tick_walk(delta: float) -> void:
	var player := _pick_nearest_player()
	if player == null:
		velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
		_play_anim("idle")
		return
	target = player
	var dir: Vector2 = (player.global_position - global_position).normalized()
	facing = dir
	velocity = velocity.lerp(dir * CHASE_SPEED, 8.0 * delta)
	_update_flip()
	_play_anim("walk")

	# Attack selection (Tasks 6 and 7; heavy added in Task 8)
	if _cooldown > 0.0:
		return
	var dist_sq: float = global_position.distance_squared_to(player.global_position)
	if dist_sq <= LIGHT_RANGE * LIGHT_RANGE:
		_begin_light()
	elif dist_sq > (LIGHT_RANGE * 1.5) * (LIGHT_RANGE * 1.5):
		_begin_roll(player)


func _begin_light() -> void:
	_s = SolenState.LIGHT_ATTACK
	_cooldown = ATTACK_COOLDOWN
	_has_hit = false
	attack_damage = LIGHT_DAMAGE
	hitbox_collision.position = facing * 22.0
	hitbox.monitoring = true
	velocity = Vector2.ZERO
	_play_anim("light_attack")


func _tick_light(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 12.0 * delta)
	if not sprite.is_playing() or sprite.animation != "light_attack":
		hitbox.monitoring = false
		_s = SolenState.WALK


func _begin_roll(player: Node2D) -> void:
	_s = SolenState.ROLL
	_cooldown = ATTACK_COOLDOWN
	_state_timer = ROLL_DURATION
	_invulnerable = true
	hitbox.monitoring = false
	var dir: Vector2 = (player.global_position - global_position).normalized()
	facing = dir
	velocity = dir * ROLL_SPEED
	_update_flip()
	_play_anim("roll")


func _tick_roll(delta: float) -> void:
	velocity = velocity.lerp(velocity.normalized() * ROLL_SPEED, 2.0 * delta)
	if _state_timer <= 0.0:
		_invulnerable = false
		_s = SolenState.WALK


func _tick_heavy(_delta: float) -> void:
	pass  # Task 8


func _tick_hurt(_delta: float) -> void:
	pass  # Task 9


func _pick_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_dead_player") and p.is_dead_player():
			continue
		var d_sq: float = global_position.distance_squared_to(p.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = p
	return best


func _play_anim(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
