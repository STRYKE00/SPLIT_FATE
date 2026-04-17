# Area 1 — The Shattered Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all 20 rooms (10 past, 10 future) of Area 1 with gear puzzle, echo communicator, bridge materialise, and Warden boss systems.

**Architecture:** Replace the current 4+4 linear room arrays with 10+10 rooms using a connection-graph for non-linear navigation. New enemy variants extend EnemyBase behavior via the existing dictionary config + a `"script"` override field. Cross-timeline puzzles use GameState flags + TimelineManager signals. Room data stays inline in `Main.gd._define_rooms()` per project conventions.

**Tech Stack:** Godot 4.6, GDScript, Jolt physics, gl_compatibility renderer.

---

## File Structure

### New Files
- `scripts/world/area1/GearPuzzleManager.gd` — Tracks gear piece collection, updates console visual, fires bridge_built signal
- `scripts/world/area1/EchoCommunicatorTrigger.gd` — Monitors both players finding communicator fragments, fires Scene 04 cutscene
- `scripts/world/area1/WardenBoss.gd` — Shared HP pool boss controller, coordinates both Warden forms across timelines
- `scripts/world/area1/BridgeMaterialise.gd` — Bridge appearance animation + collision swap for Future Rooms 05 and 08
- `data/dialogue/area1_scene02_solen.json` — Solen intro dialogue
- `data/dialogue/area1_scene04_echo_exchange.json` — Ren/Mira echo communicator exchange
- `data/dialogue/area1_scene05_warden.json` — Solen pre-boss + Warden mid-fight + Mirror room Solen

### Modified Files
- `autoloads/GameState.gd` — Add Area 1 flags dictionary, reset method
- `autoloads/TimelineManager.gd` — Add `warden_hp_changed` signal, `warden_hp`/`warden_max_hp` vars
- `scripts/Main.gd` — Replace linear room arrays with connection graph, expand `_define_rooms()` to 10+10 rooms, update `_on_room_transition()` to use graph, add `_on_boss_defeated` area completion logic
- `scripts/Room.gd` — Add configurable room size, prop spawning, interactable objects, trigger zones, conditional door locking, gear piece pickup, chest mechanics
- `scripts/EnemyBase.gd` — Add `enemy_type` string field and type-specific behavior hooks (patrol patterns, teleport dash, ranged attacks)

---

## Task 1: GameState Flags & TimelineManager Extensions

**Files:**
- Modify: `autoloads/GameState.gd`
- Modify: `autoloads/TimelineManager.gd`

- [ ] **Step 1: Add Area 1 flags to GameState**

In `autoloads/GameState.gd`, add after line 7 (`var is_transitioning`):

```gdscript
var flags: Dictionary = {}

func set_flag(key: String, value: Variant) -> void:
    flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
    return flags.get(key, default)

func reset_area1() -> void:
    flags.erase("area1_started")
    flags.erase("gear_pieces_found")
    flags.erase("gear2_placed")
    flags.erase("area1_bridge_built")
    flags.erase("mira_has_communicator")
    flags.erase("ren_has_communicator")
    flags.erase("echo_communicator_active")
    flags.erase("warden_past_dead")
    flags.erase("warden_future_dead")
    flags.erase("area1_complete")
    flags.erase("warden_hp")
```

- [ ] **Step 2: Add Warden HP tracking to TimelineManager**

In `autoloads/TimelineManager.gd`, add after line 12 (`signal boss_defeated`):

```gdscript
signal warden_hp_changed(current_hp: int, max_hp: int)
signal warden_phase_changed(phase: int)
signal gear_collected(piece_id: String)
signal communicator_found(timeline: String)

const WARDEN_MAX_HP := 300

func init_warden_hp() -> void:
    GameState.set_flag("warden_hp", WARDEN_MAX_HP)
    warden_hp_changed.emit(WARDEN_MAX_HP, WARDEN_MAX_HP)

func damage_warden(amount: int, source_timeline: String) -> int:
    var hp: int = GameState.get_flag("warden_hp", WARDEN_MAX_HP)
    hp = max(0, hp - amount)
    GameState.set_flag("warden_hp", hp)
    warden_hp_changed.emit(hp, WARDEN_MAX_HP)
    if hp <= WARDEN_MAX_HP / 2 and hp + amount > WARDEN_MAX_HP / 2:
        warden_phase_changed.emit(2)
    return hp
```

- [ ] **Step 3: Commit**

```bash
git add autoloads/GameState.gd autoloads/TimelineManager.gd
git commit -m "feat: add Area 1 flags and Warden HP tracking to autoloads"
```

---

## Task 2: Room Connection Graph in Main.gd

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Replace linear room arrays with connection graph**

Replace the `_past_rooms`/`_future_rooms` array vars and `BOSS_ROOM_INDEX` const (lines 23-27) with:

```gdscript
var _past_rooms: Dictionary = {}
var _future_rooms: Dictionary = {}
var _past_connections: Dictionary = {}
var _future_connections: Dictionary = {}
const BOSS_ROOM_INDEX := 9
```

- [ ] **Step 2: Update _on_room_transition to use connection graph**

Replace the current `_on_room_transition` method (lines 285-344) with:

```gdscript
func _on_room_transition(timeline: String, direction: String) -> void:
    if GameState.is_transitioning:
        return
    GameState.is_transitioning = true

    var current_idx: int
    var connections: Dictionary
    var overlay: ColorRect
    var player: PlayerBase

    if timeline == "past":
        current_idx = GameState.current_room_past
        connections = _past_connections
        overlay = past_overlay
        player = past_player
    else:
        current_idx = GameState.current_room_future
        connections = _future_connections
        overlay = future_overlay
        player = future_player

    var room_conns: Dictionary = connections.get(current_idx, {})
    if not room_conns.has(direction):
        GameState.is_transitioning = false
        return

    var next_idx: int = room_conns[direction]

    var tw_out := create_tween()
    tw_out.tween_property(overlay, "color:a", 1.0, FADE_TIME)\
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
    await tw_out.finished

    _load_room(timeline, next_idx)

    var entry_dir := "south" if direction == "north" else "north"
    if direction == "east":
        entry_dir = "west"
    elif direction == "west":
        entry_dir = "east"

    var room: Room = current_past_room if timeline == "past" else current_future_room
    player.position = room.get_spawn_point(entry_dir)
    player.velocity = Vector2.ZERO

    var tw_in := create_tween()
    tw_in.tween_property(overlay, "color:a", 0.0, FADE_TIME)\
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
    await tw_in.finished

    GameState.is_transitioning = false

    if next_idx == BOSS_ROOM_INDEX and not _boss_intro_played:
        _boss_intro_played = true
        await get_tree().create_timer(0.4).timeout
        DialogueManager.start_dialogue("res://data/dialogue/area1_scene05_warden.json")
```

- [ ] **Step 3: Update _load_room to use Dictionary rooms**

