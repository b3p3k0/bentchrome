# Net backlog: projectile shooter-z on the wire

**Status: deferred (Kevin, 2026-07-12). Single-player and the MP HOST are already
fixed; this note is the remaining CLIENT-side work and why it needs a wire change.**

## Problem

Terrace decks paint at `z_index 1`; floor-3/airborne cars ride `z_index 2`
(`vehicles/vehicle.gd _update_draw_order`). Projectiles fired from floor 3 must
draw at the shooter's z or they vanish under the deck paint until they clear it.

The local fix shipped: `weapons/projectile.gd setup()` copies the shooter's
`z_index` (duck-typed CanvasItem), and `pool_reset()` clears it back to 0 so a
pooled floor-3 shot never floats when reused by a ground shooter.

**MP clients still show the old bug for OTHER peers' floor-3 shots**: the
client-side visual twin is spawned with `shooter = null`
(`levels/mp/mp_match.gd _spawn_visual_projectile`), and the projectile birth
event carries no shooter information — so the twin has nothing to copy z from.
Cosmetic-only, LAN-only, floor-3-only; the shot's gameplay is host-authoritative
and unaffected.

## The fix (when a protocol bump is next scheduled)

1. `game/net/net_events.gd` — `projectile_spawned(...)` gains the shooter's
   effective z (or simply the shooter's floor/airborne flag; a `u8 z` is
   simplest and future-proof for higher terraces).
2. `game/net/net_snapshot.gd` — EV_PROJECTILE pack/unpack gains the `u8 z`
   field. **This is a wire change: bump `NetProtocol.PROTOCOL_VERSION` (8 → 9
   at time of writing) per the CLAUDE.md rule.**
3. `levels/mp/mp_match.gd _spawn_visual_projectile` — set `shot.z_index` from
   the event after `setup()` (setup can't do it; twin shooter stays null).
4. `tests/test_net_state_snapshot.gd` — update the `PROTOCOL_VERSION` lock and
   add the field to the EV_PROJECTILE round-trip case.

Fold this into whatever protocol bump comes next rather than shipping a version
gate for one cosmetic byte.
