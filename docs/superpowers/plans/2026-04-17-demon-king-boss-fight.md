# Demon King Boss Fight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Solen boss fight in `scenes/Boss_Room.tscn` with both players sharing one world, plus a debug skip-to-boss button on all non-menu scenes.

**Architecture:** Boss_Room.tscn is a single-world (non-split-screen) Node2D scene. Both `PlayerPast` and `PlayerFuture` spawn as siblings; Solen uses a custom state machine that subclasses `EnemyBase` and overrides `_physics_process` + `receive_hit` wholesale (Approach A in the design). HP bar and game-over routing are signal-driven via `TimelineManager`.

**Tech Stack:** Godot 4.6, GDScript, Jolt physics, `gl_compatibility` renderer. No test framework — verification is manual playtest in the Godot editor.

**Spec:** `docs/superpowers/specs/2026-04-17-demon-king-boss-fight-design.md`

---

## Conventions used in this plan

- **Verification** means: open `project.godot` in Godot 4.6 and run the indicated scene, then observe the indicated behavior. Where it says *run Boss_Room*, right-click the scene in the FileSystem dock and choose "Run" (or press F6 with the scene active). To run the full game, press F5.
- **Commit granularity:** one commit per task. Commit messages use the existing style in `git log` (short imperative, no conventional-commit prefix required).
- **Editor re-imports:** after adding new scripts/scenes, the `.godot/` cache may need to re-import. If Godot shows a missing-class error, re-open the project or run `godot --path . --headless --quit` to force reimport.

---

## Task 1: Clean up unused stub files

**Files:**
- Delete: `character_body_2d.gd`, `character_body_2d.gd.uid`
- Delete: `enemy_base.gd`, `enemy_base.gd.uid`

These are Godot-generated "new script" templates from the repo root that extend `EnemyBase` but contain unrelated CharacterBody2D jump/gravity boilerplate. Not referenced by any scene. The real script is `scripts/EnemyBase.gd`.

- [ ] **Step 1: Confirm no references exist**

Run in Grep tool:
- Pattern: `character_body_2d` in all files
- Pattern: `res://enemy_base.gd` in all files

Expected: no matches (other than the files themselves).

- [ ] **Step 2: Delete the files**

```bash
rm character_body_2d.gd character_body_2d.gd.uid enemy_base.gd enemy_base.gd.uid
```

- [ ] **Step 3: Verify project still opens**

Open `project.godot` in Godot 4.6. Expected: no script load errors in the Output dock.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Remove unused root-level stub scripts"
```

---

## Task 2: Add boss_hp_changed signal to TimelineManager

**Files:**
- Modify: `scripts/TimelineManager.gd` (locate the `signal` block near the top)

- [ ] **Step 1: Locate the existing signals**

Open `scripts/TimelineManager.gd`. Find the block where `boss_spawned` and `boss_defeated` are declared.

- [ ] **Step 2: Add the new signal**

Add this line immediately after the existing `boss_spawned` / `boss_defeated` signal declarations:

```gdscript
signal boss_hp_changed(current: int, max_hp: int)
```

- [ ] **Step 3: Verify project parses**

In Godot, check the Output dock. Expected: no parse errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/TimelineManager.gd
git commit -m "Add boss_hp_changed signal to TimelineManager"
```

---

## Task 3: Create DebugSkipButton autoload

**Files:**
- Create: `scripts/DebugSkipButton.gd`
- Modify: `project.godot` (add entry under `[autoload]`)

- [ ] **Step 1: Create the script**

Create `scripts/DebugSkipButton.gd` with exactly this content:

