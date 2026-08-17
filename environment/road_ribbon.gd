extends Node2D
## Organic street painter — road_marks' FILLED sibling. Takes a node-local
## polyline and a width and paints a continuous tarmac ribbon: one quad per
## segment plus a rounded join disc at every interior point, so diagonal
## avenues, gentle curves, and traffic circles (closed rings) are ONE node
## each instead of hand-tessellated polygons. Author `material` with the
## level's worn-tarmac speckle ShaderMaterial for the dappled surface look.
## Paint only: no collision, AI-blind, z 0 under cars. Buildings, curbs, and
## fences along an avenue are ordinary instances with `rotation` set to the
## avenue's angle — collision owners may rotate, never scale.

@export var points := PackedVector2Array()  # node-local centerline (>= 2 points)
@export var width := 256.0                  # full ribbon width
@export var closed := false                 # true = ring: last point joins first
@export var surface := Color(0.16, 0.16, 0.185)
@export var edge_color := Color(0.85, 0.86, 0.88, 0.5)
@export var edge_lines := true              # thin edge strokes, inset slightly

const EDGE_W := 4.0
const EDGE_INSET := 6.0

func _draw() -> void:
	if points.size() < 2:
		return
	for quad in build_quads(points, width, closed):
		draw_colored_polygon(quad, surface)
	# Round joins: a disc at every point papers over the segment miters and
	# gives open runs rounded end caps for free.
	for p in points:
		draw_circle(p, width * 0.5, surface)
	if not edge_lines:
		return
	var half := width * 0.5 - EDGE_INSET
	var segs := points.size() if closed else points.size() - 1
	for i in segs:
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var n := (b - a).normalized().orthogonal() * half
		draw_line(a + n, b + n, edge_color, EDGE_W)
		draw_line(a - n, b - n, edge_color, EDGE_W)

## One quad per segment, expanded perpendicular by width/2. Static so tests
## can probe the geometry without a canvas.
static func build_quads(line: PackedVector2Array, w: float, ring: bool) -> Array[PackedVector2Array]:
	var quads: Array[PackedVector2Array] = []
	if line.size() < 2:
		return quads
	var segs := line.size() if ring else line.size() - 1
	for i in segs:
		var a := line[i]
		var b := line[(i + 1) % line.size()]
		if a.is_equal_approx(b):
			continue
		var n := (b - a).normalized().orthogonal() * w * 0.5
		quads.append(PackedVector2Array([a + n, b + n, b - n, a - n]))
	return quads
