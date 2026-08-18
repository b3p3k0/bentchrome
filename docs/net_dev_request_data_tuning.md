# Net-dev request: standardize dev data-tuning in MP sessions

**Status: OPEN — game-side hook shipped, net-side wiring requested.**
Policy (Kevin, 2026-07): *in MP the host controls all car values; modded
client values get dropped or standardized.*

## What is already true (no work needed)

The host-authoritative architecture enforces the sim side of this policy by
construction:

- The host simulates EVERY car from the **host's own** loaded data; clients
  are interpolated puppets (`Vehicle.set_net_puppet` — sim bypassed).
- Car identity crosses the wire once, as a bare `car_id` string with the
  lobby pick; snapshots carry **no stat fields**.
- Therefore a client with tuned data (car tuner / F2 deck / hand-edited
  user files) **cannot affect the shared game at all**.
- The in-arena dev panels (F1/F2) are never instantiated in MP —
  `combat_level.gd`'s `mp_managed` early-return precedes the dev block — and
  the car tuner doesn't exist in level scenes at all (it's a Settings →
  DEVELOPER OPTIONS dialog on the title flow).

## The gaps (why this request exists)

1. **Dev-mode HOST data drives the match silently.** `Dev._ensure_tuning()`
   boot-applies `user://tuning.json` (weapon defs, TERRAIN) and
   `user://car_tuner.json` (per-car roster stats onto the `.tres`
   singletons). A host who tuned cars in single player then hosts a lobby
   runs the whole match on tuned data.
2. **Tuned CLIENTS see distorted local presentation** — their own car-select
   text, HUD-adjacent readouts, anything reading the mutated singletons.
   Cosmetic-only, but two players can disagree about what "War Pig TOP 11"
   means.
3. **The mod checksum can't see it**: `NetManifest` hashes only `.gd`
   source (by design, "not a security boundary") — data tuning never flips
   the MODDED flag.

## Requested net-side changes

1. **Call `Dev.suspend_data_tuning()` at session start, BOTH roles** (host =
   enforcement, client = standardized presentation). The hook exists now in
   `game/dev.gd`: it pushes roster-truth values back onto every car `.tres`
   **without touching the player's saved `user://car_tuner.json`** (their SP
   tuning survives; it simply re-applies on next boot). Suggested call sites:
   host-start and post-handshake client join in `net_session.gd`. Note it
   currently covers the CAR deck only; if you want the F2 deck (weapon defs /
   TERRAIN) standardized too, extend the hook with
   `tuning.reset_defs()` / `tuning.reset_terrain()` (do NOT call
   `tuning.save()` afterward — that would wipe the player's file).
2. **Optional restore:** on return-to-title after a session, either re-run
   the decks' `load_and_apply()` or leave suspended-until-reboot (current
   behavior; acceptable, just document in the MP flow).
3. **Optional stretch — disclosure instead of trust:** include a data digest
   (roster.json + `data/vehicles/*.tres` + presence/hash of active
   `user://tuning.json` / `user://car_tuner.json`) in the auth hello beside
   the script checksum → surface a lobby **[ TUNED ]** badge and a
   `strict_data` host knob, mirroring the existing MODDED flag/strict-reject
   flow in `net_auth.gd`. This makes a deliberately-tuned host visible
   rather than forbidden — LAN-appropriate.

## Constraint: do not clobber the future mods garage

Garage mods will travel as **mod IDs** with the lobby pick; the host
validates against its own catalog and composes via `VehicleLoadout.compose`
(`docs/garage_seams.md`). That flow is deliberate, per-seat, host-computed —
`suspend_data_tuning()` must run BEFORE garage composition in the spawn
order, so standardization wipes dev tuning but never a composed loadout.

## Verification sketch

`tools/nettest.sh` extension: host boots with a synthetic
`user://car_tuner.json` (e.g. warpig top_speed 20), client joins, assert
the host's spawned warpig controller reports the ROSTER max_speed
(515.55… px/s), not the tuned table value.
