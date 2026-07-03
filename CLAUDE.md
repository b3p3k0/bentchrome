# CLAUDE.md

This file guides Claude Code (claude.ai/code) when working in this repository.

## Project Overview

**Bent Chrome** is a top-down vehicular combat game built in Godot 4.7. As of June 2026 it is a clean-slate rebuild: an earlier prototype was retired to `legacy/` (reference only, excluded from the engine by `legacy/.gdignore`). The design, art, and data carried over — the code did not.

### Key design elements
- Top-down view with fake depth (drop-shadows + height for ramps/pits/jumps); 16-bit grimy dystopian style.
- Arcade driving with inertia, drift, and surface-based handling; each vehicle feels distinct (motorcycle vs land-yacht).
- Vehicles rendered as **directional sprites** — a real per-angle view (16 frames), not one sprite rotated.
- Weapons: a **machine gun** (infinite, car-relative, low chip damage; **overheats** — sustained fire locks it until it cools) plus a **selectable secondary** slot (`WeaponRack`: special / standard missile / homing missile; cycle Q/E/wheel, fire LMB, MG on RMB). Specials **recharge** to a per-car cap (authored in `roster.json`); missiles are **pickup-fed** (arena ammo crates). Everything launches forward from the nose; guidance (homing) and cover-piercing are per-weapon data. **All nine signature specials are live** — PROJECTILE ones are pure data, BEAM (Taser) / DASH (Leap) / TRIGGER (Toe Jam) have handlers in `SpecialController`; behavior table in `docs/specials_backlog.md`.
- **Free-for-all:** every vehicle (player and all AI) can damage every other — no teams. The only immunity is a shooter to its own fire; AI may engage any combatant.
- AI archetypes: **aggressor** (charges the nearest, fights to near-death), **ambusher** (flanks, hit-and-run), **opportunist** (stalks the weakest car, pounces, flees early) — expressed as a **blendable weight mix** `Vector3(aggressor, ambusher, opportunist)`, so pure types and any hybrid (e.g. brawler-jackal) share one system; traits (range, flee, flank, target scoring) interpolate. Plus tougher **mini-boss/boss** variants. Not a passive "defender." Drivers carry **obstacle feelers** (raycasts vs walls/blocks — never cars; ramming is gameplay) and an **unstick reverse-out** when pinned; all AI tuning lives in `enemy_driver.gd`'s `PURE` table. (`assets/data/ai_profiles.json` is an aspirational design spec, not yet consumed by code.)
- Environmental destruction, verticality (ramps/pits), scavenging.
- Six progressive levels, tutorial arena through final boss.

## Development environment

- **Godot 4.7** standard build. A binary is installed at `~/.local/bin/godot` but may not be on `PATH`. Tooling resolves the engine via `GODOT_BIN`, then `PATH`, then `~/.local/bin/godot`.
- **Python 3.10+**, **git**, **rg** (ripgrep). `./RUNME.sh` checks for these.

## Repository layout

- `game/` — autoload services: `GameState`, `SceneFlow`, `Spawner`, `InputRouter`, `AudioDirector`.
- `vehicles/` — the single `Vehicle` scene/script + `DrivingController`, directional sprite, depth, and `drivers/` (player + AI).
- `weapons/` — `WeaponMount`, pooled `Projectile`, and `guidance/` strategies.
- `ai/` — `AIDriver` behaviors, archetypes, targeting.
- `levels/`, `environment/`, `ui/` — scenes grouped by area. `levels/` also holds the custom-level stack: `LevelSchema` (fan-level JSON format), `EntityCatalog` (placeable whitelist), `LevelLoader`, and `custom_level.tscn` (runtime host; `-- --level=<path>` debug launch).
- `editor/` — the standalone level editor (`tools/editor.sh`, or the `level_editor` feature tag in exports). Game export presets must exclude `editor/*`. Docs: `docs/level_editor.md`, `docs/level_format.md`.
- `resources/` — typed `Resource` class scripts (schemas: `VehicleStats`, `WeaponDef`, …).
- `data/` — content instances (`.tres`) + `source_json/` authoring source.
- `assets/`, `shaders/`, `tests/`, `tools/`.
- `legacy/` — the retired prototype. Reference only; never import from it or wire new code to it.