Replace `_load_room` (lines 151-188). The key change: `room_data` is now a Dictionary keyed by room index, and room size comes from the config:

```gdscript
func _load_room(timeline: String, room_idx: int) -> void:
    var room_data: Dictionary = _past_rooms if timeline == "past" else _future_rooms
    if not room_data.has(room_idx):
        return

    var world: Node2D = past_world if timeline == "past" else future_world

    var old_room: Room
    if timeline == "past":
        old_room = current_past_room
    else:
        old_room = current_future_room

    if old_room:
        old_room.queue_free()

    var cfg: Dictionary = room_data[room_idx]
    var room := Room.new()
    room.room_w = cfg.get("room_w", 11)
    room.room_h = cfg.get("room_h", 12)
    room.timeline = timeline
    room.room_id = room_idx
    room.door_positions = cfg.get("doors", [])
    room.enemy_configs = cfg.get("enemies", [])
    room.npc_configs = cfg.get("npcs", [])
    room.prop_configs = cfg.get("props", [])
    room.trigger_configs = cfg.get("triggers", [])
    room.floor_color = cfg.get("floor_color", Color(0.5, 0.5, 0.5))
    room.wall_color = cfg.get("wall_color", Color(0.3, 0.3, 0.3))
    room.name = "Room_%s_%d" % [timeline, room_idx]

    world.add_child(room)
    room.build()

    if timeline == "past":
        current_past_room = room
        GameState.current_room_past = room_idx
    else:
        current_future_room = room
        GameState.current_room_future = room_idx
```

- [ ] **Step 4: Update _on_boss_defeated for Area 1 completion logic**

Replace `_on_boss_defeated` (line 235-238):

```gdscript
func _on_boss_defeated(tl: String) -> void:
    if tl == "past":
        GameState.set_flag("warden_past_dead", true)
    elif tl == "future":
        GameState.set_flag("warden_future_dead", true)
    if GameState.get_flag("warden_past_dead") and GameState.get_flag("warden_future_dead"):
        GameState.set_flag("area1_complete", true)
        await get_tree().create_timer(2.0).timeout
        get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

- [ ] **Step 5: Commit**

```bash
git add scripts/Main.gd
git commit -m "feat: replace linear room navigation with connection graph"
```

---

## Task 3: Room.gd Extensions — Props, Triggers, Interactables

**Files:**
- Modify: `scripts/Room.gd`

- [ ] **Step 1: Add new config vars and prop/trigger spawning**

Add after line 18 (`var npc_configs: Array = []`):

```gdscript
var prop_configs: Array = []
var trigger_configs: Array = []
```

- [ ] **Step 2: Add prop spawning to build()**

In `build()`, add after `_spawn_enemies()` (line 42):

```gdscript
_spawn_props()
_spawn_triggers()
```

- [ ] **Step 3: Implement _spawn_props**

Add method after `_spawn_npcs()`:

```gdscript
func _spawn_props() -> void:
    for cfg in prop_configs:
        var prop := StaticBody2D.new()
        prop.position = Vector2(cfg["x"], cfg["y"])
        prop.collision_layer = 1
        prop.collision_mask = 0
        prop.name = cfg.get("name", "Prop")

        var w: float = cfg.get("w", 32)
        var h: float = cfg.get("h", 32)

        var col := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Vector2(w, h)
        col.shape = rect
        prop.add_child(col)

        if not cfg.get("no_collision", false):
            prop.collision_layer = 1
        else:
            prop.collision_layer = 0
            col.disabled = true

        var vis := ColorRect.new()
        vis.size = Vector2(w, h)
        vis.position = Vector2(-w / 2, -h / 2)
        vis.color = cfg.get("color", Color(0.5, 0.4, 0.3))
        prop.add_child(vis)

        if cfg.get("label", "") != "":
            var label := Label.new()
            label.text = cfg["label"]
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            label.position = Vector2(-w / 2, -h / 2 - 16)
            label.add_theme_font_size_override("font_size", 8)
            prop.add_child(label)

        _entity_layer.add_child(prop)
```

- [ ] **Step 4: Implement _spawn_triggers**

Add method for trigger zones that respond to player overlap:

```gdscript
func _spawn_triggers() -> void:
    for cfg in trigger_configs:
        var trigger := Area2D.new()
        trigger.position = Vector2(cfg["x"], cfg["y"])
        trigger.collision_layer = 0
        trigger.collision_mask = 2
        trigger.name = cfg.get("id", "Trigger")

        var shape := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = cfg.get("radius", 40.0)
        shape.shape = circle
        trigger.add_child(shape)

        var trigger_type: String = cfg.get("type", "")
        var fires_once: bool = cfg.get("fires_once", true)
        var cfg_ref := cfg

        trigger.body_entered.connect(func(body: Node2D):
            if not body.is_in_group("players"):
                return
            if fires_once:
                trigger.set_deferred("monitoring", false)
            _handle_trigger(cfg_ref)
        )
        add_child(trigger)


func _handle_trigger(cfg: Dictionary) -> void:
    var trigger_type: String = cfg.get("type", "")
    match trigger_type:
        "cutscene":
            var dialogue_id: String = cfg.get("dialogue_path", "")
            if dialogue_id != "" and not DialogueManager.is_active():
                DialogueManager.start_dialogue(dialogue_id)
        "gear_pickup":
            var piece_id: String = cfg.get("piece_id", "")
            var count: int = GameState.get_flag("gear_pieces_found", 0)
            GameState.set_flag("gear_pieces_found", count + 1)
            TimelineManager.gear_collected.emit(piece_id)
        "communicator":
            var tl: String = cfg.get("timeline", "")
            if tl == "past":
                GameState.set_flag("mira_has_communicator", true)
            else:
                GameState.set_flag("ren_has_communicator", true)
            TimelineManager.communicator_found.emit(tl)
        "timeline_action":
            var action_id: String = cfg.get("action_id", "")
            TimelineManager.timeline_action.emit(action_id, timeline)
```

- [ ] **Step 5: Add chest spawning support**

Add after `_spawn_props`:

```gdscript
func spawn_chest(pos: Vector2, item_trigger: Dictionary) -> Node2D:
    var chest := StaticBody2D.new()
    chest.position = pos
    chest.collision_layer = 1
    chest.collision_mask = 0
    chest.name = "Chest"

    var col := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(28, 24)
    col.shape = rect
    chest.add_child(col)

    var vis := ColorRect.new()
    vis.size = Vector2(28, 24)
    vis.position = Vector2(-14, -12)
    vis.color = Color(0.7, 0.55, 0.2)
    chest.add_child(vis)

    var label := Label.new()
    label.text = "?"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.position = Vector2(-14, -28)
    label.add_theme_font_size_override("font_size", 10)
    chest.add_child(label)

    var interact := Area2D.new()
    interact.position = pos
    interact.collision_layer = 0
    interact.collision_mask = 2
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 30.0
    shape.shape = circle
    interact.add_child(shape)
    interact.monitoring = false

    interact.body_entered.connect(func(body: Node2D):
        if body.is_in_group("players") and Input.is_action_just_pressed(body.action_interact):
            interact.set_deferred("monitoring", false)
            vis.color = Color(0.4, 0.35, 0.15)
            label.text = "!"
            _handle_trigger(item_trigger)
    )
    add_child(interact)

    _entity_layer.add_child(chest)
    return chest
