class_name FoundationDeck
extends Node2D
## Poured floor-2 slab. Collision walls/approach openings remain explicit level
## content; this node owns the unified paint, floor tag, and road surface.
## Paint carries the height read: graded ledge shadows falling south/east onto
## the yard, formed retaining faces with tie marks, 512px expansion-joint bays
## matched to the skyscraper column grid, and caution stripes at both entries.

const SLAB := Color(0.47, 0.49, 0.52)
const JOINT := Color(0.35, 0.37, 0.40)
const SUB_JOINT := Color(0.42, 0.44, 0.47)
const FACE := Color(0.33, 0.35, 0.38)
const FACE_TICK := Color(0.24, 0.26, 0.29)
const LEDGE_STEPS := 6
const LEDGE_DEPTH := 40.0
## Entry openings in LOCAL coords (walls/ramps author the world positions;
## these must track them): west embankment along the left edge, south
## concrete ramp along the bottom edge.
const WEST_GAP_Y := Vector2(-320.0, 64.0)
const SOUTH_GAP_X := Vector2(-448.0, -64.0)
## Column-grid lines in LOCAL coords (world x 64/576/1088/1600, y -1456/-944/
## -432/80) — SlabColumn anchors and expansion joints share this grid.
const GRID_X: Array[float] = [-832.0, -320.0, 192.0, 704.0]
const GRID_Y: Array[float] = [-816.0, -304.0, 208.0, 720.0]

@export var size := Vector2(2048, 1792)
@export var floor_index := 2

func _ready() -> void:
	var floor := FloorZone.new()
	floor.name = "Floor"
	floor.floor_index = floor_index
	floor.size = size
	add_child(floor)
	var terrain := TerrainZone.new()
	terrain.name = "Terrain"
	terrain.terrain_type = &"road"
	terrain.terrain_priority = 50
	terrain.collision_layer = 128
	terrain.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	terrain.add_child(col)
	add_child(terrain)
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), SLAB)
	_draw_joints(half)
	_draw_stains(half)
	_draw_anchors()
	_draw_caution_band(Rect2(-half.x, WEST_GAP_Y.x, 48.0, WEST_GAP_Y.y - WEST_GAP_Y.x), true)
	_draw_caution_band(Rect2(SOUTH_GAP_X.x, half.y - 48.0,
		SOUTH_GAP_X.y - SOUTH_GAP_X.x, 48.0), false)
	_draw_faces(half)
	_draw_ledge_shadows(half)
	draw_rect(Rect2(-half, size), Color(0.25, 0.27, 0.30), false, 5.0)

func _draw_joints(half: Vector2) -> void:
	for x in range(int(-half.x) + 128, int(half.x), 128):
		draw_line(Vector2(x, -half.y + 3), Vector2(x, half.y - 3), SUB_JOINT, 1.0)
	for y in range(int(-half.y) + 128, int(half.y), 128):
		draw_line(Vector2(-half.x + 3, y), Vector2(half.x - 3, y), SUB_JOINT, 1.0)
	for x in GRID_X:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), JOINT, 2.5)
	for y in GRID_Y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), JOINT, 2.5)

