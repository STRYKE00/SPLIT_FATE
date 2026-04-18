# Dynamic Resolution Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Letterbox-scale the existing 1376×768 split-screen rendering to any window size or fullscreen display, with an F11 fullscreen toggle.

**Architecture:** Project-level Godot stretch config (`canvas_items` / `keep` / `fractional`) scales the root viewport as a unit, preserving the `SplitContainer` + dual `SubViewport` layout without any gameplay code changes. A tiny `WindowManager` autoload handles the F11 toggle.

**Tech Stack:** Godot 4.6, GDScript, `DisplayServer` API.

**Spec:** `docs/superpowers/specs/2026-04-19-dynamic-resolution-design.md`

**Note on testing:** Per `CLAUDE.md`, the project has no test framework. Verification is manual via the Godot editor. Each task below ends with a concrete manual check and a commit.

---

## File Structure

- **Create:** `autoloads/WindowManager.gd` — single-responsibility autoload; listens for F11, toggles window mode. Sibling to the existing autoloads in `autoloads/`.
- **Modify:** `project.godot` — `[display]` section (stretch + resizable), `[rendering]` section (default texture filter = Nearest), `[autoload]` section (register `WindowManager`).

No existing files need structural changes. `scripts/Main.gd` constants (`VP_W`, `VP_H`, `ROOM_W`, `ROOM_H`) are deliberately untouched.

---

### Task 1: Add stretch configuration to `project.godot`

**Files:**
- Modify: `project.godot` — `[display]` section (lines 26–29) and `[rendering]` section (lines 154–158).

- [ ] **Step 1: Edit `[display]` section**

Replace the existing `[display]` block:

```
[display]

window/size/viewport_width=1376
window/size/viewport_height=768
```

with:

```
[display]

window/size/viewport_width=1376
window/size/viewport_height=768
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale_mode="fractional"
```

Notes:
- `viewport_width` / `viewport_height` are unchanged — they remain the logical base resolution.
- Key names and string values match Godot 4.6's `ProjectSettings` exactly. Using any other spelling (e.g. `stretch_mode`, `keep_aspect`) will silently fail.

- [ ] **Step 2: Edit `[rendering]` section**

Inside the existing `[rendering]` block (currently lines 154–158), add the default texture filter line. The block becomes:

```
[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
```

Value `0` is `CANVAS_ITEM_TEXTURE_FILTER_NEAREST` — the integer enum Godot writes to `project.godot` for Nearest filtering.

- [ ] **Step 3: Manual verification**

1. Open `project.godot` in Godot 4.6.
2. Press F5 to run the main scene.
3. Drag the window edge to resize — the rendered image scales with the window; bars appear on the short axis to preserve 16:9.
4. Sprites remain sharp (no bilinear blur) at non-integer scales.
5. The split-screen divider stays centered; left/right halves remain equal width.

- [ ] **Step 4: Commit**

```bash
git add project.godot
git commit -m "Add stretch config so game scales to any window size"
```

---

### Task 2: Create `WindowManager` autoload

**Files:**
- Create: `autoloads/WindowManager.gd`

- [ ] **Step 1: Create `autoloads/WindowManager.gd`**

```gdscript
extends Node

# Toggles fullscreen on F11.
# Consumes the event so it never leaks to gameplay input.

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_F11:
		return

	var current := DisplayServer.window_get_mode()
	if current == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	get_viewport().set_input_as_handled()
```

Notes:
- Guarding on `key.echo` avoids repeat-toggle while the key is held.
- `_unhandled_input` runs after UI has had a chance to consume input, so it won't steal keys from focused text fields if any are ever added.

- [ ] **Step 2: Register the autoload in `project.godot`**

In the existing `[autoload]` block (lines 18–24), add one line so the block becomes:

```
[autoload]

DialogueManager="*res://autoloads/DialogueManager.gd"
GameState="*res://autoloads/GameState.gd"
TimelineManager="*res://autoloads/TimelineManager.gd"
AudioManager="*res://autoloads/AudioManager.gd"
DebugSkipButton="*res://autoloads/DebugSkipButton.gd"
WindowManager="*res://autoloads/WindowManager.gd"
```

The leading `*` enables autoload singleton mode (matching the existing entries).

- [ ] **Step 3: Manual verification**

1. In Godot 4.6, open Project → Project Settings → Autoload and confirm `WindowManager` is present and enabled.
2. Press F5 to run the main scene.
3. Press F11 — the window switches to fullscreen on the current monitor; rendering scales to fill.
4. Press F11 again — returns to a windowed state.
5. Hold F11 — mode does not toggle repeatedly (echo guard works).
6. Existing input (WASD for Past, arrows for Future, attack, dash) still works after toggling modes.

- [ ] **Step 4: Commit**

```bash
git add autoloads/WindowManager.gd project.godot
git commit -m "Add WindowManager autoload for F11 fullscreen toggle"
```

---

### Task 3: End-to-end verification against the spec

No code changes. Walk the spec's verification list and confirm everything still works together.

- [ ] **Step 1: Fresh run**

Close Godot, reopen the project, press F5. Window opens at 1376×768.

- [ ] **Step 2: Walk the spec checklist**

From `docs/superpowers/specs/2026-04-19-dynamic-resolution-design.md` §Verification:

1. Launch — window opens at 1376×768, plays normally.
2. Drag-resize smaller and larger — rendering scales, 16:9 aspect preserved with bars on the opposite axis.
3. F11 — fullscreen on current monitor; image scaled to fit.
4. F11 again — returns to windowed at previous size.
5. Pixel art sharp at 1×, 1.5×, 2× scales.
6. Split-screen divider stays centered; halves equal width at all window sizes.
7. Room transitions, dialogue box, HUD fade overlays, and game-over overlay behave correctly (enter room 2 → trigger a dialogue → die on purpose to confirm the fade and game-over still render correctly inside the scaled viewport).

If any check fails, stop and diagnose — do not commit partial fixes.

- [ ] **Step 3: No commit**

Task 3 is verification only. If everything passes, the feature is done. If anything fails, open a follow-up by editing the relevant prior task rather than patching on top.
