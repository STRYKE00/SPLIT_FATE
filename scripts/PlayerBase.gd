extends CharacterBody2D
class_name PlayerBase

const SPEED            := 130.0
const ACCEL_WEIGHT     := 12.0
const DECEL_WEIGHT     := 18.0
const HURT_DURATION    := 0.25
const INVINCIBLE_TIME  := 0.7
const KNOCKBACK_FORCE  := 120.0
const DASH_SPEED       := 200.0
const DASH_DURATION    := 0.22
const DASH_COOLDOWN    := 0.7

# Light combo: three chained swings, each faster / stronger than the last.
const LIGHT_RANGE         := 26.0
const LIGHT_DAMAGES       := [1, 1, 2]
const LIGHT_DURATIONS     := [0.26, 0.24, 0.32]  # total anim length per stage
const LIGHT_HIT_START     := 0.06                 # hitbox active after this much of anim
const LIGHT_COMBO_WINDOW  := 0.35                 # time after stage to press next

# Heavy attack: slow windup, big damage + knockback, cannot chain.
const HEAVY_RANGE         := 34.0
const HEAVY_DAMAGE        := 3
const HEAVY_DURATION      := 0.65
const HEAVY_HIT_START     := 0.28
const HEAVY_HIT_DURATION  := 0.18
const HEAVY_COOLDOWN      := 0.9
const HEAVY_KNOCKBACK     := 340.0

enum State { IDLE, MOVE, ATTACK, HURT, DASH, DEAD }

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN
var hurt_timer: float = 0.0
var invincible_timer: float = 0.0
var attack_timer: float = 0.0               # remaining anim time for current swing
var attack_hit_timer: float = 0.0           # remaining active-hitbox time
var attack_windup_timer: float = 0.0        # delay before hitbox activates
var attack_damage: int = 1
var attack_knockback: float = 220.0
var is_heavy: bool = false
var combo_stage: int = 0                    # 0 = not in combo; 1..3 = current light stage
var combo_queued: bool = false              # player tapped attack during active swing
var combo_window_timer: float = 0.0         # time left to continue light combo
var heavy_cooldown_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var shake_amount: float = 0.0
var timeline: String = ""
var slash_color: Color = Color.WHITE
var room_transitioning: bool = false

var action_left    := ""
var action_right   := ""
var action_up      := ""
var action_down    := ""
var action_attack  := ""
var action_heavy   := ""
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

func _connect_signals()-> void:
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	stats.died.connect(_on_died)

	add_to_group("players")

func _ready() -> void:
	# Assign sprite frames (built from individual PNGs)
	sprite.sprite_frames = _build_frames()
	sprite.play("idle")
	
	_connect_signals()	

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

	# Light combo (5 frames in "Light Combat/") split into three chained stages.
	sf.add_animation("light1")
	sf.set_animation_speed("light1", 16.0)
	sf.set_animation_loop("light1", false)
	for i in [1, 2]:
		sf.add_frame("light1", _frame("res://assets/Character/Ren/Light Combat/%d.png" % i))

	sf.add_animation("light2")
	sf.set_animation_speed("light2", 16.0)
	sf.set_animation_loop("light2", false)
	for i in [3, 4]:
		sf.add_frame("light2", _frame("res://assets/Character/Ren/Light Combat/%d.png" % i))

	sf.add_animation("light3")
	sf.set_animation_speed("light3", 12.0)
	sf.set_animation_loop("light3", false)
	sf.add_frame("light3", _frame("res://assets/Character/Ren/Light Combat/5.png"))

	sf.add_animation("heavy")
	sf.set_animation_speed("heavy", 11.0)
	sf.set_animation_loop("heavy", false)
	for i in range(1, 8):
		sf.add_frame("heavy", _frame("res://assets/Character/Ren/Heavy Attack/%d.png" % i))

	# "attack" kept as an alias for the roll/dash afterimage animation.
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
	if GameState.is_dialogue_active or GameState.is_transitioning or room_transitioning:
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
	_tick_dash_cooldown(delta)
	_tick_heavy_cooldown(delta)
	_tick_combo_window(delta)
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
	if _heavy_pressed():
		_begin_heavy()
		return
	if _attack_pressed():
		_begin_light(combo_stage + 1 if combo_window_timer > 0 else 1)


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
	if _heavy_pressed():
		_begin_heavy()
		return
	if _attack_pressed():
		_begin_light(combo_stage + 1 if combo_window_timer > 0 else 1)

