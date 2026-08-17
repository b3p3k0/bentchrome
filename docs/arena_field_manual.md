# Arena field manual

This is the authoring contract for Bent Chrome's hand-built campaign and LAN
combat arenas. Route 666 Roulette is a specialty chase level and does not inherit this
contract. The suspended custom-level editor is also outside it.

The purpose is consistency without sameness. An arena may be a city grid, a
freeway ring, a mountain, a freight yard, or a stadium. It must still speak the
same language to cars, AI, weapons, the camera, and multiplayer.

## How to read the rules

- **MUST** — engine, safety, multiplayer, or readability invariant. Tests should
  enforce it wherever geometry permits.
- **DEFAULT** — the proven starting band. Deviate only for a stated design
  reason and verify the result by playtest.
- **EXCEPTION** — a named deviation with a reason, compensating check, and
  removal condition. Silent exceptions are bugs.
- **PRECEDENT** — a shipped example demonstrating a useful solution, not a
  requirement to copy its silhouette.

When rules conflict, physical correctness and player readability win, followed
by combat counterplay, then visual flavor.

## Shared vocabulary

- **Arena** — reusable physical battlefield: bounds, floors, routes, hazards,
  cover, resources, and spawn capacity.
- **Encounter overlay** — campaign-only actors or direction layered over an
  arena, such as Lackey or Goliath. It must stand down in `mp_managed` play.
- **Combat lane** — space wide enough for speed, aiming, passing, and a BREAK
  arc. It need not look like a road.
- **Recovery route** — a readable way out of pressure: side street, outer ring,
  open field, grade, breakable wall, or drop.
- **Combat pocket** — a local fight space connected to the larger route graph.
  It is not a dead-end kill box.
- **Contested resource** — a pickup on an exposed or intersecting route.
- **Traversal reward** — a pickup earned by a jump, grade, destructible secret,
  or dangerous detour.
- **Landmark** — macro-scale silhouette/color/topology used to orient at combat
  zoom, overview zoom, and on the radar.
- **Signature destructible** — an opt-in stateful landmark whose telegraphed
  phases change local pressure and whose persistent state is host-authoritative.
- **Terrace** — a discrete driveable floor. Every XY point has one winning
  driveable floor except inside an authored grade transition.
- **Grade ramp** — grounded floor transition. Local high end is `-Y`; it always
  resists ascent and assists descent.
- **Corner grade** — right-triangle grade between cardinal slopes. The
  right-angle vertex is high; the 45-degree hypotenuse is low.
- **Terrace chamfer** — solid right-triangle cap where the empty corner belongs
  to the elevated top. It blocks both adjoining floors.
- **Jump route** — airborne transition initiated by a jump pad. It is not a ramp.
- **Lethal edge** — pit or deep water. It must be visible, floor-correct, and
  protected from AI pathing by a hazard curb.
- **Cosmetic layer** — visual/flavor content invisible to navigation and combat.

## The three authoring layers

Build and review in this order.

1. **Physical topology** — bounds, driveable floor, walls, cover footprints,
   lethal space, terraces, grades, jump routes, and collision layers.
2. **Combat and economy** — spawn graph, sightlines, recovery routes, AI
   connectors, destructibility, pickups, stations, and encounter overlay.
3. **Readability and flavor** — surface paint, road marks, landmarks, shadows,
   lights, ambience, living streets, and non-colliding motion.

Paint never excuses broken collision. Flavor never closes a route the AI or
largest car was promised.

## Capacity and arena size

### Car capacity

- **MUST:** every regular arena supports at least four simultaneously fielded
  cars, matching the four human LAN seats.
- **Small:** 4 target cars.
- **Medium:** 5–7 target cars.
- **Large:** 7–8 target cars.
- A boss overlay may field only player + boss in campaign. Its underlying arena
  still declares at least four neutral MP spawn positions.

`target_cars` means the intended full field, not enemy count. A five-car
campaign melee is one player plus four AI; a five-car LAN melee may be four
humans plus one AI.

### Aquarium rule

- **MUST:** gross interior area is at least `1,600,000 px² × target_cars`.
- **MUST:** the shorter interior dimension is at least `2048px`.
- Four cars therefore need at least `6,400,000 px²`; `2560×2560` is the first
  square 128-grid starting point above that floor.
