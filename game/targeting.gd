class_name Targeting
extends RefCounted
## Shared target queries over the "vehicles" group — used by homing weapons,
## beams, dashes, and triggers. Static; resolves the running SceneTree via
## Engine.get_main_loop(). Pass same_floor_as to restrict candidates to that
## node's terrace (contact-style specials); omit it for floor-blind queries
## (tracking weapons acquire across floors by design).

const Floors := preload("res://game/floors.gd")

## True only for a living vehicle other than `exclude`. Kept independent of
## range/floor/cone so designation and individual weapon constraints compose.
static func is_live_other(exclude: Node, candidate: Variant) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate == exclude:
		return false
	if not candidate is Node2D or not candidate.is_in_group(&"vehicles"):
		return false
	if candidate.has_method(&"get_hp") and candidate.get_hp() <= 0.0:
		return false
	return true

## Shared range/floor eligibility for later designation consumers. This does
## not replace the legacy nearest queries, whose behavior remains unchanged.
static func is_eligible_other(from: Vector2, exclude: Node, candidate: Variant,
		max_dist: float, same_floor_as: Node = null) -> bool:
	if not is_live_other(exclude, candidate):
		return false
	if same_floor_as != null and not Floors.same_floor(same_floor_as, candidate):
		return false
	return from.distance_to(candidate.global_position) < max_dist

## Reads the component-owned designation without inventing a fallback. Callers
## that support non-vehicle fixtures can distinguish a missing component and
## retain their existing nearest query.
static func designated_target(vehicle: Node) -> Node2D:
	if vehicle == null or not is_instance_valid(vehicle):
		return null
	var designator := vehicle.get_node_or_null(^"TargetDesignator")
	if designator == null or not designator.has_method(&"get_target"):
		return null
	var target: Variant = designator.get_target()
	return target as Node2D if is_live_other(vehicle, target) else null

static func nearest_other(from: Vector2, exclude: Node, max_dist: float,
		same_floor_as: Node = null) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var best: Node2D = null
	var best_dist := max_dist
	for v in tree.get_nodes_in_group(&"vehicles"):
		if v == exclude:
			continue
		if same_floor_as != null and not Floors.same_floor(same_floor_as, v):
			continue
		var d: float = from.distance_to(v.global_position)
		if d < best_dist:
			best_dist = d
			best = v
	return best

## nearest_other, but only what sits inside `half_angle` (radians) of
## `facing` — a forward-only lock (the Route 666 Leap: never an about-face
## into whatever is nearest).
static func nearest_in_cone(from: Vector2, facing: Vector2, half_angle: float, exclude: Node,
		max_dist: float, same_floor_as: Node = null) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var floor_cos := cos(half_angle)
	var nose := facing.normalized()
	var best: Node2D = null
	var best_dist := max_dist
	for v in tree.get_nodes_in_group(&"vehicles"):
		if v == exclude:
			continue
		if same_floor_as != null and not Floors.same_floor(same_floor_as, v):
			continue
		var to: Vector2 = v.global_position - from
		var d := to.length()
		if d >= best_dist or d < 0.001 or nose.dot(to / d) < floor_cos:
			continue
		best_dist = d
		best = v
	return best
