# Freeway Firefight arena brief

Freeway Firefight is the campaign's eight-car raised-highway melee. A
north-south freeway plate occupies the west side, a dirt lowland with a farm
and truck stop occupies the east, and a country road climbs from the lowland
onto a floor-3 overpass above both highway lanes. Five road grades, four grass
embankment grades, two merge lanes, three jump pads, and deliberate one-floor
deck and shelf drops connect the route graph. The same scene supports campaign
and eight-car LAN play.

## Profile

| Field | Value |
|---|---|
| Campaign slot | 4 |
| Mode / encounter | regular arena / melee |
| Size class | large |
| Interior | `4096×5376` (`22,020,096 px²`) |
| Target cars | 8 (`2,752,512 px²` gross per car): player + 7 rivals |
| Stations | 3 |
| Floors | floor 1 lowland; floor 2 highway plate, landing, and shelves; floor 3 overpass deck |
| Dominant terrain | asphalt highway over a dirt lowland |
| Accents | grass shoulders, median, embankments, and pasture; dirt patches; shallow-water pond; crop rows |
| LAN | MP-ready, 8 cars |

Arena bounds are `x=-1088…3008`, `y=-2688…2688`. The floor-2 highway plate is
`x=-1088…1088`; the floor-1 lowland is `x=1088…3008`.

## Topology and floor graph

`levels/freeway/freeway_plan.gd` is the signed layout. This picture is not to
scale; arrows on grades and pads point in the authored climbing or launch
direction.

```text
                               north ↑
       RAISED HIGHWAY PLATE, FLOOR 2       LOWLAND, FLOOR 1
  ┌──────────────────────────────────┬──────────────────────────┐
  │ southbound lane   northbound lane╲ MergeN ← ShelfN         │
  │       JumpW ↓                    │  farm + pasture          │
  │════════ COUNTRY-ROAD DECK F3 ════╪← RampA─LANDING F2←RampB─┤ road
  │ RampW ↑          JumpE ↑         │                          │
  │                         MergeS ╱  │  ShelfS ← RampS ↑       │
  │       grass median               │  BankS ← JumpLowland     │
  │ lane-end barriers at both walls  │         truck stop       │
  └──────────────────────────────────┴──────────────────────────┘
```

The floor regions are:

| Region | Floor | Rectangle |
|---|---:|---|
| `FZPlate` | 2 | `Rect2(-1088,-2688,2176,5376)` |
| `FZLowland` | 1 | `Rect2(1088,-2688,1920,5376)` |
| `FZDeck` | 3 | `Rect2(-1088,-928,2176,320)` |
| `FZLanding` | 2 | `Rect2(1472,-928,256,320)` |
| `FZShelfN` | 2 | `Rect2(1088,-2304,256,512)` |
| `FZShelfS` | 2 | `Rect2(1088,256,256,512)` |

All five road grades use road terrain and the standard `120 px/s²` downhill
pull.

| Grade | Floors | World rectangle | High direction | Guarding |
|---|---|---|---|---|
| `RampW` | 2↔3 | `Rect2(-1088,-608,256,384)` | north | built-in side rails with pointed caps |
| `RampA` | 2↔3 | `Rect2(1088,-928,384,320)` | west | authored `RampAN` / `RampAS` layer-12 barricades |
| `RampB` | 1↔2 | `Rect2(1728,-928,384,320)` | west | authored `RampBN` / `RampBS` layer-12 barricades |
| `RampN` | 1↔2 | `Rect2(1088,-1792,256,512)` | north | built-in side rails with pointed caps |
| `RampS` | 1↔2 | `Rect2(1088,-256,256,512)` | south | built-in side rails with pointed caps |

The plate/lowland seam is otherwise four west-climbing, 256px-deep grass
embankments. Each is a paintless, unrailed `Ramp` from floor 1 to floor 2 with
the standard `120 px/s²` pull, followed immediately in scene order by a
matching `freeway_deco` embankment skin.

