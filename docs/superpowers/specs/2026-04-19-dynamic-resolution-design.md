# Dynamic Resolution Scaling

## Goal

Let SplitFate run in a window of any size (including fullscreen on any display) while preserving the existing 1376×768 split-screen layout. The rendered image is scaled to fit the window with letterbox/pillarbox bars to keep the 16:9 aspect ratio. No gameplay, room, or camera code changes.

## Non-goals

- Giving players more visible world on larger displays (rejected option B).
- Separate settings UI for windowed/fullscreen/borderless modes (rejected option D). A hotkey is enough for now.
- Per-scene overrides. All scenes inherit the same stretch behavior.

## Approach

Use Godot 4's project-level stretch mode to scale the root 1376×768 viewport to the window. The split-screen `SplitContainer` + `SubViewportContainer` layout is already Control-based, so when the root viewport scales as a unit, both halves scale equally and world coordinates inside each `SubViewport` remain unchanged.

## Changes

### 1. `project.godot` — `[display]` section

Add / set:

- `window/size/viewport_width = 1376` (unchanged — logical base)
- `window/size/viewport_height = 768` (unchanged)
- `window/size/resizable = true`
- `window/stretch/mode = "canvas_items"`
- `window/stretch/aspect = "keep"`
- `window/stretch/scale_mode = "fractional"`

Rationale for each:

- `canvas_items` stretch scales output drawing, keeping UI/fonts crisp at any scale factor. (Alternative `viewport` would render at 1376×768 and upscale — more rigidly pixelated; noted as a fallback if we dislike the look.)
- `keep` aspect enforces 16:9 with letterbox/pillarbox so gameplay fairness is preserved across displays.
- `fractional` scale mode allows smooth scaling to odd window sizes. Integer-only would waste more screen space.

### 2. `project.godot` — `[rendering]` section

- `rendering/textures/canvas_textures/default_texture_filter = 0` (Nearest)

Keeps pixel-art sprites crisp under the scaled output.

### 3. New autoload — `autoloads/WindowManager.gd`

A tiny autoload that listens for F11 and toggles between windowed and fullscreen.

Responsibilities:

- In `_unhandled_input(event)`: if `event` is `InputEventKey` pressed with `keycode == KEY_F11`, toggle `DisplayServer.window_set_mode(...)` between `DisplayServer.WINDOW_MODE_WINDOWED` and `DisplayServer.WINDOW_MODE_FULLSCREEN`.
- Marks the event handled via `get_viewport().set_input_as_handled()` to avoid it leaking to gameplay.

Registered in `project.godot` `[autoload]` alongside `GameState`, `TimelineManager`, `DialogueManager`, `AudioManager`.

The game starts windowed at 1376×768 (unchanged default). Player presses F11 to go fullscreen; F11 again to return to a windowed state.

## What stays the same

- `scripts/Main.gd` constants `VP_W = 688`, `VP_H = 768`, `ROOM_W = 1376`, `ROOM_H = 768` — still the authoritative world/viewport sizes.
- `Main.tscn` scene tree, `SplitContainer`, `SubViewport`s, `World2D` setup, overlays, HUD.
- `PlayerBase` camera, room bounds, hitboxes, enemy AI, Jolt physics.
- Input actions and the existing InputMap built by `GameState._setup_input_map()`.

## Risks and trade-offs

- **Ultrawide (21:9) displays** show pillarbox bars on the left/right; **4:3 displays** show letterbox bars on top/bottom. Accepted cost of the chosen approach.
- **Non-integer window sizes** with nearest-neighbor filtering may show slight pixel unevenness. `fractional` scale mode is the explicit choice (over integer-only) to avoid large letterbox bars. If unevenness looks bad in practice, we can switch `scale_mode` to `integer` without other changes.
- **`canvas_items` vs `viewport` stretch:** `canvas_items` keeps UI crisp at large scales; `viewport` produces a more rigidly pixelated look consistent with retro aesthetics. Easy to swap later if preferred.
- **F11 key conflict:** no existing input action uses F11 (confirmed against `GameState._setup_input_map()`), so there is no collision. The autoload consumes the event to be safe.

## Verification

Manual checks after implementation:

1. Launch game — window opens at 1376×768, plays normally.
2. Drag-resize the window smaller and larger — rendering scales, 16:9 aspect preserved with bars on the opposite axis.
3. Press F11 — goes fullscreen on the current monitor, image scaled to fit.
4. Press F11 again — returns to windowed at previous size.
5. Pixel art (player sprite, enemies) remains visually sharp at common scale factors (1×, 1.5×, 2×).
6. Split-screen divider stays centered; left and right viewports remain equal width at all window sizes.
7. Existing room transitions, dialogue, HUD fades, and game-over overlay still behave correctly.