```gdscript
extends Node

const BOSS_SCENE_PATH := "res://scenes/Boss_Room.tscn"
const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"

var _layer: CanvasLayer
var _button: Button

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_button = Button.new()
	_button.text = "Skip → Boss"
	_button.anchor_left = 1.0
	_button.anchor_right = 1.0
	_button.offset_left = -140
	_button.offset_top = 12
	_button.offset_right = -12
	_button.offset_bottom = 40
	_button.focus_mode = Control.FOCUS_NONE
	_layer.add_child(_button)
	_button.pressed.connect(_on_pressed)

	get_tree().tree_changed.connect(_refresh_visibility)
	_refresh_visibility()

func _refresh_visibility() -> void:
	var cur := get_tree().current_scene
	if cur == null:
		_button.visible = false
		return
	_button.visible = cur.scene_file_path != MAIN_MENU_PATH

func _on_pressed() -> void:
	GameState.is_dialogue_active = false
	GameState.is_transitioning = false
	get_tree().change_scene_to_file(BOSS_SCENE_PATH)
```

- [ ] **Step 2: Register the autoload in project.godot**

Open `project.godot` and locate the `[autoload]` section. Add this line at the end of the autoload entries (exact spelling; the `*` marks it as a singleton):

```
DebugSkipButton="*res://scripts/DebugSkipButton.gd"
```

- [ ] **Step 3: Verify button appears and hides correctly**

