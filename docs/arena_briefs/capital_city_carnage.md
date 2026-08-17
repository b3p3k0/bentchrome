# Capital City Carnage — arena brief

Slot 12 (second-to-last, the final regular level before Goliath). LARGE melee,
8 target cars (player + 7), 3 stations, mp_ready, `optional: true` while in
test. Interior 5632×3584 (±2816 × ±1792) — the campaign's biggest. Scene:
`levels/capital/capital_city_carnage.tscn`; shell subclass
`capital_city_carnage.gd` (headlight beams only — the storm owns its own
tint). Tests: `test_capital_city`, `test_marine_one`, `test_storm_director`,
`test_road_ribbon`; plus the global order/spawn/floor/MP gates.

## Districts and coordinates (center 0,0; 128 grid)

| Feature | Position / span | Notes |
|---|---|---|
| Potomac deep channel | x −2304..−1920, three rects (N y −1792..−160, M 160..960, S 1280..1792) | `DeepWaterZone` — lethal, airborne clears; gaps ARE the bridges |
| Shallow banks | x −2432..−2304 and −1920..−1792, segmented at the gaps | `water` terrain (slow); curbs line every deep rim ~12px land-side |
| Memorial Bridge | gap y −160..160; angled ribbon (−2464, 48)→(−1760, −48) w 224 | destructible rails ids 20/21, deck curbs, balustrade paint |
| 14th St Bridge | gap y 960..1280; ribbon y 1120 w 224 | rails ids 22/23; **rear-missile crate mid-span** |
| Arlington | west bank y −1792..640; drive ribbon x −2624 | headstone-row paint ×4, tablet clutter ×4, eternal flame, **[H1] (−2624, −896)** |
| Pentagon | (−2560, 1520) 320² solid, five-ring paint | chain-link on N + E faces (ids 54/55) |
| Lincoln terrace | FZ floor 2 (−1536, 0) 384²; steps `Ramp` (−1216, 0) high-west | temple solid + colonnade paint; layer-8 retaining N/W + E flanks; **open S rim** (edge connector) |
| Reflecting Pool | (−960, 0) 640×160 | shallow `water`, `soften_visual` off, never lethal |
| Memorial cluster | Vietnam (−1120, −240), Korean (−1120, 240), WWII (−576, 0) + 4 bollards | paint + clutter |
| Monument knoll | `DriveableHill` (0, 0), summit 384², grades 192 | grass; obelisk core solid + giant SE shadow; **summit mine + power crates (floor 2)** |
| Mall panels | (1184, ±192) 1472×256 grass | center lane y ±64 asphalt; jump pad (768, 0) |
| Capitol terrace | FZ floor 2 (2432, 0) 448×640; steps `Ramp` (2080, 0) high-east | building solid straddles floors (layer 28); **open S rim**; security barriers ids 47/48 |
| White House | solid (0, −1424) 448×160; lawn (0, −1216) | **iron-fence ring ids 10-17** (8 × 30 HP, group `wh_fence`); garden bushes + hydrant |
| Marine One | (64, −1136), id 1 | see phase table below; door (0, −1344), exit (2600, 1560) |
| Crash site | Ellipse (0, −640), dormant | 2 junk hulks, 2 debris clutter, power/homing/rear cache — wakes only on the air kill |
| Constitution Ave | ribbon y −448 w 192 | **6 food trucks ids 30-35** (4 liveries) + vendors; crosswalks, lights |
| Pennsylvania Ave | diagonal (352, −1120)→circle→(2304, −192) | ribbon pair + traffic circle ring (1280, −640) r≈288, fountain core |
| Maryland Ave | diagonal (−1760, 1120)→(96, 512) | barrel cluster ids 51-53 on the shoulder |
| K Street | ribbon y −1600 w 176 | **[H2] (320, −1600)**, crate/barrel cluster ids 42-45, vagrants |
| Capitol south | **[H3] (2240, 1216)** | homing crate beside it |
| City blocks | NE ×3, SW ×2, SE ×2, museums N ×1 / S ×3 | building_deco, wall_face facades, alley junk id 49 |

## Spawns (all ≥700px apart; props ≥300 from AI starts)

