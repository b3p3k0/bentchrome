# CLAUDE.md

This file guides Claude Code (claude.ai/code) when working in this repository.

## Project Overview

**Bent Chrome** is a top-down vehicular combat game built in Godot 4.7. As of June 2026 it is a clean-slate rebuild: an earlier prototype was retired to `legacy/` (reference only, excluded from the engine by `legacy/.gdignore`). The design, art, and data carried over — the code did not.

### Key design elements
- Top-down view with fake depth (drop-shadows + height for ramps/pits/jumps); 16-bit grimy dystopian style.
- Arcade driving with inertia, drift, and surface-based handling; each vehicle feels distinct (motorcycle vs land-yacht).
- Vehicles rendered as **directional sprites** — a real per-angle view (16 frames), not one sprite rotated.
- Weapons: a **machine gun** (infinite, car-relative, low chip damage; **overheats** — sustained fire locks it until it cools) plus a **selectable secondary** slot (`WeaponRack`: special / fire missile / homing missile / power missile; cycle Q/E/wheel, fire LMB, MG on RMB; auto-cycles off a dry slot). Specials **recharge** to a per-car cap (authored in `roster.json`); missiles are **pickup-fed** (arena ammo crates: M/H/P). Missile trio: fire = medium damage + moderate homing, homing = light damage + aggressive homing, power = heavy damage dead straight. Everything launches forward from the nose; guidance (homing) and cover-piercing are per-weapon data. **All nine signature specials are live** — PROJECTILE ones are pure data, BEAM (Taser) / DASH (Leap) / TRIGGER (Toe Jam) / FLAME (Blunt Blaze) have handlers in `SpecialController`; behavior table in `docs/specials_backlog.md`.
- **Free-for-all:** every vehicle (player and all AI) can damage every other — no teams. The only immunity is a shooter to its own fire; AI may engage any combatant. AI runs the player's full loadout at 3× mount cooldown (`WeaponMount.cooldown_scale`), line-of-sight gated. **Balance intent: AI brawls are theater, kills belong to the player** — AI-on-AI damage runs at 0.35× and a fellow AI under 10% HP is *immune* to AI damage entirely (`Vehicle.combat_scale`); targeting is unrestricted, so the shooting never stops — it just can't finish. The player deals/receives full damage and carries a small targeting-priority bonus. Knobs: `AI_VS_AI_DAMAGE`, `AI_MERCY_HP` (vehicle.gd), `PLAYER_PRIORITY` (enemy_driver.gd).
- AI archetypes: **aggressor** (charges the nearest, fights to near-death), **ambusher** (flanks, hit-and-run), **opportunist** (stalks the weakest car, pounces, flees early) — expressed as a **blendable weight mix** `Vector3(aggressor, ambusher, opportunist)`, so pure types and any hybrid (e.g. brawler-jackal) share one system; traits (range, flee, flank, target scoring) interpolate. Plus tougher **mini-boss/boss** variants. Not a passive "defender." Drivers carry **obstacle feelers** (raycasts vs walls/blocks — never cars; ramming is gameplay) and an **unstick reverse-out** when pinned; all AI tuning lives in `enemy_driver.gd`'s `PURE` table. (`assets/data/ai_profiles.json` is an aspirational design spec, not yet consumed by code.)
- **AI is perpetual-motion** (test-locked by `tests/test_no_camping.gd`): empty scan → HUNT the nearest combatant anywhere (parking is never a strategy); close spacing → a committed **BREAK** arc (drive-by pass), not a retreat; long approaches weave on a per-driver phase; damage records `last_attacker` for **revenge targeting** (+0.5 score); dry hunters **scavenge** the nearest crate; AI burns its own boost tank to close gaps and flee. **RELENT** (player-only pressure relief): 6s of in-range LoS engagement or 30 player HP lost while engaged → 3.5s no-fire disengage arc (`ENGAGE_LIMIT`/`RELENT_DAMAGE`/`RELENT_TIME` knobs).
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
- **Physics:** CharacterBody2D arcade driving with velocity decomposition + lateral-friction grip; per-vehicle feel comes from data, not forks. A per-car **mass** stat (1–10, roster.json) shapes launch, coast, and braking (heavy = slow launch, long coast, soft brakes); `LCTRL` handbrake cuts lateral grip for drift. Feel bands are test-locked in `tests/test_driving_controller.gd`; history + current model in `VEHICLE_PHYSICS_PROGRESSION.md` (Phase 4 = the rebuild).
- **Rendering:** 2D sprites, GL Compatibility, nearest-neighbor filter; fake depth via a separate shadow sprite + height offset + per-level Y-sort.
- **Screen layout:** fullscreen on a 1280×720 base viewport — a centered **720×720 play square** with opaque 280px gutters (`ui/hud.gd`): left = dash (HP/speed/MG heat/boost/weapon slots/keyguide), right = full-arena north-up minimap (`ui/radar.gd` — geometry duck-typed off collision layers; enemy blips range-limited to 1500px) + opponent roster with health bars. ESC pause menu in `ui/pause_menu.gd`; win/lose end screen in `ui/end_screen.gd`.
- **Collision layers** (named in project.godot): 1 = ground (vehicles, dummies), 2 = wall (arena boundary), 3 = obstacle (blocks/cover — airborne cars and `pierces_cover` projectiles ignore it), 8 = terrain zones (road/grass/dirt/ice/water multipliers in `driving_controller.gd`).
- **Destructibles:** any body with a `Health` child takes weapon fire and speed-scaled ram damage; `environment/destructible_block.gd` is the reusable obstacle flavor (layer 3, exported size/HP).
- **Performance:** 60 FPS locked on mid-range GPUs.
- **Packaging:** AppImage for Linux.

