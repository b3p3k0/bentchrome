# Shooting Gallery Task Cards

Cards are strict review boundaries. RA accepts one before DA starts the next. Plan: `docs/shooting_gallery_plan.md`.

Rules for every card:

- Edit only the files the card names. If the card cannot pass its own acceptance without touching another file, STOP and report the measurement or contradiction in the handoff instead of widening scope.
- Nothing else may be removed. List every removed node, function, or line of behavior in the handoff.
- Match the style of the file you are in. Tunables are `static var`, never `const` containers. Type every `:=` whose right side is untyped or Variant. Projectile-side scripts never name `Vehicle`.
- Checks are run bare: `tools/smoke.sh`, then `tools/test.sh`, then `git diff --check`. Report the exact command and its actual output. A sandbox that blocks sockets will fail the `tests/test_net_*` suites; say so rather than hiding it.
- Handoff format: Completed / Files changed (path — why) / Checks run (command — result) / Not tested / Risks / Next.

## Card G-0 — Planning packet

Status: this commit.

Goal: put the plan and these cards in the repo before implementation.

Files: `docs/shooting_gallery_plan.md`, `docs/shooting_gallery_cards.md`.

## Card G-1 — Shared target pieces

Status: accepted (RA full pass; smoke PASS, tests PASS 17014 checks).

Goal: make dummies respawnable, share the HP label, give the lap driver a per-instance throttle, and make the exit prompt reusable, with zero behavior change for every existing caller.

Files it may edit:

- `environment/hp_label.gd` — NEW. `extends Label`. `bind(health: Node)` connects `damaged` and refreshes; `refresh()` writes `"%d" % roundi(hp)`; `static func attach(parent: Node, health: Node, y: float) -> Label` instantiates, positions above the parent (centered, `offset_top = y`), binds, adds as child, returns it. Preload by path everywhere; no `class_name` needed.
- `environment/target_dummy.gd` — add `@export var respawn_seconds := 0.0`. With 0 keep today's `died → queue_free`. With > 0: on death hide the body, `Col.set_deferred("disabled", true)`, `remove_from_group(&"dummies")`, then after `respawn_seconds` (scene-tree timer, guard `is_inside_tree()`) write `_health.hp = _health.max_hp`, re-enable `Col`, show, re-add to `dummies`, refresh the label. Drop the local `_on_changed/_refresh` in favor of the shared label.
- `environment/target_dummy.tscn` — the existing `Label` node takes `hp_label.gd`.
- `vehicles/goliath/victory_lap_driver.gd` — add `var throttle := -1.0` (per instance; negative means use `LAP_THROTTLE`). `get_intent` reports `throttle` when it is ≥ 0, else `LAP_THROTTLE`. Do not change the static.
- `levels/tutorial/exit_confirm.gd` — `const PROMPT` becomes `var prompt := "LEAVE DRIVER'S ED?"`; `_build_ui` reads it. Nothing else changes.
- `tests/test_gallery_level.gd` — NEW suite (`extends RefCounted`, `var t`, `_init(runner)`), first tests below.
- `tests/run_tests.gd` — preload the new suite immediately before `test_stat_rebase.gd` (which stays last).

Acceptance:

- A `target_dummy` with `respawn_seconds = 0` is freed on death (instantiate under `t.root`, `Health.kill()`, pump frames, `is_instance_valid` false).
- With `respawn_seconds = 0.2`: after death it is hidden, its `Col.disabled` is true, and it is out of `dummies`; after the delay it is visible, `hp == max_hp`, back in `dummies`, and the label reads `max_hp`.
- `victory_lap_driver` with `throttle = 0.45` reports 0.45 in `get_intent` on a fixture with a loop; an untouched instance still reports `LAP_THROTTLE` (`tests/test_goliath_driver.gd` stays green).
- `exit_confirm` default caption is `"LEAVE DRIVER'S ED?"`; setting `prompt = "X"` before `add_child` shows X. Tests unpause the tree in teardown (`tests/test_tutorial_director.gd` idiom).
- `hp_label.attach` on a Node2D with a Health child creates one Label reading the current hp and updates it after `take_damage`.

