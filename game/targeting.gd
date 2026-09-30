class_name Targeting
extends RefCounted
## Shared target queries over the "vehicles" group — used by homing weapons,
## beams, dashes, and triggers. Static; resolves the running SceneTree via
## Engine.get_main_loop(). Pass same_floor_as to restrict candidates to that
## node's terrace (contact-style specials); omit it for floor-blind queries
## (tracking weapons acquire across floors by design).

const Floors := preload("res://game/floors.gd")

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
