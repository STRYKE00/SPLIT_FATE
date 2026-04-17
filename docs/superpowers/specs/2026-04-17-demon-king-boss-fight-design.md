# Demon King Boss Fight — Design

**Date:** 2026-04-17
**Branch:** firdaus
**Status:** Approved design, ready for implementation plan

## Goal

Implement the Solen (Demon King) boss fight inside `scenes/Boss_Room.tscn`, plus a debug skip-to-boss button on every scene from the prologue onwards. The boss room is **not** split-screen: both Past and Future players share one `World2D` and fight Solen together.

## Scope

1. A global "Skip → Boss" debug button visible on every scene except `main_menu.tscn`.
2. `Boss_Room.tscn` populated with both player instances, Solen, and a boss HUD.
3. A full rewrite of `scenes/characters/demon_king.gd` with its own state machine.
4. A boss HP bar ("Solen", 20 HP) that animates in on spawn and drains on damage.
5. Game-over / victory routing back to the main menu.

Out of scope: the actual puzzle-to-boss transition from the main gameplay scene, post-victory cutscene, revive/resurrection mechanics, polished win/lose UI screens.

## Architecture Overview

```
DebugSkipButton (autoload)         ← top-right CanvasLayer button, all scenes except main_menu
    └─ "Skip → Boss" → change_scene_to_file("res://scenes/Boss_Room.tscn")

Boss_Room.tscn (Node2D, root script BossRoom.gd)
    ├─ [existing tilemap / environment]
    ├─ PlayerPast   (spawn point south-left)
    ├─ PlayerFuture (spawn point south-right)
    ├─ DemonKing    (center of arena, is_boss = true)
    └─ BossHUD      (CanvasLayer, top-center)

TimelineManager (autoload, existing)
    + boss_hp_changed(current: int, max_hp: int)   ← NEW signal
    (boss_spawned, boss_defeated, player_died already exist)
```

### Why single-world (no split-screen) here

`Main.tscn` uses two `SubViewport`s with independent `World2D`s so Past and Future physics never mix. The boss fight is a climactic co-op moment — both players need to be in the same physics space to fight one boss, so `Boss_Room.tscn` is a plain `Node2D` scene with one shared world. Each player still reads its own per-timeline input actions (`past_*` / `future_*`), so local co-op still works.

### Why Approach A (subclass-heavy) for Solen

`EnemyBase.gd` is a shared base for 13 enemies. Adding virtual hooks for boss-only behavior risks regressions across all of them for the sake of one boss. Instead, `DemonKing.gd` overrides `_physics_process` wholesale with its own state machine and reuses EnemyBase only for node wiring (`_init_configs`), the `stats` component, the `hitbox` area, and the `receive_hit` entry point (also overridden, to drop the sync check).

## Components

### 1. `scripts/DebugSkipButton.gd` (new autoload)

Creates a `CanvasLayer` (layer 100) with a `Button` anchored to the top-right. On `_ready`, connects to `get_tree().tree_changed` to auto-refresh visibility on scene swaps. Hidden on `main_menu.tscn`, shown everywhere else.

On press:
1. Reset `GameState.is_dialogue_active = false` and `GameState.is_transitioning = false`.
2. `get_tree().change_scene_to_file("res://scenes/Boss_Room.tscn")`.

Registered in `project.godot` as `DebugSkipButton="*res://scripts/DebugSkipButton.gd"`.

### 2. `scripts/BossRoom.gd` (new, attached to Boss_Room.tscn root)

Listens to:
- `TimelineManager.player_died(timeline)` — tracks `_past_dead` / `_future_dead`. When both true, calls `solen.play_victory()` and after 2s transitions to `main_menu.tscn`.
- `TimelineManager.boss_defeated(timeline)` — after 2s, transitions to `main_menu.tscn`.

No per-frame logic. Pure signal-driven coordination.

### 3. `scripts/BossHUD.gd` + `scenes/ui/BossHUD.tscn` (new)

Scene tree: `CanvasLayer` → `Control` (top-center anchor) → `VBoxContainer` → `Label "Solen"` + `ProgressBar` (max 20, red fill). Bar width ~70% of viewport, 16px tall.

Behavior:
- `visible = false` at start.
- On `TimelineManager.boss_spawned`: `visible = true`, `max_value = 20`, `value = 20`, tween `scale.x` from 0.05 → 1.0 over 1.0s with `EASE_OUT`.
- On `TimelineManager.boss_hp_changed(current, max_hp)`: tween `value` to `current` over 0.2s.
- On `TimelineManager.boss_defeated`: tween `modulate.a` to 0, then `visible = false`.

