# Mountainside Mayhem arena brief

Mountainside Mayhem is the campaign's five-car mountain-pass melee. One tight
road climbs southwest to northeast between solid mountain and a lethal drop,
with a bridge, a parallel jump lane, a driveable knoll, and a one-exit runaway
ledge providing the route choices. The same scene supports campaign and
five-car LAN play.

## Profile

| Field | Value |
|---|---|
| Campaign slot | 10 |
| Mode / encounter | regular arena / melee |
| Size class | medium |
| Interior | `4096×4096` (`16,777,216 px²`) |
| Target cars | 5 (`3,355,443.2 px²` gross per car): player + 4 rivals |
| Stations | 1 |
| Floors | floor 2 base; floor 3 knoll summit and runaway ledge |
| Dominant terrain | asphalt road through snow |
| Accents | three ice bends; mud runaway ramp and ledge |
| LAN | MP-ready, 5 cars |

Arena bounds are `x=-2048…2048`, `y=-2048…2048`. The layout grid is 32×32
cells at 128px, with cell `(0,0)` beginning at `(-2048,-2048)`.

## Topology and floor graph

`levels/snowy/pass_grid.gd` is the signed layout. The driveable pass is one
four-connected region between mountain on the northwest and drop on the
southeast. Its eight asphalt rectangles are:

| Leg | Grid rectangle `(x,y,w,h)` |
|---|---|
| `trailhead_ew` | `(2,27,8,2)` |
| `climb_ns` | `(8,23,2,6)` |
| `saddle_ew` | `(8,23,10,2)` |
| `knoll_ns` | `(16,17,2,8)` |
| `apron` | `(15,9,5,8)` |
| `upper_ew` | `(17,7,8,2)` |
| `summit_ns` | `(23,3,2,6)` |
| `overlook_ew` | `(20,2,9,2)` |

Grid rows 12–13 form the chasm. Columns 17–19 remain driveable as a
`384×256` bridge with deck paint centered at `(320,-384)`. Columns 14–16 are
the west pit and columns 20–23 are the east pit. The bridge is the dependable
crossing. West-pit columns 15–16 form the parallel stunt lane between `JumpSW`
at `(0,-64)` and `JumpNW` at `(0,-704)`.

`SnowyHill` is centered at `(-256,640)`. Its `320×320` floor-3 summit and 192px
grades make a `512×512` footprint; four cardinal and four corner faces connect
floor 2 to floor 3 with snow handling and 180px/s² downhill pull. The summit
holds two ammo crates and the deer herd.

The runaway spur occupies grid rectangle `(3,21,3,2)`. `RunawayRamp` is a
local `256×384` grade rotated to a `384×256` world footprint at `(-1472,768)`;
it climbs west from floor 2 to floor 3 with mud handling and 120px/s² downhill
pull. `FZLedge` occupies `(1,21,2,2)`, a `256×256` floor-3 reward platform
centered at `(-1792,768)`. The same ramp is its only way in and out.

The checked grid picture is produced by
`godot --headless --path . -s res://tools/probes/print_pass_grid.gd`:

```text
################################################################
########################################                     |..
######################################  ======iiii========   |..
######################################  ======iiiiE1======   |..
####################################          ====           |..
####################################          ====         |....
################################              ====     |........
##############################    iiii==E2========   |..........
############################      iiii============ |............
############################  ==========       |................
############################  Jv========       |................
############################  ==========       |................
############################XXXXXX][][][XXXXXXXX................
############################XXXXXX][][][XXXXXXXX................
############################  ==========       |................
############################  J^========       |................
##########################    ==========       |................
##################              ====           |................
################                ====           |................
##############          /\/\/\/\====         |..................
##############          /\K*/\/\====  E3     |..................
##p LL<<<<<<      E4    /\/\/\/\====       |....................
##LLLL<<<<<<            /\/\/\/\====     |......................
########        iiii================ |..........................
######          iiii+ ==============............................
####            ====         |..................................
##              ====     |......................................
##  ================ |..........................................
##  ====P ========== |..........................................
##                   |..........................................
##                   |..........................................
######################..........................................
```

