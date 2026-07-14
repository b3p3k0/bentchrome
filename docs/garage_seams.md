# Mods Garage — backend seams (contract for the future feature)

The 2026-07 stats rebase pre-built the composition seams the mods garage will
consume. The garage UI/economy is NOT built; everything here exists so that
building it never has to re-plumb the stats backend.

## The one composition function

`resources/vehicle_loadout.gd` — `VehicleLoadout.compose(base, mods) -> VehicleStats`.
Duplicates the base .tres (shipped resources are process-wide singletons —
never mutate them) and folds an ordered mod list:

- `stat_deltas` — ints added on the 1-20 design scale, clamped (launch 0-20);
  **tradeoffs are negative deltas** (bay expansion: +ammo, −handling, −armor).
  Deltas ride the same StatCurves tables as authored stats, so a +2 top_speed
  part means the same thing on every car.
- `terrain_profile` — wholesale `terrain_modifiers` swap (tires/drivetrain:
  offroad tires = point at `awd_utility`-style tables; lift/lowering kits =
  a swap plus handling deltas).
- `capabilities` — direct grants: `burn_taken`, `no_mines`, `special`,
  `special_b`, `special_ammo_cap`, `special_recharge_seconds`.
- `controller_overrides` — merged into `handling_overrides`, the existing
  post-curve knob layer (boost factors, brake feel).
- `reserved` — named but unwired axes for the planned categories:
  `radar_range_scale` (CPU/electronics; NOTE the base game currently paints
  the radar map-wide — limited base range is its own future feature, the mod
  axis just reserves the name), `mg_heat_scale` (MG cooling), `lock_time_scale`
  (improved lock), `detectability` (the lock tradeoff: your targeting signal
  makes you easier to see).

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