### 4. `scenes/characters/demon_king.gd` (full rewrite)

Extends `EnemyBase`. Declares own state enum; overrides `_physics_process` and `receive_hit`.

**States:** `IDLE`, `WALK`, `LIGHT_ATTACK`, `HEAVY_ATTACK`, `ROLL`, `HURT`, `DEAD`, `VICTORY`.

**Constants:**

| Constant | Value | Notes |
|---|---|---|
| `MAX_HP` | 20 | |
| `PHASE_2_HP` | 10 | 50% — heavy attacks unlock |
| `WALK_SPEED` | 70.0 | |
| `CHASE_SPEED` | 110.0 | |
| `LIGHT_RANGE` | 36.0 | melee |
| `LIGHT_DAMAGE` | 1 | |
| `HEAVY_TELEGRAPH` | 1.0 | seconds of windup |
| `HEAVY_RADIUS` | 112.0 | 7 tiles × 16px |
| `HEAVY_DAMAGE` | 3 | |
| `ROLL_SPEED` | 260.0 | |
| `ROLL_DURATION` | 0.35 | |
| `ATTACK_COOLDOWN` | 1.4 | |
| `HURT_DURATION` | 0.25 | |

**Target selection:** each frame in `WALK`, `_pick_nearest_player()` iterates the `"players"` group and picks the closest live player. No sticky target.

**Attack selection (after cooldown expires, in `WALK`):**

- Phase 1 (`hp > PHASE_2_HP`): if `distance_to_target > LIGHT_RANGE * 1.5` → `ROLL` toward target; else → `LIGHT_ATTACK`.
- Phase 2 (`hp <= PHASE_2_HP`): compute `heavy_chance = lerp(0.3, 0.7, 1.0 - hp/float(PHASE_2_HP))`. If `randf() < heavy_chance` → `HEAVY_ATTACK`; else → phase-1 logic.

**`LIGHT_ATTACK`:** plays `light_attack` animation. Enables the existing `hitbox` (from `EnemyBase.tscn`) positioned in `facing * 22.0`, with `attack_damage = LIGHT_DAMAGE`. Disables on animation end. Returns to `WALK`.

**`HEAVY_ATTACK` (radial AoE):**
1. Lock velocity to zero, play `heavy_attack` animation.
2. Spawn a child `Node2D` with a custom `_draw()` that renders an expanding circle outline (or a tweened `ColorRect` with a circle shader — whichever is simpler in GDScript — the simple option is a `ColorRect` with `scale` tweened on a circle sprite).
3. Tween the visual's `scale` from 0 → 1 over `HEAVY_TELEGRAPH` (1.0s).
4. At telegraph end, create an `Area2D` with a `CircleShape2D(radius = HEAVY_RADIUS)` at Solen's position, `monitoring = true` for one physics frame. Scan `"players"` group members; for each with distance `<= HEAVY_RADIUS`, call `receive_hit(HEAVY_DAMAGE, (player - solen).normalized())`.
5. Free the telegraph visual and the probe Area2D. Return to `WALK`.

Heavy attack is **uninterruptible** once started (no HURT cancel during windup) for simplicity.

**`ROLL`:** plays `roll` animation. Sets `velocity = dir_to_target * ROLL_SPEED`, `_invulnerable = true`. Duration `ROLL_DURATION`. Does not damage on contact. Returns to `WALK` on timeout. `receive_hit` early-returns while `_invulnerable`.

**`HURT`:** on successful `receive_hit`, plays `hurt`, applies `knockback_dir * KNOCKBACK_FORCE`, locks out for `HURT_DURATION`. Interrupts `LIGHT_ATTACK` and `ROLL`. Does not interrupt `HEAVY_ATTACK`.

**`receive_hit(damage, knockback_dir)` override:**
- If `is_dead` or `_invulnerable`: return.
- Skip EnemyBase's `is_synced` check.
- `stats.take_damage(damage)`, emit `TimelineManager.boss_hp_changed.emit(stats.hp, stats.max_hp)`.
- If not dead, enter `HURT` state with knockback.

**`DEAD`:** on `stats.died` signal, enter `DEAD`, play `death` animation, disable all collision, emit `TimelineManager.boss_defeated.emit(timeline)` (reuses existing EnemyBase `_on_died`, which already handles cleanup). Override the fade-out so the death animation plays fully before `queue_free`.