## Architecture

- **One vehicle, two drivers.** A single `Vehicle` (CharacterBody2D) owns all physics, health, and weapons. A `Driver` supplies intent; `PlayerDriver` reads input, `AIDriver` runs a behavior FSM. Physics lives exactly once — player and AI never duplicate it. (The retired build's two ~1,700-line vehicle monoliths are the mistake this prevents.)
- **Data-driven content.** Vehicles, weapons, and AI profiles are typed `Resource` files; adding a car or weapon is a `.tres`, not code.
- **Physics:** CharacterBody2D arcade driving with velocity decomposition + lateral-friction grip; per-vehicle feel comes from data, not forks. Tuning history in `VEHICLE_PHYSICS_PROGRESSION.md`.
- **Rendering:** 2D sprites, GL Compatibility, nearest-neighbor filter; fake depth via a separate shadow sprite + height offset + per-level Y-sort.
- **Screen layout:** fullscreen on a 1280×720 base viewport — a centered **720×720 play square** with opaque 280px gutters (`ui/hud.gd`): left = dash (HP/speed/MG heat/weapon slots/keyguide), right = rotating player-up radar (`ui/radar.gd`). ESC pause menu in `ui/pause_menu.gd`.
- **Collision layers** (named in project.godot): 1 = ground (vehicles, dummies), 2 = wall (arena boundary), 3 = obstacle (blocks/cover — airborne cars and `pierces_cover` projectiles ignore it), 8 = terrain zones.
- **Performance:** 60 FPS locked on mid-range GPUs.
- **Packaging:** AppImage for Linux.

## Code standards

- **File size:** ≤1200 lines excellent; 1700 is a hard stop — pause and modularize. Shared logic lives once; never duplicate player/AI or weapon logic.
- **Idiomatic Godot 4:** typed `Resource` classes, `class_name`, and composition are expected. (The retired build banned `class_name` to cope with a tangled codebase; that ban is dropped — a clean dependency graph plus the CI parse gate is the real protection.)
- **Validate InputMap actions on boot** — carried-forward safety against missing-action regressions.
- **After any script change, run the smoke gate:** `tools/smoke.sh` (headless import + boot; fails on parse errors, failed loads, or missing autoloads) **and the unit tests:** `tools/test.sh` (headless suites in `tests/`, driven by `tests/run_tests.gd`). CI runs both on push/PR via `.github/workflows/smoke.yml`.

## Level progression

1. **Arena (Small)** — tutorial, 1 enemy.
2. **Freeway (Medium)** — 3 enemies, multi-tiered interchanges.
3. **Suburbs (Medium)** — 5 enemies, flat destructible terrain.
4. **Junkyard (Small+)** — mini-boss, debris hazards.
5. **Downtown (Large)** — 7 enemies, landmark-rich city.
6. **Central Park (Boss)** — final boss, continues Downtown topology.

## Design references

- `docs/requirements.md` — condensed technical requirements and system checklist.
- `assets/data/roster.json` — the 9 vehicles: stats (1–10 scale), lore, special weapons. Authoring source for `VehicleStats`.
- `assets/data/ai_profiles.json` — per-vehicle AI tuning. Authoring source for AI archetypes/profiles.
- `VEHICLE_PHYSICS_PROGRESSION.md` — physics tuning history from the prototype; the starting point for driving feel.
- `README.md` — player-facing lore and controls.

## Development workflow

1. Work narrow and deep: one drivable system at a time, vertical-slice first (driving feel before breadth).
2. Keep changes scoped; match the existing style of the file you edit.
3. Hold the 16-bit dystopian aesthetic and per-vehicle distinctiveness while keeping top-down combat readable.
4. Run `tools/smoke.sh` after script changes; keep files under the size ceiling.