## Code standards

- **File size:** ≤1200 lines excellent; 1700 is a hard stop — pause and modularize. Shared logic lives once; never duplicate player/AI or weapon logic.
- **Idiomatic Godot 4:** typed `Resource` classes, `class_name`, and composition are expected. (The retired build banned `class_name` to cope with a tangled codebase; that ban is dropped — a clean dependency graph plus the CI parse gate is the real protection.)
- **Validate InputMap actions on boot** — carried-forward safety against missing-action regressions.
- **After any script change, run the smoke gate:** `tools/smoke.sh` (headless import + boot; fails on parse errors, failed loads, or missing autoloads) **and the unit tests:** `tools/test.sh` (headless suites in `tests/`, driven by `tests/run_tests.gd`). CI runs both on push/PR via `.github/workflows/smoke.yml`.

## Level progression

**Shipped campaign** (`SceneFlow.CAMPAIGN`, all hand-authored scenes sharing `levels/combat_level.gd` — lives loop, enemy re-roll, menus): size classes small/med/large = 1-3 / 4-6 / 6-8 enemies and 1 / 1-2 / 2-3 health stations.

1. **Downtown** (MED, 4 enemies, 1 station) — the city arena: park, secrets, courtyard.
2. **Freeway Loop** (LARGE 2176×5376, 6 enemies, 3 stations) — NS ring road, infield crossover, low-HP guardrails, overpass ramps.
3. **Suburbs** (MED, 6 enemies, 2 stations) — smashable houses on grass blocks, school/gas-station anchors, lakeside east edge.
4. **Snowy Pass** (MED, 6 enemies, 1 station) — snow/ice switchbacks and **pit drop-offs** (`environment/pit_zone.gd`: grounded cars fall; ramp jumps clear them).

Interstitial (`ui/interstitial.gd`, stub visuals) between levels; player has **3 lives** per campaign (respawn at start with 2s shield; full-wipe restart). Design targets beyond these (Junkyard mini-boss, Central Park boss) remain future levels.

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
