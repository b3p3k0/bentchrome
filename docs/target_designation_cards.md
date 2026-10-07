# Target Designation Task Cards

Cards are strict review boundaries. RA accepts one before DA starts the next.

## Card TD-1 — Durable designation

Status: accepted by RA on 2026-10-07.

Goal: add per-vehicle target ownership without changing weapon or HUD behavior.

Likely files:

- `game/target_designator.gd` — new component with stable-nearest selection and driver preference.
- `game/targeting.gd` — designation lookup and reusable eligibility checks.
- `vehicles/vehicle.tscn` — attach the component to every base vehicle.
- `vehicles/drivers/driver.gd` — default target-preference seam.
- `vehicles/drivers/enemy_driver.gd` — expose the existing committed target.
- `tests/test_target_designator.gd`, `tests/run_tests.gd` — component contract.

Acceptance:

- Initial nearest, hysteretic hold/switch, death/free replacement, empty roster, and AI preference are test-locked.
- Existing `nearest_other` and `nearest_in_cone` behavior remains unchanged.
- No weapon, HUD, camera, input, or network behavior changes.

Checks:

```sh
~/.local/bin/godot --headless --path . -s res://tests/run_tests.gd
git diff --check
```

## Card TD-2 — Weapon cutover

Status: accepted by RA on 2026-10-07 after one Required source-comment correction.

Goal: make every existing nearest-lock weapon consume the shared designation.

Likely files:

- `weapons/weapon_mount.gd` — tracking projectile waves.
- `vehicles/special_controller.gd` — twin selection, beam latch, and dash lock.
- `tests/test_target_designator.gd`, `tests/test_tracking_scale.gd` — designated-target and constraint coverage.

Acceptance:

- A designated farther opponent wins over an undesignated nearer opponent when eligible.
- Ineligible designation yields no lock; it never silently redirects.
- Range, same-floor, cone, line-of-sight, tracking scale, rear launch, and no-component fallback remain test-locked.
- Every production `Targeting.nearest_*` weapon call is cut over or explicitly documented as intentionally stateless.

Checks:

```sh
~/.local/bin/godot --headless --path . -s res://tests/run_tests.gd
git diff --check
```

## Card TD-3 — VCR marker and closeout

Status: accepted by RA on 2026-10-07 after source-comment and behavior-document closeout.

Goal: show the local player's off-screen designation as two overlapping chevrons and close behavior documentation.

Likely files:

- `ui/offscreen_tracker.gd` — designation flag and reusable one/two-triangle geometry.
- `tests/test_offscreen_tracker.gd` — single versus VCR marker contract.
- `README.md`, `CLAUDE.md`, `docs/matrices.md` — behavior and tuning documentation.
- `LESSONS_LEARNED.md` — review findings from this effort.

Acceptance:

- Designated off-screen marker geometry contains two same-direction triangles with a deliberate overlap.
- Ordinary markers remain a single triangle.
- Existing edge inset, overlap spreading, sensor bounds, hysteresis, paint color, and hit bursts remain unchanged.
- On-screen or unsensed targets receive no marker.
- Docs describe the designation, weapon relationship, and future-ready access seam without claiming the camera feature exists.

Checks:

```sh
~/.local/bin/godot --headless --path . -s res://tests/run_tests.gd
tools/smoke.sh
git diff --check
```

Manual acceptance uses the seven-step route in `docs/target_designation_plan.md`.