**`VICTORY`:** public method `play_victory()` called by `BossRoom.gd` when both players are dead. Sets state = `VICTORY`, plays `victory` animation, zeroes velocity, disables all collision. Terminal.

### 5. `scenes/Boss_Room.tscn` modifications

Add under the root Node2D:
- `PlayerPast` (instance of `res://scenes/characters/PlayerPast.tscn`) at a south-left spawn point.
- `PlayerFuture` (instance of `res://scenes/characters/PlayerFuture.tscn`) at a south-right spawn point.
- `DemonKing` (instance of `res://scenes/characters/DemonKing.tscn`) at the arena center, with `is_boss = true` exported.
- `BossHUD` (instance of `res://scenes/ui/BossHUD.tscn`).
- Attach `scripts/BossRoom.gd` to the root.

### 6. `scripts/TimelineManager.gd`

Add one signal:
```gdscript
signal boss_hp_changed(current: int, max_hp: int)
```

No other changes.

### 7. Cleanup

Delete root-level `character_body_2d.gd` and `enemy_base.gd` (unused Godot-generated stub files in the repo root; not the real `scripts/EnemyBase.gd`).

## Data Flow

**Skip button pressed:**
`DebugSkipButton._on_pressed` → resets gameplay gates → `change_scene_to_file(Boss_Room.tscn)` → `BossRoom.gd._ready` → Solen's `_init_configs` fires (inherited from EnemyBase) → `TimelineManager.boss_spawned.emit(self)` → `BossHUD` receives, animates in.

**Player hits Solen:**
Player's attack hitbox → Solen's hurtbox → `DemonKing.receive_hit(dmg, dir)` → `stats.take_damage` → `TimelineManager.boss_hp_changed.emit(hp, max_hp)` → `BossHUD` tweens bar value.

**Solen hits player (heavy AoE):**
`_state_heavy_attack` telegraph ends → probe Area2D scans `"players"` group → for each hit player calls `PlayerBase.receive_hit(3, dir)` → player's StatsComponent drains → if `hp <= 0`, `TimelineManager.player_died.emit(timeline)`.

**Both players dead:**
`BossRoom._on_player_died` sets both flags true → calls `solen.play_victory()` → 2s timer → main menu.

**Solen dies:**
`stats.died` → `EnemyBase._on_died` → `TimelineManager.boss_defeated.emit` → `BossHUD` fades out → `BossRoom._on_boss_defeated` → 2s timer → main menu.

## Error Handling

- `DemonKing._pick_nearest_player` returns null if no live players exist (both dead mid-frame). State machine treats null target as "stay in WALK, no attack selection" — `BossRoom.gd` will trigger `VICTORY` via its `player_died` listener on the next frame.
- Heavy attack's probe Area2D is created with `monitoring = true` for one physics frame and then freed, avoiding lingering-collider leaks.
- Roll's `_invulnerable` flag is cleared in `_state_roll` timeout handler; if Solen enters `DEAD` mid-roll, the flag is irrelevant since `is_dead` short-circuits `receive_hit` first.
- `DebugSkipButton` defensively resets `GameState.is_dialogue_active` and `is_transitioning` so a mid-dialogue skip doesn't leave the boss scene's input frozen.

## Testing

No automated test framework exists. Manual test checklist:

1. Launch game → main menu shows no skip button.
2. Advance to prologue → skip button visible top-right.
3. Click skip → Boss_Room loads, both players controllable, Solen visible, HP bar animates in.
4. Walk Past player into Solen's light-attack range → Solen swings, 1 HP damage to player.
5. Keep distance until phase 2 (10 HP), verify heavy-attack telegraph is visible, dodgeable by moving outside 112px, deals 3 damage if caught.
6. Verify roll triggers when player is far, repositions Solen, and Solen is invulnerable during the roll frames.
7. Kill both players → Solen plays `victory`, main menu after 2s.
8. Kill Solen (20 hits) → `death` plays, HP bar fades, main menu after 2s.

## Open Questions / Future Work

- Revive/resurrection mechanic when one player is down (deferred by user).
- Proper win/lose UI screens instead of direct main-menu bounce.
- Wire the actual puzzle-to-boss transition in `Main.gd` once the bridge puzzle flow is ready.
- Second boss would motivate refactoring `EnemyBase` into the virtual-hooks approach.