Player (0, 896) Mall south-center. Enemies: Arlington N (−2624, −1216), K St W
(−896, −1600), K St E (1664, −1600), Capitol plaza (2432, 768), SE blocks
(1408, 1408), Maryland Ave (−960, 1216), Mall W (−960, 224).

## The storm (`storm_director.gd` statics)

Cycle: thunder boom → `THUNDER_LEAD` 0.45s → `FLASH` 0.12s (tint 1.55, over-white)
→ `DIP` 0.35s (tint 0.3 — eyes readjust) → `RECOVER` 0.9s ease to `BASE` 0.56.
Cadence 8–20s seeded; `DISTANT_CHANCE` 0.35 = boom only. `thunder` sfx is
drop-in/no-op. Rain: `RainSquall` intensity 1.3, wind (190, 820). All
cosmetic-local; each LAN client rolls its own storm.

## Marine One (`marine_one.gd` statics; contract per docs/signature_destructibles.md)

| Phase | Trigger | Counterplay window |
|---|---|---|
| PARKED (260 HP) | — | free shots behind the fence problem |
| SPOOLING 6s | first `wh_fence` breach (host census); figure sprints, searchlight on | the easy kill |
| CLIMBING 12s | spool ends | altitude stages ride floor bits: 0-⅓ floor 1 (anyone), ⅓-⅔ floor 2 (terraces/knoll), ⅔-1 floor 3; position/lift derived from the phase clock |
| ESCAPED | climb completes | hidden, collisionless tombstone — bounty missed |
| DYING 2.2s | killed while climbing | deterministic smoke spiral to the Ellipse; SP pauses for the cutscene (skipped if no live player; MP presents live) |
| DEAD | — | lawn wreck (ground kill) or crash site: environmental blast (r 380, 45→12 dmg, attribution cleared) + dormant props/cache activate once |

Any attributed kill pays `Economy.award_kill(&"mini_boss")` = 2,500 scaled.
Net: flags ladder (ALIVE/ARMED/ACTIVE/WARNING/**ESCAPE**), `timer_ms` elapsed
clock, apply-twice-safe, initial-state death suppression.

## Net-id ledger (37 ids, unique — pinned by test_capital_city)

| Range | Entities |
|---|---|
| 1 | Marine One |
| 10-17 | White House iron fence ring |
| 20-23 | bridge rails (Memorial N/S, 14th N/S) |
| 30-35 | food trucks 1-6 |
| 40, 41, 50, 56, 57 | derelicts (Constitution ×2, Independence, bridgehead, Penn) |
| 42-49, 51-55 | breakable cover (K St crates/barrels, circle kiosk, Capitol barriers, alley junk, Maryland barrels, Pentagon chain-link) |

Crash-site props carry NO ids — their activation rides Marine One's flags.

## Human acceptance route

1. Boot via SINGLE BATTLE → Capital City Carnage. Confirm the storm: rain
   slashing, thunder (silent until asset), flash then the dark dip — readable,
   not seizure-y (knobs in storm_director statics).
2. Drive west on Constitution, through the food-truck line (vendors at the
   windows), across the angled Memorial Bridge. Nose into the shallow bank
   (slow), then the deep channel (sink death — respawn); jump clears it.
3. Arlington: drive the cemetery lane past the headstone rows to [H1]; south
   to the Pentagon, smash the chain-link, cross the 14th St Bridge grabbing
   the rear-missile crate mid-span.
4. Climb the Lincoln steps to the colonnade terrace; hop the open south rim.
   Ford the Reflecting Pool (slow, harmless). Crest the Monument knoll for
   the mine + power crates. Climb the Capitol steps; dive its south rim.
5. Run Pennsylvania Avenue end to end — diagonal read, circle flows, rotated
   blocks face the avenue. Check AI takes the circle cleanly.
6. Breach the White House fence: figure sprints, rotor spools — kill it on
   the lawn once (bounty pops), then on a Restart let it climb and chase it:
   ground fire loses it at stage 2; race up a terrace to keep the shot; kill
   it mid-climb → SP cutscene, spiral, Ellipse crash, blast, debris + cache.
   Let it escape once: it shrinks SE and is gone.
7. MP smoke: host two windows, melee fields 8, break a fence + a truck on the
   host and confirm client tombstones; join late mid-flight and confirm the
   chopper converges.