func _draw_stains(half: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	for i in 6:
		var p := _stain_point(rng, half)
		draw_circle(p, rng.randf_range(30.0, 80.0), Color(0.05, 0.06, 0.08, rng.randf_range(0.08, 0.14)))
	for i in 4:
		var p := _stain_point(rng, half)
		draw_circle(p, rng.randf_range(12.0, 24.0), Color(0.45, 0.25, 0.10, rng.randf_range(0.10, 0.16)))
		draw_circle(p, rng.randf_range(4.0, 8.0), Color(0.38, 0.20, 0.08, 0.22))
	for i in 5:
		var p := _stain_point(rng, half)
		var start := rng.randf_range(0.0, TAU)
		draw_arc(p, rng.randf_range(40.0, 90.0), start, start + rng.randf_range(1.2, 2.4),
			16, Color(0.08, 0.08, 0.09, 0.15), 4.0)
	var wash := _stain_point(rng, half)
	var wash_dir := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(90.0, 150.0)
	var side := wash_dir.orthogonal().normalized() * 22.0
	draw_colored_polygon(PackedVector2Array([
		wash - side, wash + side, wash + wash_dir + side * 0.5, wash + wash_dir - side * 0.5,
	]), Color(0.70, 0.71, 0.70, 0.10))

## Sixteen column anchors on the 512px grid: steel base plate, four bolt
## heads, and a rebar dowel cluster waiting for the pour. SlabColumns rise on
## four of these; the empty twelve promise the rest of the tower.
func _draw_anchors() -> void:
	for x in GRID_X:
		for y in GRID_Y:
			var p := Vector2(x, y)
			draw_rect(Rect2(p - Vector2(24, 24), Vector2(48, 48)), Color(0.40, 0.42, 0.45))
			draw_rect(Rect2(p - Vector2(24, 24), Vector2(48, 48)),
				Color(0.30, 0.32, 0.35), false, 2.0)
			for d: Vector2 in [Vector2(-14, -14), Vector2(14, -14),
					Vector2(-14, 14), Vector2(14, 14)]:
				draw_circle(p + d, 3.5, Color(0.22, 0.23, 0.26))
			for d: Vector2 in [Vector2(-6, 0), Vector2(6, -5), Vector2(2, 7)]:
				draw_circle(p + d, 2.5, Color(0.38, 0.24, 0.14))

func _stain_point(rng: RandomNumberGenerator, half: Vector2) -> Vector2:
	return Vector2(rng.randf_range(-half.x + 90.0, half.x - 90.0),
		rng.randf_range(-half.y + 90.0, half.y - 90.0))

## Yellow/black construction striping painted onto the slab at both grade
## entries; stripes advance along the entry's width with a lazy 45-degree cut.
func _draw_caution_band(rect: Rect2, vertical: bool) -> void:
	var step := 26.0
	var k := 0
	var t := rect.position.y if vertical else rect.position.x
	var end := rect.end.y if vertical else rect.end.x
	while t < end - 1.0:
		var t2 := minf(t + step, end)
		var col := Color(0.83, 0.65, 0.10, 0.85) if k % 2 == 0 else Color(0.10, 0.10, 0.12, 0.80)
		if vertical:
			draw_colored_polygon(PackedVector2Array([
				Vector2(rect.position.x, t), Vector2(rect.position.x, t2),
				Vector2(rect.end.x, minf(t2 + 14.0, end)), Vector2(rect.end.x, minf(t + 14.0, end)),
			]), col)
		else:
			draw_colored_polygon(PackedVector2Array([
				Vector2(t, rect.position.y), Vector2(t2, rect.position.y),
				Vector2(minf(t2 + 14.0, end), rect.end.y), Vector2(minf(t + 14.0, end), rect.end.y),
			]), col)
		t = t2
		k += 1

## Formed-concrete retaining faces on the sun-facing south/east rims, with
## form-tie marks every 64px; both entry gaps stay open.
func _draw_faces(half: Vector2) -> void:
	for seg: Array in [[-half.x, SOUTH_GAP_X.x], [SOUTH_GAP_X.y, half.x]]:
		var a := float(seg[0])
		var b := float(seg[1])
		draw_rect(Rect2(Vector2(a, half.y), Vector2(b - a, 10.0)), FACE)
		var x := ceilf(a / 64.0) * 64.0 + 32.0
		while x < b:
			draw_line(Vector2(x, half.y + 1.0), Vector2(x, half.y + 9.0), FACE_TICK, 3.0)
			x += 64.0
	draw_rect(Rect2(Vector2(half.x, -half.y), Vector2(8.0, size.y)), FACE)
	var y := -half.y + 32.0
	while y < half.y:
		draw_line(Vector2(half.x + 1.0, y), Vector2(half.x + 7.0, y), FACE_TICK, 3.0)
		y += 64.0

## The dock ledge idiom: 6-step falloff bands dropping onto the floor-1 yard
## south and east, a thin ambient seat north and west, entries skipped.
func _draw_ledge_shadows(half: Vector2) -> void:
	var step_h := LEDGE_DEPTH / LEDGE_STEPS
	for i in LEDGE_STEPS:
		var a := 0.26 * (1.0 - float(i) / float(LEDGE_STEPS))
		var y := half.y + float(i) * step_h
		draw_rect(Rect2(Vector2(-half.x, y),
			Vector2(SOUTH_GAP_X.x + half.x, step_h + 1.0)), Color(0, 0, 0, a))
		draw_rect(Rect2(Vector2(SOUTH_GAP_X.y, y),
			Vector2(half.x - SOUTH_GAP_X.y, step_h + 1.0)), Color(0, 0, 0, a))
		draw_rect(Rect2(Vector2(half.x + float(i) * step_h, -half.y),
			Vector2(step_h + 1.0, size.y + LEDGE_DEPTH)), Color(0, 0, 0, a))
	draw_rect(Rect2(Vector2(-half.x, -half.y - 12.0), Vector2(size.x, 12.0)), Color(0, 0, 0, 0.12))
	draw_rect(Rect2(Vector2(-half.x - 12.0, -half.y), Vector2(12.0, WEST_GAP_Y.x + half.y)),
		Color(0, 0, 0, 0.12))
	draw_rect(Rect2(Vector2(-half.x - 12.0, WEST_GAP_Y.y), Vector2(12.0, half.y - WEST_GAP_Y.y)),
		Color(0, 0, 0, 0.12))