func _play_dash_animation() -> void:
	_play("walk") 

func _get_dash_duration() -> float:
	return DASH_DURATION

func _state_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_dir * DASH_SPEED
	_play_dash_animation()
	if dash_timer <= 0:
		state = State.IDLE
		velocity *= 0.4


func _state_attack(delta: float) -> void:
	attack_timer -= delta

	# Activate the hitbox after the windup finishes.
	if attack_windup_timer > 0.0:
		attack_windup_timer -= delta
		if attack_windup_timer <= 0.0:
			hitbox.monitoring = true

	# Deactivate the hitbox when its active window ends.
	if attack_hit_timer > 0.0:
		attack_hit_timer -= delta
		if attack_hit_timer <= 0.0 and hitbox.monitoring:
			hitbox.set_deferred("monitoring", false)

	# Queue the next light combo step if the player taps during the current swing.
	if not is_heavy and combo_stage < 3 and _attack_pressed():
		combo_queued = true

	# Heavy cancels the combo queue — the player is committing.
	if _heavy_pressed() and heavy_cooldown_timer <= 0.0 and not is_heavy:
		combo_queued = false

	var decel := 12.0 if is_heavy else 8.0
	velocity = velocity.lerp(Vector2.ZERO, decel * delta)

	if attack_timer <= 0.0:
		hitbox.set_deferred("monitoring", false)
		if not is_heavy and combo_queued and combo_stage < 3:
			combo_queued = false
			_begin_light(combo_stage + 1)
			return
		if not is_heavy and combo_stage > 0:
			combo_window_timer = LIGHT_COMBO_WINDOW
		combo_queued = false
		is_heavy = false
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
	var duration := _get_dash_duration()
	dash_timer = duration
	dash_cooldown_timer = DASH_COOLDOWN
	# Immunity for the full dash duration plus a small recovery window
	invincible_timer = duration + 0.05
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


func _begin_light(stage: int) -> void:
	stage = clamp(stage, 1, 3)
	state = State.ATTACK
	is_heavy = false
	combo_stage = stage
	combo_queued = false
	combo_window_timer = 0.0
	_hit_targets.clear()

	var idx := stage - 1
	attack_timer = LIGHT_DURATIONS[idx]
	attack_windup_timer = LIGHT_HIT_START
	attack_hit_timer = LIGHT_DURATIONS[idx] - LIGHT_HIT_START
	attack_damage = LIGHT_DAMAGES[idx]
	attack_knockback = 180.0 + 50.0 * idx

	hitbox_collision.position = facing * LIGHT_RANGE
	hitbox.monitoring = false  # activated after windup
	velocity = facing * SPEED * (0.6 if stage == 1 else 0.5)
	_play("light%d" % stage)


func _begin_heavy() -> void:
	if heavy_cooldown_timer > 0.0:
		return
	state = State.ATTACK
	is_heavy = true
	combo_stage = 0
	combo_queued = false
	combo_window_timer = 0.0
	_hit_targets.clear()

	attack_timer = HEAVY_DURATION
	attack_windup_timer = HEAVY_HIT_START
	attack_hit_timer = HEAVY_HIT_DURATION
	attack_damage = HEAVY_DAMAGE
	attack_knockback = HEAVY_KNOCKBACK
	heavy_cooldown_timer = HEAVY_COOLDOWN

	hitbox_collision.position = facing * HEAVY_RANGE
	hitbox.monitoring = false
	velocity = facing * SPEED * 0.25
	_play("heavy")
	shake_amount = 1.5  # windup rumble


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
		target.receive_hit(attack_damage, dir * (attack_knockback / 220.0))
		shake_amount = 4.0 if is_heavy else 2.5


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


func _tick_heavy_cooldown(delta: float) -> void:
	if heavy_cooldown_timer > 0.0:
		heavy_cooldown_timer -= delta


func _tick_combo_window(delta: float) -> void:
	if combo_window_timer > 0.0:
		combo_window_timer -= delta
		if combo_window_timer <= 0.0:
			combo_stage = 0


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


func _heavy_pressed() -> bool:
	return action_heavy != "" and Input.is_action_just_pressed(action_heavy)


func _update_sprite_flip() -> void:
	if abs(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
