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
   - `stats` — acceleration / top_speed / handling / armor / special_power, integers 1-10.
   - `colors` — `primary` + `accent` hex.
   - `portrait` — `res://assets/img/bios/<id>.png`.
   - `mass` — 1-10 (bike 1-2, sedan 3-5, truck 6-8; 9-10 is boss territory).
   - Optional: `special_ammo_cap` (default 1), `special_recharge_seconds` (default 12),
     `terrain_modifiers` (see CLAUDE.md "Terrain-profile authoring recipe").
2. **Special weapon** — reuse a `data/weapons/*.tres` or author a new one (existing
   Kinds are pure data; a NEW Kind needs code — see recipe below).
3. **Run the importer**: `godot --headless --path . -s res://tools/import_roster.gd`
   It fails loudly on any contract violation. NOTE: it rewrites ALL of
   `data/vehicles/*.tres` with fresh resource ids — commit only the car you added,
   `git checkout` the cosmetic churn on the others.
4. **Paint file**: `vehicles/paint/<id>.gd` — copy a similar silhouette. `STYLE` dict
   (half_len / half_wid / radius / skid_points / steer_wheels, plus `"blink": true`
   for a flashing light bar and `"mg_points": [Vector2, …]` for staggered
   multi-barrel MG fire — Hubcap's twins) + `static func paint(c, primary, accent, steer, phase)`.
   Draw with `Parts.*` helpers; never preload car_paint.gd from a style file.
5. **Register it**: one preload line in `car_paint.gd`'s `STYLE_SCRIPTS`.
6. **Size canon**: insert the id into `tests/test_car_paint.gd` `ORDER` at its radius
   rank (strictly ascending, radius must be unique across the roster).
7. **Portrait**: `assets/img/bios/<id>.png` (see existing files for the format).
8. **Gates**: `tools/smoke.sh` and `tools/test.sh`. Then a matrices.md row (docs/matrices.md).

## Conventions

- **Radius is gameplay.** Hitbox stays 1:1 while the body renders at
  `FLEET_SCALE` 1.25 — deliberate near-miss forgiveness, don't "fix" it.
  Corner-escape AI budgets couple to radius (kandykane pinned at 22).
  Taken radii: 12, 13.5, 14, 15, 16, 17, 18, 19, 20, 21, 21.5, 22, 26.
- **Stat budget (advisory)**: the fleet totals 27-35 points across the five
  stats (Cyclone's 35 is paid for by the offroad penalty box). Stay in the
  band unless the car IS the gimmick; low armor buys speed.
- **Ammo economics**: cap 1-3; recharge 6-12s for light specials, 90s+ for
  heavy sustained ones (taser/blaze class).
- **Terrain identity**: only where it sells the car (Cricket dirt, 4WD snow);
  omitted surfaces are neutral ×1.0. Unknown names fail import.

## Role grid (the current thirteen) — open niches for the rest of the fleet

| id        | mass | speed/armor  | special kind        | archetype   | terrain    |
|-----------|------|--------------|---------------------|-------------|------------|
| mrghastly | 1    | fast/paper   | PROJECTILE (sniper) | aggressor   | —          |
| cyclone   | 2    | fastest/glass| TORNADO             | ambusher    | road+, offroad− |
| cricket   | 2    | fast/light   | DASH                | aggressor   | dirt/grass |
| hubcap    | 3    | agile/mid    | PULSE               | aggressor   | — (dual MG, wider than long) |
| ghost     | 3    | fastest/thin | PROJECTILE (homing) | aggressor   | —          |
| lovebug   | 4    | peppy/light  | PROJECTILE (disarm) | opportunist | water=road; burn 1.5x |
| hornet    | 5    | all 6s       | PROJECTILE (burn)   | aggressor   | —          |
| splatcat  | 5    | nimble/mid   | PROJECTILE (slow-fx)| ambusher    | —          |
| bumper    | 6    | slow/heavy   | FLAME               | defender    | —          |
| smoky     | 6    | punchy/heavy | BEAM                | defender    | 4WD        |
| kandykane | 7    | slow/heavy   | PROJECTILE (burn)   | mini_boss   | —          |
| razorback | 7    | slow/heavy   | PROJECTILE (salvo)  | defender    | 4WD        |
| hammertoe | 8    | mid/heavy    | TRIGGER             | ambusher    | all-road   |

Open niches: BEAM/FLAME/DASH/TRIGGER/TORNADO/PULSE each have exactly one owner;
**no DROP signature** (mines are only shared slots); no rear-launch special;
no ice or snow specialist; mass 9-10 unused (boss territory); radius gaps
under 12, at 20.5, 23-25, and above 26.

## New special Kind recipe (when data isn't enough)

1. Add the value to `WeaponDef.Kind` (`resources/weapon_def.gd`).
2. Handler in `vehicles/special_controller.gd` — dispatch lives in `activate()`;
   study BEAM (sustained + lockout), DASH (controller bypass), DROP (rear
   deploy), TORNADO (self-AoE + visual override — the newest worked example).
3. Same-floor filtering and mask-restore etiquette apply (see CLAUDE.md multi-floor).
4. A test in `tests/` (register in `run_tests.gd` SUITES) + a row in
   `docs/specials_backlog.md`'s behavior table + matrices.md.
5. LAN: if the effect isn't a plain projectile, check `net_events.gd` needs a tap.
