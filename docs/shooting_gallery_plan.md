# Shooting Gallery Plan

Goal: add one standalone, no-enemy weapon-testing range where an invincible, infinite-ammo player shoots static dummies, destructible cover, and non-hostile parked and looping target cars that all come back, with floating HP labels as the only readout. Primary audience: developers tuning weapons (F2 live editor + this yard). Secondary: players getting a feel for a car's loadout.

Approved by Kevin on 2026-10-07. Decisions locked that day: entry through the Driver's Ed sign-up dialog; player invincible with infinite ammo but the real 2 s non-MG bay lock and real MG overheat; HP labels only, no DPS overlay.

## Current state

| Fact | Where |
|---|---|
| Sign-up dialog `SUB_OPTIONS` 3 rows, `SUB_MODES` [tutorial, test_drive], `SUB_BACK_INDEX = 2`; `_commit_sub_choice` stamps `game_mode`; single battle pins `Difficulty.tier = MEDIUM` | `ui/mode_select.gd:28-31, 121-123, 155-156` |
| Car select confirm routes every non-campaign, non-single_battle mode to `to_tutorial()`; ESC already returns to mode select for those modes | `ui/car_select.gd:112-121, 76-81` |
| `TUTORIAL` const + `to_tutorial()`; `MusicDirector.TRACKS` keyed by scene path (drivers_ed → `bgm_menu`); music test hard-lists flow constants | `game/scene_flow.gd:13, 111-112`, `game/music_director.gd:30-56`, `tests/test_music_director.gd:62-65` |
| DEVGOD precedent sets `_health.god`, `_rack.god`, `arm_all_once()` | `vehicles/vehicle.gd:296-304` |
| Non-player vehicles `queue_free()` on death; `vehicle.gd` is 1584 lines (hard stop 1700) | `vehicles/vehicle.gd:1129-1132` |
| Vehicle root rotation is always 0 (heading is separate), so a child Label stays upright | `vehicles/vehicle.gd:288-289` |
| Non-player car with `stats == null` paints blank; runtime spawn sets `stats` + driver props before `add_child` | `vehicles/vehicle.gd:253-254`, `levels/chase/chase_director.gd:122-172` |
| `combat_level` needs a child named `Vehicle`; `face_spawns_inward` runs over DIRECT Vehicle children; lives loop early-returns while hp > 0 | `levels/combat_level.gd:28, 44-49, 84-88, 139-153` |
| Driver's Ed shell = `super()` + pin `suppress_group_win` on the end-screen CanvasLayer | `levels/tutorial/drivers_ed.gd` |
| `Combat.scale`: player → any non-player vehicle = `Difficulty.knob(&"player_damage_dealt")` (1.0 at every tier today) | `game/combat.gd:38-39`, `game/difficulty.gd` |
| HUD roster + end-screen win latch key on group `enemies`; radar paints `dummies` dots and every sensed `vehicles` member; fight director skips drivers lacking `set_focus_assignment` | `ui/hud.gd:128`, `ui/end_screen.gd:85-95`, `ui/radar.gd:66-69`, `ai/fight_director.gd:83-85` |
| `environment/target_dummy.gd/.tscn`: layer-1 StaticBody2D, Health 60, HP Label, group `dummies`, `died → queue_free`; unused by any shipped level | `environment/target_dummy.gd:11`, `levels/entity_catalog.gd:147-155`, `levels/level_loader.gd:151-158` |
| `victory_lap_driver`: `set_loop()`, `static LAP_THROTTLE 0.8 / LAP_ARRIVE 260`, gathers a `GoliathLoop` sibling of the car's parent, else base zero intent (= parked) | `vehicles/goliath/victory_lap_driver.gd:7-9, 19-57` |
| Inherited-scene pattern: faction, Driver script override, Camera2D disabled | `vehicles/enemy_vehicle.tscn` |
| Block revive seam `apply_arena_state({"flags":1,"hp":1.0}, false)` restores layer + plain-slab polygon + emits `restored`; derelict has the same seam and resets its tint; derelict has no `flattened` signal, so key on `Health.died` | `environment/destructible_block.gd:254-271`, `environment/derelict_car.gd:90-103` |
| `exit_confirm.gd` hard-codes `const PROMPT`; `tutorial_deco` kinds tunnel / exit_text / sign / gate / helipad; `road_marks` styles dashed_yellow / dashed_white / crosswalk / stop_line | `levels/tutorial/exit_confirm.gd:14, 92`, `levels/tutorial/tutorial_deco.gd:26-40`, `environment/road_marks.gd:25-33` |
| Level lint lists are hand-kept: `tests/test_spawn_distance.gd` `CAMPAIGN` (drivers_ed included; floor lint only fires on FloorZone scenes); `tests/run_tests.gd` SUITES explicit, `test_stat_rebase.gd` last | `tests/` |
| Stickers earn only in campaign / single_battle; Economy campaign-only | `game/stickers.gd:46-57`, `levels/combat_level.gd:59` |