| Bank | World rectangle | Paired connector centers |
|---|---|---|
| `BankNE` | `Rect2(1088,-2688,256,360)` | `ConBankNEUp/Down` at `(1216,-2508)` |
| `BankN` | `Rect2(1088,-1280,256,328)` | `ConBankNUp/Down` at `(1216,-1116)` |
| `BankMid` | `Rect2(1088,-584,256,328)` | `ConBankMidUp/Down` at `(1216,-420)` |
| `BankS` | `Rect2(1088,792,256,1896)` | `ConBankS1Up/Down` at `(1216,1024)`; `ConBankS2Up/Down` at `(1216,1740)`; `ConBankS3Up/Down` at `(1216,2432)` |

Every road grade also has paired up/down connectors at its center.
`ConDeckDownN` at `(0,-968)` and `ConDeckDownS` at `(0,-568)` describe the open
north/south floor-3 deck drops to the plate. `ConPlateDownN` at `(1048,-2000)`
describes the eastbound floor-2 drop over `FZShelfN`'s east ledge. The three
jump connectors share their pads' positions:

| Pad / connector | Position | Transition | Authored approach | Proven landing |
|---|---|---|---|---|
| `JumpW` / `ConDeckJump` | `(-640,-1280)` | floor 2→3 | south | `FZDeck` |
| `JumpE` / `ConDeckJumpE` | `(640,-256)` | floor 2→3 | north | `FZDeck` |
| `JumpLowland` / `ConLowlandJump` | `(1536,2400)` | floor 1→2 | west | `BankS` or `FZPlate`, west of the bank's foot |

All three pads retain the default `launch_rivals = true`. Their landings are
live-simulated in `tests/test_freeway_level.gd`; the east-lane simulation also
continues through the deck's north edge and verifies the floor-2 landing.
`JumpLowland`'s clear run-up occupies `x=1648…2098`. There are no pits or
deep-water kill zones.

## Surfaces

One asphalt polygon covers the arena substrate. On the plate, grass occupies
the two `256×5376` side shoulders, `InfieldN` at
`Rect2(-448,-2688,896,2560)`, and `InfieldS` at
`Rect2(-448,128,896,2560)`. The two infields carry the median grass to the
north and south walls. `DirtN` is `384×384` centered at
`(-128,-1472)`; `DirtS` is `384×512` centered at `(128,1408)`. The infield pond
is a `384×384` shallow-water zone centered at `(0,448)`.

`LowlandDirt` covers the complete floor-1 rectangle. Higher-priority surface
zones then establish the destinations:

| Surface | Rectangle | Terrain / priority |
|---|---|---|
| `TruckStopLot` | `Rect2(1664,320,1344,1856)` | road / 10 |
| `FrontageRoad` | `Rect2(2560,-608,256,928)` | road / 10 |
| `LandingRoad` | `Rect2(1472,-928,256,320)` | road / 10 |
| `CountryRoad` | `Rect2(2112,-928,896,320)` | road / 10 |
| `ShelfNRoad` | `Rect2(1088,-2304,256,512)` | road / 10 |
| `ShelfSRoad` | `Rect2(1088,256,256,512)` | road / 10 |
| `Pasture` | `Rect2(1400,-2688,1608,1688)` | grass / 5 |

Two priority-10 road polygons connect the shelves diagonally to the east
carriageway. The east carriageway is northbound and the west carriageway is
southbound, following right-hand traffic.

| Merge | `Plan.MERGES` polygon | Directional role |
|---|---|---|
| `MergeN` | `[(1088,-2304),(1088,-1942),(768,-2262),(768,-2624)]` | leaves the north `362px` of `FZShelfN` and runs north-west into the northbound carriageway |
| `MergeS` | `[(768,726),(768,1088),(1088,768),(1088,406)]` | leaves the northbound carriageway south-west of `FZShelfS` and reaches the shelf's south `362px` |

The country road has one dashed-yellow centerline from `(3008,-768)` to
`(2112,-768)`. `RoadMarks/LaneW` and `RoadMarks/LaneE` both run from
`y=-2688` to `y=2688`; the highway has no end-loop road surface. `Field` adds
paint-only crop rows over `Rect2(2176,-1920,768,640)`. `OverpassDeck` paints
the full `2176×320` floor-3 deck at z 1 over `OverpassShadow` at z 0. Its
`south_gaps = [(-1088,-832)]` opens the south kerb and edge line over
`RampW`'s mouth; `north_gaps` is empty. The deck and truck-stop canopy use the
shared under-fade so floor-2 and floor-1 traffic remains readable below them.

## Combat and economy

The eight starts are direct root children:

