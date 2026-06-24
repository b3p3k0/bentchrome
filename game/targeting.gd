class_name Targeting
extends RefCounted
## Shared target queries over the "vehicles" group — used by homing weapons and,
## later, beams / dashes / triggers. Static; resolves the running SceneTree via
## Engine.get_main_loop().

static func nearest_other(from: Vector2, exclude: Node, max_dist: float) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var best: Node2D = null
	var best_dist := max_dist
	for v in tree.get_nodes_in_group(&"vehicles"):
		if v == exclude:
			continue
		var d: float = from.distance_to(v.global_position)
		if d < best_dist:
			best_dist = d
			best = v
	return best