```

- [ ] **Step 6: Add method to unlock chests when room is cleared**

Modify `_on_enemy_killed` to also enable chest interact areas:

```gdscript
func _on_enemy_killed(tl: String) -> void:
    if tl != timeline:
        return
    _live_enemies -= 1
    if _live_enemies <= 0:
        is_cleared = true
        _set_doors_open(true)
        _unlock_chests()
        TimelineManager.room_cleared.emit(timeline)


func _unlock_chests() -> void:
    for child in get_children():
        if child is Area2D and child.name.begins_with("ChestInteract"):
            child.monitoring = true
```

- [ ] **Step 7: Commit**

```bash
git add scripts/Room.gd
git commit -m "feat: add prop, trigger, and chest spawning to Room.gd"
```

---

## Task 4: Dialogue JSON Files

**Files:**
- Create: `data/dialogue/area1_scene02_solen.json`
- Create: `data/dialogue/area1_scene04_echo_exchange.json`
- Create: `data/dialogue/area1_scene05_warden.json`

- [ ] **Step 1: Create Solen intro dialogue**

```json
[
    {"speaker": "Solen", "text": "Don't be afraid. You were brought here because you are needed. Both of you."},
    {"speaker": "Solen", "text": "He lives. He is where he must be — as you are where you must be."},
    {"speaker": "Solen", "text": "Time separated you. Time will reunite you. But first... the King must fall."},
    {"speaker": "Solen", "text": "A guide. That is all you need to know for now."}
]
```

- [ ] **Step 2: Create echo exchange dialogue**

```json
[
    {"speaker": "Ren", "text": "Mira. Mira, is that actually you? Your voice is—"},
    {"speaker": "Mira", "text": "It's me. It's me, I'm okay. Are you okay? You sound like you swallowed gravel."},
    {"speaker": "Ren", "text": "I'm in some kind of destroyed future. Everything's ash and ruins. You?"},
    {"speaker": "Mira", "text": "The opposite. It's beautiful here, actually. Like a painting. But Ren — I keep seeing echoes of destruction. Like a warning of what's coming."},
    {"speaker": "Ren", "text": "It came. Whatever it is — it already happened here. The world's gone, Mira. I don't want that to be your world."},
    {"speaker": "Mira", "text": "Then we stop it. Together. Even if we can't be in the same place right now, we're still — we're still together, right?"},
    {"speaker": "Ren", "text": "Yeah. Yeah, we are. ...Hey. About what I said on the rooftop—"},
    {"speaker": "Mira", "text": "Don't you dare make this moment awkward, Ren."},
    {"speaker": "Ren", "text": "Right. Later. When I see you in person."},
    {"speaker": "Mira", "text": "Promise."}
]
```

- [ ] **Step 3: Create Warden/Solen dialogue (multi-context)**

```json
[
    {"speaker": "Solen", "text": "The Warden has stood guard here since before any kingdom remembered why. Don't mistake its purpose for malice."}
]
```

Note: The Warden mid-fight dialogue and mirror room Solen dialogue will be stored in separate files since they fire from different triggers:

Create `data/dialogue/area1_warden_midfight.json`:
```json
[
    {"speaker": "Warden", "text": "...You carry his face. Why do you carry his face."}
]
```

Create `data/dialogue/area1_mirror_solen.json`:
```json
[
    {"speaker": "Solen", "text": "A conqueror. One who let despair corrupt him beyond recovery. Nothing more."},
    {"speaker": "Solen", "text": "I leave out only what would break your focus when focus is all that can save you. Come. She's waiting."}
]
```

- [ ] **Step 4: Commit**

```bash
git add data/dialogue/area1_scene02_solen.json data/dialogue/area1_scene04_echo_exchange.json data/dialogue/area1_scene05_warden.json data/dialogue/area1_warden_midfight.json data/dialogue/area1_mirror_solen.json
git commit -m "feat: add Area 1 dialogue JSON files"
```

---

## Task 5: Enemy Type Variants

**Files:**
- Modify: `scripts/EnemyBase.gd`

The PRD defines 4 new enemy types. Rather than separate scripts, extend EnemyBase with an `enemy_type` field that modifies behavior. This keeps the existing spawning pipeline intact.

- [ ] **Step 1: Add enemy_type field and type-specific behavior**

Add after line 14 (`@export var is_boss: bool = false`):

```gdscript
@export var enemy_type: String = "default"
var teleport_cooldown: float = 0.0
var ranged_cooldown: float = 0.0
var patrol_axis: String = ""
```

- [ ] **Step 2: Add type-specific chase behavior**

Modify `_state_chase` to support teleport dash (HollowWraith) and ranged attack (ArcherScout/PhantomSniper):

```gdscript
func _state_chase(delta: float) -> void:
    if not target or not is_instance_valid(target):
        state = State.IDLE
        idle_timer = 1.0
        return
    var dir: Vector2 = (target.global_position - global_position).normalized()
    facing = dir
    var dist := global_position.distance_to(target.global_position)

    match enemy_type:
        "hollow_wraith":
            teleport_cooldown -= delta
            if teleport_cooldown <= 0 and dist > 60.0:
                _teleport_toward_target()
                teleport_cooldown = randf_range(2.0, 3.5)
            else:
                velocity = velocity.lerp(dir * chase_speed, 8.0 * delta)
        "archer_scout", "phantom_sniper":
            if dist < 80.0:
                velocity = velocity.lerp(-dir * speed, 6.0 * delta)
            elif dist > 140.0:
                velocity = velocity.lerp(dir * speed * 0.5, 6.0 * delta)
            else:
                velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
            ranged_cooldown -= delta
            if ranged_cooldown <= 0 and dist < detection_radius:
                _ranged_attack()
                ranged_cooldown = attack_cooldown
                return
        _:
            velocity = velocity.lerp(dir * chase_speed, 8.0 * delta)

    _update_flip()
    _play("walk")
    if dist < attack_radius and attack_timer <= 0 and enemy_type not in ["archer_scout", "phantom_sniper"]:
        _begin_attack()
```

- [ ] **Step 3: Add teleport method for HollowWraith**

```gdscript
func _teleport_toward_target() -> void:
    if not target or not is_instance_valid(target):
        return
    var dir: Vector2 = (target.global_position - global_position).normalized()
    var tp_dist := randf_range(40.0, 80.0)
    var old_pos := global_position
    global_position = target.global_position - dir * tp_dist
    _flash()
