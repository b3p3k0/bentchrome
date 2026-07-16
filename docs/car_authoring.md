# Adding a Car — Quick Reference

One car = one roster entry + one paint file + one test line + one portrait.
Everything else scales automatically (car select, MP lobby, enemy pools, AI).
The contract is enforced by `tests/test_roster_contract.gd` — skip a step and
the suite goes red and names it.

## The checklist

1. **roster.json entry** (`assets/data/roster.json`) — copy an existing car. Keys:
   - `id` — lowercase, no spaces; used as filename/style/portrait key everywhere.
   - `car_name`, `driver_name`, `flavor` — lore.
   - `special_weapon` — prose, `"Name: description"` (the colon split feeds the HUD).
   - `special_def` — basename of the WeaponDef: `data/weapons/<special_def>.tres`.
   - `ai_archetype` — `aggressor | ambusher | opportunist` (`defender`/`mini_boss` are legacy aliases).
   - Optional: `burn_taken` — burn-DoT multiplier (Lovebug's air-cooled 1.5).
   - `stats` — acceleration / top_speed / handling / armor / special_power, integers
     **1-20** (schema v2; odd values are the migrated legacy 1-10 line — old v = new 2v-1).
     Optional `stats.launch` — standing-start torque (omit = derived from mass; authoring
     slot `21 - 2×engine_mass` reproduces the derived shove, so author ABOVE that for a
     heavy-but-torquey ride, below it for a needs-a-running-start one).
   - `colors` — `primary` + `accent` hex.
   - `portrait` — `res://assets/img/bios/<id>.png`.
   - `mass` — 1-20 (bike 1-5, sedan 7-9, truck 11-15; 17+ is boss territory). The
     engine folds it to its native 1-10 knob: `engine_mass = (mass + 1) / 2`.
   - Optional: `special_ammo_cap` (default 1), `special_recharge_seconds` (default 12),
     `terrain_profile` (a name from top-level `terrain_profiles` — shared tables like
     `awd_utility`), `terrain_modifiers` (per-car inline table; overlays the profile
     per surface+property, inline wins — see CLAUDE.md "Terrain-profile authoring recipe").
   - The file requires top-level `"schema_version": 2`; the importer rejects anything else.
2. **Special weapon** — reuse a `data/weapons/*.tres` or author a new one (existing
   Kinds are pure data; a NEW Kind needs code — see recipe below).
3. **Run the importer**: `godot --headless --path . -s res://tools/import_roster.gd`
   It fails loudly on any contract violation. NOTE: it rewrites ALL of
   `data/vehicles/*.tres` with fresh resource ids — commit only the car you added,
   `git checkout` the cosmetic churn on the others.
4. **Paint file**: `vehicles/paint/<id>.gd` — copy a similar silhouette. `STYLE` dict
   (half_len / half_wid / radius / skid_points / steer_wheels, plus `"blink": true`
   for a flashing light bar, `"mg_points": [Vector2, …]` for staggered
   multi-barrel MG fire — Hubcap's twins, and `"tail_len"` when half_len
   includes nose gear — Coldfront's plow — so taillights sit on the real
   bumper) + `static func paint(c, primary, accent, steer, phase)`.
   Draw with `Parts.*` helpers; never preload car_paint.gd from a style file.
5. **Register it**: one preload line in `car_paint.gd`'s `STYLE_SCRIPTS`.
6. **Size canon**: insert the id into `tests/test_car_paint.gd` `ORDER` at its radius
   rank (strictly ascending, radius must be unique across the roster).
7. **Portrait**: `assets/img/bios/<id>.png` (see existing files for the format).
8. **Gates**: `tools/smoke.sh` and `tools/test.sh`. Then a matrices.md row (docs/matrices.md).

## Conventions

- **Radius is gameplay.** Hitbox stays 1:1 while the body renders at
  `FLEET_SCALE` 1.50 — deliberate near-miss forgiveness, don't "fix" it.
  Corner-escape AI budgets couple to radius (kandykane pinned at 22).
  Taken radii: 12, 13.5, 14, 15, 16, 17, 18, 19, 20, 21, 21.5, 22, 23, 26.
- **Stat budget (advisory)**: the fleet totals 49-65 points across the five
  stats on the 1-20 scale (Cyclone's 65 is paid for by the offroad penalty
  box; Lovebug's 44 sits BELOW the band by design — the weakest driveline pays
  for water-walking + disarm). Stay in the band unless the car IS the gimmick;
  low armor buys speed. `launch` and `mass` sit outside the budget.
- **MPH is the tuning vocabulary** (US units; `MPH_PER_PXS 0.15` in ui/hud.gd):
  top_speed slot 1 = 54 mph, +2.33 mph per slot, slot 19 = 96 mph, slot 20 =
  98.3 mph headroom. The importer log and F1 dashboard read back mph and a
  measured 0-60; per-car real-world targets live in `docs/car_tuning_baselines.md`.
- **Ammo economics**: cap 1-3; recharge 6-12s for light specials, 90s+ for
  heavy sustained ones (taser/blaze class).
- **Terrain identity**: only where it sells the car (Cricket dirt, 4WD snow);
  omitted surfaces are neutral ×1.0. Unknown names fail import.

## Role grid (the current fourteen) — open niches for the rest of the fleet

Mass on the 1-20 authoring scale (engine folds to 1-10).

| id        | mass | speed/armor  | special kind        | archetype   | terrain    |
|-----------|------|--------------|---------------------|-------------|------------|
| mrghastly | 1    | fast/paper   | PROJECTILE (sniper) | aggressor   | —          |
| cyclone   | 3    | fastest/glass| TORNADO             | ambusher    | road+, offroad− (racing_slicks) |
| cricket   | 3    | fast/light   | DASH                | aggressor   | dirt/grass (dirt_racer) |
| hubcap    | 5    | agile/mid    | PULSE               | aggressor   | — (dual MG, wider than long) |
| ghost     | 5    | fastest/thin | PROJECTILE (homing) | aggressor   | —          |
| lovebug   | 7    | windup/light | PROJECTILE (disarm) | opportunist | water=road (inline); burn 1.5x; launch 1 (slowest start, by design) |
| hornet    | 9    | all 11s      | PROJECTILE (burn)   | aggressor   | —          |
| splatkat  | 9    | nimble/mid   | PROJECTILE (slow-fx)| ambusher    | —          |
| bumper    | 11   | slow/heavy   | FLAME               | defender    | —          |
| smoky     | 11   | punchy/heavy | BEAM                | defender    | awd_utility |
| kandykane | 13   | slow/heavy   | PROJECTILE (burn)   | mini_boss   | —          |
| coldfront | 13   | mid/heavy    | PROJECTILE (freeze) | opportunist | snow/ice=road (snowplow) |
| razorback | 13   | slow/heavy   | PROJECTILE (salvo)  | defender    | awd_utility |
| hammertoe | 15   | mid/heavy    | TRIGGER             | ambusher    | all-road (monster_tires) |

Open niches: BEAM/FLAME/DASH/TRIGGER/TORNADO/PULSE each have exactly one owner;
**no DROP signature** (mines are only shared slots); no rear-launch special;
mass 17+ unused (boss territory); radius gaps under 12, at 20.5, 24-25,
and above 26. (Ice/snow specialist: taken — coldfront.)

## Node-level vehicle schema (boss flags — scene-authored, NOT in .tres)

These `Vehicle` exports are part of the official car schema but live on the
node in the level scene (stadium.tscn Goliath, depot.tscn Lackey, buzzard.tscn),
not in `data/vehicles/*.tres`:

| flag | consumer | who sets it |
|------|----------|-------------|
| `fixed_loadout` | combat_level re-roll skip; disarm/freeze immunity | Goliath, Lackey |
| `launch_immune` | jump pads / jump mines / tornado / pulse all no-op | Goliath only |
| `mine_weakness` | mine.gd damage scale (the soft underbelly) | Goliath 6.0 |
| `rear_weakspot` | projectile.gd from-behind amplifier | Goliath & Lackey 1.75 |
| `body_scale` | visual + collision-radius scale | Goliath 1.6, Lackey 1.5 |
| `hp_scale` | multiplies StatCurves HP | Lackey 1.7 (Goliath uses goliath_boss.gd pools) |
| `ai_cooldown_scale` | AI fire-rate divisor (default 3.0) | Lackey 1.5 |
| `start_floor` | multi-floor spawn adoption | per-spawn on terrace maps |

## Tuning a car fast (the car-tuner workflow)

Title → SETTINGS → **DEVELOPER OPTIONS** → **CAR TUNER** (row unlocks with
Developer Mode) opens the tuner: every roster car × every authored value
(stats, mass, launch, ammo cap, recharge) in one mouse-driven grid, ESC
backs out. Edits land on the loaded car data (the next arena spawn drives
them), read back engine units + mph in the status line, and persist to
`user://car_tuner.json` across sessions. When a
setup feels right: **Export**, then run the printed command —
`python3 tools/migrate_roster_v2.py --fold <export>` — which surgically
updates roster.json and re-runs the importer. That fold intentionally moves
feel, so re-pin `tests/test_stat_rebase.gd`'s GOLDEN table (and
`test_specials_data` if caps changed) as part of the same commit.