| Start | Position | Floor |
|---|---|---:|
| Player | `(0,2304)` | 2 |
| Enemy 1 | `(-640,-2240)` | 2 |
| Enemy 2 | `(640,-2240)` | 2 |
| Enemy 3 | `(-640,0)` | 2 |
| Enemy 4 | `(640,0)` | 2 |
| Enemy 5 | `(-640,1408)` | 2 |
| Enemy 6 | `(896,960)` | 2 |
| Enemy 7 | `(1792,1088)` | 1 |

The player start lies on the south median grass.

The repair stations keep the shared defaults: 2 uses, a 45s level-wide
cooldown, and a 2s treatment. Their instances remain floor-ungated, while
their physical locations resolve as follows:

| Station | Position | Physical floor |
|---|---|---:|
| `HealthStation1` | `(0,-2240)` | 2 |
| `HealthStation2` | `(2432,2048)` | 1 |
| `HealthStation3` | `(0,0)` | 2 |

`HealthStation1` lies on the north median grass.

All ammo crates respawn after the shared 20s default.

| Pickup | Kind / amount | Position | Physical floor |
|---|---|---|---:|
| `AmmoStandard1` | Standard / 2 | `(-640,-1856)` | 2 |
| `AmmoStandard2` | Rear / 2 | `(640,1856)` | 2 |
| `AmmoHoming1` | Homing / 1 | `(0,-704)` | 3 |
| `AmmoHoming2` | Homing / 1 | `(0,1792)` | 2 |
| `AmmoPower1` | Power / 1 | `(-384,-1088)` | 2 |
| `AmmoPower2` | Power / 1 | `(832,2560)` | 2 |
| `AmmoMine1` | Land Mine / 2 | `(256,0)` | 2 |
| `AmmoJump1` | Jump Mine / 1 | `(0,2432)` | 2 |
| `AmmoStandard3` | Standard / 2 | `(2048,1300)` | 1 |
| `AmmoMine2` | Land Mine / 2 | `(2912,2040)` | 1 |
| `AmmoPower3` | Power / 1 | `(2560,-2560)` | 1 |

The deck Homing crate and farm Power crate explicitly author floors 3 and 1.
The remaining crates use the shared ground-bit behavior at unambiguous XY
locations.

Highway cover includes twelve 20-HP floor-2 rails, four 60-HP debris blocks,
two derelict cars, and two permanent `128×256` crossover pillars at
`(-512,0)` and `(512,0)`. Four `64×96`, 400-HP destructible overpass pillars at
`(-832,-768)`, `(-448,-768)`, `(448,-768)`, and `(832,-768)` stand on lane
edges rather than inside either traffic lane. Eight floor-2 `128×32`, 80-HP
`barrier` blocks stand flush against the north and south boundary, two per
carriageway end:

| End | Barriers and centers |
|---|---|
| north, west carriageway | `BarrierNW1 (-704,-2672)`; `BarrierNW2 (-576,-2672)` |
| north, east carriageway | `BarrierNE1 (576,-2672)`; `BarrierNE2 (704,-2672)` |
| south, west carriageway | `BarrierSW1 (-704,2672)`; `BarrierSW2 (-576,2672)` |
| south, east carriageway | `BarrierSE1 (576,2672)`; `BarrierSE2 (704,2672)` |

## Rails, embankments and barricades

Sixteen floor-3 breakaway rails line the overpass deck. Each has 12 HP,
`z_index = 2`, and a stable ID from 100 through 115. The north run has eight
`256×12` segments centered at `y=-920`; the south run has eight `224×12`
segments centered at `y=-616`. Segment gaps are 16px, rail centerlines sit 8px
inside the deck edge, no segment exceeds 256px, the south-west opening clears
`RampW`, and both runs stop 16px before the east end for `RampA`.

There are no AI curbs on the deck. Curbs are floor-blind and would wall off the
two floor-2 lanes beneath it. Cars may break a rail and drop from the deck to
the plate; the two authored edge connectors make those routes legible to AI.

The plate/lowland seam is a driveable grass grade everywhere that a road grade
or shelf does not occupy it. `plate_east_edge_covered()` proves that a bank,
road grade, shelf, or barricade covers every point on the seam. The embankment
skin's four bands run lightest at local `-y`, the crest, to darkest at local
`+y`, the foot.

