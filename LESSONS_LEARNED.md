# Lessons Learned

## Target designation

- A durable target is vehicle state, not weapon state. Keeping it in a small child component gives weapons and presentation one owner without expanding the near-limit `Vehicle` script.
- Driver target preference and stable-nearest fallback are separate policies. The shared designator can reuse AI commitment while player and network drivers remain free of targeting state.
- Stateless nearest-query fallbacks remain useful for fixtures and non-vehicle callers. The weapon cutover should preserve that compatibility while making real vehicles authoritative through their designator.
- A displayed designation and an actual weapon lock must never diverge silently. When the designation fails a weapon's range, floor, cone, or line-of-sight constraint, no lock is clearer than redirecting to an unmarked opponent.
- Source comments around targeting are part of the behavior contract. A cutover from nearest acquisition to designation must update those comments in the same card, not wait for player-facing documentation.
- Screen-space marker geometry is easier to trust when it is a pure helper. Returning one or two polygons made direction, axial offset, overlap, and play-rim containment testable without a visible window.
- The full suite's fixed UDP probe port can collide with unrelated desktop processes. An isolated network namespace gives the suite its own port table without killing or reconfiguring the process that owns the host port.

## Shooting Gallery

- A non-hostile target car is a faction, not a flag. Spawning `vehicle.tscn` with faction `targets` keeps it in `vehicles` (hittable, lockable, on radar, status-receiving) while every hostile system keys on `enemies` and never sees it; nothing in `vehicle.gd` changed.
- Anything that parents a Vehicle must stay unrotated. `vehicle.gd` seats `heading = rotation` and zeroes the root, so a rotated parent skews paint, muzzle, marks and labels past the heading math. Aim parked cars with their own rotation (`facing_deg`), never the lane's; the review caught this in the first G-2 pass.
- A spawner that owns its car as a child sidesteps level-wide passes over direct children (`face_spawns_inward`) without a new flag.
- Layout clearance claims need a run, not a ruler. A 40 s headless lap probe (every prop's HP plus closest approach per loop car) is cheap and caught nothing after the wreck row moved; it would have caught the ram the capture only suggested.
- Shared probes (`tools/shot.sh`) run the level `mp_managed`, which strips the player before the subclass `_ready` resumes. A level script that touches `_player` after `super()` needs the null guard or the capture crashes.
- Scene-file groups are readable on an instantiated, never-entered scene (`is_in_group` works before `_ready`), so structural lint tests can check group membership without touching the tree.
- Doc claims carried from a plan's risk table ("the special slot reads 1") are guesses until a probe prints them; the probe showed every slot reads 1.
