class_name TerrainZone
extends Area2D
## A painted surface region (road/dirt/ice/water). The vehicle's TerrainSensor
## reads terrain_type to modulate grip, acceleration, and top speed.
## The painted Vis polygon is softened at ready — rounded corners, jittered
## edges — so fields read organic instead of surveyor-straight. Paint only:
## the Col shape (grip footprint) and the radar's rect stay crisp.

const CORNER_RADIUS := 48.0  # how far corners pull in before rounding
const EDGE_STEP := 96.0      # jitter a point roughly every this many px
const EDGE_JITTER := 10.0    # max perpendicular wobble

@export var terrain_type: StringName = &"road"

func _ready() -> void:
	var vis := get_node_or_null(^"Vis") as Polygon2D
	if vis and vis.polygon.size() >= 3:
		vis.polygon = _soften(vis.polygon)

## Deterministic per-zone: rounds each corner (chamfer + inward mid point) and
## subdivides/jitters the straights between them.
func _soften(poly: PackedVector2Array) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + 17
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var prev := poly[(i - 1 + n) % n]
		var cur := poly[i]
		var next := poly[(i + 1) % n]
		var dir_prev := (prev - cur).normalized()
		var dir_next := (next - cur).normalized()
		var r := minf(CORNER_RADIUS, minf((prev - cur).length(), (next - cur).length()) * 0.4)
		var a := cur + dir_prev * r
		var b := cur + dir_next * r
		out.append(a)
		out.append(cur + (dir_prev + dir_next) * r * 0.3)  # rounded shoulder
		out.append(b)
		# The straight from this corner's exit to the next corner's entry.
		var edge_end := next + (cur - next).normalized() * r
		var edge := edge_end - b
		var steps := int(edge.length() / EDGE_STEP)
		if steps > 1:
			var perp := edge.normalized().orthogonal()
			for s in range(1, steps):
				out.append(b + edge * (float(s) / steps)
					+ perp * rng.randf_range(-EDGE_JITTER, EDGE_JITTER))
	return out