Legend: `##` mountain, `..` drop, `XX` chasm pit, `][` bridge, `==` asphalt,
`ii` ice, `|` the open drop rim, `J^`/`Jv` jump pads, `/\` knoll grade, `K*`
knoll summit, `<<` runaway ramp, `LL` ledge, `p` ledge power crate, `+` repair
station, and `P`/`E1`–`E4` the five starts.

## Surfaces

Asphalt is the arena substrate and covers the eight road legs. Every other
driveable grid cell receives snow through one `TerrainField` skin over 35
collision-only `TerrainZone` rectangles. The bridge deck is paint-only concrete
with a 256px asphalt carriageway through its `384×256` footprint.

The three `256×256` ice bends are fixed road decisions:

| Bend | Grid rectangle | World center |
|---|---|---|
| Low | `(8,23,2,2)` | `(-896,1024)` |
| Mid | `(17,7,2,2)` | `(256,-1024)` |
| Top | `(23,2,2,2)` | `(1024,-1664)` |

The knoll uses snow on all grades and its summit. The runaway grade and ledge
use mud. `pass_deco.gd` is paint only: its `kind` export selects
`bridge_deck` or `runaway_bed`, while `size` owns the exact paint footprint.
The level uses the `384×256` bridge deck at `(320,-384)` and a `640×256`
runaway gravel bed at `(-1600,768)`; neither changes collision, terrain, or
floors.

## Combat and economy

All five starts are direct root children on floor 2:

| Start | Position |
|---|---|
| Player | `(-1472,1600)` |
| Enemy 1 | `(1216,-1600)` |
| Enemy 2 | `(576,-1088)` |
| Enemy 3 | `(448,576)` |
| Enemy 4 | `(-832,704)` |

The repair station is at `(-704,1088)` on the floor-2 saddle. It keeps the
shared station defaults: 2 uses, 45s cooldown, and a 2s treatment.

All ammo crates respawn after the shared 20s default. Physical floor below
describes the route carrying the crate; the ledge crate also explicitly authors
`floor_index = 3`.

| Pickup | Kind / amount | Position | Physical floor |
|---|---|---|---:|
| `AmmoStandard1` | Standard / 2 | `(-1088,1344)` | 2 |
| `AmmoStandard2` | Rear / 2 | `(-320,960)` | 2 |
| `AmmoHoming1` | Homing / 1 | `(1600,-1600)` | 2 |
| `AmmoHoming2` | Homing / 1 | `(-576,448)` | 2 |
| `AmmoPower1` | Power / 1 | `(320,-704)` | 2 |
| `AmmoJump1` | Jump Mine / 1 | `(64,704)` | 2 |
| `AmmoMine1` | Land Mine / 2 | `(960,-1216)` | 2 |
| `AmmoPowerSummit` | Power / 1 | `(-256,640)` | 3 |
| `AmmoStandardSummit` | Standard / 2 | `(-168,720)` | 3 |
| `AmmoPowerLedge` | Power / 1 | `(-1856,704)` | 3 |

The economy provides Standard, Rear, Homing, and Power missiles on the main
route, mines on exposed branches, two rewards on the knoll, and one Power reward
at the end of the runaway spur.

## Rails and furniture

Forty-two breakaway rails cover guarded sections of the southeast drop, both
chasm lips outside the jump lane, and both long bridge sides. Each rail has
12 HP, belongs to floor 2, stays at `z_index = 0` so cars draw over it, and is
split to at most 256px after a 16px run-end clearance. The rail rectangle is
12px thick and sits 8px back from the lethal rim. Invisible AI curbs remain at
the lethal lips after a rail breaks.

Generated furniture is deliberately sparse around the road, rim, concave wall
corners, and jump-lane columns:

| Kind | Count | Collision / durability | LAN identity |
|---|---:|---|---|
| Boulder | 4 | permanent `128×128` hard cover, no Health | none |
| Wreck | 3 | destructible, 50 HP | 50–52 |
| Pine | 31 | destructible, 40 HP | none |
| Snow drift | 10 | 1 HP clutter | none |
| Cone | 6 | 1 HP clutter | none |
| Sign | 3 | 1 HP clutter | none |

The four boulders use seeds 11–14 for stable organic outlines. Wrecks flatten
into collisionless charred remains when destroyed; pines and small clutter
flatten into collisionless debris. Permanent boulders and mountain bodies draw
as solid shapes on the radar, while live destructibles use the breakable pass.

## Living site and weather

Two floor-2 skiers follow the closed route `(-1728,1728) → (-832,1728) →
(-832,1310) → (-1200,1310) → (-1728,1728)` at 80px/s with 20px lane spread.
Five floor-3 deer circle the knoll on local points `(-120,-110) → (120,-110) →
(120,110) → (-120,110) → (-120,-110)` at 92px/s with 34px lane spread. Both
populations are nonblocking, untargeted, cosmetic-local in LAN, and absent from
the radar.

Snowfall is cosmetic. `StreetDeco` covers extents `(2074,2074)` with
`snow_amount = 337`; it changes no handling, collision, visibility, or damage.

## Arena-state identities

IDs are unsigned 16-bit values unique within the scene:

| IDs | Entities |
|---|---|
| 50 | `WreckBendLow` at `(-1130,1060)` |
| 51 | `WreckOverlook` at `(460,-1400)` |
| 52 | `WreckTrailhead` at `(-1780,1850)` |
| 100–141 | `Rail001`–`Rail042`, in generated rim order |

The wrecks and rails are the only Mountainside furniture with `arena_net_id`.
Destroyed instances remain collisionless tombstones so repeated LAN snapshots
converge without replaying their death presentation.

## Measured baselines

These are comparison baselines for any later route, AI, rail, or furnishing
change.

Botlab baseline: 12 matches × 5 stock rivals, shipping governor, 180s.

| Metric | Mountainside pass | Open-field reference |
|---|---:|---:|
| Deaths | 12 of 60 | 18 |
| Environmental deaths | 6 | 4 |
| Stationary share of car-time | 12.1% | 8.0% |
| Worst single car stationary | 20.3% | 16.3% |
| Wall hits per car | 49.5 | not recorded |
| Distance per car | 32,343px | not recorded |
| Pickups per car | 3.65 | not recorded |

Stall baseline: 8 seeds × 5 stock rivals, 180s. Rivals were stalled for 5.5%
of car-time; the longest stall was 7s; 2 cars fell. No 128px cell accumulated
more than 48s of stalled time across the eight matches.

## Regenerating the pass

Never hand-edit `pass_snow.tscn`, `pass_mountain.tscn`, `pass_drop.tscn`,
`pass_rails.tscn`, or `pass_furniture.tscn`.

| Generated scene | Contents |
|---|---|
| `pass_snow.tscn` | one `TerrainField` over 35 authored snow tiles |
| `pass_mountain.tscn` | one `MountainWall` over 17 authored mountain blocks |
| `pass_drop.tscn` | one `DropField` over 33 paintless pits and 34 AI curbs |
| `pass_rails.tscn` | 42 breakaway rail segments |
| `pass_furniture.tscn` | 4 boulders, 3 wrecks, 31 pines, 10 drifts, 6 cones, and 3 signs |

```sh
# Rewrite all five generated scenes.
godot --headless --path . -s res://tools/carve_pass.gd

