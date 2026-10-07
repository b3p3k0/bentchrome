# Target Designation Plan

Goal: give every combat vehicle one durable designated opponent, route tracking and locking weapons through that designation, and distinguish the local player's off-screen target with a two-chevron VCR fast-forward marker.

## Progress

| Card | State | Evidence |
|---|---|---|
| TD-1 — Durable designation | Accepted by RA | Full suite: `TESTS: PASS (16936 checks)`; `git diff --check` clean |
| TD-2 — Weapon cutover | Accepted by RA | Full suite: `TESTS: PASS (16947 checks)`; zero production `Targeting.nearest_*` callers |
| TD-3 — VCR marker and closeout | Pending | — |

## Current state

- `game/targeting.gd` provides stateless nearest-vehicle queries.
- `weapons/weapon_mount.gd` acquires a target independently when each tracking projectile wave launches.
- `vehicles/special_controller.gd` independently queries nearest targets for twin selection, beam latch, and dash lock.
- `vehicles/drivers/enemy_driver.gd` already maintains a committed combat target, but weapons do not consume it.
- `ui/offscreen_tracker.gd` owns sensor-bounded off-screen marker state and paints one triangle per visible marker.
- `vehicles/vehicle.gd` is 1,584 lines, close to the project's 1,700-line hard stop, so designation logic must not be added there.

## Decisions

1. Add a `TargetDesignator` child component to the base vehicle scene. It owns the current target per vehicle and exposes it without adding state to `Vehicle`.
2. Player and network-driven vehicles designate the nearest living opponent. The current target remains stable until another opponent is meaningfully closer, preventing rapid marker and weapon churn around distance ties.
3. Enemy drivers publish their existing committed combat target through the shared `Driver` interface. If a driver has no valid preference, the designator falls back to the stable-nearest rule.
4. `Targeting` remains the dependency-light validation seam. New designation-aware queries prefer the component's target and use the existing nearest behavior only for fixtures or shooters without a designator.
5. A designated target that fails a weapon's existing range, floor, cone, or line-of-sight rules does not silently redirect that weapon to a different opponent. The marker and the lock must describe the same opponent.
6. The off-screen tracker remains sensor-bounded. When the designated opponent already earns an off-screen marker, it paints two same-direction triangles offset along their axis and slightly overlapping, like an old VCR fast-forward symbol. Other opponents keep one triangle.
7. Target choice is derived locally from existing vehicle state. This wave adds no network protocol field.

## Non-goals

- Target cycling or new input bindings.
- The future camera key that frames the player and target.
- Changes to AI target scoring, commitment, or navigation.
- Changes to straight weapons, mines, area attacks, or machine-gun aim.
- Expanding radar or off-screen sensor reach.
- Network protocol or snapshot changes.

## Affected areas

| Area | Files | Impact |
|---|---|---|
| Designation state | `game/target_designator.gd`, `vehicles/vehicle.tscn` | Every base vehicle gains one reusable target owner. |
| Target source | `vehicles/drivers/driver.gd`, `vehicles/drivers/enemy_driver.gd`, `game/targeting.gd` | AI exposes its existing target; shared queries validate designated targets. |
| Weapon consumers | `weapons/weapon_mount.gd`, `vehicles/special_controller.gd` | Projectile, beam, twin, and dash locks agree on the designation. |
| Presentation | `ui/offscreen_tracker.gd` | The local target gets the overlapping double-chevron marker. |
| Tests | `tests/test_target_designator.gd`, `tests/test_tracking_scale.gd`, `tests/test_offscreen_tracker.gd`, `tests/run_tests.gd` | Locks target stability, weapon consumption, constraints, and marker geometry. |
| Behavior docs | `README.md`, `CLAUDE.md`, `docs/matrices.md`, `LESSONS_LEARNED.md` | Records player-facing behavior, architecture, tuning, and review lessons. |

## Call-site inventory

All current shared target queries were enumerated before cutover:

| Caller | Existing query | Planned behavior |
|---|---|---|
| `WeaponMount._fire_wave` | nearest or nearest-in-cone | designated target, preserving acquisition radius and optional cone |
| `SpecialController._active_def` | nearest, same floor | designated target decides whether the beam twin is viable |
| `SpecialController._beam` | nearest, same floor | designated target, preserving range and line of sight |
| `SpecialController._dash` | nearest or nearest-in-cone, same floor | designated target, preserving range and optional cone |
| `tests/test_weapon_gating.gd` | direct nearest queries | unchanged; continues specifying stateless query behavior |

## Acceptance criteria

1. Each base-scene vehicle can report zero or one valid designated opponent.
2. A player-controlled vehicle initially designates the nearest living opponent, holds through small distance ties, switches when another is meaningfully closer, and replaces dead/freed targets immediately.
3. An enemy vehicle's designation agrees with its existing committed combat target without changing AI scoring.
4. Tracking projectile waves, beam/twin selection, and dash locks consume the designation.
5. Existing acquisition radius, floor, forward-cone, line-of-sight, tracking-scale, launch-side, and projectile-flight behavior remain enforced.
6. Shooters without a designator retain the current nearest-target fallback for lightweight tests and non-vehicle fixtures.
7. The local player's designated off-screen opponent draws two overlapping forward triangles; every other off-screen opponent draws one.
8. On-screen targets and targets outside the existing sensor roster do not gain a new marker.
9. No input binding, camera behavior, AI scoring, or network packet changes land.
10. Behavior and agent-facing documentation match the runtime.

## Validation

Run after each card as specified in `docs/target_designation_cards.md`. Final validation:

```sh
~/.local/bin/godot --headless --path . -s res://tests/run_tests.gd
tools/smoke.sh
git diff --check
```

Manual check:

1. Start a battle with at least three opponents.
2. Confirm ordinary off-screen opponents show one triangle.
3. Confirm the designated opponent shows two slightly overlapping triangles in the same direction, visually reading as a VCR fast-forward glyph.
4. Cross a distance tie and confirm the target does not chatter; move another opponent decisively closer and confirm the glyph moves.
5. Fire Fire, Homing, Rear, Phantom Phire, Taser, and Leap where available; confirm each locks only the designated opponent when its own constraints allow.
6. Confirm target death immediately transfers the double-chevron to the replacement.
7. In a LAN match, confirm the client marker and host-authoritative projectile birth identify the same opponent away from a distance tie.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Near-equal distances cause visible target chatter. | A named switch margin keeps the current live target until a challenger is meaningfully closer. |
| A weapon redirects away from the displayed target. | Designation-aware queries return no lock when the designation fails that weapon's constraints. |
| AI behavior changes beyond weapon aim. | Reuse the driver's existing target; do not alter scoring, commitment, or navigation. |
| Host/client choose differently at an exact distance tie. | Stable hysteresis and deterministic iteration minimize the window; no protocol cost is accepted in this wave. |
| Component work bloats `Vehicle`. | Put state and selection in a new child script; touch the base scene rather than the vehicle monolith. |

## Rollback

Revert the acceptance commits in reverse order. Removing the `TargetDesignator` node restores the fallback nearest queries; reverting the weapon card restores direct nearest acquisition; reverting the HUD card restores single-triangle markers. No saved data, schema, or wire format requires migration.
