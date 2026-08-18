# Capital City Carnage — arena brief

Slot 12 (second-to-last, the final regular level before Goliath). LARGE melee,
8 target cars (player + 7), 3 stations, mp_ready, `optional: true` while in
test. Interior 6144×3840 (±3072 × ±1920) — the campaign's biggest. FLAT by
design after the first playtest (smooth playability beats clever
architecture): the only elevation is the Monument knoll `DriveableHill`.
Scene: `levels/capital/capital_city_carnage.tscn`; shell subclass
`capital_city_carnage.gd` (headlight beams only — the storm owns its own
tint). Tests: `test_capital_city`, `test_marine_one`, `test_storm_director`,
`test_road_ribbon`; plus the global order/spawn/floor/MP gates.

## Districts and coordinates (center 0,0; 128 grid)

| Feature | Position / span | Notes |
|---|---|---|
| Potomac deep channel | x −2304..−1920, three rects (N y −1920..−160, M 160..960, S 1280..1920 — wall to wall) | `DeepWaterZone` — lethal, airborne clears; gaps ARE the bridges (and are exactly what `Mode.DETOUR`'s rect-end routing finds) |
| Shore banding | outward from tarmac: **guardrail (ids 60-65, x −2474/−1750) → patchy dirt shore (96px) → shallow water (64px) → deep channel**, mirrored both sides, segmented at the gaps; river runs wall to wall (±1920) | AI curbs stay FLUSH at the deep rims (bridge cross-curbs mirror Memorial's flush mount; `tests/test_hazard_coverage.gd` lints it) |
| Memorial Bridge | gap y −160..160; STRAIGHT deck (−2752, 0)→(−1616, 0) | rails ids 20/21; tees into **Riverfront Drive (x −1696, full height)** on the east bank |
| 14th St Bridge | gap y 960..1280; deck →(−1616, 1120) | rails ids 22/23; tees into Riverfront Drive; **rear-missile crate mid-span** |
| Arlington | west bank x −3072..−2432 (640 wide); drive ribbon x −2752 | four headstone-row columns CLEAR of drive + bridge corridor, tablet clutter, eternal flame NW, **[H1] (−2752, −960)** |
| Pentagon | OVERSIZED into the SW corner: deco (−2960, 1936) ×880, mostly off-board (implied scale); on-board solid (−2836, 1800) 460×240 | chain-link ids 54/55 on the exposed faces |
| Lincoln plaza | temple solid (−1456, 0) — EAST of Riverfront Drive, off the bridge lane; deco 320×416 | FLAT: gravel plaza + stepped plinth + peristyle + east stair cascade |
| Reflecting Pool | (−864, 0) 736×160 | **SOLID coping walls** (PoolWalls, layer 12) — cars cannot ford it; `pool_surround` coping + algae paint; sidewalk ring outside |
| Memorial cluster | Vietnam (−1024, −260), Korean (−1024, 260), WWII (−296, 0) — clear of the pool | plaza pads + bollards + **invisible-core blockers** (MemorialBlockers, layer 12): indestructible, gently bumped, paint marks the spot |
| Monument knoll | `DriveableHill` (320, 0), summit 384², grades 192 | THE high ground; obelisk + flag ring + shadow; **summit mine + power crates (floor 2)**; jump pad (960, 0) |
| Mall panels | (1408, ±192) 1792×256 grass + center sidewalk walk | jump pad (832, 0) |
| Capitol | building (2944, 0) 256×640 flush east wall | FLAT west plaza + step cascade (paint); barriers ids 47/48 at (2368, ±256) |
| White House | solid (0, −1536) 448×160; lawn (0, −1312) 640×448 | **iron-fence ring ids 10-17** (8 × 30 HP, group `wh_fence`); executive-drive paint, garden bushes + hydrant |
| Marine One | (64, −1200), id 1 | door (0, −1400) — clear of the facade; exit (2880, 1700) |
| Crash site | Ellipse (0, −768), dormant | 2 junk hulks, 2 debris, power/homing/rear cache — wakes on the air kill only |
| Constitution Ave | ribbon y −512 | **6 food trucks ids 30-35** (96×44 — KandyKane class) + vendors; derelicts run `pool_override` (no monster trucks in DC) |
| Pennsylvania Ave | (512, −1728)→(1184, −960) and (1725, −581)→(2560, −256) | full diagonal from K Street through the circle |
| Traffic circle | ring at (1408, −704) r≈288 | fountain core solid + paint; kiosk id 46 NE |
| Maryland Ave | (−1760, 1120)→(−704, 704)→(160, 576) | barrel cluster ids 51-53; endpoint dies under Independence |
| K Street | ribbon y −1728 | **[H2] (320, −1728)**, crate/barrel cluster ids 42-45, vagrants |
| Side streets | verticals x −576, 1664, 2560 (N) and −192, 1792 (S) | dashed-white marks |
| Pocket parks | (−1152, −1088), (2240, −768), (−1024, 1568) — 320² each | pines/bushes/clutter + sidewalk rings |
| Capitol south | **[H3] (2496, 1312)** | homing crate beside it |
| City blocks | NE ×3, SW ×2, SE ×2, museums N ×1 / S ×3 | building_deco facades; alley junk id 49 |

## Spawns (all ≥700px apart; props ≥300 from AI starts)

Player (0, 1024) Mall south-center. Enemies: Arlington rows (−2900, −1344), K St W
(−896, −1728), K St E (2048, −1728), Capitol plaza (2560, 896), SE blocks
(1536, 1536), Maryland Ave (−896, 1152), Mall W (−640, 288).

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
| SPOOLING 6s | first `wh_fence` breach (host census); **POTUS + three-guard detail sprint from the door**, searchlight on | the easy kill |
| CLIMBING 12s | spool ends | TWO altitude stages ride floor bits: 0-½ floor 1 (anyone), ½-1 floor 2 (**knoll shooters keep the shot**); position/lift derived from the phase clock |
| ESCAPED | climb completes | hidden, collisionless tombstone — bounty missed |
| DYING 2.2s | killed while climbing | deterministic smoke spiral to the Ellipse; SP pauses for the cutscene (skipped if no live player; MP presents live) |
| DEAD | — | lawn wreck (ground kill) or crash site: environmental blast (r 380, 45→12 dmg, attribution cleared) + dormant props/cache activate once |

Any attributed kill pays `Economy.award_kill(&"mini_boss")` = 2,500 scaled.
Net: flags ladder (ALIVE/ARMED/ACTIVE/WARNING/**ESCAPE**), `timer_ms` elapsed
clock, apply-twice-safe, initial-state death suppression.

## Net-id ledger (43 ids, unique — pinned by test_capital_city)

| Range | Entities |
|---|---|
| 1 | Marine One |
| 10-17 | White House iron fence ring |
| 20-23 | bridge rails (Memorial N/S, 14th N/S) |
| 30-35 | food trucks 1-6 |
| 40, 41, 50, 56, 57 | derelicts (Constitution ×2, Independence, bridgehead, Penn) |
| 42-49, 51-55 | breakable cover (K St crates/barrels, circle kiosk, Capitol barriers, alley junk, Maryland barrels, Pentagon chain-link) |
| 60-65 | river guardrails (E and W deep rims, N/M/S) |

Crash-site props carry NO ids — their activation rides Marine One's flags.

## Human acceptance route

1. Boot via SINGLE BATTLE → Capital City Carnage. Confirm the storm and —
   critically — drive the FULL map hunting invisible collisions: every stop
   must be a visible rail, wall, building, or water. Nothing else.
2. West on Constitution through the food-truck line (trucks read as trucks
   now), across the straight Memorial Bridge. Nose the shallow bank (slow),
   smash a river guardrail, take the plunge (sink death); jump clears it.
3. Arlington: the lane runs CLEAN between the headstone columns to [H1];
   Pentagon chain-link, 14th St Bridge, rear-missile crate mid-span.
4. Lincoln plaza reads as the memorial from cold; ford the pool past the
   algae and coping; crest the knoll for the crates; Capitol plaza reads
   from cold. Check the sidewalk trails ring every greenspace.
5. Penn Ave from K Street to the Capitol through the circle; side streets
   and pocket parks break up the districts.
6. Breach the White House fence: POTUS + three guards sprint clean (no
   wall-hugging), rotor spools — kill it grounded once; on a restart chase
   the climb: ground fire loses it halfway, the knoll keeps the shot; the
   air kill spirals into the Ellipse with blast + debris + cache; an escape
   shrinks away SE.
7. MP smoke: host two windows, melee fields 8, tombstones converge, late
   join mid-flight converges.
