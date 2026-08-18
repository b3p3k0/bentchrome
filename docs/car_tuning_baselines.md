# Car Tuning Baselines — real-world anchors for the feel pass

**STATUS: the balance pass LANDED 2026-07-15** — the "tuned" column below is
the shipped result (all within ±0.3s of target; anchors and bosses unmoved).
Keep this doc as the reference for future car additions and re-tunes. US units.

- **IRL 0-60** is the ballpark figure for the car's real-world analog (from
  roster lore).
- **Compressed target** is √-compression (`game ≈ √irl`): slow cars stay
  ~2× slower instead of ~10× — big rigs feel heavy without taking forever to
  reach 25 mph. Targets are suggestions; the tuning pass owns the final call.
- **Measured now** is the pre-tuning value from `tools/probes/stat_baseline.gd`
  (time to 400 px/s = 60 mph, full throttle on road, terrain profile applied).
  The F1 dashboard shows the same number live while you drag knobs.
- The new `stats.launch` axis (1-20, omit = mass-derived) is the tool for
  "torquey off the line vs needs a running start" — it moves the standing-start
  shove WITHOUT touching mass's coast/brake identity. Derived-equivalence:
  slot `21 - 2×engine_mass` reproduces today's shove; author above/below that.

| car | analog | IRL 0-60 | target | pre-pass | tuned | note |
|---|---|---|---|---|---|---|
| cyclone | escaped open-wheeler | ~2.5-3s | anchor | 0.98s | 0.98s | ANCHOR — the fleet's rabbit, untouched |
| mrghastly | old-school Harley | ~4-5s | ~2.0s | 1.18s | 1.77s | cruiser not dragster; launch 15 |
| cricket | dirt-track midget | ~4-5s | ~1.6s road | 1.28s | 1.43s | pavement tamed; dirt ratio 1.5 keeps it king of dirt |
| ghost | '60s sports car (E-Type-ish) | ~7s | ~1.9s | 1.37s | 1.77s | launch 11 pop, top end still screams; recharge 12→18 pays for the kit |
| smoky | pursuit SUV (Explorer PIU) | ~6.5s | ~2.5s | 2.25s | 2.50s | launch 13 = the authored "jumps off the line" surge |
| splatkat | compact courier hatch | ~7-8s | hold | 2.22s | 2.22s | unchanged |
| hornet | checker cab | ~13-15s | anchor | 2.28s | 2.28s | ANCHOR — the yardstick, untouched |
| bumper | '70s Cadillac land yacht | ~11-13s | ~3.6s | 4.23s | 3.43s | launch 11 V8 grunt, still a slow spool |
| coldfront | '80s plow pickup | ~13-15s | ~3.7s | 3.43s | 3.98s | launch 11 working torque; the plow is armor now (13→15) |
| warpig | HMMWV | ~13-15s | ~3.7s | 4.78s | 3.77s | **launch 15** — dead-stop diesel grunt, slow to top; +dirt/mud accel overlay |
| hammertoe | lifted monster truck | ~7-9s | ~2.9s | 3.93s | 3.02s | **launch 17, the fleet's strongest**; accel 12 (first even slot) |
| kandykane | ice cream step-van | ~20s+ | ~4.2s | 3.32s | 3.97s | launch 5 — the van winds up |
| lovebug | classic VW Beetle | ~20-27s | ~4.5s | 1.90s | 4.28s | **launch 1, accel 4** — genuinely needs a running start; handling 11 compensates; flavor reworded |
| hubcap | none (two wheels + Rex) | n/a | hold | 1.62s | 1.62s | unchanged |
| goliath | semi tractor (bobtail) | ~15-20s | boss | 8.18s | 8.18s | boss theater, untouched |

Budget note: lovebug now totals 44 (below the 49-65 advisory) **by design** —
the fleet's weakest driveline pays for water-walking + the disarm special.

Roster-external support cast (buzz_bike 1.07s / buzz_sedan 2.38s /
buzz_technical never reaches 60 — top 58.7 mph by design / goliath_ph2 3.80s /
lackey 3.38s) tunes to its role, not to realism.

Workflow per car — fast path: Settings → DEVELOPER OPTIONS → **CAR TUNER**
(grid with mph feedback, `user://` persistence) → Export → `migrate_roster_v2.py
--fold` (see docs/car_authoring.md "Tuning a car fast"). Formal checklist:
"Migrating / rescaling a car" in the same doc — change ints, re-import, read
the mph/0-60 log, confirm on F1, then re-pin whatever feel-band tests the
intentional change moves (test_stat_rebase's GOLDEN table first).