In Godot, press F5 to run the main scene. Expected:
- Main menu: **no** skip button.
- After advancing to prologue: button appears top-right with text "Skip → Boss".
- Clicking the button: scene changes; you now see the Boss_Room tilemap (players/boss not there yet — that's Task 11). Button is still visible on Boss_Room.

If the button appears on the main menu, re-check `MAIN_MENU_PATH` matches the actual file path.

- [ ] **Step 4: Commit**

```bash
git add scripts/DebugSkipButton.gd scripts/DebugSkipButton.gd.uid project.godot
git commit -m "Add DebugSkipButton autoload for jumping to Boss_Room"
```

Note: the `.uid` file is auto-generated by Godot the first time the script is imported. If it doesn't exist yet, omit it from the `git add`.

---

## Task 4: Create BossHUD scene and script

**Files:**
- Create: `scripts/BossHUD.gd`
- Create: `scenes/ui/BossHUD.tscn`

- [ ] **Step 1: Create the script**

Create `scripts/BossHUD.gd` with exactly this content:

```gdscript
extends CanvasLayer

@onready var _root: Control = $Root
@onready var _label: Label = $Root/VBox/Label
@onready var _bar: ProgressBar = $Root/VBox/ProgressBar

func _ready() -> void:
	_root.visible = false
	_root.modulate.a = 1.0
	_bar.max_value = 20
	_bar.value = 20

	TimelineManager.boss_spawned.connect(_on_boss_spawned)
	TimelineManager.boss_hp_changed.connect(_on_hp_changed)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)

func _on_boss_spawned(_boss: Node) -> void:
	_root.visible = true
	_root.modulate.a = 1.0
	_bar.max_value = 20
	_bar.value = 20
	_root.scale = Vector2(0.05, 1.0)
	_root.pivot_offset = _root.size * 0.5
	var tw := create_tween()
	tw.tween_property(_root, "scale", Vector2.ONE, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_hp_changed(current: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	var tw := create_tween()
	tw.tween_property(_bar, "value", current, 0.2)

func _on_boss_defeated(_timeline: String) -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _root.visible = false)
```

- [ ] **Step 2: Create the scene**

In the Godot editor: **Scene → New Scene → Other Node → CanvasLayer**. Build this tree:

```
BossHUD (CanvasLayer)  [attach script: res://scripts/BossHUD.gd]
└─ Root (Control)
   └─ VBox (VBoxContainer)
      ├─ Label (Label, text="Solen", horizontal_alignment = Center)
      └─ ProgressBar (ProgressBar, max_value = 20, value = 20, show_percentage = false)
```

For the `Root` Control node, set anchors so it sits top-center, ~70% viewport width:
- Anchor preset: **Top Wide**
- `offset_left = 204` (`(1376 - 0.7*1376) / 2` ≈ 206 for 70% width)
- `offset_right = -204`
- `offset_top = 12`
- `offset_bottom = 64`

For the `ProgressBar`, set:
- `custom_minimum_size.y = 16`
- (Optional visual polish — not required for functional correctness) set a red fill via Theme Overrides → Styles → Fill → StyleBoxFlat bg_color `Color(0.8, 0.1, 0.1, 1.0)`.

Save to `res://scenes/ui/BossHUD.tscn`.

- [ ] **Step 3: Smoke-test the HUD wiring**

Open Boss_Room.tscn, temporarily drag BossHUD.tscn into it as a child of the root, save, run Boss_Room (F6). Expected: bar is initially hidden (no boss spawned yet; `boss_spawned` hasn't fired). No errors in Output. Undo the temporary add (Ctrl+Z) before moving on, **or** leave it — Task 11 adds it as a permanent child.

- [ ] **Step 4: Commit**

```bash
git add scripts/BossHUD.gd scripts/BossHUD.gd.uid scenes/ui/BossHUD.tscn
git commit -m "Add BossHUD for Solen health bar with spawn animation"
```

---

## Task 5: Rewrite demon_king.gd — skeleton (states, idle, walk, target select)

**Files:**
- Modify: `scenes/characters/demon_king.gd` (full rewrite)

This task establishes the state machine and WALK/IDLE behavior. Light attack, roll, heavy, hurt, death, and victory are separate tasks.

- [ ] **Step 1: Replace the file contents**

Replace `scenes/characters/demon_king.gd` entirely with:

```gdscript
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
	super._ready()           # calls EnemyBase._ready which calls _init_configs
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

	# Attack selection (placeholder — tasks 6-8 will flesh out)
	# Intentionally left empty in this task.

func _tick_light(_delta: float) -> void:
	pass  # Task 6

func _tick_heavy(_delta: float) -> void:
	pass  # Task 8

func _tick_roll(_delta: float) -> void:
	pass  # Task 7

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
```

**Note on `is_dead_player`:** `PlayerBase` uses a `DEAD` state. If it does not already expose a public method like `is_dead_player()`, the `_pick_nearest_player` loop's dead-check falls through (the `has_method` guard) and simply includes all players — which is fine for now. Task 11 will verify behavior; if needed, add a one-line helper on `PlayerBase`.

- [ ] **Step 2: Verify boss walks toward player**

Temporarily add `DemonKing.tscn` as a child of `Main.tscn` (drop it into any room's world), run with F5, walk a player toward him. Expected: Solen turns to face the player and walks toward them playing the `walk` animation. He does not attack yet (those states are stubs).

Alternatively — and preferred — skip this verification until Task 11 when Boss_Room is fully wired; just ensure no parse errors in the Output dock after saving.

- [ ] **Step 3: Commit**

```bash
git add scenes/characters/demon_king.gd
git commit -m "Rewrite DemonKing with state-machine skeleton (IDLE/WALK/target-select)"
```

---

## Task 6: Implement Solen's light attack

**Files:**
- Modify: `scenes/characters/demon_king.gd`

- [ ] **Step 1: Add the attack-trigger branch in `_tick_walk`**

In `_tick_walk`, replace the trailing "Attack selection (placeholder...)" comment with:

```gdscript
	# Attack selection
	if _cooldown > 0.0:
		return
	var dist_sq: float = global_position.distance_squared_to(player.global_position)
	if dist_sq <= LIGHT_RANGE * LIGHT_RANGE:
		_begin_light()
	# Roll and heavy added in later tasks.
```

- [ ] **Step 2: Add `_begin_light` and flesh out `_tick_light`**

Replace the empty `_tick_light` stub and add `_begin_light` above it:

```gdscript
func _begin_light() -> void:
	_s = SolenState.LIGHT_ATTACK
	_cooldown = ATTACK_COOLDOWN
	_has_hit = false
	attack_damage = LIGHT_DAMAGE
	hitbox_collision.position = facing * 22.0
	hitbox.monitoring = true
	velocity = Vector2.ZERO
	_play_anim("light_attack")

func _tick_light(_delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 12.0 * _delta)
	if not sprite.is_playing() or sprite.animation != "light_attack":
		hitbox.monitoring = false
		_s = SolenState.WALK
```

**Why reuse EnemyBase's `hitbox` / `attack_damage` / `_has_hit`:** EnemyBase's `_on_hitbox_area_entered` already calls `receive_hit` on any body with that method and disables the hitbox after the first hit. We reuse it verbatim.

- [ ] **Step 3: Verify light attack deals 1 HP damage**

This cannot be fully verified until Task 11 when players are in Boss_Room. Skip verification and move on — just confirm no parse errors in the Output dock.

- [ ] **Step 4: Commit**

```bash
git add scenes/characters/demon_king.gd
git commit -m "Implement Solen light attack (1 dmg, melee range)"
```

---

## Task 7: Implement Solen's reactive roll

**Files:**
- Modify: `scenes/characters/demon_king.gd`

- [ ] **Step 1: Extend attack selection in `_tick_walk`**

Find the attack selection block in `_tick_walk` added in Task 6. Replace it with:

```gdscript
	# Attack selection
	if _cooldown > 0.0:
		return
	var dist_sq: float = global_position.distance_squared_to(player.global_position)
	if dist_sq <= LIGHT_RANGE * LIGHT_RANGE:
		_begin_light()
	elif dist_sq > (LIGHT_RANGE * 1.5) * (LIGHT_RANGE * 1.5):
		_begin_roll(player)
	# Heavy added in Task 8.
```

- [ ] **Step 2: Add `_begin_roll` and implement `_tick_roll`**

Replace the empty `_tick_roll` stub and add `_begin_roll` above it:

```gdscript
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
	# Preserve roll velocity; damp slightly
	velocity = velocity.lerp(velocity.normalized() * ROLL_SPEED, 2.0 * delta)
	if _state_timer <= 0.0:
		_invulnerable = false
		_s = SolenState.WALK
```

- [ ] **Step 3: Commit**

```bash
git add scenes/characters/demon_king.gd
git commit -m "Implement Solen reactive roll with i-frames"
```

---

## Task 8: Implement Solen's heavy attack (radial AoE with telegraph)

**Files:**
- Modify: `scenes/characters/demon_king.gd`

- [ ] **Step 1: Add phase-2 heavy attack to attack selection**

Replace the attack-selection block in `_tick_walk` with the final version:

```gdscript
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
```

- [ ] **Step 2: Add `_begin_heavy` and flesh out `_tick_heavy`**

Add below `_begin_roll`:

```gdscript
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
	# A simple filled ColorRect stretched to a square approximating the circle.
	# For a true ring, a Polygon2D or shader would be nicer; we keep it simple.
	var holder := Node2D.new()
	var size: float = HEAVY_RADIUS * 2.0
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.2, 0.2, 0.35)
	rect.size = Vector2(size, size)
	rect.position = Vector2(-size * 0.5, -size * 0.5)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# We want it in 2D world space; ColorRect is a Control so wrap it in a CanvasLayer-less
	# Node2D with a child Sprite using a white circle texture would be cleaner, but a
	# stretched ColorRect inside a Node2D renders fine at the node's world transform.
	holder.add_child(rect)
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
```

**Implementation note:** the `ColorRect`-inside-`Node2D` trick works but draws a square, not a circle. If visual polish matters, swap the ring visual for a `Sprite2D` with `res://assets/` circle texture, or a `Polygon2D` generating a 32-segment circle. Functionality (damage at radius) is handled by `_resolve_heavy_damage` which does a proper distance check.

- [ ] **Step 3: Commit**

```bash
git add scenes/characters/demon_king.gd
git commit -m "Implement Solen heavy attack (1s telegraph, 112px AoE, 3 dmg)"
```

---

## Task 9: Override receive_hit and implement HURT state

**Files:**
- Modify: `scenes/characters/demon_king.gd`

- [ ] **Step 1: Override `receive_hit`**

Add to the bottom of `demon_king.gd`:

```gdscript
func receive_hit(damage: int, knockback_dir: Vector2) -> void:
	if is_dead or _invulnerable:
		return
	stats.take_damage(damage)
	TimelineManager.boss_hp_changed.emit(stats.hp, stats.max_hp)
	if stats.is_dead:
		return
	# Uninterruptible heavy windup — block HURT transition
	if _s == SolenState.HEAVY_ATTACK:
		_flash()
		return
	_s = SolenState.HURT
	_state_timer = HURT_DURATION
	velocity = knockback_dir * KNOCKBACK_FORCE
	hitbox.monitoring = false
	_play_anim("hurt")
	_flash()
```

- [ ] **Step 2: Implement `_tick_hurt`**

Replace the empty `_tick_hurt` stub:

```gdscript
func _tick_hurt(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
	if _state_timer <= 0.0:
		_s = SolenState.WALK
```

- [ ] **Step 3: Commit**

```bash
git add scenes/characters/demon_king.gd
git commit -m "Override Solen receive_hit (drops sync check) and wire HP signal"
```

---

## Task 10: Implement DEAD and VICTORY states

**Files:**
- Modify: `scenes/characters/demon_king.gd`

- [ ] **Step 1: Override `_on_died` to play the death animation before cleanup**

Add to the bottom of `demon_king.gd`:

```gdscript
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
	# Let the death animation play one full loop before freeing
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
```

**Why override `_on_died`:** `EnemyBase._on_died` fades the sprite to 0 alpha and shrinks it — we want Solen's death animation to play fully instead. This override replaces that fade with a timer-gated `queue_free`.

- [ ] **Step 2: Commit**

```bash
git add scenes/characters/demon_king.gd
git commit -m "Add Solen DEAD (plays death anim) and VICTORY states"
```

---

## Task 11: Populate Boss_Room.tscn and add BossRoom.gd

**Files:**
- Create: `scripts/BossRoom.gd`
- Modify: `scenes/Boss_Room.tscn` (add child nodes and root script)

- [ ] **Step 1: Create BossRoom.gd**

Create `scripts/BossRoom.gd` with:

```gdscript
extends Node2D

const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"

@onready var past_player: Node2D = $PlayerPast
@onready var future_player: Node2D = $PlayerFuture
@onready var solen: Node = $DemonKing

var _past_dead := false
var _future_dead := false
var _victory_fired := false
var _defeat_fired := false

func _ready() -> void:
	TimelineManager.player_died.connect(_on_player_died)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)

func _on_player_died(timeline: String) -> void:
	if timeline == "past":
		_past_dead = true
	elif timeline == "future":
		_future_dead = true
	if _past_dead and _future_dead and not _victory_fired and not _defeat_fired:
		_victory_fired = true
		if solen and solen.has_method("play_victory"):
			solen.play_victory()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _on_boss_defeated(_timeline: String) -> void:
	if _defeat_fired:
		return
	_defeat_fired = true
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
```

- [ ] **Step 2: Open Boss_Room.tscn in the editor**

Open `res://scenes/Boss_Room.tscn`. Attach `res://scripts/BossRoom.gd` to the root `Node2D`.

- [ ] **Step 3: Add player and boss instances**

In the Scene dock, with the root selected:

1. Click **Instantiate Child Scene** (chain-link icon) → select `res://scenes/characters/PlayerPast.tscn`. Name it `PlayerPast`. Position it at a south-left spawn (roughly `Vector2(480, 600)` — adjust so it's inside the arena floor of the existing tilemap).
2. Same for `res://scenes/characters/PlayerFuture.tscn` → name `PlayerFuture`, position south-right (`Vector2(900, 600)` ballpark).
3. Instantiate `res://scenes/characters/DemonKing.tscn` → name `DemonKing`. Position at arena center (`Vector2(688, 384)` ballpark — adjust to actual arena center of the existing tilemap).
4. Instantiate `res://scenes/ui/BossHUD.tscn` → leave as `BossHUD`.

Save the scene.

- [ ] **Step 4: Verify all the wiring works end-to-end**

Run Boss_Room (F6). Expected:
- Both players spawn; WASD controls Past, arrow keys control Future.
- Solen spawns at center; HP bar animates in (short → wide) over ~1s, showing 20/20 labeled "Solen".
- Walk a player close to Solen → Solen walks toward the nearest player.
- Close to melee range → Solen plays `light_attack`, player takes 1 damage (HP icon in player HUD drops by 1).
- Move far away → Solen plays `roll` and dashes toward the nearest player; during the roll, hitting him does nothing (i-frames).
- Hit Solen 10 times to reach phase 2 → heavy attack starts appearing; a red square (the telegraph) expands from Solen over 1s; standing inside it when it reaches full size deals 3 damage; moving outside it avoids damage.
- Kill Solen (20 total hits) → death animation plays, HP bar fades, after ~2s scene changes to main menu.
- Alternate: let Solen kill both players → Solen plays `victory` animation, after ~2s scene changes to main menu.

Common issues:
- Solen doesn't see players → players may be in the wrong group. Confirm `PlayerBase._ready` adds `add_to_group("players")`. If not, the fix is a one-line addition there.
- Damage doesn't apply → confirm player scenes have a Hurtbox on collision_layer 16 (EnemyBase hitbox has `collision_mask = 16`).
- HP bar doesn't animate in → confirm `BossHUD` is instantiated *after* `DemonKing` in the scene tree, OR ensure the signal connection in `BossHUD._ready` happens before `EnemyBase._init_configs` emits `boss_spawned`. Since autoload signals survive node order, this is usually fine; if the bar stays hidden, add `call_deferred("emit", self)` in EnemyBase or verify signal connection timing.

- [ ] **Step 5: Commit**

```bash
git add scripts/BossRoom.gd scripts/BossRoom.gd.uid scenes/Boss_Room.tscn
git commit -m "Wire Boss_Room with players, Solen, HUD, and BossRoom controller"
```

---

## Task 12: Full playtest pass

No code changes — this is a verification task. If any issue surfaces, stop, fix inline in the appropriate file, commit separately with a descriptive message, then continue.

- [ ] **Step 1: Launch from main menu**

Press F5. Verify:
- Main menu shows, **no** skip button.
- Advance to prologue — skip button appears top-right.

- [ ] **Step 2: Skip to boss**

Click "Skip → Boss". Verify Boss_Room loads; both players are controllable.

- [ ] **Step 3: Phase 1 behaviors**

- Walk Past into melee range → light attack fires, 1 dmg.
- Walk Past far away → Solen rolls toward; during roll, hit him with an attack — the hit should not register (i-frame flash, no HP drop).
- Both players alive: Solen always targets the closer one. Move Past closer than Future → Solen chases Past. Switch distances → target switches.

- [ ] **Step 4: Phase 2 behaviors**

- Deal 10+ hits to reach HP ≤ 10. Heavy attack starts appearing in rotation; confirm telegraph is visible and dodgeable. As HP drops further, heavy attack frequency increases.

- [ ] **Step 5: Death & victory paths**

- Path A: kill Solen (20 total hits). Confirm death anim plays fully, HP bar fades, main menu after 2s.
- Restart → Path B: let Solen kill both players. Confirm victory anim plays, main menu after 2s.

- [ ] **Step 6: Commit any fixes**

If any tuning changes were needed (spawn positions, player group registration, signal timing), each should already have its own commit from the step where it was fixed. Nothing additional to commit here if playtest passed clean.

---

## Summary of file changes

| File | Action |
|---|---|
| `character_body_2d.gd` / `.uid` | Deleted |
| `enemy_base.gd` / `.uid` | Deleted |
| `scripts/TimelineManager.gd` | +1 signal |
| `scripts/DebugSkipButton.gd` | Created |
| `project.godot` | +1 autoload line |
| `scripts/BossHUD.gd` | Created |
| `scenes/ui/BossHUD.tscn` | Created |
| `scenes/characters/demon_king.gd` | Full rewrite |
| `scripts/BossRoom.gd` | Created |
| `scenes/Boss_Room.tscn` | +4 child instances, root script attached |

## Rollback

Every task is a single commit. To unwind any task:

```bash
git log --oneline    # find the commit to undo
git revert <sha>     # undoes the change as a new commit
```
