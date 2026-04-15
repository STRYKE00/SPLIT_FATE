extends CharacterBody2D
class_name PlayerBase

const SPEED            := 130.0
const ACCEL_WEIGHT     := 12.0
const DECEL_WEIGHT     := 18.0
const ATTACK_COOLDOWN  := 0.45
const ATTACK_DURATION  := 0.3
const HURT_DURATION    := 0.25
const INVINCIBLE_TIME  := 0.7
const KNOCKBACK_FORCE  := 220.0
const ATTACK_RANGE     := 26.0
const ATTACK_DAMAGE    := 1
const DASH_SPEED       := 360.0
const DASH_DURATION    := 0.22
const DASH_COOLDOWN    := 0.7

enum State { IDLE, MOVE, ATTACK, HURT, DASH, DEAD }

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var invincible_timer: float = 0.0
var attack_active_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var shake_amount: float = 0.0
var timeline: String = ""
var slash_color: Color = Color.WHITE

var action_left    := ""
var action_right   := ""
var action_up      := ""
var action_down    := ""
var action_attack  := ""
var action_interact := ""
var action_dash    := ""

var _hit_targets: Array = []

# --- Node references (set up in the .tscn scene file) ---
@onready var sprite: AnimatedSprite2D     = $Sprite
@onready var hitbox: Area2D               = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hurtbox: Area2D              = $Hurtbox
@onready var stats: StatsComponent        = $StatsComponent
@onready var camera: Camera2D             = $Camera2D


func _ready() -> void:
	# Assign sprite frames (built from individual PNGs)
	sprite.sprite_frames = _build_frames()
	sprite.play("idle")

	# Connect signals
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	stats.died.connect(_on_died)

	add_to_group("players")


# --- Sprite frame builder (loads Ren's PNGs as AtlasTextures) ---

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	sf.add_animation("idle")
	sf.set_animation_speed("idle", 8.0)
	sf.set_animation_loop("idle", true)
	for i in [9, 10, 11, 12]:
		sf.add_frame("idle", _frame("res://assets/Character/Ren/idle/%d.png" % i))

	sf.add_animation("walk")
	sf.set_animation_speed("walk", 10.0)
	sf.set_animation_loop("walk", true)
	for i in range(1, 7):
		sf.add_frame("walk", _frame("res://assets/Character/Ren/walk/%d.png" % i))

	sf.add_animation("attack")
	sf.set_animation_speed("attack", 14.0)
	sf.set_animation_loop("attack", false)
	for i in range(1, 6):
		sf.add_frame("attack", _frame("res://assets/Character/Ren/Roll/%d.png" % i))

	sf.add_animation("hurt")
	sf.set_animation_speed("hurt", 10.0)
	sf.set_animation_loop("hurt", false)
	sf.add_frame("hurt", _frame("res://assets/Character/Ren/idle/9.png"))

	return sf


func _frame(path: String) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(path)
	at.region = Rect2(0, 0, 64, 64)
	return at


# --- Physics & State Machine ---

func _physics_process(delta: float) -> void:
	if GameState.is_dialogue_active or GameState.is_transitioning:
		velocity = velocity.lerp(Vector2.ZERO, DECEL_WEIGHT * delta)
		move_and_slide()
		_play("idle")
		return

	match state:
		State.IDLE:   _state_idle(delta)
		State.MOVE:   _state_move(delta)
		State.ATTACK: _state_attack(delta)
		State.HURT:   _state_hurt(delta)
		State.DASH:   _state_dash(delta)
		State.DEAD:   velocity = Vector2.ZERO

	_tick_invincibility(delta)
	_tick_attack_cooldown(delta)
	_tick_dash_cooldown(delta)
	_tick_camera_shake(delta)
	move_and_slide()


func _state_idle(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, DECEL_WEIGHT * delta)
	_play("idle")
	var dir := _input_dir()
	if dir != Vector2.ZERO:
		state = State.MOVE
		return
	if _dash_pressed():
		_begin_dash()
		return
	if _attack_pressed():
		_begin_attack()


func _state_move(delta: float) -> void:
	var dir := _input_dir()
	if dir == Vector2.ZERO:
		state = State.IDLE
		return
	facing = dir.normalized()
	_update_sprite_flip()
	velocity = velocity.lerp(facing * SPEED, ACCEL_WEIGHT * delta)
	_play("walk")
	if _dash_pressed():
		_begin_dash()
		return
	if _attack_pressed():
		_begin_attack()