The barricades use two collision recipes:

- Layer 12 is obstacle + floor-1. `ShelfN_E`/`ShelfN_N` and
  `ShelfS_E`/`ShelfS_S` barricade the shelf east and cap edges;
  `LandingN`/`LandingS` and `RampAN`/`RampAS`/`RampBN`/`RampBS` barricade the
  overpass approach. Floor-1 cars stop at these faces while floor-2 cars ignore
  them. `ConPlateDownN` keeps the upper shelf's east drop legible to AI.
- Layer 20 is obstacle + floor-2. `DeckEastStop` occupies
  `Rect2(1064,-928,24,320)` and prevents plate traffic beneath the deck from
  entering `RampA` at the wrong floor.

`Ramp` paints the two long sides of an ordinary grade, never a line across its
high or low end. Its opt-in `rail_caps` adds a 24px pointed cap at both ends of
each built-in rail; `RampN`, `RampS`, and `RampW` enable it so diagonal impacts
slide past their rail ends.

## Living site

### Hate's Travel Stop

The floor-1 truck stop occupies the south-east lowland. Its lot is
`Rect2(1664,320,1344,1856)` and the frontage road connects its north edge to
the country road. `Store` is a `384×256`, 260-HP storefront at `(2400,448)`;
its south face carries a `340×56` Signage band reading `HATE'S TRAVEL STOP`.
The `512×288` canopy at `(2400,864)` rides z 1 and under-fades over four 40-HP
gasoline pumps at `(2208,816)`, `(2208,912)`, `(2592,816)`, and `(2592,912)`.

The diesel chain occupies the east side of the lot: two 40-HP pumps at
`(2880,1152)` and `(2880,1248)`, a `320×72`, 90-HP tanker at `(2624,1200)`,
and three `40×40`, 30-HP barrels at `(2900,1340)`, `(2952,1372)`, and
`(2916,1424)`. A tanker blast reaches 200px from the hull spine for 40 flat
damage; each barrel reaches 130px for 25. The live test proves that destroying
the tanker kills both diesel pumps and begins the barrel chain while a Health
body 300px off the tanker's flank remains untouched.

Two `320×72`, 120-HP semis stand at `(2016,1650)` and `(2496,1650)`. Two
`256×256`, 260-HP storefront garages at `(2176,2048)` and `(2688,2048)` face
each other across the 256px drive-through repair bay. Two local 50-HP crates
sit at `(2660,600)` and `(2730,640)`. `PylonSign` at `(1760,400)` is a
`256×200` `z_index = 1` sign reading `HATE'S` / `DIESEL 4.99`; `LotMarks` at `(1832,1950)`
paint a `336×200` parking row. The lot also owns exactly seven clutter pieces:
cones at `(2800,1080)`, `(2820,1330)`, and `(2760,1460)`; trash at
`(1900,800)` and `(2700,1870)`; a hydrant at `(2180,600)`; and a sign at
`(1700,720)`.

The `z_index = 1` `448×160` billboard at `(1600,1900)` stands south of the
interchange before the exit. It reads `HATE'S TRAVEL STOP` / `NEXT EXIT`, with
weathering `0.6` and one dead letter. Billboard and pylon signage build the
shared `UnderFade` area and ease to `UnderFade.ALPHA` while a body renders
beneath them; the storefront band does not.

### Farm

The north-east farm rests on the priority-5 pasture. The `768×640` crop field
is centered at `(2560,-1600)`. A `320×256`, 220-HP barn stands at
`(2560,-2300)`. Seven `64×64`, 20-HP hay bales stand at `(2300,-1540)`,
`(2460,-1540)`, `(2620,-1540)`, `(2780,-1540)`, `(2380,-1380)`,
`(2540,-1380)`, and `(2700,-1380)`. Three `160×16`, 15-HP fences stand at
`(2240,-1232)`, `(2496,-1232)`, and `(2752,-1232)`; a `96×96`, 60-HP junk
pile stands at `(2864,-2340)`. `AmmoPower3` waits against the north boundary.

Farm props use local destruction and have no arena IDs.

### Ambient life

All eleven actors are cosmetic-local, nonblocking floor-1 soft targets.

