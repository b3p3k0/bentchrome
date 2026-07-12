# Ground Floor Gore arena brief

Ground Floor Gore is the campaign's construction-site melee and the first arena
to exercise mud, a sparse floor-3 scaffold network, and a networked signature
destructible together. It follows Piers of Pain and precedes Goliath's Arena. The
same scene supports campaign and eight-car LAN play.

## Profile

| Field | Value |
|---|---|
| Mode / encounter | regular arena / melee |
| Size class | large |
| Interior | `4608×3840` (`17,694,720 px²`) |
| Target cars | 8 (`2,211,840 px²` gross per car) |
| Stations | 2: floor 1 southwest, floor 3 north repair platform |
| Dominant terrain | dirt |
| Accents | three mud basins, two shallow-water puddles |
| Floors | yard 1, foundation 2, scaffold 3 |
| LAN | MP-ready, protocol 8 arena-state rows |

Arena bounds are `x=-2304…2304`, `y=-1920…1920`. The dry outer haul road is
the recovery line; mud, the generator envelope, and scaffold rewards are
voluntary risk rather than mandatory circulation.

## Topology and floor graph

The poured foundation is centered at `(896,-640)`, sized `2048×1792`, and spans
`x=-128…1920`, `y=-1536…256`. Its north and east faces stop 384px short of the
arena walls, preserving the narrow floor-1 racing alley requested by the brief.
Retaining faces are solid everywhere except the two authored entries:

- West dirt embankment at `(-384,-768)`, floor 1↔2, `384×512`, pull 120.
- South concrete ramp at `(640,512)`, floor 1↔2, `384×512`, pull 120.

The scaffold is a connected floor-3 circuit built from 256px runs and 448px
work platforms. Its repair platform is widened to `640×448`. Two ordinary
grades connect floors 2↔3; the north repair-platform edge deliberately drops to
floor 2, while the west cantilever deliberately drops to floor 1. Protected
edges carry visible rails and AI curbs; open edges are readable commitments.
All four grade pairs have explicit two-way `FloorConnector`s.

The eight baked starts are four on floor 1, three on floor 2, and one on floor
3. Their exact positions live in `ground_floor_gore.tscn`; tests enforce unique
positions, authored floors, 700px player/enemy separation, and prop clearance.

## Combat and economy

The 11-crate budget is fixed:

- 2 Standard, 2 Rear, 2 Homing, 2 Power, 2 Land Mine, 1 Jump Mine.
- Floor-3 Power and Jump rewards sit on exposed scaffold branches.
- No crate may enter a spawn safety zone, generator blast envelope, connector
  approach, or repair release lane.

Permanent machine cover consists of a `256×128` bulldozer and `320×128` dump
and cement trucks. Containers, chain link, porta-potties, and the generator are
temporary cover. The three mud basins interrupt local fights without cutting
the dependable dry perimeter route.

## Signature generator

The floor-1 generator is a `256×192`, 450 HP landmark at `(350,1000)`. It is
ordinary cover until HP reaches 112.5, then warns for 1.2s, arcs for 2s, and
waits exactly 60s after the burst. Every same-floor, line-of-sight car within
480px is latched impartially. A full latch deals 16 environmental damage and
refreshes 50% interference through a 0.4s tail. The warning ring, cabinet cover,
and the ability to leave or break line of sight provide its counterplay.

Death creates a blue-white electrical blast: same-floor damage falls 50→15 and
shove falls 420→140 across 420px. It may chain through soft targets and
destructible site cover, clears player attribution, and leaves a nonblocking
charred pad. Full reusable rules are in
[`signature_destructibles.md`](../signature_destructibles.md).

## Living site and weather

Sixteen baseline workers are authored as 10 on floor 1, four on floor 2, and
two supply carriers on floor 3. Empty-handed, wheelbarrow, and supply variants
share the existing nonblocking 1 HP soft-target contract. Eight west-side
porta-potties have 20 HP and stable LAN identities; each has a host-authoritative
20% chance to release one worker who panics for 2.5s before wandering normally.

Rain is cosmetic. `RainSquall` supplies bounded GPU streaks and opt-in
world-space ripples to mud and shallow water without altering traction,
visibility, collision, damage, or audio. Mud alone supplies the handling change.

## Arena-state identities

IDs are unsigned 16-bit values unique within this scene:

| IDs | Entities |
|---|---|
| 1 | power generator |
| 10–17 | west porta-potties |
| 20–22 | breakable containers |
| 23 | south chain-link cover |

Destroyed networked props remain hidden, noncolliding tombstones so late and
repeated snapshots converge without replaying their death presentation.

## Human acceptance route

1. Lap the dry perimeter in both directions and verify the north/east alley
   never dead-ends.
2. Cross every mud basin and puddle with neutral, off-road, 4WD, and Cyclone
   profiles; inspect rain and ripples at combat and overview zoom.
3. Use both foundation grades and both scaffold grades in both directions with
   a small and heavy car.
4. Complete every scaffold branch, use the repair bay from floor 3, then take
   both deliberate drops; verify a floor-1 car below cannot collect or repair.
5. Fight around all three machines, destroy the porta row, and check worker
   containment on every floor.
6. Wake the generator with shots and rams, test cover/escape counterplay, then
   trigger its blast into nearby destructibles.
7. Repeat a generator cycle and prop destruction in a two-window LAN match.
8. Run eight combatants with full ambience and inspect the frame-time target.