```

- [ ] **Step 4: Add ranged attack for Archer/Sniper types**

```gdscript
func _ranged_attack() -> void:
    if not target or not is_instance_valid(target):
        return
    state = State.ATTACK
    attack_timer = attack_cooldown
    _play("attack")
    var dir: Vector2 = (target.global_position - global_position).normalized()

    var projectile := Area2D.new()
    projectile.collision_layer = 0
    projectile.collision_mask = 16
    projectile.position = global_position + dir * 16.0

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 4.0
    shape.shape = circle
    projectile.add_child(shape)

    var vis := ColorRect.new()
    vis.size = Vector2(8, 8)
    vis.position = Vector2(-4, -4)
    vis.color = Color(1.0, 0.3, 0.1) if enemy_type == "archer_scout" else Color(0.6, 0.2, 0.9)
    projectile.add_child(vis)

    var proj_speed := 200.0
    var proj_dir := dir
    var damage := attack_damage

    get_tree().current_scene.add_child(projectile)

    projectile.area_entered.connect(func(area: Area2D):
        var hit_target := area.get_parent()
        if hit_target.has_method("receive_hit"):
            hit_target.receive_hit(damage, proj_dir)
        projectile.queue_free()
    )

    var tw := projectile.create_tween()
    tw.tween_property(projectile, "position", projectile.position + proj_dir * 300.0, 300.0 / proj_speed)
    tw.tween_callback(projectile.queue_free)
```

- [ ] **Step 5: Add patrol_NS pattern for ArcherScout**

Modify `_state_patrol` to support axis-locked patrol:

```gdscript
func _state_patrol(delta: float) -> void:
    if patrol_axis == "NS" and abs(patrol_dir.x) > 0.1:
        patrol_dir = Vector2(0, 1 if patrol_dir.y >= 0 else -1)
    velocity = velocity.lerp(patrol_dir * speed, 6.0 * delta)
    _update_flip()
    _play("walk")
    patrol_timer -= delta
    if patrol_timer <= 0:
        if patrol_axis == "NS":
            patrol_dir = Vector2(0, -patrol_dir.y)
            patrol_timer = randf_range(1.5, 3.0)
        else:
            state = State.IDLE
            idle_timer = randf_range(1.0, 2.5)
    if target and is_instance_valid(target):
        state = State.CHASE
```

- [ ] **Step 6: Update Room._spawn_enemies to pass new fields**

In `scripts/Room.gd`, update `_spawn_enemies` to set the new fields:

```gdscript
func _spawn_enemies() -> void:
    for cfg in enemy_configs:
        var enemy: EnemyBase = preload("res://scenes/characters/EnemyBase.tscn").instantiate()
        enemy.position = Vector2(cfg["x"], cfg["y"])
        enemy.timeline = timeline
        enemy.tint = cfg.get("tint", Color(0.9, 0.3, 0.2))
        enemy.hp = cfg.get("hp", 3)
        enemy.speed = cfg.get("speed", 55.0)
        enemy.chase_speed = cfg.get("chase_speed", 85.0)
        enemy.is_boss = cfg.get("is_boss", false)
        enemy.enemy_type = cfg.get("enemy_type", "default")
        enemy.patrol_axis = cfg.get("patrol_axis", "")
        enemy.attack_damage = cfg.get("attack_damage", 1)
        enemy.attack_cooldown = cfg.get("attack_cooldown", 1.2)
        enemy.detection_radius = cfg.get("detection_radius", 120.0)
        _entity_layer.add_child(enemy)
        _live_enemies += 1

    if _live_enemies > 0:
        TimelineManager.enemy_killed.connect(_on_enemy_killed)
```

- [ ] **Step 7: Commit**

```bash
git add scripts/EnemyBase.gd scripts/Room.gd
git commit -m "feat: add enemy type variants (archer, wraith, sniper, soldier)"
```

---

## Task 6: GearPuzzleManager

**Files:**
- Create: `scripts/world/area1/GearPuzzleManager.gd`

- [ ] **Step 1: Create GearPuzzleManager script**

```gdscript
extends Node
class_name GearPuzzleManager

var _gear_console_room: Room = null

func _ready() -> void:
    TimelineManager.gear_collected.connect(_on_gear_collected)


func _on_gear_collected(piece_id: String) -> void:
    var count: int = GameState.get_flag("gear_pieces_found", 0)
    if piece_id == "GEAR_PIECE_2":
        GameState.set_flag("gear2_placed", true)
        TimelineManager.timeline_action.emit("gear2_placed", "past")


func try_complete_puzzle() -> bool:
    var count: int = GameState.get_flag("gear_pieces_found", 0)
    if count >= 3 and not GameState.get_flag("area1_bridge_built", false):
        GameState.set_flag("area1_bridge_built", true)
        TimelineManager.timeline_action.emit("bridge_built", "past")
        return true
    return false
```

- [ ] **Step 2: Commit**

```bash
mkdir -p scripts/world/area1
git add scripts/world/area1/GearPuzzleManager.gd
git commit -m "feat: add GearPuzzleManager for gear piece tracking"
```

---

## Task 7: BridgeMaterialise

**Files:**
- Create: `scripts/world/area1/BridgeMaterialise.gd`

- [ ] **Step 1: Create BridgeMaterialise script**

```gdscript
extends Node2D
class_name BridgeMaterialise

signal materialise_complete

var _chasm_collision: CollisionShape2D
var _bridge_collision: CollisionShape2D
var _sections: Array[ColorRect] = []
var _is_materialised: bool = false


func setup(chasm_col: CollisionShape2D, bridge_col: CollisionShape2D, bridge_rect: Rect2) -> void:
    _chasm_collision = chasm_col
    _bridge_collision = bridge_col
    _bridge_collision.set_deferred("disabled", true)

    var section_w := bridge_rect.size.x
    var section_h := bridge_rect.size.y / 3.0
    for i in 3:
        var sect := ColorRect.new()
        sect.size = Vector2(section_w, section_h)
        sect.position = Vector2(bridge_rect.position.x, bridge_rect.position.y + i * section_h)
        sect.color = Color(0.55, 0.5, 0.45)
        sect.visible = false
        add_child(sect)
        _sections.append(sect)


func materialise() -> void:
    if _is_materialised:
        return
    _is_materialised = true

    for i in 3:
        _sections[i].visible = true
        _sections[i].modulate.a = 0.0
        var target_y := _sections[i].position.y
        _sections[i].position.y = target_y + 30.0

        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(_sections[i], "modulate:a", 1.0, 0.4)
        tw.tween_property(_sections[i], "position:y", target_y, 0.4)\
            .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

        if i < 2:
            await get_tree().create_timer(0.2).timeout

    await get_tree().create_timer(0.3).timeout
    _chasm_collision.set_deferred("disabled", true)
    _bridge_collision.set_deferred("disabled", false)
    materialise_complete.emit()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/world/area1/BridgeMaterialise.gd