- **DEFAULT:** dimensions and major footprints land on the 128px grid; detailed
  props may use 64px increments.
- **MUST:** area is only the first gate. Human review must discount buildings,
  lethal water, unreachable terraces, and dense cover. A large bounding box can
  still be a tiny aquarium.

Review both the gross ratio and whether all cars can circulate without spending
the match in single-file traffic.

## Physical topology

- **MUST:** root is a `Node2D` using `combat_level.gd` or a subclass that honors
  `mp_managed` before campaign-only work.
- **MUST:** the player/spawn source and arena geometry are direct children while
  `combat_level.gd` derives MP spawn data from baked cars.
- **MUST:** physics bodies stay scale `Vector2.ONE`. Resize shapes or authored
  radius values; never scale a collision owner.
- **MUST:** use named collision channels from `project.godot`. No private level
  bit may be invented.
- **MUST:** visible hard boundaries and collision agree. The only deliberately
  invisible rails are `hazard_curb` AI feelers along lethal edges.
- **MUST:** player-to-enemy baked starts remain at least 700px apart.
- **MUST:** clutter and blocking props remain at least 300px from AI starts.
- **DEFAULT:** enemy starts are also separated enough to choose independent
  opening lines instead of beginning in an antler lock.
- **DEFAULT (don't author it unless the design says so):** spawn FACING.
  `combat_level.face_spawns_inward` aims every ordinary car at the shared
  spawn centroid at boot — baked `.tscn` rotations are ignored for ordinary
  cars, so position spawns for geometry and let the shell handle the aim.
  Opt-outs, most specific first: a `fixed_loadout` boss keeps its authored
  entrance pose (author those deliberately); a specialty level that stages
  its own opening tableau sets `face_spawns = false` on the root and keeps
  every baked rotation; scenes baking fewer than two cars are exempt
  automatically. MP seats inherit the same inward-facing spawn data via the
  harvest. Custom/editor levels are separate: their schema authors
  `heading_deg` per spawn explicitly, and the loader honors it.
- **DEFAULT:** primary lanes allow two large ordinary vehicles to pass with
  steering room; 320px+ is a useful high-speed starting width. Optional cuts
  may narrow, but may not trap the largest selectable car.
- **DEFAULT:** every combat pocket has two exits or one normal exit plus a clear,
  intentional breakable escape.

Do not build a uniform empty plane or a corridor maze. Alternate readable
700–1200px firing opportunities with cover breaks and 300–600px local fights.
The AI fires to 1000px and feels obstacles roughly 200px plus speed lead; give
those systems room to express themselves.

## Grades, corner grades, and chamfers

- **MUST:** every `Ramp` has positive downhill force. Ordinary grades use
  `120 px/s²`; uphill loses speed and downhill gains it.
- **DEFAULT:** compact `DriveableHill` facets use `180 px/s²`. Their short
  240px crossing needs the stronger impulse to register; standalone ramps stay
  at 120 and Goliath's Arena stairs retain their explicit 170.
- **MUST:** terrain composes with grade force. `road` means asphalt; grass,
  snow, dirt, ice, and water retain the shared controller modifiers and vehicle
  terrain profiles.
- **MUST:** ramp-local terrain has priority over broad background terrain. An
  asphalt garage grade over grass still drives as road.
- **MUST:** rectangular ramps split into low/high ramp-tagged floor halves.
- **MUST:** corner grades use the triangular convention defined above and split
  into a high triangle and low trapezoid. Crossing either way is grounded: no
  jump pop and no fall bill.
- **MUST:** a solid elevated corner uses `TerraceChamfer`, carrying obstacle plus
  both adjoining floor bits.
- **DEFAULT:** a hill uses four cardinal grades plus four corner grades. This is
  the accepted eight-sided approximation of a circular slope.
- **DEFAULT:** side rails belong on chokepoint ramps. They are disabled where
  cardinal and corner facets must meet as one continuous hill.
- **EXCEPTION:** Goliath's Arena seating uses explicit `170 px/s²`, `stairs = true`,
  row speed nicks, and camera bumps. It is stadium anatomy, not a gradual hill,
  and must retain its current feel.

Every grade route needs a clear 220px AI approach on its `from_floor`. Author
paired connectors for both directions; grade commits do not boost.

### Driveable hills: one root, one skin

- **MUST:** author a regular eight-faced mound through `DriveableHill`, not as
  eight independently positioned or painted prefabs. The node owns the summit
  FloorZone/TerrainZone, four cardinal `Ramp`s, four `CornerRamp`s, and all
  paired connectors.
- **MUST:** `grade_length` is the only slope-depth input. Corner leg equals
  exactly half that length; the full footprint is `summit_size + grade_length`.
  Do not hand-scale a corner to fill a visually estimated gap.
- **MUST:** one clipped-octagon surface paints the complete mound. Individual
  grades set `surface_paint = false`; per-face opaque paint produces seams,
  bands, overlaps, and arrowhead corners.
- **MUST:** assign the same substrate and terrain materials used around the
  hill. The component repaints the substrate, then applies the terrain once;
  this prevents translucent grass/snow from stacking brighter over itself.
- **MUST:** slope relief stays cosmetic. It may tint and re-project terrain and
  interpolate vehicle/shadow lift, but may never scale or offset physics.
- **MUST:** a prop spanning a grade/floor seam carries both adjoining floor
  bits. Hill skin draws first, then slope props, then vehicles.
- **DEFAULT:** relief uses the shared fixed northwest light, strength `0.22`,
  projected pattern compression `1.55`, all-slope darkening `0.06`, an 18px
  crest (`0.10`), a 20px foot (`0.12`), and a `(12,14)` southeast contact
  shadow at `0.20` alpha. It is static and self-contained: no shimmer, contour
  bands, normal-map assets, or scene-wide light dependency.
- **DEFAULT:** ordinary grades interpolate the existing floor lift and visual
  scale continuously from low to high. `stairs = true` opts out so the
  Goliath's Arena retains its row-by-row visual language.
- **DEFAULT:** place authored summit rewards and ambience beneath the hill root
  so moving the hill cannot strand its content. Keep roads/markings outside the
  footprint and re-run all eight connector approaches after any transform.

Failure precedents now locked out: individually opaque grade strips, manually
sized corner facets, translucent terrain painted twice, a binary midpoint
height pop, props hidden behind the skin, and single-floor collision on a prop
that crosses a grade seam.

## Terraces and airborne routes

- **MUST:** every occupied floor has a route up and a route down. A one-way drop
  is supporting texture, never the only way back into the fight.
- **MUST:** spawns author `start_floor`, and every collision-bearing prop on a
  terrace authors `floor_index` or explicit floor bits.
- **MUST:** straight weapons, rams, contact specials, mines, and hazards obey
  same-floor rules. Tracking weapons retain their endpoint-cover policy.
- **MUST:** a missing terrace boundary is replaced by a real ramp, open drop, or
  solid wall. Never delete it and let lower-floor cars ghost into raised XY.
- **MUST:** jump pads are floor-stamped, stand clear of solid scenery, and have a
  usable run-up and landing zone.
- **DEFAULT:** high routes pay with exposure or traversal effort and return a
  vantage, shortcut, pickup, or escape option.

### Scaffold networks

- **DEFAULT:** scaffold runs start at 256px wide and connect through readable
  448px work platforms. Widen a repair platform to at least `640×448` and give
  it a clean entry, exit, and release runway.
- **MUST:** a scaffold network offers multiple connected paths, paired grades
  back to its supporting floor, and no accidental gaps. Deliberate drops use
  `FloorConnector kind = edge` and remain visually distinct from guarded edges.
- **DEFAULT:** classify every deck edge as exactly one of rail, gate, seam, or
  drop (`ScaffoldDeck` exports). A gate is an authored opening (`gate_width`,
  optional center offset) exactly covered by a neighboring deck or a ramp
  mouth; its shoulders build guard statics, so junctions cannot leak
  accidental lips. Seam edges draw nothing and build nothing — abutting decks
  merge into one surface.
- **DEFAULT:** a breakaway rail is a drop edge wearing a low-HP destructible
  guardrail (`destructible_block` `deco = &"rail"`, ~12 HP, floor-stamped,
  z_index 2, host-synced `arena_net_id` on MP maps) plus an AI-only
  `hazard_curb` on the same lip — the player earns the yeet, the bots never
  lemming. The hazard-tape lip paint underneath stays readable after the rail
  dies.
- **MUST:** rails and AI hazard curbs agree. Protected edges show both; committed
  drops omit both only where a safe landing and recovery route exist.
- **MUST:** floor-3 stations, pickups, props, and soft targets are explicitly
  floor-gated so traffic beneath the deck cannot interact through it.
- **MUST:** overhead deck paint uses the established under-fade/z-order seam.
  Floor-1/2 vehicles remain readable below it, and collision bodies stay
  unscaled.

## Terrain and hazards

- **MUST:** surface paint and `TerrainZone.terrain_type` describe the same
  material. Broad material regions beat decorative confetti patches.
- **DEFAULT:** one dominant surface establishes identity; one or two accents
  create decisions. More types require a clear geographic reason.
- Ice needs a straight entry and recovery run. Water needs a visible shallow
  buffer before lethal deep water. Dirt/grass/snow should change route choice,
  not merely tint asphalt.
- Mud is a first-class wet-soil surface: global accel `0.55`, top `0.60`, grip
  `0.42`, steer `0.90`. It belongs in geographically coherent basins with a dry
  recovery route; isolated brown confetti is neither readable nor interesting.
- Vehicle mud profiles are authored through `VehicleTerrainModifier`, never car
  ID branches. Ground Floor Gore establishes Cricket `0.62/0.65/0.50/0.98`,
  Hammertoe `0.80/0.80/0.60/0.98`, Smoky/Razorback
  `0.72/0.74/0.55/0.96`, and Cyclone `0.36/0.40/0.25/0.78` as effective values.
  Lovebug's water affinity and Cricket's dirt dash bonus do not imply mud perks.
- **MUST:** pits and deep water are visually legible before commitment, floor
  gated, and hazard-curbed for AI. Airborne bypass is intentional gameplay.
- **DEFAULT:** pair severe hazards with a safer, slower route or a demanding but
  readable skill route.

## Cover and destruction

- `StaticBody2D` walls define permanent topology.
- `DestructibleBlock` is temporary cover that opens the match over time.
- `Clutter` is 1HP pop-through flavor, not a tactical wall.
- `DerelictCar` is readable medium-soft cover using the vehicle language.
- Road marks, lights, weather, signs, overhead paint, and living streets are
  cosmetic unless their scene explicitly says otherwise.

- **MUST:** solid cover does not overlap other solid cover accidentally.
- **MUST:** cover never overlaps jump pads or connector approach lanes.
- **DEFAULT:** cover clusters interrupt sightlines without fully enclosing a
  pocket. Destructible exits are a useful pressure valve, not a secret required
  for basic circulation.
- Fuel barrels and other explosive scenery need readable spacing and must not
  produce unavoidable spawn-chain damage.

### Signature destructibles

- **DEFAULT:** one signature destructible may anchor a regular arena. It must
  be a landmark with a telegraphed, counterable pressure pattern—not a quota or
  an oversized ordinary barrel.
- **MUST:** gameplay state is host-authoritative and repeatedly snapshotted
  through stable unsigned 16-bit arena IDs. Destroyed entities remain hidden,
  noncolliding tombstones so late clients converge without replaying death.
- **MUST:** dangerous phases state range/floor/LoS rules, expose an AI-only
  danger cue, and provide cover, distance, or destruction counterplay.
- **MUST:** attribution and death aftermath are explicit. Environmental hazards
  do not become accidental player weapons.
- Full interface, phase checklist, and generator precedent:
  [`signature_destructibles.md`](signature_destructibles.md).

## Resource economy

- Default ammo respawn is 20s.
- Standard/rear/mine crates normally grant 2; homing/power/jump grant 1 unless
  the encounter has a documented reason.
- **MUST:** pickups are outside spawn safety zones, lethal footprints, and
  connector run-ups.
- **DEFAULT:** use a mix of baseline access, contested resources, traversal
  rewards, and occasional destructible secrets.
- **DEFAULT:** every melee arena supplies standard, homing, power, and rear
  missiles. Mine types are encounter/topology choices rather than quotas.
- **MUST:** repair-station count follows the arena profile: small 1, medium 1–2,
  large 2–3. A boss overlay may intentionally use one.
- Stations need several clean exit bearings because repaired cars resume their
  saved velocity and then receive the two-second shield.

## Readability, landmarks, and ambience

- **MUST:** the arena remains readable at combat zoom, overview zoom, and on the
  north-up radar.
- **DEFAULT:** every major district has a macro landmark, distinct material or
  topology, and a memorable route relationship.
- Opaque overhead art must obey the established floor/z-order contract. If cars
  can travel beneath it, under-fade behavior must remain readable.
- Ambient populations stay nonblocking, untargeted, cosmetic-local in LAN, and
  sparse enough that combat silhouettes win.
- Pure animation must not create false collision or weapon telegraphs.
- **MUST:** cosmetic weather is bounded and material-opt-in. Rain, ripples,
  wind, dust, and lighting overlays do not alter handling, collision, damage,
  visibility, or audio unless the arena brief names a separate gameplay system.
- **DEFAULT:** duplicate weather-touched materials locally; shared dry terrain
  must render byte-identically. GPU effects require a safe headless fallback.

## Campaign and LAN are one arena

- **MUST:** every new regular arena ships in both `CAMPAIGN` and `MP_MAPS` using
  the same scene.
- **MUST:** `target_cars` unique baked/declared spawn positions exist with sane
  floors. Four human seats never require a smaller special-case ruleset.
- **MUST:** `mp_managed` removes campaign cars into spawn data and stands down
  pause/end UI, lives, enemy rerolls, boss controllers, cutscenes, and victory
  choreography.
- Gameplay remains host-authoritative. Client-local ambience is allowed only
  when it cannot affect collision, damage, targeting, score, or objectives.
- **EXCEPTION:** Lackey's Arena and Goliath's Arena currently bake only player + boss and are not
  in `MP_MAPS`. They are the only grandfathered exceptions; their removal
  condition is a neutral four-plus spawn seam independent of campaign actors.

## Inserting or reordering a campaign level

The campaign order and display names live in one place; almost everything else
resolves by scene path, so a reorder is a small, safe edit. The recipe:

1. **Order + name:** edit the `CAMPAIGN` array in `game/scene_flow.gd` — the
   single source of truth for both. Move or insert the level dict; set its
   `name`. The full slot order is deliberately pinned in
   `tests/test_ground_floor.gd` (`test_campaign_order_thirteen_slots`) —
   update the expected list in the same change; that test failing on an
   unedited list is the point.
2. **Invariants to preserve:** Goliath's Arena stays last (finale), exactly
   one `specialty` entry exists, and `placeholder`/`optional` slots must
   never be last — their advance is a relative `+1`, so a next slot has to
   exist (the frame-invariants test enforces all of this).
3. **Unbuilt and optional slots:** a slot can hold its place before its level
   exists — `mode: &"placeholder"`, `scene: ""` (ArenaContract exempts it).
   The interstitial shows the shared sawhorse card
   (`assets/img/cards/level_X.png`, "UNDER CONSTRUCTION") and any key rolls
   past; consecutive placeholders chain. When the level becomes playable,
   swap in the real scene and add `"optional": true` to keep the STAY/DETOUR
   chooser (Route 666's) while it's still in test; drop the flag to make it
   mandatory. `SceneFlow.to_level` routes placeholder slots to the
   interstitial from every entry point, so restarts and jumps can't strand.
4. **Loading card:** cards are keyed by scene filename in `ui/interstitial.gd`
   (`CARDS`), never by position — add a line only if the new level has bespoke
   art. Boss levels get a `bios/` banner (also by scene name); everything else
   falls to the blocky panel. No index math is involved, so reordering never
   mismatches art.
5. **Versus:** if the level is MP-ready, add it to `MP_MAPS` (same
   `game/scene_flow.gd`) with a `cars` count and a matching `name`, and keep the
   duplicate scene list in `tests/test_spawn_distance.gd` in membership sync.
   New melee arenas also join SINGLE BATTLE's fight card automatically
   (`ui/level_select.gd` filters `CAMPAIGN` by mode/encounter — no edit).
6. **Docs:** update the Shipped-precedents table below, the Campaign table in
   `docs/matrices.md`, the Level-progression list in `CLAUDE.md`, and the
   player-facing walkthrough in `README.md`.
7. **Verify:** `tools/smoke.sh` (boots every level) and `tools/test.sh`
   (`test_ground_floor.gd` pins the slot order; `test_mp_maps.gd` validates
   every profile and the MP mirror by scene path).

## Shipped precedents

| Arena | Class / target | Dominant topology | Signature pressure | Reusable lesson |
|---|---:|---|---|---|
| Downtown Derby | Medium / 5 | city grid + park + roof pair | corners, crosswalks, rooftop rewards | districts and landmarks turn a grid into a readable place |
| Freeway Firefight | Large / 7 | long ring + infield crossover | speed, guardrails, long sightlines | a narrow dimension can work when circulation never dead-ends |
| Suburban Savagery | Medium / 7 | neighborhood blocks + yards | houses progressively open routes | destructibility can change topology without losing orientation |
| Mountainside Mayhem | Medium / 7 | switchbacks + exact-fit `DriveableHill` | ice, pits, relieved snow grades | one root/skin fits an 848 summit + 240 grades between roads; slope prop carries both floor bits |
| Lackey's Arena | Medium / planned 4 MP | containment yard | Lackey, turret, container erosion | boss logic is an overlay; destructible cover creates phases naturally |
| Piers of Pain | Large / 8 | three-floor harbor network | water, ship stunt, bridges | vertical routes need complete connectors and floor-correct rewards |
| Ground Floor Gore | Large / 8 | dirt loop + foundation + scaffold network | mud, voluntary drops, wounded generator | a dry recovery ring can frame layered risk; stateful landmarks need explicit LAN identity and counterplay |
| Goliath's Arena | Large / planned 4 MP | field bowl + continuous crown ring | Goliath phases, stair grades | bespoke encounter drama can sit on a rigorously reusable route graph |

## Copy-paste level/change brief

```markdown
# <Arena/change name>

## Intent
- Fantasy and campaign role:
- Existing precedent being extended (if any):
- Player skill or decision this should emphasize:

## Profile
- Mode: arena
- Size class: small / medium / large
- Interior size: <w × h> = <area>
- Target cars: <n>; area per car: <area/n>
- Campaign encounter: melee / miniboss / boss
- MP target and spawn plan:
- Stations:

## Topology
- One-sentence topology:
- Primary circulation loop:
- Secondary/recovery routes:
- Combat pockets and exits:
- Permanent vs destructible cover:
- Signature pressure mechanic and its counterplay:

## Surfaces and floors
- Dominant terrain and accents:
- Grades/corner grades/chamfers:
- Floors and paired connectors:
- Jump routes and landing/run-up clearance:
- Lethal hazards, telegraph, safe alternative, hazard curbs:

## Economy and readability
- Baseline / contested / traversal / secret pickups:
- Repair-bay placement and exit bearings:
- Macro landmarks at both zooms and radar:
- Ambient/deco budget and collision status:

## Implementation contract
- Reused scenes/scripts:
- New reusable primitive, if genuinely needed:
- Campaign logic that must stand down under mp_managed:
- Automated gates to add or extend:
- Human route/feel/performance playtest:

## Exceptions
- Rule:
- Reason:
- Compensating design/test:
- Removal condition:
```

## Copy-paste hill brief

```markdown
# <Hill name>
- Center / low floor / high floor:
- Summit size / grade length / derived corner leg / total footprint:
- Substrate material / terrain material / terrain type:
- Downhill pull (compact hill default 180; standalone ramp 120):
- Relief overrides (prefer shared defaults):
- Summit rewards and ambience parented to the hill:
- Slope props, draw order, and floor bits:
- Road/marking clearance:
- Eight paired connector approaches clear by 220px:
- Small-car and large-car eight-direction test route:
- Combat/overview visual check and eight-car performance result:
```

## Acceptance loop

1. Validate profile, capacity, spawn clearance, and floor topology headlessly.
2. Drive every primary, recovery, jump, grade, diagonal, drop, and secret route
   with a small and large vehicle.
3. Watch normal AI circulate, recover, scavenge, and change floors.
4. Inspect combat and overview zoom plus radar readability.
5. Run eight combatants and the authored ambience at 60 FPS.
6. Host the same scene in a two-window LAN match and verify spawn/floor parity.
7. Record any exception explicitly before calling the arena complete.
