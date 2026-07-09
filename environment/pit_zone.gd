extends Area2D
## Drop-off hazard: a grounded vehicle that strays in falls off the map —
## shrinks into the void, then dies (no explosion; gravity doesn't pop).
## Airborne cars (ramp jumps) sail straight over. The kill area is inset from
## the painted edge so clipping the rim doesn't instantly doom you. Exported
## size, like the destructible block, so one scene serves any cliff.

const VOID := Color(0.02, 0.02, 0.04)
const RIM := Color(0.55, 0.5, 0.2, 0.8)      # hazard-yellow lip
const STRATA_TOP := Color(0.28, 0.26, 0.29)  # upper rock shelf, still catching light
const CRACK := Color(0.14, 0.13, 0.16)
const RUBBLE := Color(0.36, 0.34, 0.37)
const KILL_INSET := 48.0
const STRATA_STEPS := 3  # visible wall storeys before the black swallows it

@export var size := Vector2(256, 256)

var is_pit := true  # minimap duck-type marker

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = (size - Vector2(KILL_INSET, KILL_INSET)).max(Vector2(32, 32))
	col.shape = shape
	add_child(col)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method(&"fall_into_pit") and body.get("height") == 0.0:
			body.fall_into_pit()

func _draw() -> void:
	# A drop you can read: descending rock strata — each ring a storey deeper,
	# darker, and nudged south so the sunlit far wall shows under the north
	# rim — until the void swallows the bottom. Crumbling cracks split the
	# lip; rubble clings to the top shelf. All seeded per position.
	var pts := _rounded_rect(size * 0.5, 32.0)
	draw_colored_polygon(pts, STRATA_TOP)
	for i in STRATA_STEPS:
		var t := float(i + 1) / float(STRATA_STEPS)
		var half := size * 0.5 * (1.0 - 0.2 * (i + 1))
		if half.x < 20.0 or half.y < 20.0:
			break
		var ring := _rounded_rect(half, maxf(32.0 * (1.0 - 0.25 * i), 8.0))
		var off := Vector2(0.0, 9.0 + 6.0 * i)
		var moved := PackedVector2Array()
		for p in ring:
			moved.append(p + off)
		draw_colored_polygon(moved, STRATA_TOP.lerp(VOID, t))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0)) + 41
	# Rubble on the top shelf, hugging the rim band.
	for i in 7 + rng.randi() % 4:
		var edge := rng.randi() % 4
		var at := Vector2(
			rng.randf_range(-size.x * 0.5 + 18.0, size.x * 0.5 - 18.0),
			rng.randf_range(-size.y * 0.5 + 18.0, size.y * 0.5 - 18.0))
		match edge:
			0: at.y = -size.y * 0.5 + rng.randf_range(8.0, 22.0)
			1: at.y = size.y * 0.5 - rng.randf_range(8.0, 22.0)
			2: at.x = -size.x * 0.5 + rng.randf_range(8.0, 22.0)
			3: at.x = size.x * 0.5 - rng.randf_range(8.0, 22.0)
		var r := rng.randf_range(2.0, 5.0)
		draw_circle(at, r, RUBBLE if rng.randf() < 0.6 else CRACK)
	# Crumbling lip: short jagged cracks splitting outward past the rim.
	var cracks := 5 + rng.randi() % 4
	for i in cracks:
		var a := rng.randf_range(0.0, TAU)
		var dir := Vector2.RIGHT.rotated(a)
		var start := Vector2(dir.x * size.x * 0.5, dir.y * size.y * 0.5) * 0.98
		var mid := start + dir * rng.randf_range(6.0, 12.0) \
			+ dir.orthogonal() * rng.randf_range(-5.0, 5.0)
		var tip := mid + dir * rng.randf_range(5.0, 10.0) \
			+ dir.orthogonal() * rng.randf_range(-4.0, 4.0)
		draw_line(start, mid, CRACK, 2.0)
		draw_line(mid, tip, CRACK, 1.4)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, RIM, 3.0)

## Soft-cornered rect: chamfer points + an inward shoulder per corner, matching
## the terrain-zone treatment so hazards sit in the same visual language.
func _rounded_rect(half: Vector2, r: float) -> PackedVector2Array:
	r = minf(r, minf(half.x, half.y) * 0.6)
	var corners := [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	]
	var out := PackedVector2Array()
	for i in corners.size():
		var prev: Vector2 = corners[(i - 1 + corners.size()) % corners.size()]
		var cur: Vector2 = corners[i]
		var next: Vector2 = corners[(i + 1) % corners.size()]
		var dir_prev := (prev - cur).normalized()
		var dir_next := (next - cur).normalized()
		out.append(cur + dir_prev * r)
		out.append(cur + (dir_prev + dir_next) * r * 0.3)
		out.append(cur + dir_next * r)
	return out