git commit -m "feat: add BridgeMaterialise for cross-timeline bridge animation"
```

---

## Task 8: EchoCommunicatorTrigger

**Files:**
- Create: `scripts/world/area1/EchoCommunicatorTrigger.gd`

- [ ] **Step 1: Create EchoCommunicatorTrigger script**

```gdscript
extends Node
class_name EchoCommunicatorTrigger

var _cutscene_fired: bool = false


func _ready() -> void:
    TimelineManager.communicator_found.connect(_on_communicator_found)


func _on_communicator_found(_timeline: String) -> void:
    if _cutscene_fired:
        return
    var mira := GameState.get_flag("mira_has_communicator", false)
    var ren := GameState.get_flag("ren_has_communicator", false)
    if mira and ren:
        _cutscene_fired = true
        _fire_scene04()


func _fire_scene04() -> void:
    GameState.set_flag("echo_communicator_active", true)
    DialogueManager.start_dialogue("res://data/dialogue/area1_scene04_echo_exchange.json")
```

- [ ] **Step 2: Commit**

```bash
git add scripts/world/area1/EchoCommunicatorTrigger.gd
git commit -m "feat: add EchoCommunicatorTrigger for Scene 04 cutscene"
```

---

## Task 9: WardenBoss

**Files:**
- Create: `scripts/world/area1/WardenBoss.gd`

- [ ] **Step 1: Create WardenBoss controller script**

This script attaches to a Warden enemy node and overrides its `receive_hit` to use the shared HP pool. It coordinates with the other timeline's Warden via TimelineManager signals.

```gdscript
extends Node
class_name WardenBoss

var _enemy: EnemyBase
var _timeline: String
var _recognition_fired: bool = false
var _is_dying: bool = false


func setup(enemy: EnemyBase, tl: String) -> void:
    _enemy = enemy
    _timeline = tl
    TimelineManager.warden_phase_changed.connect(_on_phase_changed)
    TimelineManager.warden_hp_changed.connect(_on_hp_changed)


func apply_damage(amount: int) -> void:
    if _is_dying:
        return
    if _timeline == "future":
        amount = int(amount * 1.25)
    var remaining := TimelineManager.damage_warden(amount, _timeline)
    if remaining <= 0:
        _begin_death()


func _on_phase_changed(phase: int) -> void:
    if phase == 2 and not _recognition_fired:
        _recognition_fired = true
        _enemy.velocity = Vector2.ZERO
        _enemy._play("hurt")
        if _timeline == "future":
            DialogueManager.start_dialogue("res://data/dialogue/area1_warden_midfight.json")


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
    pass


func _begin_death() -> void:
    _is_dying = true
    _enemy.is_dead = true
    _enemy.state = EnemyBase.State.DEAD
    _enemy.hitbox.monitoring = false
    _enemy.hurtbox.collision_layer = 0
    _enemy.detection.monitoring = false
    _enemy.collision_layer = 0
    _enemy.velocity = Vector2.ZERO

    TimelineManager.boss_defeated.emit(_timeline)

    var tw := _enemy.create_tween()
    tw.tween_property(_enemy.sprite, "modulate:a", 0.0, 1.0)
    tw.parallel().tween_property(_enemy.sprite, "scale", Vector2(0.3, 0.3), 1.0)\
        .set_ease(Tween.EASE_IN)
    tw.tween_callback(_enemy.queue_free)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/world/area1/WardenBoss.gd
git commit -m "feat: add WardenBoss controller with shared HP pool"
```

---

## Task 10: Integrate Systems into Main.gd & Define All 20 Rooms

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Add system instances to Main.gd**

Add after the existing vars (after line 26):

```gdscript
var _gear_manager: GearPuzzleManager
var _echo_trigger: EchoCommunicatorTrigger
```

In `_ready()`, after `_connect_signals()` (line 44), add:

```gdscript
_gear_manager = GearPuzzleManager.new()
add_child(_gear_manager)
_echo_trigger = EchoCommunicatorTrigger.new()
add_child(_echo_trigger)
TimelineManager.init_warden_hp()
GameState.set_flag("area1_started", true)
```

- [ ] **Step 2: Define past room connections**

Add after `_define_rooms()` call, or at end of `_define_rooms()`:

```gdscript
_past_connections = {
    0: {"north": 1},
    1: {"south": 0, "north": 2},
    2: {"south": 1, "west": 3, "east": 6},
    3: {"east": 2, "north": 4},
    4: {"south": 3, "north": 5},
    5: {"south": 4},
    6: {"west": 2, "north": 7},
    7: {"south": 6, "north": 8},
    8: {"south": 7, "north": 9},
    9: {"south": 8},
}

