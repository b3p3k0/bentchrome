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
| Floors | yard 1, foundation 2, scaffold 3 (+ two-tier south dirt pile 1→2→3) |
| Lighting | rainy dusk: `night_arena` CanvasModulate `(0.62,0.65,0.78)`, five SHOOTABLE 30-HP worklights (varied aim), headlight beams on every car (viewer cool-white, others warm), explosion blooms |
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

The scaffold is an orthogonal floor-3 ring on column lines `x=384/1536` and
row lines `y=-1152/-128`: five 448px-deep work platforms (northwest, repair
`640×448`, southeast, southwest, west cantilever) joined by five derived 256px
runs whose lengths equal the platform-edge gaps exactly. The ring encloses a
floor-2 **courtyard fight pit** (`x=512…1408`, `y=-1024…-256`); two switchback
scaffold grades rise from inside it — north ramp `(784,-832)`, south ramp
`(1088,-448)`, both `256×384`, pull 120, floors 2↔3, skinned deco over
`surface_paint=false`. Every deck edge is classified **rail / gate / seam /
drop**: gates are authored openings exactly covered by a neighboring deck or a
ramp mouth (their shoulders build guard statics, so junctions cannot leak
accidental lips); the repair platform's north lip drops to floor 2 and the
cantilever's west lip drops to floor 1, both hazard-taped. All four grade
pairs have explicit two-way `FloorConnector`s. Deck support posts, base
plates, and cast shadows ride an understructure canvas that stays visible
while the deck plane under-fades for traffic below.

Three ring rails are **breakaway**: 12 HP destructible guardrails (net ids
24–26) over hazard-taped drop lips on WestRun's courtyard side, EastRun's
courtyard side, and SoutheastPlatform's south face — smash through and drive
off the deck. AI-only hazard curbs on the same lips keep bots from following.

The southern yard is dominated by the **spoil heap**: a two-tier octagonal
`DriveableHill` pair at `(-200,1150)` — an 848px floor-2 dirt apron
(grade 240, pull 180) carrying a 448px floor-3 cap (grade 200) — all sixteen
faces driveable, relief-shaded slopes against flat caps, with the relocated
land-mine crate on top. The pile forced the generator west and reshuffled the
south yard (Enemy2, dump truck, southwest mud, stray props).

Two smaller **twin heaps** (320px summits, grade 200, floors 1→2, outer 520)
fill the southwest corner at `(-1750,1350)` and `(-1150,950)` with a driveable
saddle between them; the player spawn moved to `(-900,1650)`, the southwest
mud basin to `(-1500,380)` beside the porta lane, and the wheelbarrow crew
patrols the west lane around them.

Four poured `112×112` **SlabColumns** stand on the slab's painted sixteen-anchor
512px grid — a courtyard cover pair at `(576,-944)`/`(1088,-944)`, a west
corridor column at `(64,-432)`, and a south strip column at `(1088,80)`. They
are permanent floor-2 obstacle cover (no Health), one node owning paint and
unscaled collision.

The eight baked starts are four on floor 1, three on floor 2, and one on floor
3. Their exact positions live in `ground_floor_gore.tscn`; tests enforce unique
positions, authored floors, 700px player/enemy separation, and prop clearance.

## Combat and economy

The 11-crate budget is fixed:

- 2 Standard, 2 Rear, 2 Homing, 2 Power, 2 Land Mine, 1 Jump Mine.
- Floor-3 Power and Jump rewards sit on exposed scaffold branches.
- No crate may enter a spawn safety zone, generator blast envelope, connector
  approach, or repair release lane.

Permanent cover consists of a `256×128` bulldozer, `320×128` dump and cement
trucks, and the four poured slab columns. Containers (one now serves as
courtyard cover beside the east run), chain link, porta-potties, and the
generator are temporary cover. The three mud basins interrupt local fights
without cutting the dependable dry perimeter route.

## Signature generator

The floor-1 generator is a `256×192`, 220 HP landmark at `(-1420,-60)` in the
west service yard (flanked by fuel barrels and a pipe bundle). Below 90% HP it
pops intermittent insulator sparks and a smoke wisp, amplified below 75% — the
early interactivity cue, visual-only and identical on LAN puppets. It is
ordinary cover until HP reaches 55, then warns for 1.2s, arcs for 2s, and
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
`48×60` porta-potties (72px pitch, doors east with one leaf hanging ajar) have
20 HP and stable LAN identities; each has a host-authoritative 20% chance to
release one worker who panics for 2.5s before wandering normally.

Rain is cosmetic. `RainSquall` supplies bounded GPU streaks and opt-in
world-space ripples to mud and shallow water without altering traction,
visibility, collision, damage, or audio. Mud alone supplies the handling change.

## Arena-state identities

IDs are unsigned 16-bit values unique within this scene:

| IDs | Entities |
|---|---|
| 1 | power generator |
| 10–17 | west porta-potties |
| 20–22 | breakable containers (west pair + slab) |
| 23 | south chain-link cover |
| 24–26 | breakaway scaffold rails (west / east / south lips) |
| 27–28 | added containers (slab east, south yard) |
| 29–33 | fuel barrels (generator pair, hill pair, cement truck) |
| 34–36 | junk piles |
| 37–38 | slab crates |
| 39–40 | entry barriers |
| 41–47 | parking-lot derelicts (NW corner, mundane pool) |
| 48–54 | promoted site props: forms, two spools, two pipe bundles, two rebar cages |
| 55–59 | shootable worklights (dark toppled-mast tombstones) |

Destroyed networked props remain hidden, noncolliding tombstones so late and
repeated snapshots converge without replaying their death presentation.

## Human acceptance route

1. Lap the dry perimeter in both directions and verify the north/east alley
   never dead-ends.
2. Cross every mud basin and puddle with neutral, off-road, 4WD, and Cyclone
   profiles; inspect rain and ripples at combat and overview zoom.
3. Use both foundation grades and both courtyard scaffold grades in both
   directions with a small and heavy car.
4. Lap the floor-3 ring both ways, take the cantilever spur, use the repair
   bay from floor 3, then take both hazard-taped drops; verify a floor-1 car
   below cannot collect or repair, and that fading decks leave their posts and
   ground shadows visible.
5. Fight around all three machines and inside the courtyard pit against the
   slab columns, destroy the porta row, and check worker containment on every
   floor.
6. Chip the generator to 89% and 74% HP and confirm the two spark/smoke tiers;
   then wake it fully, test cover/escape counterplay, and trigger its blast
   into the neighboring barrels.
7. Climb the spoil heap on every face, grab the cap mine crate, and jump off
   both tiers; verify slope shading reads against the flat caps at dusk.
8. Smash all three breakaway rails and take each yeet; confirm AI never
   follows and the hazard tape reads after the rail dies.
9. Tour the dusk pass: worklight pools, viewer glow, explosion blooms, rain
   and mud sheen under the tint, radar/HUD untinted; sweep the parking lot and
   porta row (one door ajar).
10. Repeat a generator cycle, rail break, and derelict kill in a two-window
    LAN match (tombstones on the client, sparks on the puppet).
11. Run eight combatants with full ambience and inspect the frame-time target.