## Migrating / rescaling a car (the razorback-pilot checklist)

When a schema or scale change touches authored values, per car:
1. `python3 tools/migrate_roster_v2.py --car <id> --dry-run` — before/after ints
   AND engine px/s + mph; any `*** FEEL MOVED ***` flag is a stop-the-line bug.
2. Apply (script for roster cars; hand-edit for the six roster-external .tres:
   buzz_bike / buzz_sedan / buzz_technical / goliath / goliath_ph2 / lackey).
3. Re-run the importer; read back the mph + net-terrain log lines.
4. `tools/probes/stat_baseline.gd` before vs after — engine values and 0-60s
   must not move unless the change MEANS to move them.
5. Gates (`tools/smoke.sh`, `tools/test.sh`) — `tests/test_stat_rebase.gd`'s
   golden lock holds the fleet's engine values bit-exact.
6. F1 in an arena: pick the car, check top (mph), mass, launch_factor, and the
   live terrain readout on each surface the car claims an identity for.

## New special Kind recipe (when data isn't enough)

1. Add the value to `WeaponDef.Kind` (`resources/weapon_def.gd`).
2. Handler in `vehicles/special_controller.gd` — dispatch lives in `activate()`;
   study BEAM (sustained + lockout), DASH (controller bypass), DROP (rear
   deploy), TORNADO (self-AoE + visual override — the newest worked example).
3. Same-floor filtering and mask-restore etiquette apply (see CLAUDE.md multi-floor).
4. A test in `tests/` (register in `run_tests.gd` SUITES) + a row in
   `docs/specials_backlog.md`'s behavior table + matrices.md.
5. LAN: if the effect isn't a plain projectile, check `net_events.gd` needs a tap.
