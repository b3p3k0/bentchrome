This repository: Bent Chrome — a Godot 4 (GDScript) top-down vehicular combat game.

Keep the guidance below short, concrete, and focused on patterns discoverable in the codebase.

Key facts

- Engine & language: Godot 4 (GDScript). Project entry is configured in `project.godot` (main scene: `res://scenes/ui/SplashScreen.tscn`).
- Core singletons (autoloads): `scripts/managers/game_manager.gd`, `scripts/managers/selection_state.gd`, `scripts/ai/ai_profile_loader.gd`, `scripts/ai/ai_debug_commands.gd` — these provide the central APIs for spawning, roster selection, and AI profiles.
- Data sources: `assets/data/ai_profiles.json`, `assets/data/roster.json` — JSON files drive AI and roster configurations; code performs comment-stripping and merges defaults.

Architecture notes for agents (big-picture)

- Scenes: UI lives under `scenes/ui/` (SplashScreen, PlayerSelect, HUD). Gameplay scenes and vehicles live under `scenes/vehicles/` and `scenes/environment/`.
- GameManager is the single source of truth for runtime dynamic objects (bullets, pickups, enemies, effects). Use GameManager.spawn\_\* helpers to create in-game objects so they are tracked and cleaned up correctly.
- AIProfileLoader holds profile defaults and merges per-roster configs. Many AI decisions expect profiles to be present; fallback/emergency defaults are implemented when JSON parsing fails.
- SelectionState persists player roster choice and exposes helpers for preparing opponents. Update this singleton when changing player selection flows.

Developer workflows & commands

- Quick dev-run: open the project in Godot 4 or run `godot4 --path .` from the repo root (RUNME.sh also detects required tools).
- Environment check: `./RUNME.sh` prints which tools are available and checks for Godot 4, Python3 and ripgrep.
- Tests: there are no automated unit tests in the repo. For runtime checks, run the project and use `AIDebug` (autoload `scripts/ai/ai_debug_commands.gd`) to exercise profile loading and spawning (`debug_validate_profiles()`, `debug_test_spawn()`).

Project-specific conventions and patterns

- Roster/JSON parsing: files may contain comment lines; `selection_state.gd` strips lines starting with `//` before JSON.parse. When editing data files, follow the same comment style.
- Resource paths: portrait and asset paths typically use `res://assets/...`. Validate resource existence with `ResourceLoader.exists()` when adding new assets.
- Spawn & placement: always use `GameManager.get_game_root()` or `GameManager.register_scene_root()` before adding runtime nodes. Directly adding to the scene tree bypasses tracking and cleanup.
- Profile merging: `AIProfileLoader.get_profile(id)` returns merged profile with defaults — do not assume raw JSON shape; use getters and defaults.

Integration points & external dependencies

- External runtime: Godot 4 standard binary required (project uses features around 4.x rendering). Some contributors may use Flatpak (`flatpak run org.godotengine.Godot`).
- Tools: Python 3.10+ is used for auxiliary scripts; ripgrep (`rg`) is used in tooling and prompts.

When creating PRs or implementing features

- Keep changes scoped: modify one system at a time (AI, spawning, UI) and document decisions in `prompts/YYYY-MM-DD-*.md` under `prompts/` (project convention for tracking prompts/decisions).
- Prefer using existing autoload singletons to interact with game state (GameManager, SelectionState, AIProfileLoader). Update or add autoloads in `project.godot` if new global services are required.
- Add small play-mode validation: e.g., call `AIDebug.debug_test_spawn("bumper")` or `AIProfileLoader.load_profiles(...)` to verify runtime behavior.

Examples (copy/paste friendly)

- Spawn enemy by roster id via GameManager:
  var scene = load("res://scenes/vehicles/EnemyCar.tscn")
  GameManager.spawn_enemy(scene, Vector2(100,100), "bumper")
- Load and inspect an AI profile:
  var p = AIProfileLoader.get_profile("bumper")
  print(p.get("archetype"))

Notes and gotchas

- Many scripts assume autoload singletons are available at runtime. Unit tests are not present; run scenes in the editor to validate.
- JSON parse errors are handled by fallbacks but will log warnings — inspect console output for missing resources or malformed data.
- Some UI scripts referenced under `scripts/singletons/ui/` are thin or missing — when editing UI, open the matching `scenes/ui/*.tscn` to verify node paths and connections.

If anything in this file is unclear or you need deeper detail about a subsystem, ask and include which scene or script you plan to modify.