Checks:

```sh
tools/smoke.sh
tools/test.sh
git diff --check
```

## Card G-2 — Gallery nodes

Status: accepted (RA full pass after one revision: parked facing moved from lane rotation to a `facing_deg` export; smoke PASS, tests PASS 17087 checks).

Goal: the target car scene, the lane spawner/respawner, the prop reset helper, and the range-tick paint, unit-locked in tree-entered fixtures.

Files it may edit:

- `vehicles/target_vehicle.tscn` — NEW inherited scene from `vehicles/vehicle.tscn` (copy the shape of `vehicles/enemy_vehicle.tscn`): `faction = &"targets"`, `Driver` script = `res://vehicles/goliath/victory_lap_driver.gd`, `Camera2D.enabled = false`. Do not set stats here.
- `levels/gallery/target_lane.gd` — NEW, `extends Node2D`. Exports: `car_id: StringName`, `throttle := 0.6`, `respawn_seconds := 3.0`, `label_y := -70.0`, `facing_deg := 0.0` (parked nose direction; lanes are ALWAYS authored unrotated — a rotated lane would put a rotated transform under the Vehicle root, which vehicle.gd never expects; `_ready` push_warns on a rotated lane). On `_ready`: collect Marker2D children into a `PackedVector2Array` of GLOBAL positions, then `_spawn()`. `_spawn()`: instantiate `target_vehicle.tscn`, set `stats = load("res://data/vehicles/%s.tres" % car_id)` (push_error and return if the file does not exist), set `driver.throttle`, `driver.set_loop(points)` when there are ≥ 2 markers, position at marker[0] facing marker[1] (set `rotation` before add so `heading` adopts it) or at the lane's own position/rotation when parked, `add_child` (the car is the lane's child, never the level's), attach the HP label via `hp_label.attach`, connect `Health.died` → `_on_target_died`. `_on_target_died`: scene-tree timer `respawn_seconds`, then `_spawn()` if `is_inside_tree()`. `_draw`: when ≥ 2 markers, paint the loop as a dashed closed polyline (`draw_dashed_line`, local coords) so the authored markers are the single source of coordinates. Provide `func target() -> Node` returning the live car or null.
- `levels/gallery/target_reset.gd` — NEW, `extends Node`. Exports `watch_group := &"gallery_reset"`, `delay := 6.0`. On `_ready` (deferred one frame so siblings exist): for every group member with `has_method(&"apply_arena_state")` and a `Health` child, connect `died` → timer `delay` → `apply_arena_state({"flags": 1, "hp": 1.0}, false)` if the prop is still valid and this node is inside the tree. Never touches props outside the group.
- `levels/gallery/gallery_deco.gd` — NEW paint-only `extends Node2D` in the `levels/tutorial/tutorial_deco.gd` idiom: `@export var kind: StringName = &"range_tick"`, `@export var size := Vector2(896, 8)`, `@export var text := ""`. `range_tick` draws a thin pale bar across `size.x` and the `text` at the left margin. Enumerate kinds in a `match`; push_error on an unknown kind.
- `tests/test_gallery_level.gd` — tests below.

Acceptance:

- `target_vehicle.tscn` instance: `faction == &"targets"`, Driver script resource path ends in `victory_lap_driver.gd`, `Camera2D.enabled == false`.
- Parked lane fixture (`car_id = &"ghost"`, no markers) under `t.root`: exactly one Vehicle child whose parent is the lane, in `targets` and `vehicles`, not in `enemies`, `stats.id == &"ghost"`, has a Label child reading its max hp, `get_intent` throttle 0. `Health.kill()` → after `respawn_seconds = 0.05` and frame pumps, a NEW valid Vehicle child exists.
- Loop lane fixture (≥ 3 markers, `throttle = 0.9`): the car spawns at marker[0]'s global position and its driver reports throttle 0.9.
- `target_reset` fixture: a crate `destructible_block` and a `derelict_car` in `gallery_reset` with `delay = 0.05`; `Health.kill()` each → after the delay `collision_layer != 0` and `capture_arena_state().flags & 1 != 0`.
- Fixtures release the tree unpaused and free every node.

