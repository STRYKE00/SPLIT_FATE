extends EnemyBase

const MAX_HP := 20
const PHASE_2_HP := 10
const WALK_SPEED := 70.0
const CHASE_SPEED := 110.0

const LIGHT_RANGE := 36.0
const LIGHT_DAMAGE := 1
const LIGHT_ATTACK_DURATION := 0.6
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

	# Attack selection
	if _cooldown > 0.0:
		return
	var dist_sq: float = global_position.distance_squared_to(player.global_position)

	# Phase 2: heavy attack can pre-empt range-based choices
	if stats.hp <= PHASE_2_HP:
		var t: float = 1.0 - float(stats.hp) / float(PHASE_2_HP)
		var heavy_chance: float = lerp(0.3, 0.7, t)
		if randf() < heavy_chance:
			_begin_heavy()
			return

	if dist_sq <= LIGHT_RANGE * LIGHT_RANGE:
		_begin_light()
	elif dist_sq > (LIGHT_RANGE * 1.5) * (LIGHT_RANGE * 1.5):
		_begin_roll(player)


func _begin_light() -> void:
	_s = SolenState.LIGHT_ATTACK
	_cooldown = ATTACK_COOLDOWN
	_state_timer = LIGHT_ATTACK_DURATION
	_has_hit = false
	attack_damage = LIGHT_DAMAGE
	hitbox_collision.position = facing * 22.0
	hitbox.monitoring = true
	velocity = Vector2.ZERO
	_play_anim("light_attack")


func _tick_light(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 12.0 * delta)
	if _state_timer <= 0.0:
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


var _telegraph: Node2D = null


func _begin_heavy() -> void:
	_s = SolenState.HEAVY_ATTACK
	_cooldown = ATTACK_COOLDOWN + HEAVY_TELEGRAPH
	_state_timer = HEAVY_TELEGRAPH
	velocity = Vector2.ZERO
	hitbox.monitoring = false
	_play_anim("heavy_attack")
	_spawn_telegraph()


func _tick_heavy(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_resolve_heavy_damage()
		_cleanup_telegraph()
		_s = SolenState.WALK


func _spawn_telegraph() -> void:
	_cleanup_telegraph()
	var t := Node2D.new()
	t.name = "HeavyTelegraph"
	add_child(t)
	_telegraph = t

	var visual := _make_ring_visual()
	t.add_child(visual)
	visual.scale = Vector2(0.01, 0.01)

	var tw := t.create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE, HEAVY_TELEGRAPH)


func _make_ring_visual() -> Node2D:
	var holder := Node2D.new()
	var poly := Polygon2D.new()
	poly.color = Color(1.0, 0.2, 0.2, 0.35)
	var verts := PackedVector2Array()
	var segments := 48
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		verts.append(Vector2(cos(angle), sin(angle)) * HEAVY_RADIUS)
	poly.polygon = verts
	holder.add_child(poly)
	return holder


func _resolve_heavy_damage() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d <= HEAVY_RADIUS and p.has_method("receive_hit"):
			var dir: Vector2 = (p.global_position - global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			p.receive_hit(HEAVY_DAMAGE, dir)


func _cleanup_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _tick_hurt(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
	if _state_timer <= 0.0:
		_s = SolenState.WALK


func _pick_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p is PlayerBase and p.stats and p.stats.is_dead:
			continue
		var d_sq: float = global_position.distance_squared_to(p.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = p
	return best


func _play_anim(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func receive_hit(damage: int, knockback_dir: Vector2) -> void:
	if is_dead or _invulnerable:
		return
	stats.take_damage(damage)
	TimelineManager.boss_hp_changed.emit(stats.hp, stats.max_hp)
	if stats.is_dead:
		return
	# Uninterruptible heavy windup — do not cancel into HURT
	if _s == SolenState.HEAVY_ATTACK:
		_flash()
		return
	_s = SolenState.HURT
	_state_timer = HURT_DURATION
	velocity = knockback_dir * KNOCKBACK_FORCE
	hitbox.monitoring = false
	_play_anim("hurt")
	_flash()


func _on_died() -> void:
	is_dead = true
	_s = SolenState.DEAD
	hitbox.monitoring = false
	hurtbox.collision_layer = 0
	detection.monitoring = false
	collision_layer = 0
	velocity = Vector2.ZERO
	_cleanup_telegraph()
	_play_anim("death")
	TimelineManager.enemy_killed.emit(timeline)
	TimelineManager.boss_defeated.emit(timeline)
	await get_tree().create_timer(1.2).timeout
	queue_free()


func play_victory() -> void:
	if is_dead:
		return
	_s = SolenState.VICTORY
	velocity = Vector2.ZERO
	hitbox.monitoring = false
	_cleanup_telegraph()
	_play_anim("victory")
