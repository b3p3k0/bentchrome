# The Mods Garage — project workspace

Design + architecture home for the garage feature (economy, shop UI, mod
application). Start here; each doc owns one concern.

| doc | owns |
|---|---|
| [economy.md](economy.md) | currency, earn/lose rules, difficulty scaling, price bands |
| [ui_concepts.md](ui_concepts.md) | shop UI proposals + SVG mockups (`mockups/`) |
| [recon.md](recon.md) | code seams the feature hooks into, as of 2026-07-19 |
| ../garage_seams.md | the pre-built backend contract (`VehicleLoadout.compose`, persistence, LAN) |
| ../net_dev_request_data_tuning.md | OPEN net-dev request the garage must not collide with |

## Status

- **Phase: PLAYABLE (branch `feature/garage`).** The standalone in-engine
  playable is live — launch it scene-direct, no live-flow wiring exists:

      godot --path . res://ui/garage/garage_playable.tscn

  Pieces: `game/economy.gd` (BOLTS leaf + difficulty knobs),
  `assets/data/garage_catalog.json` + `ui/garage/garage_catalog.gd`
  (validated catalog), `ui/garage/garage.tscn` (the Concept-B shop with
  live compose-driven delta previews), `ui/garage/garage_playable.tscn`
  (9-stop campaign sim: receipts, fork, force-toggles, economy knobs,
  export to `user://econ_export.json`). Tests: `test_economy`,
  `test_garage_catalog`. Numbers remain draft — tune by playing, export,
  fold back into economy.md.
- Branch flow: `feature/garage` → merge to `development` → promotion to
  `main`. The plug-in phase (GameState funds, end-screen fork, prop
  last_hitter, station billing, HUD wallet) is NOT started.
- **Decided (Kevin, 2026-07-19):** currency = **BOLTS**, start at 0; earned
  by destroying enemies/destructibles/soft targets (size-proportionate,
  per-level salvage cap); lost as a PERCENTAGE of current funds (destroyed
  −20%; falls/sinks harsher −30%; health station use −10%); difficulty =
  identical earnings, gentler penalties + cheaper prices on easier tiers;
  **parts survive death** (money is the only loss); staged parts are
  prerequisite chains priced per increment (NA→boost → blower → injectors);
  garage opens BETWEEN levels off the win screen (KEEP ROLLIN' / PIT STOP).
- **UI:** two SVG concepts in ui_concepts.md — soft rec: build Concept B's
  catalog machine first, wrap Concept A's painted room around it later.
- **Open questions:** tracked at the bottom of economy.md.

## Ground rules

- **Branch flux warning:** a branch→main promotion is in flight (2026-07-19).
  Every reference in these docs is by SYSTEM/SEAM NAME, not line number —
  re-verify seams in recon.md before implementation starts.
- v1 is SINGLE-PLAYER CAMPAIGN only. MP garage rides the picks+mod-ids
  contract in ../garage_seams.md later (matrices already reserves a
  "garage sync" netplay row).
- Money is RUN STATE (like lives/score): lives on GameState, never persisted
  to disk, resets with the campaign.