| Population | Count / kind | Center and authored area | Movement |
|---|---|---|---|
| `Truckers` | 5 truckers | `(2375,1325)`, `1050×550` | wander |
| `Clerks` | 2 clerks | `(2400,630)`, `200×0` | stationary at `(2300,630)` and `(2500,630)` |
| `LotDog` | 1 dog | `(2400,1250)`, `1100×1700` | wander |
| `Hitchhiker` | 1 hitchhiker | `(1400,-1470)`, `0×0` | stationary, facing the on-ramp |
| `FarmHands` | 2 farm hands | `(2560,-1600)`, `768×640` | wander |

## Arena-state identities

IDs are unsigned 16-bit values unique within the scene. The 31 opted-in
entities are the deck rails and truck-stop landmarks.

| IDs | Entities |
|---|---|
| 100–107 | `RailDeckN01`–`RailDeckN08` |
| 108–115 | `RailDeckS01`–`RailDeckS08` |
| 200 | `Tanker` |
| 201–202 | `DieselPump1`–`DieselPump2` |
| 203–205 | `Barrel1`–`Barrel3` |
| 206–209 | `Pump1`–`Pump4` |
| 210 | `Store` |
| 211–212 | `GarageW`–`GarageE` |
| 213–214 | `Semi1`–`Semi2` |

Destroyed synced props remain collisionless visible tombstones. The plan's
`TRUCK_STOP_IDS` dictionary and computed `RAILS` order are the identity ledger;
the level test rejects missing, duplicate, or extra positive IDs.

## Measured baselines

These are comparison baselines for any later route, AI, wall, rail, or
furnishing change.

Bot lab baseline: 12 matches × 7 stock rivals, shipping governor, 180s.

| Metric | Raised highway | Flat reference |
|---|---:|---:|
| Car-matches | 84 | 72 |
| Deaths | 29 | 25 |
| Environmental deaths | 4, all fuel-chain final hits | 0 |
| Stationary share of car-time | 8.6% | 9.2% |
| Worst single car stationary | 17.0% (Kandy Kane) | 18.3% |
| Wall hits per car | 35.5 | not recorded |
| Distance per car | 38,647px | not recorded |
| Pickups per car | 1.44 | not recorded |

The environment deaths come from the truck stop's fuel chain. This arena has
no pits.

Stall baseline: 8 seeds × 7 stock rivals, 180s. Rivals were stalled for 3.0%
of car-time; the longest stall was 5.3s; no cars fell. No 128px cell accumulated
more than 10.5s of stall time across the eight matches. The flat reference
measured 3.1% stalled time and a 6.4s longest stall.

## Changing the layout

The plan file owns the numbers. Change `ARENA_RECT`, `FLOOR_ZONES`, `RAMPS`,
`BANKS`, `MERGES`, `LANE_END_BARRIERS`, `WALLS`, `JUMP_LOWLAND`,
`COUNTRY_ROAD`, `FARM_FIELD`, `PASTURE`, `TRUCK_STOP`, or `TRUCK_STOP_IDS`
there first. `RAILS` is derived from the deck plus the `RampW` and `RampA`
openings by `_build_rails()`; do not hand-invent a second rail layout. The scene
is the authored mirror rather than generated output, so update its matching
zones, grades, collision, paint, connectors, and instances after the plan.

| File | Owns |
|---|---|
| `game/scene_flow.gd` | campaign slot/profile and eight-car LAN map entry |
| `levels/freeway/freeway_plan.gd` | signed rectangles, floors, road grades, banks, merges, barricade layers, lane-end barriers, lowland pad position, site footprints, computed rail rectangles, and truck-stop IDs |
| `levels/freeway/freeway.tscn` | the plan mirror plus surfaces, connectors, pads, props, economy, ambience, starts, boundary, HUD, and authored exceptions |
| `levels/freeway/freeway_deco.gd` | paint-only deck, shadow, canopy, embankment, lot marks, and crop rows; deck kerb/edge gaps and deck/canopy under-fade |
| `environment/ramp.gd` | floor adoption, grade force, long-side outline, built-in rails, and opt-in pointed rail caps |
| `environment/signage.gd` | paint-only billboard, pylon, and band text with fit/weather/dead-letter knobs, billboard/pylon under-fade, and parent-death visibility |
| `environment/destructible_block.gd` | temporary cover, road-site styles, facing, flatten/restore signals, and the barrel/tanker blast table |
| `tests/test_freeway_level.gd` | static plan/scene parity plus live road grades, banks, merges, barricades, pads, garage, ambience, and chain reactions |