func _state_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_dir * DASH_SPEED
	_play("walk")
	if dash_timer <= 0:
		state = State.IDLE
		velocity *= 0.4


func _state_attack(delta: float) -> void:
	attack_active_timer -= delta
	if attack_active_timer <= 0 and hitbox.monitoring:
		hitbox.monitoring = false
	velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
	if not sprite.is_playing() or sprite.animation != "attack":
		hitbox.monitoring = false
		state = State.IDLE


func _state_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
	if hurt_timer <= 0:
		state = State.IDLE


# --- Combat ---

func _begin_dash() -> void:
	if dash_cooldown_timer > 0:
		return
	var input := _input_dir()
	dash_dir = input.normalized() if input != Vector2.ZERO else facing
	facing = dash_dir
	_update_sprite_flip()
	state = State.DASH
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	# Immunity for the full dash duration plus a small recovery window
	invincible_timer = DASH_DURATION + 0.05
	velocity = dash_dir * DASH_SPEED
	# Visual feedback: brief tinted afterimage flash
	var tw := create_tween()
	sprite.modulate = sprite.modulate.lightened(0.4)
	tw.tween_property(sprite, "modulate", Color.WHITE, DASH_DURATION)


func _tick_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta


func _dash_pressed() -> bool:
	return Input.is_action_just_pressed(action_dash)


func _begin_attack() -> void:
	if attack_timer > 0:
		return
	state = State.ATTACK
	attack_timer = ATTACK_COOLDOWN
	attack_active_timer = ATTACK_DURATION
	_hit_targets.clear()
	hitbox_collision.position = facing * ATTACK_RANGE
	hitbox.monitoring = true
	velocity = facing * SPEED * 0.6
	_play("attack")
	_spawn_slash()


func _spawn_slash() -> void:
	var slash := Line2D.new()
	slash.width = 2.5
	slash.default_color = slash_color
	slash.z_index = 10
	var base_angle := facing.angle()
	for i in 9:
		var angle := base_angle - PI / 3.0 + (2.0 * PI / 3.0) * (float(i) / 8.0)
		slash.add_point(Vector2.from_angle(angle) * 30.0)
	add_child(slash)
	var tw := create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.2)
	tw.tween_callback(slash.queue_free)


func receive_hit(damage: int, knockback_dir: Vector2) -> void:
	if state == State.DEAD or state == State.DASH or invincible_timer > 0:
		return
	stats.take_damage(damage)
	if stats.is_dead:
		return
	state = State.HURT
	hurt_timer = HURT_DURATION
	invincible_timer = INVINCIBLE_TIME
	velocity = knockback_dir * KNOCKBACK_FORCE
	hitbox.monitoring = false
	_play("hurt")
	_flash_hurt()
	shake_amount = 4.0


func _on_hitbox_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target in _hit_targets:
		return
	_hit_targets.append(target)
	if target.has_method("receive_hit"):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		target.receive_hit(ATTACK_DAMAGE, dir)
		shake_amount = 2.5


func _on_died() -> void:
	state = State.DEAD
	hitbox.monitoring = false
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
	TimelineManager.player_died.emit(timeline)


# --- Visual effects ---

func _flash_hurt() -> void:
	sprite.modulate = Color.RED
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _tick_invincibility(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta
		sprite.visible = fmod(invincible_timer, 0.12) > 0.06
		if invincible_timer <= 0:
			sprite.visible = true


func _tick_attack_cooldown(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta


func _tick_camera_shake(delta: float) -> void:
	if shake_amount > 0:
		camera.offset = Vector2(
			randf_range(-1.0, 1.0) * shake_amount,
			randf_range(-1.0, 1.0) * shake_amount
		)
		shake_amount = max(0.0, shake_amount - 12.0 * delta)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 10.0 * delta)


# --- Input helpers ---

func _input_dir() -> Vector2:
	return Vector2(
		Input.get_action_strength(action_right) - Input.get_action_strength(action_left),
		Input.get_action_strength(action_down) - Input.get_action_strength(action_up)
	)


func _attack_pressed() -> bool:
	return Input.is_action_just_pressed(action_attack)


func _update_sprite_flip() -> void:
	if abs(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
