# Signature specials — backlog (deferred to a separate plan)

Each car has a signature special, stored as a `WeaponDef` and wired to the car
via `VehicleStats.special`. Specials that fit the current projectile system are
implemented; those needing systems we haven't built are **stubbed**
(`WeaponDef.stub = true`, fires nothing) so turning them on later is just adding
the behavior — the data and wiring already exist.

## Implemented (fit current tech)
- **Scythe of the Damned** (Mr. Ghastly) — straight, slow, heavy projectile.
- **Red Glare** (Razorback) — 20-rocket tight-spread salvo.
- **Phantom Phire** (Ghost) — map-wide aggressive homing missile.
- **Molotov Cocktail** (Kandy Kane) — impact burst (15s burn deferred).

## Stubbed (need new systems)
| Car | Special | Needs |
|-----|---------|-------|
| Bumper | Blunt Blaze | front fire cone + burn-over-time |
| Cricket | Leap | dash / body-check + brief invulnerability |
| Hammertoe | Toe Jam | collision-trigger charged hit |
| Smoky | Taser | close-range channeled beam + handling cripple (slow) |
| Splat Cat | Splat Effect | on-hit speed-halving debuff |

## Shared systems to build first
- **Status effects** — burn-over-time, slow (covers Blunt Blaze, Molotov burn, Taser, Splat Effect).
- **Dash / leap** movement ability (Leap).
- **Collision-trigger** charge (Toe Jam).
- **Channeled beam** weapon type (Taser).