The test runner has a 120s ceiling. Structural Freeway checks reuse one shared
instantiated level, while live simulations own their instances and stop as
soon as the tested result is established.

## Named exceptions

### No AI curbs on the deck

The overpass deck has breakaway rails but no `HazardCurb`s. A curb has no floor
gate, so one authored along the deck edge would also become an invisible wall
across the floor-2 highway below. Deck edge connectors and live pad/edge
simulations provide the navigation and landing proof instead.

### Farm props are unsynchronized

`Barn`, `Hay1`–`Hay7`, `Fence1`–`Fence3`, and `FarmJunk` keep
`arena_net_id = 0`. They are ordinary local destruction rather than shared
arena-state landmarks. Keep them out of `TRUCK_STOP_IDS`.

### Highway props are unsynchronized

The twelve 20-HP highway rails, eight 80-HP lane-end barriers, four 60-HP
debris blocks, two derelict cars, two permanent crossover pillars, and four
400-HP overpass pillars have no positive arena IDs. The only synced breakables
are the sixteen deck rails and the fifteen truck-stop entries listed above.

## Human acceptance route

This route is designed to fit in ten minutes with one ordinary car.

1. Start at `(0,2304)` on the median grass. Inspect the four south lane-end
   barriers, drive the east carriageway northbound to the four north barriers,
   cross the median away from the boundary, and return southbound on the west
   carriageway. Touch the center and north repair stations while damaged.
   Confirm the full-length lane marks, grass, dirt, pond, rails, debris, wrecks,
   barriers, and permanent crossover pillars leave both directions readable.
2. Approach `JumpW` at `(-640,-1280)` southbound at launch speed. Land on the
   floor-3 deck, verify the Homing crate and rail draw order, break one rail,
   and confirm the open edge drops to floor 2 rather than a pit.
3. Return to the deck, descend east through `RampA` to `FZLanding`, continue
   through `RampB` onto the floor-1 country road, then reverse the route across
   the overpass. From the deck, descend `RampW` to the west shoulder. This
   checks both grounded routes off the deck and both directions of the two-step
   country-road climb.
4. Approach `JumpE` at `(640,-256)` northbound and land on the deck. Continue
   through its open north edge to the plate, confirming the pad landing and
   one-floor drop remain clear of rails, pillars, and walls.
5. Enter the lowland, take `RampN` north onto `FZShelfN`, and follow `MergeN`
   north-west into the northbound east carriageway. Approach `MergeS`
   northbound from that carriageway, follow it north-east into the south
   `362px` of `FZShelfS`, and descend `RampS` north into the lowland. Confirm
   both merge polygons, both built-in rail pairs and pointed caps, the shelf
   barricades, and bidirectional grade adoption.
6. Approach `JumpLowland` at `(1536,2400)` westbound from its clear
   `x=1648…2098` run-up and land west over `BankS` on floor 2. Turn east and
   drive down `BankS` into the lowland without a hop, then climb west over the
   same grass grade. Repeat on another bank and confirm both directions stay
   grounded.
7. Follow the frontage road into Hate's Travel Stop. Pass beneath the billboard
   at `(1600,1900)` and the pylon and confirm each thins while the car is
   underneath. Shoot the tanker and verify both diesel pumps and at least one
   barrel join the chain; then drive through the 256px garage gap, use
   `HealthStation2`, and exit without snagging either storefront.
8. Cross the pasture and crop rows, circle the barn and hay/fence rows, collect
   `AmmoPower3`, and confirm the farm route remains clear of the north shelf,
   country road, and arena boundary.
9. At combat zoom and overview zoom, inspect the radar from the lowland, plate,
   and deck. Verify same-floor dots and cross-floor chevrons, the raised plate
   and grass embankments, the overpass/underpass read, the truck-stop canopy
   fade, and all eleven ambient actors staying nonblocking and off-radar.
10. Host the scene in two windows. Fill all eight unique authored starts,
    including Enemy 7's floor-1 lot start; repeat one deck-rail break and the
    tanker chain, and verify both windows converge on the same rail and
    truck-stop tombstones.
