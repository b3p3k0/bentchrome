extends RefCounted
## Multi-floor terrain math, dependency-free ON PURPOSE — same contract as
## combat.gd: no class_name, no preloads, duck-typing only. Scripts on the
## projectile side of the graph load this; naming Vehicle here creates a
## circular resource load that kills cold boots.
##
## Floors are terraced — every point on the map has exactly one driveable
## floor (1 = sea level, 2 = street/dock, 3 = rooftops). A warehouse is a wall
## to a floor-2 car and a driving surface to a floor-3 car. floor_index -1 =
## legacy single-plane level; every helper degrades to today's exact
## layer/mask values there, bit for bit.
##
## Collision channels (project.godot): 1 ground | 2 wall | 4 obstacle |
## 8/16/32 floor low/mid/high | 64 hazard_edge (AI feelers only) |
## 128 terrain | 256 floor_tag.

static var VISUAL_SCALE := {1: 0.94, 2: 1.0, 3: 1.06}  # size cue — visuals only, NEVER radii
static var DROP_POP_VZ := 240.0    # ledge-hop impulse per floor dropped
static var FALL_FREE_FLOORS := 1   # drops this many floors deep stay free

const MIN_FLOOR := 1
const MAX_FLOOR := 3

static func floor_bit(floor_index: int) -> int:
	return 8 << (clampi(floor_index, MIN_FLOOR, MAX_FLOOR) - 1)

## Duck-typed floor of any node; -1 = not floor-aware (legacy).
static func floor_of(node: Object) -> int:
	if node == null:
		return -1
	var f: Variant = node.get("floor_index")
	return int(f) if f is int else -1

## Legacy participants never gate — only two floor-aware nodes can mismatch.
static func same_floor(a: Object, b: Object) -> bool:
	var fa := floor_of(a)
	var fb := floor_of(b)
	return fa < MIN_FLOOR or fb < MIN_FLOOR or fa == fb

## Vehicle collision_layer while grounded. Bit 1 stays on in every mode —
## pickups, stations, mines, pits, and the radar all key on the ground bit.
static func ground_layer(floor_index: int) -> int:
	if floor_index < MIN_FLOOR:
		return 1
	return 1 | floor_bit(floor_index)

## Vehicle collision_mask while grounded. Floor mode drops the plain ground +
## obstacle bits: same-floor cars and statics carry the floor bit instead.
static func ground_mask(floor_index: int) -> int:
	if floor_index < MIN_FLOOR:
		return 1 | 2 | 4
	return 2 | floor_bit(floor_index)

## Projectile flight mask. Straight shots live entirely on the shooter's
## floor — no plain vehicle bit, so a cross-floor car is never even signaled.
## Tracking shots "arc" between floors: boundary walls only, any vehicle.
static func projectile_mask(floor_index: int, tracking: bool) -> int:
	if floor_index < MIN_FLOOR:
		return 1 | 2 | 4  # legacy; the mount applies pierces_cover on top
	if tracking:
		return 1 | 2
	return 2 | floor_bit(floor_index)

## Line-of-sight raycast mask (beams, AI fire gates): walls + whatever blocks
## on the caster's floor; legacy keeps today's ground|wall|obstacle.
static func los_mask(floor_index: int) -> int:
	if floor_index < MIN_FLOOR:
		return 1 | 2 | 4
	return 1 | 2 | floor_bit(floor_index)