Checks:

```sh
tools/smoke.sh
tools/test.sh
git diff --check
```

## Card G-3 — Scene and level shell

Status: accepted (RA full pass after one revision: wreck row moved into the [488, 600] alley clear of LaneSlow; a 40 s headless lap probe left every wreck and barrel at full HP; smoke PASS, tests PASS 17162 checks). Playtest note: LaneFast\'s bike skims Barrel1 at ~111 px center-to-center without contact; if the chain ever pops on its own, nudge the trio east by 80 px.

Goal: the flat yard and its script, structural tests, lint-list update, and capture for Kevin's veto pass.

Files it may edit:

- `levels/gallery/shooting_gallery.tscn` — NEW. Node tree per the plan's "Yard layout" table. Copy the Boundary (layer 2, Vis + Col pairs incl. NorthW/NorthE/JambW/JambE/Cap), `Asphalt`, `TunnelFloor`, and `GridFloor` nodes from `levels/tutorial/drivers_ed.tscn` with the same 2816 extents; no FloorZone; no ExitGate. Player `Vehicle` at (0, 1000) facing north, last two children `Vehicle` then `HUD` (combat_level idiom). Props in group `gallery_reset` as listed. Lanes carry their Marker2D children and are authored with `rotation = 0`; `LaneParkE` uses `facing_deg = 180`, `LaneParkW` the default 0.
- `levels/gallery/shooting_gallery.gd` — NEW, `extends "res://levels/combat_level.gd"`. `_ready`: `super()`; pin `suppress_group_win` on the end-screen CanvasLayer (drivers_ed idiom); `_player.get_node(^"Health").god = true`; `var rack := _player.get_rack(); rack.god = true; rack.arm_all_once()`; connect `ExitZone.body_entered` → if body in group `player` and no confirm open: instance `exit_confirm.gd` with `prompt = "LEAVE THE GALLERY?"`, `confirmed` → `get_tree().paused = false; SceneFlow.to_title()` (autoload by path), `cancelled` → unpause and free the confirm. Keep under ~70 lines.
- `tests/test_gallery_level.gd` — structural tests below.
- `tests/test_spawn_distance.gd` — append the scene path to `CAMPAIGN` with a `# zero enemies — instantiate coverage` comment, like drivers_ed.

Acceptance (instantiate without entering the tree, then `free()`):

- `Vehicle` and `HUD` exist; zero children named `Enemy*`; root script chain reaches `res://levels/combat_level.gd`; no node with `floor_index` export AND a FloorZone script anywhere (no FloorZone in the scene); `Boundary.collision_layer == 2` with the named segments; `ExitZone` present, `ExitGate` absent; no node named `GoliathLoop`.
- ≥ 4 `target_dummy` instances, every one `respawn_seconds > 0`.
- Each `Tick*` node's `text` equals `str(roundi(abs(tick.position.y - 700)))` (distance from the firing line at y = 700).
- Exactly 4 `target_lane` nodes with distinct `car_id`s whose `.tres` files exist: 2 with ≥ 6 Marker2D children, 2 with none; every `throttle` in (0, 1].
- ≥ 3 barrel blocks and ≥ 3 derelicts in `gallery_reset`; every `destructible_block` in the scene has a non-empty `deco`.
- `tests/test_spawn_distance.gd` and `tests/test_floor_props.gd` sweeps include the scene and pass (flat, so the floor lint skips it).
- Captures for review: `tools/shot.sh levels/gallery/shooting_gallery.tscn <out>/gallery.png` and `--center=0,-700 --zoom=1.2`.