## Decisions

1. `GameState.game_mode = &"gallery"`. Sign-up row "SHOOTING GALLERY" at index 2, BACK moves to 3. `_commit_sub_choice` pins `Difficulty.tier = HARD` for that row so damage numbers are the ×1.0 truth.
2. `SceneFlow.GALLERY := "res://levels/gallery/shooting_gallery.tscn"` + `to_gallery()`; `TRACKS[GALLERY] = &"bgm_menu"`; `car_select` confirm gains an `== &"gallery"` branch before the tutorial fallthrough. The level stays OUTSIDE `CAMPAIGN` (contract-exempt, like Driver's Ed).
3. `levels/gallery/shooting_gallery.gd` extends `combat_level.gd` by path: `super()`, pin `suppress_group_win`, god the player's Health and rack, `arm_all_once()`, wire `ExitZone` → `exit_confirm` (prompt "LEAVE THE GALLERY?") → unpause + `to_title()`. No `_process` override. Nothing is added to `vehicle.gd`.
4. `vehicles/target_vehicle.tscn` inherits `vehicle.tscn`: `faction = &"targets"`, Driver = `victory_lap_driver.gd`, Camera2D off. Target cars are in `vehicles` (hittable, lockable, radar, StatusReceiver) but never `enemies` (no roster row, no win latch, no re-roll). `victory_lap_driver` gains one instance var `throttle := -1.0` (negative = `LAP_THROTTLE`), leaving the stadium default untouched.
5. `levels/gallery/target_lane.gd` (Node2D): exports `car_id`, `throttle`, `respawn_seconds`; Marker2D children = loop points, painted as a dashed closed loop in `_draw`. Spawns the car as ITS OWN child (so `face_spawns_inward` never sees it): `stats = load(.tres)`, `set_loop`, `driver.throttle`, the car's own `rotation` (loop = toward marker[1], parked = `facing_deg`; lanes are always authored unrotated), then `add_child`; `Health.died` → timer → re-instantiate (guard `is_inside_tree()`). No markers = parked target. Attaches an HP label per spawn.
6. `environment/hp_label.gd` is the one HP label (`bind(health)`, `refresh()`, `static attach(parent, health, y)`), used by the dummy and the lanes.
7. `target_dummy.gd` gains `@export var respawn_seconds := 0.0`; 0 = today's `queue_free`; >0 = hide + disable `Col` + leave `dummies`, then write `hp = max_hp` and restore.
8. `levels/gallery/target_reset.gd` (Node): for every member of group `gallery_reset` with `apply_arena_state` and a `Health` child, `died` → `delay` s → `apply_arena_state({"flags":1,"hp":1.0}, false)`. The gallery authors only deco'd blocks, so the un-reset plain-slab `_vis.color` never shows.
9. `levels/gallery/gallery_deco.gd` kind `range_tick` (bar + distance number). Everything else reuses `tutorial_deco` and `road_marks`.
10. No ammo crates, no repair bay: a god rack never depletes and a god hull never needs repair. F1/F2 arrive for free from `combat_level` when Developer Mode is on.

## Non-goals

Lessons, cards, or hints; a DPS or hit-log overlay; new weapons or data; MP or net state; FloorZones or terraces; stickers or economy (both already exclude the mode); edits to `vehicle.gd`, `enemy_driver.gd`, or `combat_level.gd`; level-editor exposure of lanes.

## Affected areas

| Area | Files | Impact |
|---|---|---|
| Mode plumbing | `ui/mode_select.gd`, `ui/car_select.gd`, `game/scene_flow.gd`, `game/music_director.gd` | 4th sub-row, `&"gallery"` stamp + HARD pin, `to_gallery()` branch, GALLERY const and track |
| Shared pieces | `environment/hp_label.gd` (new), `environment/target_dummy.gd/.tscn`, `vehicles/goliath/victory_lap_driver.gd`, `levels/tutorial/exit_confirm.gd` | label once, dummy respawn (default unchanged), per-instance throttle, `prompt` var |
| Gallery stack (new) | `levels/gallery/shooting_gallery.gd/.tscn`, `target_lane.gd`, `target_reset.gd`, `gallery_deco.gd`, `vehicles/target_vehicle.tscn` | level shell, spawner/respawner, prop reset, range paint |
| Tests | `tests/test_gallery_level.gd` (new), `tests/run_tests.gd`, `tests/test_mode_select.gd`, `tests/test_music_director.gd`, `tests/test_spawn_distance.gd`, `tests/test_stickers.gd` | locks and list updates |
| Docs | `CLAUDE.md`, `README.md`, `docs/matrices.md` | paragraph, lane bullet, knob table |

## Call-site inventory: `game_mode` comparisons

| Site | Branch needed? |
|---|---|
| `ui/mode_select.gd` stamps | yes: `SUB_MODES` + HARD pin |
| `ui/car_select.gd:117-119` tutorial fallthrough | yes: `== &"gallery"` → `to_gallery()` first |
| `ui/car_select.gd:76-78` ESC | no (already returns to mode select) |
| `ui/difficulty_select.gd:70`, `ui/end_screen.gd:104,175,523` | no (off-campaign path: Restart reloads the scene) |
| `levels/combat_level.gd:59,175`, `vehicles/vehicle.gd:247,521` | no (campaign-only economy, mods, carry) |
| `game/stickers.gd:50,85,309`, `game/game_state.gd:80` | no (earns nothing; DEVGOD stays allowed) |

## Yard layout

Flat 2816×2816 asphalt yard using the Driver's Ed Boundary / Asphalt / GridFloor / tunnel idiom, no FloorZone, no ExitGate (the tunnel is always open). Origin center, north = −y.

| Node | Kind | Position / params |
|---|---|---|
| Helipad + Vehicle | tutorial_deco `helipad` 380; player faces north | (0, 1000) |
| TunnelDeco / ExitText / ExitSign / ExitZone | tutorial_deco tunnel / exit_text / sign z1; Area2D mask 1, 300×120 | (0,−1408) / (0,−1120) / (0,−1480) / (0,−1560) |
| FiringLine / RangeAxis | road_marks `stop_line` (−448..448, 700); `dashed_white` (0, 660 → −640) | |
| Tick400 / Tick800 / Tick1200 | gallery_deco `range_tick` (896×8), text = distance from the firing line | (0,300) / (0,−100) / (0,−500) |
| Dummy400 / Dummy800 / Dummy1200 / DummyFar | target_dummy `respawn_seconds 3` | (−200,300), (0,−100), (200,−500); (0,−860) behind the wall for pierce and punch-through |
| Cover wall (group `gallery_reset`) | destructible_block barrier 80 HP ×2, crate 60 HP ×2, fence 15 HP center | y = −700, x = −352 / −224 / 0 / 224 / 352 |
| Barrel1-3 (`gallery_reset`) | destructible_block barrel 30 HP, chainable | (−640,60), (−560,110), (−480,60) |
| Wreck1-3 (`gallery_reset`) | derelict_car 50 HP | (600,320), (640,−40), (580,−420) |
| TargetReset | target_reset `delay 6` | |
| LaneSlow / LaneFast | target_lane `hammertoe` 0.45 / `mrghastly` 0.9, respawn 3, 8-marker ovals (±260 × ±800) | (960,−200) / (−960,−200) |
| LaneParkW / LaneParkE | target_lane `ghost` / `warpig`, no markers, respawn 3, unrotated; `facing_deg` 0 / 180 | (−560,760) / (560,760) |
| ConeW / ConeE, LightSW / LightSE, HUD | clutter cone; street_deco; `ui/hud.tscn` | (±470,700); (±420,1200) |

Roster masses for ram feel: mrghastly 2, ghost 6, hammertoe 15, warpig 13.

## Acceptance criteria

1. Title → SINGLE PLAYER → DRIVER'S ED → SHOOTING GALLERY → car select → gallery; ESC on car select returns to mode select; `Difficulty.tier == HARD` after the commit.
2. The player never loses HP (barrel blast, ram, status), no ammo slot ever decrements, the non-MG bay still locks 2 s, and the MG still overheats.
3. At least four dummies with range ticks whose painted distance equals their measured distance from the firing line; each dummy returns `respawn_seconds` after death at full HP with a correct label.
4. Two loop lanes field a heavy and a light car at different throttles; two parked lanes hold still; every target car carries `StatusReceiver`, is lockable (homing, Taser, Leap), shows an upright HP label, and is re-instantiated after `respawn_seconds`.
5. Target cars are in `vehicles` + `targets`, never `enemies`: HUD roster empty, end screen never latches a win, fight director ignores them.
6. Cover wall, barrel trio, and derelicts revive through `apply_arena_state` after `delay` seconds with collision and paint restored.
7. Driving into the north tunnel pops "LEAVE THE GALLERY?" (KEEP PRACTICING default; ESC backs out; re-entry re-prompts); leaving unpauses then goes to title.
8. `target_dummy` default behavior, Driver's Ed, the stadium victory lap, and every existing suite are unchanged.

## Validation

After every card, run bare: `tools/smoke.sh`, then `tools/test.sh`, then `git diff --check`. From card G-3: `tools/shot.sh levels/gallery/shooting_gallery.tscn <out>.png` and the same with `--center=0,-700 --zoom=1.2`. Direct launch before G-4 lands: `godot --path . res://levels/gallery/shooting_gallery.tscn`.

Playtest (Kevin, after G-5): run the flow in criterion 1; empty every slot into Dummy400 and watch the label; confirm no slot decrements while the bay lock and overheat still bite; Leap / Taser / homing the parked pair; Molotov / Chilblain / Chill Out them for status; ram the barrel trio and the fence at speed; shoot DummyFar through the wall with Phantom Phire; watch dummies, wall, barrels, wrecks and both loop cars come back; sit in the tunnel for the prompt, ESC out, re-enter, leave.

## Risks

| Risk | Mitigation |
|---|---|
| Lane cars as level children would rotate the player's spawn via `face_spawns_inward` | lanes parent their own cars; a test asserts the parent is the lane |
| `_gather_loop` finds a stray `GoliathLoop` | `set_loop` before `add_child`; the scene has no such node (test-locked) |
| Barrel chain repeatedly kills the parked pair | parked lanes sit ~900 px from the trio; blast radius is 130 |
| Respawn timer fires after a scene swap | `is_inside_tree()` guard in the callback |
| Exit confirm leaves the headless tree paused | tests unpause in teardown (test_tutorial_director idiom) |
| Special slot reads "1" on the HUD after `arm_all_once` | DEVGOD precedent; noted in matrices |

## Rollback

Revert cards in reverse order. G-5 and G-4 are docs and flow only; G-3 deletes the scene; G-2 deletes `levels/gallery/*` and `target_vehicle.tscn`; G-1 restores the dummy (default already identical), the static-only throttle, and the const prompt. No saved data, schema, or wire format is involved.
