# Splash Screen Implementation - 2025-10-27

## Prompt

Claude, I need you to stand up the new game splash screen for Bent Chrome (Godot 4.2 project). This repo already boots directly into res://scenes/ui/PlayerSelect.tscn and that scene still transitions into res://scenes/main/Main.tscn after a driver is chosen; do not break any of that logic.

Goal
Introduce an initial splash/menu scene that shows assets/img/story/splashscreen.png, overlays a minimal menu in the bottom‑center cell of a 3×3 grid (cell index 7, counting left→right, top→bottom, zero-based), and on "Start 1P" press moves the player into the existing character selection screen.

Required changes
New scene + script

Create res://scenes/ui/SplashScreen.tscn (root Control) with script res://scripts/ui/splash_screen.gd.
Layout:
Fullscreen TextureRect using res://assets/img/story/splashscreen.png, stretch_mode = STRETCH_SCALE, expand = true.
Optional semi-transparent ColorRect overlay so UI text stays readable.
A GridContainer (3 columns) sized to the full viewport that acts as the 3×3 subdivider. Populate it with 9 placeholder Control nodes that expand to fill their cells.
Child index 7 (bottom-middle cell) should contain a VBoxContainer or MarginContainer hosting:
Label text like "Welcome to Bent Chrome".
A single Button labeled "Start 1P" (focusable, big enough for controller navigation). Style it with the existing dark/neon palette (e.g., dark background, cyan border) for consistency.
A helper Label describing inputs (e.g., "Enter / Space / A to start").
Script behavior:
On _ready, grab focus for the "Start 1P" button.
When the button is pressed (or ui_accept is triggered), guard against double fires and call get_tree().change_scene_to_file("res://scenes/ui/PlayerSelect.tscn").
Expose a start_game() method to keep button signal clean.
Wire it into the build

Update project.godot so [application] run/main_scene points to res://scenes/ui/SplashScreen.tscn.
Keep every other config entry untouched; don't rename existing scenes or signals.
Docs / logging

Add a prompt log entry prompts/2025-10-27-splash-screen.md (follow the folder's conventions: prompt, Claude plan, follow-ups).
Optional but nice: drop a single sentence in README.md's "Getting Started" section mentioning that the game now boots into the splash screen before character select.
Acceptance criteria
Game launch path: SplashScreen → (press Start 1P via mouse, Enter, Space, or controller south button) → PlayerSelect (existing behavior) → Main scene after choosing a driver.
Splash background uses the provided PNG at native aspect; UI overlay respects the 3×3 grid layout with the menu clearly in section 7.
"Start 1P" is highlighted/focus-ready on load and accessible via keyboard/controller/mouse.
No regressions to SelectionState, PlayerSelect navigation, or existing inputs.
No new warnings/errors in the Godot output when moving through the new flow.
Testing
From repo root: godot4 --path . (or launch via the editor) to confirm the splash shows, the menu button responds to Enter/Space/click/controller A, and selecting a character still loads the arena.
Verify console/log stays clean during scene transitions.
Stick strictly to the scope above—do not refactor unrelated systems.

## Claude Plan

Implemented a complete splash screen system with the following components:

### Scene Structure
- **SplashScreen.tscn**: Control root with fullscreen background and 3×3 grid overlay
- **Background**: TextureRect with STRETCH_KEEP_ASPECT_COVERED to prevent distortion
- **Overlay**: Mandatory ColorRect (Color(0,0,0,0.3)) with MOUSE_FILTER_IGNORE for text readability
- **UIGrid**: GridContainer (3 columns) with 9 Control cells, all using MOUSE_FILTER_IGNORE
- **Cell7**: MarginContainer in bottom-center containing VBoxContainer with welcome text, Start 1P button, and help text

### Script Implementation
- **splash_screen.gd**: Event-based input handling using `event.is_action_pressed("ui_accept")`
- **Focus Management**: Deferred `grab_focus()` call to avoid Godot settling issues
- **Double-fire Protection**: `is_transitioning` flag prevents multiple scene transitions
- **Error Handling**: Proper error checking on `change_scene_to_file()` calls

### Configuration Changes
- **project.godot**: Changed `run/main_scene` from PlayerSelect.tscn to SplashScreen.tscn
- **Preserved**: All InputMap actions, autoloads, and other settings remain unchanged

### Technical Specifications
- Background uses STRETCH_KEEP_ASPECT_COVERED to maintain aspect ratio
- All grid cells configured with MOUSE_FILTER_IGNORE and SIZE_EXPAND_FILL
- Button has FOCUS_ALL mode with proper styling (dark bg, cyan border)
- VBoxContainer centered with proper alignment and separation
- Event-based input handling instead of polling for better event ordering

## Follow-ups

[Any modifications made during implementation will be noted here]