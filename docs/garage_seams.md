# Mods Garage — backend seams (contract for the future feature)

The 2026-07 stats rebase pre-built the composition seams the mods garage
consumes. The garage UI/economy is LIVE (see docs/garage/README.md), and the
2026-08 plug-in pass wired the formerly-reserved axes into real systems —
this file is the authoritative mod-shape contract.

## The one composition function

`resources/vehicle_loadout.gd` — `VehicleLoadout.compose(base, mods) -> VehicleStats`.
Duplicates the base .tres (shipped resources are process-wide singletons —
never mutate them) and folds an ordered mod list:

- `stat_deltas` — ints added on the 1-20 design scale, clamped (launch 0-20);
  **tradeoffs are negative deltas** (bay expansion: +ammo, −handling, −armor).
  Deltas ride the same StatCurves tables as authored stats, so a +2 top_speed
  part means the same thing on every car.
- `terrain_profile` — wholesale `terrain_modifiers` swap (drivetrain-grade
  identity change; code-authored mods only today).
- `terrain_overlay` — **the tire-package verb** (wired 2026-08): a raw
  `{surface: {property: factor}}` table patched PER PROPERTY over the composed
  modifiers via `resources/terrain_tables.gd` `overlay_modifiers` — the
  overlay wins where it speaks (buffs AND authored downsides, cutting both
  ways), silent properties keep the car's authored identity (Cricket keeps her
  dirt `dash_damage` under street slicks). Patched entries duplicate, so
  shipped .tres never mutate. Validated at catalog load with the importer's
  terrain checks.
- `capabilities` — three semantics by key (wired 2026-08):
  - **scale axes** (`VehicleLoadout.SCALE_FIELDS`): `mg_heat_scale` (MG heat
    gain), `tracking_scale` (shooter-side lock reach + homing turn),
    `radar_range_scale` (viewer sensor reach), `detectability` (target-side
    signature: sensor paint distance AND the AI's scored-tier gate). These
    compose MULTIPLICATIVELY so co-owned electronics stack order-free
    (improved_lock 1.5 × jammer 0.8 = 1.2 either way).
  - `special_ammo_cap_bonus` — ADDS to the authored cap, floored at 1.
  - direct grants: `burn_taken`, `no_mines`, `special`, `special_b`,
    `special_ammo_cap`, `special_recharge_seconds`.
- `controller_overrides` — merged into `handling_overrides`, the existing
  post-curve knob layer (boost factors, brake feel).

The `reserved` bag is RETIRED — the catalog validator rejects it (and any
unknown key/capability), and an item that changes nothing fails the load
outright (the meaningfulness rule). The backing systems live at:
`weapons/weapon_mount.gd` `heat_scale`, the tracking seams in
`weapon_mount._fire_wave` + `vehicles/special_controller.gd`,
`Vehicles.BASE_SENSOR_RANGE`/`sensed_others` (radar + edge arrows, 2200px
base), and `EnemyDriver._det` (scored tier only — HUNT stays unfiltered per
the no-camping contract; duel/focus leases pierce detectability by design).

**Rival keep-up asymmetry (deliberate):** rivals mirror the player's positive
`stat_deltas` × `Economy.RIVAL_KEEPUP` only (`combat_level._randomize_enemies`).
Terrain overlays, sensor/tracking/heat scales, and cap bonuses are
player-exclusive — electronics are a player-identity purchase, not an arms
race.

## Application rules

- **Between runs / at car select:** `Vehicle.set_stats(VehicleLoadout.compose(tres, mods))`
  — set_stats is a full re-init (repaint, radius sync, HP reset), correct here.
- **Mid-run tweaks:** the Goliath pattern — `StatCurves.apply(composed, ctrl, null)`
  — never set_stats (it repaints and slams HP to full).

## Persistence (when built)

`user://garage.json` following GameState's settings-whitelist pattern
(`game/game_state.gd` save_settings/load_settings): `{car_id: [mod_id, ...]}`.
Player-facing, survives sessions; NOT the dev-only `user://tuning.json`.

## LAN (when built)

The host simulates every car, so a client's mods MUST reach the host:
- `NetRoster` picks grow from a bare car-id `String` to `{car, mods: [ids]}`;
  clients send mod IDS only — the host validates against its own catalog and
  composes locally (never trust streamed numbers).
- Any pick/snapshot shape change bumps `PROTOCOL_VERSION` (`game/net/net_protocol.gd`).
- `NetManifest` hashes only .gd sources — data-only mods are invisible to the
  mod checksum by design (it is not a security boundary).

## Category sketch (from design discussion, 2026-07-14)

~5-6 categories, flavor-feelable, "gravy not the main dish":
engine stages (accel/top) · suspension & tires (handling + terrain swaps) ·
weapon systems (MG cooling, bay expansion, improved lock + detectability) ·
CPU/electronics (jammer, extended radar) · armor/plating. Stat changes should
be feelable but not overwhelming; every strong buff carries a tradeoff.
