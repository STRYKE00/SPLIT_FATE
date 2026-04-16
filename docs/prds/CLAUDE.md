# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 split-screen co-op action-RPG ("SplitFate" / `RPG_SLOP`). Two players — Past and Future — share one keyboard and play simultaneously in two independent timelines rendered side-by-side. Renderer is `gl_compatibility`; physics uses Jolt. All scripts are GDScript.

## Running

Open `project.godot` in Godot 4.6 and press F5, or from CLI:

```bash
godot --path . # run main scene (main_menu.tscn)
godot --path . scenes/Main.tscn # run the gameplay scene directly
godot --path . --headless --quit # import assets / regenerate .godot cache
```

No test framework, lint config, or build scripts exist — don't invent commands. The `.godot/` cache is gitignored; after pulling, let the editor (or a headless run) re-import.

## Architecture

### Split-screen viewport model (`scripts/Main.gd`)
`Main.tscn` holds a `SplitContainer` with two `SubViewport`s. Each viewport gets its **own `World2D`** (`left_viewport.world_2d = World2D.new()`) so the Past and Future timelines have fully independent physics spaces — players and enemies in one timeline cannot collide with the other. Each viewport also has its own `CanvasLayer` fade overlay (`past_overlay` / `future_overlay`) used for room-transition and death fades.

Room content is defined declaratively as Dictionaries in `_define_rooms()` (doors, enemy configs, NPC configs, floor/wall colors) and instantiated via `Room.new().build()` into the appropriate world. Room 3 is the boss room (`BOSS_ROOM_INDEX`).

### Autoloads (see `project.godot` `[autoload]`)
- **`GameState`** — puzzle flags, current room index per timeline, global `is_dialogue_active` / `is_transitioning` gates that freeze player input. Also builds the InputMap at runtime in `_setup_input_map()` (no input actions are defined in `project.godot`).
- **`TimelineManager`** — event bus (all cross-timeline signals: `room_transition_requested`, `player_died`, `boss_defeated`, `sync_changed`, etc.) **and** the Sync meter, which charges when both players are in the same room index and decays otherwise. Gameplay code should emit/listen on TimelineManager rather than reaching across the scene tree.
- **`DialogueManager`** — loads JSON from `data/dialogue/*.json` (array of `{speaker, text}`), sets `GameState.is_dialogue_active`, emits `line_ready` / `dialogue_ended`.
- **`AudioManager`**.

### Player architecture
`PlayerBase` (`scripts/PlayerBase.gd`) is a `CharacterBody2D` with a state machine (`IDLE/MOVE/ATTACK/HURT/DASH/DEAD`), dash i-frames, attack hitbox, camera shake. It reads input via **string action names** stored in `action_left`, `action_right`, … `action_dash`. The subclasses `PlayerPast` and `PlayerFuture` only set those action strings + `timeline` + `slash_color` before calling `super._ready()`. This is the seam for per-timeline input — to add a new player action, add an `action_*` field on `PlayerBase`, register the action in `GameState._setup_input_map()` for both `past_*` and `future_*` variants, and assign it in both subclasses.

Input action naming convention: `past_<verb>` and `future_<verb>` (e.g. `past_attack`, `future_dash`). Past uses WASD + Space/E/Shift, Future uses arrows + Enter/./Slash.

### Sprite frames
`PlayerBase._build_frames()` constructs `SpriteFrames` programmatically from individual PNGs in `assets/Ren/...` as `AtlasTexture`s with a fixed 64×64 region. Subclasses re-tint via `sprite.modulate`.

## Conventions

- `class_name` is used for types referenced from other scripts (`PlayerBase`, `Room`). Add a `class_name` when exposing a type across files; otherwise leave it out.
- Cross-system communication goes through `TimelineManager` signals. Do not have gameplay nodes hold direct references across the two worlds.
- When gameplay should pause (dialogue, transition), gate behavior on `GameState.is_dialogue_active` / `is_transitioning` — `PlayerBase._physics_process` and `Main._process` already do this; new systems should too.
- Room data lives inline in `Main.gd._define_rooms()` as Dictionaries — edit there rather than creating per-room scene files.

## Editor plugin

`addons/ai_assistant_hub` is a third-party plugin enabled in `project.godot` (`ollama_api`). It is not part of the game; ignore it when reasoning about gameplay code.