# Compare the scenes on disk with a fresh build without writing them.
godot --headless --path . -s res://tools/carve_pass.gd -- --check

# Print the reviewable grid picture used above.
godot --headless --path . -s res://tools/probes/print_pass_grid.gd
```

Ownership is split deliberately:

| File | Owns |
|---|---|
| `game/scene_flow.gd` | campaign order and profile, plus the five-car LAN map entry |
| `pass_grid.gd` | grid size/origin, row spans, chasm and bridge cells, road/ice rectangles, knoll, pads, runaway spur/ledge, spawn/station anchors, rail geometry constants, furniture data, and deterministic derived rectangles |
| `pass_builder.gd` | generated node-tree composition, collision layers, paint seed 4096, paintless pits, AI curbs, rail 12 HP and IDs from 100, and furniture scene types |
| `carve_pass.gd` | output paths, stable packed-scene IDs, write mode, and `--check` signatures |
| `snowy.tscn` | level materials, three ice zones, bridge/runaway paint, floor zones and connectors, knoll/ramp instances, pickups, ambience, spawns, station, boundary, and generated-scene instances |
| `mountain_wall.gd` / `drop_field.gd` / `terrain_field.gd` / `boulder.gd` | reusable skin defaults and paint algorithms; authored child rectangles remain the static-inspection contract, while `MountainWall` alone derives runtime notch chamfers |

`tests/test_mountain_pass.gd` and
`tests/mountain_pass_furniture_checks.gd` lock connectivity, clearances,
generated-scene parity, rail draw order and IDs, furniture counts, economy,
ambience, and the hand-authored scene mirrors.

For visual review, `tools/shot.sh levels/snowy/snowy.tscn <out.png>` captures
the level and requires `xvfb-run`. For circulation review,
`tools/stalls.sh levels/snowy/snowy.tscn` runs the standard 8 seeds from base
11 for 180s with 5 cars, logs grounded stalls of at least 1s below 25px/s and
all pit falls, then reports stalled car-time, longest stall, and the ten worst
128px cells. Its probe is `tools/probes/stall_probe.gd`; its report generator is
`tools/stall_report.py`.

## Named exceptions

### One-exit runaway ledge

`FZLedge` has one way in and the same way out, through `RunawayRamp`. This is a
small, visible floor-3 traversal-reward platform rather than a combat pocket;
the Power crate is the reason to accept the turnaround. Keep the full ramp and
ledge notch free of mountain collision and solid furniture.

### Unrailed jump lane

The north and south faces of the west pit omit breakaway rails in grid columns
15–16. The omission is the stunt route: a rail would stop the pad run-up or
landing. AI hazard curbs remain on both lips, and the bridge immediately east
is the safe crossing.

### Pads ignore rivals

`JumpNW` and `JumpSW` both set `launch_rivals = false`. Cars in the `&"player"`
group launch; ordinary rivals cross the pad as flat floor-2 ground and are held
out of the pit by the hazard curb. Do not replace this rule with an AI-only
hazard rectangle near the mountain wall: that geometry can pin a rival between
the wall and its avoidance response.

## Human acceptance route

This route is designed to fit in ten minutes with one ordinary car.

1. Start at `(-1472,1600)`. Drive the trailhead east, take the low ice bend at
   `(-896,1024)` in both directions, use the repair station while damaged, and
   verify the trailhead/climb/saddle legs remain passable around the boulders,
   wrecks, and pines.
2. Turn off the saddle onto `RunawayRamp`, climb west through the mud to
   `FZLedge`, collect the Power crate, turn around on the `256×256` platform,
   and descend the same ramp. Confirm there is no second exit or collision lip.
3. Circle `SnowyHill`, climb all four cardinal faces and all four corner
   faces, collect both summit crates, cross the deer route, and descend on the
   opposite side. Confirm floor 2↔3 changes remain grounded in both directions.
4. Follow the knoll leg north to the chasm apron. Cross the bridge northbound
   and southbound, checking its side rails, centered road mark, and radar shape.
5. Approach `JumpSW` northbound at speed and clear the west pit to `JumpNW`.
   Turn around and use `JumpNW` southbound to clear it again. Confirm both pad
   faces remain unrailed and a rival driving over either pad stays grounded.
6. Break one ordinary drop-side rail, drive through its remains into the drop,
   and confirm the pit death. After respawn, break one bridge-side rail and
   verify the lethal lip and AI curb remain aligned with the missing segment.
7. Continue north through the apron, take the mid ice bend at `(256,-1024)`,
   run the upper and summit legs, take the top ice bend at `(1024,-1664)`, and
   traverse the full overlook leg in both directions. This completes all eight
   road rectangles and all three ice bends.
8. At combat zoom and overview zoom, inspect the full route and snowfall.
   Verify mountain wall/obstacle bodies and boulders draw as radar solids,
   pits read as void, live rails/wrecks read as breakables, and destroyed
   breakables disappear from the radar.
9. Watch stock rivals circulate through every bend, bridge approach, knoll
   side, and runaway mouth. Run the Botlab and stall baselines after any route
   or furniture change; inspect every fall lead-in and any newly dominant cell.
10. Host the scene in two windows. Seat one host and one client, confirm the
    three stock rivals backfill the five unique authored starts on floor 2,
    then repeat one wreck kill and one rail break and verify both windows
    converge on the same collisionless remains.