_future_connections = {
    0: {"north": 1},
    1: {"south": 0, "north": 2},
    2: {"south": 1, "north": 3},
    3: {"south": 2, "north": 4},
    4: {"south": 3, "north": 5},
    5: {"south": 4, "north": 6},
    6: {"south": 5, "north": 7},
    7: {"south": 6, "north": 8},
    8: {"south": 7, "north": 9},
    9: {"south": 8},
}
```

- [ ] **Step 3: Define Past rooms 0-4**

Replace `_past_rooms` definition with Dictionary keyed by index:

```gdscript
_past_rooms = {
    0: {
        "room_w": 13, "room_h": 9,
        "doors": ["north"],
        "enemies": [],
        "npcs": [{"x": 208, "y": 60, "dialogue": "res://data/dialogue/area1_scene02_solen.json"}],
        "props": [
            {"x": 100, "y": 180, "w": 32, "h": 32, "color": Color(0.4, 0.35, 0.3), "label": "well", "no_collision": true},
            {"x": 280, "y": 100, "w": 24, "h": 24, "color": Color(0.45, 0.35, 0.2), "label": "crate"},
            {"x": 310, "y": 130, "w": 24, "h": 24, "color": Color(0.45, 0.35, 0.2), "label": "crate"},
            {"x": 60, "y": 80, "w": 20, "h": 20, "color": Color(0.5, 0.3, 0.1), "label": "barrel"},
            {"x": 350, "y": 200, "w": 20, "h": 20, "color": Color(0.5, 0.3, 0.1), "label": "barrel"},
            {"x": 380, "y": 220, "w": 20, "h": 20, "color": Color(0.5, 0.3, 0.1), "label": "barrel"},
        ],
        "triggers": [],
        "floor_color": Color(0.82, 0.72, 0.52),
        "wall_color": Color(0.50, 0.42, 0.30),
    },
    1: {
        "room_w": 13, "room_h": 11,
        "doors": ["south", "north"],
        "enemies": [
            {"x": 140, "y": 120, "tint": Color(0.7, 0.5, 0.3), "hp": 3, "enemy_type": "archer_scout", "patrol_axis": "NS", "attack_cooldown": 2.0, "attack_damage": 1, "detection_radius": 150.0},
            {"x": 280, "y": 250, "tint": Color(0.7, 0.5, 0.3), "hp": 3, "enemy_type": "archer_scout", "patrol_axis": "NS", "attack_cooldown": 2.0, "attack_damage": 1, "detection_radius": 150.0},
        ],
        "npcs": [],
        "props": [
            {"x": 100, "y": 160, "w": 40, "h": 28, "color": Color(0.55, 0.45, 0.3), "label": "stall"},
            {"x": 250, "y": 100, "w": 40, "h": 28, "color": Color(0.55, 0.45, 0.3), "label": "stall"},
            {"x": 320, "y": 220, "w": 40, "h": 28, "color": Color(0.55, 0.45, 0.3), "label": "stall"},
        ],
        "triggers": [],
        "floor_color": Color(0.78, 0.68, 0.48),
        "wall_color": Color(0.48, 0.40, 0.28),
    },
    2: {
        "room_w": 13, "room_h": 11,
        "doors": ["south", "west", "east"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 208, "y": 120, "w": 48, "h": 32, "color": Color(0.6, 0.55, 0.5), "label": "GEAR CONSOLE"},
            {"x": 100, "y": 200, "w": 20, "h": 40, "color": Color(0.5, 0.45, 0.4), "label": "lever"},
        ],
        "triggers": [
            {"id": "gear_console", "x": 208, "y": 120, "radius": 40.0, "type": "gear_console", "fires_once": false},
        ],
        "floor_color": Color(0.75, 0.65, 0.45),
        "wall_color": Color(0.45, 0.38, 0.26),
    },
    3: {
        "room_w": 11, "room_h": 9,
        "doors": ["east", "north"],
        "enemies": [
            {"x": 176, "y": 144, "tint": Color(0.6, 0.45, 0.3), "hp": 4, "speed": 50.0, "chase_speed": 80.0},
        ],
        "npcs": [],
        "props": [
            {"x": 250, "y": 80, "w": 24, "h": 24, "color": Color(0.45, 0.35, 0.2), "label": "crate"},
            {"x": 100, "y": 200, "w": 24, "h": 24, "color": Color(0.45, 0.35, 0.2), "label": "crate"},
        ],
        "triggers": [
            {"id": "gear1", "x": 280, "y": 200, "radius": 30.0, "type": "gear_pickup", "piece_id": "GEAR_PIECE_1", "fires_once": true},
        ],
        "floor_color": Color(0.72, 0.62, 0.42),
        "wall_color": Color(0.42, 0.35, 0.24),
    },
    4: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [
            {"x": 100, "y": 80, "tint": Color(0.6, 0.45, 0.3), "hp": 4, "speed": 50.0, "chase_speed": 80.0},
            {"x": 300, "y": 80, "tint": Color(0.6, 0.45, 0.3), "hp": 4, "speed": 50.0, "chase_speed": 80.0},
        ],
        "npcs": [],
        "props": [
            {"x": 208, "y": 140, "w": 48, "h": 28, "color": Color(0.5, 0.4, 0.3), "label": "cart"},
        ],
        "triggers": [
            {"id": "gear2", "x": 208, "y": 144, "radius": 30.0, "type": "gear_pickup", "piece_id": "GEAR_PIECE_2", "fires_once": true},
        ],
        "floor_color": Color(0.72, 0.62, 0.42),
        "wall_color": Color(0.42, 0.35, 0.24),
    },
}
```

- [ ] **Step 4: Define Past rooms 5-9**

```gdscript
# Continue _past_rooms:
    5: {
        "room_w": 11, "room_h": 11,
        "doors": ["south"],
        "enemies": [
            {"x": 80, "y": 80, "tint": Color(0.6, 0.45, 0.3), "hp": 3, "speed": 50.0, "chase_speed": 80.0},
            {"x": 260, "y": 80, "tint": Color(0.6, 0.45, 0.3), "hp": 3, "speed": 50.0, "chase_speed": 80.0},
            {"x": 176, "y": 60, "tint": Color(0.6, 0.45, 0.3), "hp": 4, "speed": 55.0, "chase_speed": 85.0},
        ],
        "npcs": [],
        "props": [
            {"x": 176, "y": 200, "w": 32, "h": 32, "color": Color(0.4, 0.4, 0.45), "label": "well"},
        ],
        "triggers": [
            {"id": "gear3", "x": 176, "y": 200, "radius": 30.0, "type": "gear_pickup", "piece_id": "GEAR_PIECE_3", "fires_once": true},
        ],
        "floor_color": Color(0.70, 0.60, 0.40),
        "wall_color": Color(0.40, 0.33, 0.22),
    },
    6: {
        "room_w": 13, "room_h": 9,
        "doors": ["west", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 80, "y": 80, "w": 60, "h": 20, "color": Color(0.5, 0.45, 0.4), "label": "mural 1", "no_collision": true},
            {"x": 80, "y": 160, "w": 60, "h": 20, "color": Color(0.5, 0.45, 0.4), "label": "mural 2", "no_collision": true},
            {"x": 80, "y": 240, "w": 60, "h": 20, "color": Color(0.5, 0.45, 0.4), "label": "mural 3", "no_collision": true},
            {"x": 360, "y": 144, "w": 60, "h": 20, "color": Color(0.6, 0.5, 0.35), "label": "mural ?", "no_collision": true},
            {"x": 208, "y": 230, "w": 40, "h": 20, "color": Color(0.45, 0.42, 0.4), "label": "bench", "no_collision": true},
        ],
        "triggers": [
            {"id": "mural4_solen", "x": 340, "y": 144, "radius": 48.0, "type": "cutscene", "fires_once": true, "dialogue_path": "res://data/dialogue/area1_scene02_solen.json"},
            {"id": "communicator_past", "x": 208, "y": 230, "radius": 30.0, "type": "communicator", "timeline": "past", "fires_once": true},
        ],
        "floor_color": Color(0.75, 0.65, 0.45),
        "wall_color": Color(0.45, 0.38, 0.26),
    },
    7: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 208, "y": 144, "w": 96, "h": 16, "color": Color(0.55, 0.5, 0.45), "label": "bridge"},
        ],
        "triggers": [],
        "floor_color": Color(0.72, 0.62, 0.42),
        "wall_color": Color(0.42, 0.35, 0.24),
    },
    8: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 140, "y": 40, "w": 24, "h": 40, "color": Color(0.7, 0.4, 0.1), "label": "brazier", "no_collision": true},
            {"x": 276, "y": 40, "w": 24, "h": 40, "color": Color(0.7, 0.4, 0.1), "label": "brazier", "no_collision": true},
        ],
        "triggers": [
            {"id": "solen_pre_boss", "x": 208, "y": 100, "radius": 60.0, "type": "cutscene", "fires_once": true, "dialogue_path": "res://data/dialogue/area1_scene05_warden.json"},
        ],
        "floor_color": Color(0.60, 0.48, 0.35),
        "wall_color": Color(0.38, 0.28, 0.20),
    },
    9: {
        "room_w": 15, "room_h": 16,
        "doors": ["south"],
        "enemies": [
            {"x": 240, "y": 160, "tint": Color(0.85, 0.15, 0.1), "hp": 300, "speed": 45.0, "chase_speed": 70.0, "is_boss": true, "enemy_type": "warden_past"},
        ],
        "npcs": [],
        "props": [
            {"x": 100, "y": 100, "w": 28, "h": 28, "color": Color(0.5, 0.45, 0.4), "label": "column"},
            {"x": 380, "y": 100, "w": 28, "h": 28, "color": Color(0.5, 0.45, 0.4), "label": "column"},
            {"x": 100, "y": 350, "w": 28, "h": 28, "color": Color(0.5, 0.45, 0.4), "label": "column"},
            {"x": 380, "y": 350, "w": 28, "h": 28, "color": Color(0.5, 0.45, 0.4), "label": "column"},
        ],
        "triggers": [],
        "floor_color": Color(0.55, 0.40, 0.32),
        "wall_color": Color(0.32, 0.22, 0.18),
    },