Checks:

```sh
tools/smoke.sh
tools/test.sh
git diff --check
tools/shot.sh levels/gallery/shooting_gallery.tscn /tmp/gallery.png
```

## Card G-4 — Flow plumbing

Status: accepted (RA full pass; smoke PASS, tests PASS 17176 checks; a headless flow probe drove mode_select → car_select confirm → the yard with the player godded).

Goal: the mode, the route, the music row, and the dialog option.

Files it may edit:

- `ui/mode_select.gd` — `SUB_OPTIONS` gains `"SHOOTING GALLERY"` at index 2 (BACK moves to 3, `SUB_BACK_INDEX = 3`); `SUB_MODES` gains `&"gallery"`; `_commit_sub_choice` pins `Difficulty.tier = Difficulty.Tier.HARD` when the chosen mode is `&"gallery"` (no other row changes tier). Update the dialog's header comment.
- `ui/car_select.gd` — confirm: `elif GameState.game_mode == &"gallery": SceneFlow.to_gallery(); return` before the existing tutorial fallthrough. ESC handler unchanged.
- `game/scene_flow.gd` — `const GALLERY := "res://levels/gallery/shooting_gallery.tscn"` beside `TUTORIAL`; `func to_gallery()` beside `to_tutorial()`. Not in `CAMPAIGN`.
- `game/music_director.gd` — `TRACKS[GALLERY path] = &"bgm_menu"`.
- `tests/test_mode_select.gd` — `test_sub_choice_stamps_game_mode` adds: `_sub_index = 2; _commit_sub_choice()` → `game_mode == &"gallery"` and `Difficulty.tier == HARD`; restore both `game_mode` and `tier` afterwards. Existing index 0/1 assertions stay.
- `tests/test_music_director.gd` — append `flow.GALLERY` to the explicit flow-constant list.
- `tests/test_stickers.gd` — add `&"gallery"` to the non-earning mode loop.
- `tests/test_gallery_level.gd` — `SceneFlow.GALLERY == SCENE` and the scene is absent from `CAMPAIGN` (via `get_script_constant_map`, test_tutorial_level idiom); `SUB_OPTIONS.size() == 4`.

Acceptance:

- All of the above assertions pass; every existing `test_mode_select` nav test stays green without index edits (they read `SUB_BACK_INDEX`).
- Manual: Title → SINGLE PLAYER → DRIVER'S ED → SHOOTING GALLERY → car select → the yard; ESC on car select returns to mode select.

Checks:

```sh
tools/smoke.sh
tools/test.sh
git diff --check
```

## Card G-5 — Docs closeout

Status: pending.

Goal: agent-facing and player-facing docs match the runtime.

Files it may edit:

- `CLAUDE.md` — a **Shooting Gallery** paragraph directly after the Driver's Ed paragraph (scene path, outside CAMPAIGN, god hull + god rack, real bay lock and overheat, HARD pin, target cars in `targets`, lanes own their cars, dummies/props come back, exit prompt, F2 as the companion); extend the mode-select sentence with the third sign-up option.
- `README.md` — "Pick Your Lane": a Shooting Gallery sentence under the DRIVER'S ED bullet.
- `docs/matrices.md` — new `## Shooting Gallery (knobs)` section between Driver's Ed and Route 666, in the Driver's Ed format: Sources paragraph + `| Knob | Value | Where | Detail |` rows for dummy `respawn_seconds` 3, lane `respawn_seconds` 3, `TargetReset.delay` 6, lane throttles 0.45 / 0.9 against `LAP_THROTTLE` 0.8, `LAP_ARRIVE` 260, god flags, HARD pin, prompt string; then a "Yard fixtures:" paragraph with the coordinates.

Acceptance:

- Every number in the docs is grep-able in the scene or scripts.
- `git diff --check` clean. Then Kevin's playtest per the plan's Validation section.

Checks:

```sh
tools/smoke.sh
tools/test.sh
git diff --check
```
