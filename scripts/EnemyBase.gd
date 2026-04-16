extends CharacterBody2D
class_name EnemyBase

const KNOCKBACK_FORCE := 180.0

@export var speed: float = 60.0
@export var chase_speed: float = 90.0
@export var detection_radius: float = 120.0
@export var attack_radius: float = 28.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.2
@export var hp: int = 3
@export var tint: Color = Color.WHITE
@export var is_boss: bool = false

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN
var target: Node2D = null
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var idle_timer: float = 0.0
var patrol_dir: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0
var is_dead: bool = false
var timeline: String = ""
var _has_hit: bool = false
var type = ""

# --- Node references (set up in the .tscn scene file) ---
@onready var sprite: AnimatedSprite2D     = $Sprite
@onready var hitbox: Area2D               = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hurtbox: Area2D              = $Hurtbox
@onready var detection: Area2D            = $Detection
@onready var stats: StatsComponent        = $StatsComponent

func _init_configs()->void:
	# Apply per-instance config to scene nodes
	stats.max_hp = hp
	stats.hp = hp
	$Detection/CollisionShape2D.shape.radius = detection_radius

	if is_boss:
		sprite.scale = Vector2(1.9, 1.9)
		attack_radius = 38.0
		add_to_group("bosses")
		TimelineManager.boss_spawned.emit(self)

	# Connect signals
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	detection.body_entered.connect(_on_player_detected)
	detection.body_exited.connect(_on_player_lost)
	stats.died.connect(_on_died)

	add_to_group("enemies")
	idle_timer = randf_range(0.5, 2.0)
	
func _ready() -> void:
	# Assign sprite frames and apply tint
	sprite.sprite_frames = _build_frames()
	sprite.modulate = tint
	sprite.play("idle")
	
	_init_configs()


# --- Sprite frame builder (same Ren PNGs, tinted per enemy) ---

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	sf.add_animation("idle")
	sf.set_animation_speed("idle", 6.0)
	sf.set_animation_loop("idle", true)
	for i in [9, 10, 11, 12]:
		sf.add_frame("idle", _frame("res://assets/Character/Ren/idle/%d.png" % i))

	sf.add_animation("walk")
	sf.set_animation_speed("walk", 8.0)
	sf.set_animation_loop("walk", true)
	for i in range(1, 7):
		sf.add_frame("walk", _frame("res://assets/Character/Ren/walk/%d.png" % i))

	sf.add_animation("attack")
	sf.set_animation_speed("attack", 12.0)
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


# --- Physics & AI State Machine ---

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if GameState.is_dialogue_active or GameState.is_transitioning:
		velocity = velocity.lerp(Vector2.ZERO, 12.0 * delta)
		_play("idle")
		move_and_slide()
		return

	attack_timer = max(0.0, attack_timer - delta)

	match state:
		State.IDLE:    _state_idle(delta)
		State.PATROL:  _state_patrol(delta)
		State.CHASE:   _state_chase(delta)
		State.ATTACK:  _state_attack(delta)
		State.HURT:    _state_hurt(delta)

	move_and_slide()


func _state_idle(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
	_play("idle")
	idle_timer -= delta
	if idle_timer <= 0:
		state = State.PATROL
		patrol_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		patrol_timer = randf_range(1.5, 3.0)
	if target and is_instance_valid(target):
		state = State.CHASE


func _state_patrol(delta: float) -> void:
	velocity = velocity.lerp(patrol_dir * speed, 6.0 * delta)
	_update_flip()
	_play("walk")
	patrol_timer -= delta
	if patrol_timer <= 0:
		state = State.IDLE
		idle_timer = randf_range(1.0, 2.5)
	if target and is_instance_valid(target):
		state = State.CHASE


func _state_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		state = State.IDLE
		idle_timer = 1.0
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	velocity = velocity.lerp(dir * chase_speed, 8.0 * delta)
	_update_flip()
	_play("walk")
	var dist := global_position.distance_to(target.global_position)
	if dist < attack_radius and attack_timer <= 0:
		_begin_attack()


func _state_attack(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
	if not sprite.is_playing() or sprite.animation != "attack":
		hitbox.monitoring = false
		state = State.CHASE if (target and is_instance_valid(target)) else State.IDLE
		if state == State.IDLE:
			idle_timer = 0.8


func _state_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
	if hurt_timer <= 0:
		state = State.CHASE if (target and is_instance_valid(target)) else State.IDLE
		if state == State.IDLE:
			idle_timer = 0.5


# --- Combat ---

func _begin_attack() -> void:
	state = State.ATTACK
	attack_timer = attack_cooldown
	_has_hit = false
	hitbox_collision.position = facing * 22.0
	hitbox.monitoring = true
	velocity = facing * speed * 0.4
	_play("attack")


func receive_hit(damage: int, knockback_dir: Vector2) -> void:
	if is_dead:
		return
	if is_boss and not TimelineManager.is_synced():
		_flash_blocked()
		return
	stats.take_damage(damage)
	if stats.is_dead:
		return
	state = State.HURT
	hurt_timer = 0.25
	velocity = knockback_dir * KNOCKBACK_FORCE
	hitbox.monitoring = false
	_play("hurt")
	_flash()


func _flash_blocked() -> void:
	var original := sprite.modulate
	sprite.modulate = Color(0.4, 0.8, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", original, 0.18)


func _flash() -> void:
	var original := sprite.modulate
	sprite.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", original, 0.12)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if _has_hit:
		return
	var hit_target := area.get_parent()
	if hit_target.has_method("receive_hit"):
		_has_hit = true
		var dir: Vector2 = (hit_target.global_position - global_position).normalized()
		hit_target.receive_hit(attack_damage, dir)
		hitbox.set_deferred("monitoring", false)


func _on_player_detected(body: Node2D) -> void:
	if body.is_in_group("players"):
		target = body


func _on_player_lost(body: Node2D) -> void:
	if body == target:
		target = null


func _on_died() -> void:
	is_dead = true
	state = State.DEAD
	hitbox.monitoring = false
	hurtbox.collision_layer = 0
	detection.monitoring = false
	collision_layer = 0
	velocity = Vector2.ZERO
	TimelineManager.enemy_killed.emit(timeline)
	if is_boss:
		TimelineManager.boss_defeated.emit(timeline)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.5)\
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


# --- Helpers ---

func _update_flip() -> void:
	if abs(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