```

- [ ] **Step 5: Define Future rooms 0-4**

```gdscript
_future_rooms = {
    0: {
        "room_w": 13, "room_h": 9,
        "doors": ["north"],
        "enemies": [],
        "npcs": [{"x": 208, "y": 60, "dialogue": "res://data/dialogue/area1_scene02_solen.json"}],
        "props": [
            {"x": 100, "y": 180, "w": 40, "h": 40, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
            {"x": 280, "y": 100, "w": 24, "h": 24, "color": Color(0.35, 0.3, 0.25), "label": "crate"},
            {"x": 310, "y": 130, "w": 24, "h": 24, "color": Color(0.35, 0.3, 0.25), "label": "crate"},
        ],
        "triggers": [],
        "floor_color": Color(0.28, 0.30, 0.38),
        "wall_color": Color(0.18, 0.20, 0.28),
    },
    1: {
        "room_w": 13, "room_h": 11,
        "doors": ["south", "north"],
        "enemies": [
            {"x": 140, "y": 120, "tint": Color(0.45, 0.2, 0.65), "hp": 3, "speed": 55.0, "chase_speed": 100.0, "enemy_type": "hollow_wraith"},
            {"x": 280, "y": 250, "tint": Color(0.45, 0.2, 0.65), "hp": 3, "speed": 55.0, "chase_speed": 100.0, "enemy_type": "hollow_wraith"},
        ],
        "npcs": [],
        "props": [
            {"x": 100, "y": 160, "w": 40, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
            {"x": 250, "y": 100, "w": 40, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
            {"x": 320, "y": 220, "w": 40, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "debris"},
        ],
        "triggers": [],
        "floor_color": Color(0.24, 0.26, 0.34),
        "wall_color": Color(0.15, 0.17, 0.25),
    },
    2: {
        "room_w": 13, "room_h": 11,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 208, "y": 120, "w": 48, "h": 32, "color": Color(0.35, 0.32, 0.3), "label": "ruined console"},
        ],
        "triggers": [],
        "floor_color": Color(0.22, 0.24, 0.32),
        "wall_color": Color(0.13, 0.15, 0.22),
    },
    3: {
        "room_w": 11, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [
            {"x": 80, "y": 60, "tint": Color(0.5, 0.3, 0.7), "hp": 4, "speed": 40.0, "chase_speed": 70.0, "enemy_type": "phantom_sniper", "attack_cooldown": 2.5, "attack_damage": 2, "detection_radius": 180.0},
            {"x": 260, "y": 60, "tint": Color(0.5, 0.3, 0.7), "hp": 4, "speed": 40.0, "chase_speed": 70.0, "enemy_type": "phantom_sniper", "attack_cooldown": 2.5, "attack_damage": 2, "detection_radius": 180.0},
        ],
        "npcs": [],
        "props": [
            {"x": 176, "y": 80, "w": 60, "h": 40, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
        ],
        "triggers": [],
        "floor_color": Color(0.20, 0.22, 0.30),
        "wall_color": Color(0.12, 0.14, 0.20),
    },
    4: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 208, "y": 144, "w": 96, "h": 8, "color": Color(0.2, 0.2, 0.2), "label": "chasm"},
        ],
        "triggers": [],
        "floor_color": Color(0.22, 0.24, 0.32),
        "wall_color": Color(0.13, 0.15, 0.22),
    },
}
```

- [ ] **Step 6: Define Future rooms 5-9**

```gdscript
# Continue _future_rooms:
    5: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 80, "y": 80, "w": 24, "h": 24, "color": Color(0.4, 0.35, 0.5), "label": "echo", "no_collision": true},
            {"x": 330, "y": 80, "w": 24, "h": 24, "color": Color(0.4, 0.35, 0.5), "label": "echo", "no_collision": true},
            {"x": 80, "y": 220, "w": 24, "h": 24, "color": Color(0.4, 0.35, 0.5), "label": "echo", "no_collision": true},
            {"x": 330, "y": 220, "w": 24, "h": 24, "color": Color(0.5, 0.2, 0.3), "label": "echo ?", "no_collision": true},
        ],
        "triggers": [
            {"id": "communicator_future", "x": 208, "y": 144, "radius": 50.0, "type": "communicator", "timeline": "future", "fires_once": true},
        ],
        "floor_color": Color(0.22, 0.24, 0.32),
        "wall_color": Color(0.13, 0.15, 0.22),
    },
    6: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 208, "y": 60, "w": 48, "h": 48, "color": Color(0.35, 0.3, 0.4), "label": "mirror", "no_collision": true},
        ],
        "triggers": [
            {"id": "mirror_trigger", "x": 208, "y": 100, "radius": 40.0, "type": "cutscene", "fires_once": true, "dialogue_path": "res://data/dialogue/area1_mirror_solen.json"},
        ],
        "floor_color": Color(0.20, 0.22, 0.30),
        "wall_color": Color(0.12, 0.14, 0.20),
    },
    7: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [
            {"x": 208, "y": 144, "w": 96, "h": 16, "color": Color(0.3, 0.28, 0.25), "label": "bridge ruins"},
        ],
        "triggers": [],
        "floor_color": Color(0.22, 0.24, 0.32),
        "wall_color": Color(0.13, 0.15, 0.22),
    },
    8: {
        "room_w": 13, "room_h": 9,
        "doors": ["south", "north"],
        "enemies": [],
        "npcs": [],
        "props": [],
        "triggers": [],
        "floor_color": Color(0.18, 0.20, 0.28),
        "wall_color": Color(0.10, 0.12, 0.18),
    },
    9: {
        "room_w": 15, "room_h": 16,
        "doors": ["south"],
        "enemies": [
            {"x": 240, "y": 160, "tint": Color(0.55, 0.1, 0.85), "hp": 300, "speed": 45.0, "chase_speed": 70.0, "is_boss": true, "enemy_type": "warden_future"},
        ],
        "npcs": [],
        "props": [
            {"x": 100, "y": 100, "w": 28, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
            {"x": 380, "y": 100, "w": 28, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
            {"x": 100, "y": 350, "w": 28, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
            {"x": 380, "y": 350, "w": 28, "h": 28, "color": Color(0.3, 0.28, 0.25), "label": "rubble"},
        ],
        "triggers": [],
        "floor_color": Color(0.18, 0.10, 0.28),
        "wall_color": Color(0.10, 0.05, 0.18),
    },
```

- [ ] **Step 7: Commit**

```bash
git add scripts/Main.gd
git commit -m "feat: define all 20 Area 1 rooms with connections and systems"
```

---

## Task 11: Wire Gear Console & Bridge Materialise into Room.gd

**Files:**
- Modify: `scripts/Room.gd`
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Add gear_console trigger handling in Room._handle_trigger**

In Room.gd `_handle_trigger`, add a case for "gear_console":

```gdscript
        "gear_console":
            var count: int = GameState.get_flag("gear_pieces_found", 0)
            if count >= 3:
                var manager := GearPuzzleManager.new()
                if manager.try_complete_puzzle():
                    manager.queue_free()
```

Note: gear_console trigger has `fires_once: false` so the player can re-interact after collecting pieces.

- [ ] **Step 2: Add conditional door locking for east door of Past Room 2**

The east door of Past Room 2 (gear console hub) should be locked until `area1_bridge_built` is true. Add to Room.gd a `locked_doors` config and check in door body_entered:

Add var after `trigger_configs`:
```gdscript
var locked_doors: Dictionary = {}
```

Modify door `body_entered` lambda in `_build_doors()`:

```gdscript
        var dir_captured: String = dir
        door_area.body_entered.connect(func(body: Node2D):
            if body.is_in_group("players") and is_cleared:
                if locked_doors.has(dir_captured):
                    var lock_flag: String = locked_doors[dir_captured]
                    if not GameState.get_flag(lock_flag, false):
                        return
                TimelineManager.room_transition_requested.emit(timeline, dir_captured)
        )
```

Then in Main.gd, Past Room 2 config, add:
```gdscript
"locked_doors": {"east": "area1_bridge_built"},
```

And in `_load_room`, add:
```gdscript
room.locked_doors = cfg.get("locked_doors", {})
```

- [ ] **Step 3: Add bridge materialise listener for Future Room 4 (Chasm)**

In Main.gd `_ready()`, after system setup, connect the timeline_action signal for bridge materialise:

```gdscript
TimelineManager.timeline_action.connect(_on_timeline_action)
```

Add handler:
```gdscript
func _on_timeline_action(action_id: String, source: String) -> void:
    match action_id:
        "gear2_placed":
            if current_future_room and current_future_room.room_id == 4:
                _materialise_chasm_bridge()
        "bridge_built":
            pass
```

```gdscript
func _materialise_chasm_bridge() -> void:
    pass
```

The bridge materialise will be a visual effect in Room 4 of future. For now, the flag-based door locking handles the gameplay gate. Full animation can be added as a polish step.

- [ ] **Step 4: Commit**

```bash
git add scripts/Room.gd scripts/Main.gd
git commit -m "feat: wire gear console puzzle and conditional door locks"
```

---

## Task 12: Wire Warden Boss to Shared HP Pool

**Files:**
- Modify: `scripts/EnemyBase.gd`
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Override boss receive_hit for Warden types**

In EnemyBase.gd, modify `receive_hit` to use shared HP for Warden:

```gdscript
func receive_hit(damage: int, knockback_dir: Vector2) -> void:
    if is_dead:
        return
    if is_boss and not TimelineManager.is_synced():
        _flash_blocked()
        return

    if enemy_type in ["warden_past", "warden_future"]:
        var bonus := 1.25 if enemy_type == "warden_future" else 1.0
        var final_damage := int(damage * bonus)
        var remaining := TimelineManager.damage_warden(final_damage, timeline)
        if remaining <= 0:
            _on_died()
        else:
            state = State.HURT
            hurt_timer = 0.25
            velocity = knockback_dir * KNOCKBACK_FORCE
            hitbox.monitoring = false
            _play("hurt")
            _flash()
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
```

- [ ] **Step 2: Add Warden phase 2 listener**

In EnemyBase `_ready`, connect phase change:

```gdscript
if enemy_type in ["warden_past", "warden_future"]:
    TimelineManager.warden_phase_changed.connect(_on_warden_phase)

func _on_warden_phase(phase: int) -> void:
    if phase == 2:
        velocity = Vector2.ZERO
        _play("hurt")
        speed *= 1.3
        chase_speed *= 1.3
        attack_cooldown *= 0.7
        if enemy_type == "warden_future" and not DialogueManager.is_active():
            await get_tree().create_timer(0.5).timeout
            DialogueManager.start_dialogue("res://data/dialogue/area1_warden_midfight.json")
```

- [ ] **Step 3: Commit**

```bash
git add scripts/EnemyBase.gd
git commit -m "feat: wire Warden boss to shared HP pool with phase transitions"
```

---

## Task 13: Final Integration & Reset Logic

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Add area reset on restart**

In `_on_restart_pressed()` and `_on_menu_pressed()`, add:

```gdscript
GameState.reset_area1()
```

- [ ] **Step 2: Verify `_load_room` doesn't index into array**

Ensure all references to room_data use `.has(room_idx)` dictionary check instead of `room_idx >= room_data.size()` array bound check. This was already handled in Task 2 Step 3.

- [ ] **Step 3: Commit**

```bash
git add scripts/Main.gd
git commit -m "feat: add area reset logic and final integration"
```

---

## Spec Coverage Check

| PRD Requirement | Task |
|---|---|
| 10 past rooms | Task 10 Steps 3-4 |
| 10 future rooms | Task 10 Steps 5-6 |
| Non-linear room connections | Task 2 |
| Gear puzzle (3 pieces) | Tasks 3, 6, 11 |
| Bridge materialise | Task 7, 11 |
| Echo communicator | Task 8 |
| Scene 04 cutscene | Task 4, 8 |
| Warden shared HP | Tasks 1, 9, 12 |
| Warden phase 2 at 50% | Task 12 |
| ArcherScout (patrol_NS, ranged) | Task 5 |
| OldKingdomSoldier (room_guard) | Task 10 (default enemy type) |
| HollowWraith (teleport) | Task 5 |
| PhantomSniper (ranged) | Task 5 |
| Conditional door locks | Task 11 |
| GameState flags | Task 1 |
| Dialogue files | Task 4 |
| Area completion logic | Task 2 Step 4 |
| Reset on restart | Task 13 |

## Known Simplifications

The following PRD features are represented with simplified visuals (ColorRect props instead of sprites, no particle effects) since no art assets exist yet:
- Torch/brazier flame animations
- Bridge materialise dust puffs
- Echo stone ghost overlays
- Mirror reflection effect
- Dark energy crack VFX
- Warden Recognition Reach animation

These can be upgraded when art assets are available without changing the underlying systems.
