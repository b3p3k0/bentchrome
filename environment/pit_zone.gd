extends Area2D
## Drop-off hazard: a grounded vehicle that strays in falls off the map —
## shrinks into the void, then dies (no explosion; gravity doesn't pop).
## Airborne cars (ramp jumps) sail straight over. The kill area is inset from
## the painted edge so clipping the rim doesn't instantly doom you. Exported
## size, like the destructible block, so one scene serves any cliff.

const VOID := Color(0.015, 0.018, 0.03)
const RIM := Color(0.55, 0.5, 0.2, 0.8)  # hazard-yellow lip
const SNOW_CAP := Color(0.78, 0.82, 0.9)
const SNOW_GLINT := Color(0.94, 0.96, 1.0, 0.85)
const CLIFF_FACE := Color(0.28, 0.29, 0.34)
const CLIFF_STRIPE := Color(0.43, 0.44, 0.49, 0.65)
const OCCLUSION := Color(0.055, 0.055, 0.075)
const CRACK := Color(0.14, 0.15, 0.19)
const KILL_INSET := 48.0

# Presentation knobs: a tight cap over one compressed face reads as a sheer
# snow cut from above. These never touch the collision or kill inset.
static var SNOW_CAP_WIDTH := 12.0
static var CLIFF_FACE_WIDTH := 52.0
static var STRIATION_GAP := 9.0
static var OCCLUSION_OFFSET := Vector2(0.0, 12.0)

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
			var body_2d := body as Node2D
			if body_2d:
				var target: Vector2 = fall_target_for(body_2d.global_position)
				body.call(&"fall_into_pit", target)

## The long cliff should swallow a car across its short axis, never vacuum it
## hundreds of pixels along the drop. A square chooses the dominant normalized
## entry axis, so its nearest deep centerline stays deterministic too.
func fall_target_for(world_position: Vector2) -> Vector2:
	var local_position: Vector2 = to_local(world_position)
	if size.x < size.y:
		local_position.x = 0.0
	elif size.y < size.x:
		local_position.y = 0.0
	else:
		var half: Vector2 = (size * 0.5).max(Vector2.ONE)
		var nx: float = absf(local_position.x) / half.x
		var ny: float = absf(local_position.y) / half.y
		if nx >= ny:
			local_position.x = 0.0
		else:
			local_position.y = 0.0
	return to_global(local_position)

func _draw() -> void:
	# One steep face, not a terraced excavation: snow overhang, compressed rock
	# grain, then a hard occlusion break into black. The southward void offset
	# exposes more of the lit far wall and makes the depth directional.
	var outer_half: Vector2 = size * 0.5
	var cap_width: float = minf(SNOW_CAP_WIDTH, minf(outer_half.x, outer_half.y) * 0.2)
	var face_half: Vector2 = (outer_half - Vector2.ONE * cap_width).max(Vector2(24.0, 24.0))
	var face_width: float = minf(CLIFF_FACE_WIDTH,
		minf(face_half.x, face_half.y) - 12.0)
	face_width = maxf(face_width, 8.0)
	var void_half: Vector2 = (face_half - Vector2.ONE * face_width).max(Vector2(12.0, 12.0))
	var outer: PackedVector2Array = _rounded_rect(outer_half, 32.0)
	var face: PackedVector2Array = _rounded_rect(face_half, 27.0)
	var void_shape: PackedVector2Array = _rounded_rect(void_half,
		maxf(27.0 - face_width * 0.3, 7.0))
	draw_colored_polygon(outer, SNOW_CAP)
	draw_colored_polygon(face, CLIFF_FACE)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0)) + 41
	# Tight perspective scratches run down the single face. The void is drawn
	# afterward and clips their inner ends into a hard bottomless edge.
	var gap: float = maxf(STRIATION_GAP, 3.0)
	var x := -face_half.x + gap
	while x < face_half.x:
		var jitter := rng.randf_range(-2.5, 2.5)
		draw_line(Vector2(x, -face_half.y),
			Vector2(x + jitter, -void_half.y) + OCCLUSION_OFFSET, CLIFF_STRIPE, 1.0)
		draw_line(Vector2(x, face_half.y),
			Vector2(x - jitter, void_half.y) + OCCLUSION_OFFSET, CRACK, 1.0)
		x += gap
	var y := -face_half.y + gap
	while y < face_half.y:
		var jitter := rng.randf_range(-2.5, 2.5)
		draw_line(Vector2(-face_half.x, y),
			Vector2(-void_half.x, y + jitter) + OCCLUSION_OFFSET, CLIFF_STRIPE, 1.0)
		draw_line(Vector2(face_half.x, y),
			Vector2(void_half.x, y - jitter) + OCCLUSION_OFFSET, CRACK, 1.0)
		y += gap

	var shadow_shape: PackedVector2Array = _rounded_rect(void_half + Vector2.ONE * 7.0,
		maxf(30.0 - face_width * 0.3, 8.0))
	draw_colored_polygon(_offset_polygon(shadow_shape, OCCLUSION_OFFSET * 0.35), OCCLUSION)
	draw_colored_polygon(_offset_polygon(void_shape, OCCLUSION_OFFSET), VOID)

	# Dense little snow glints keep the cap texture finer than the broad driving
	# surface; a few dark splits stop the overhang from reading manufactured.
	var cap_marks := maxi(14, int(round((size.x + size.y) / 20.0)))
	for i in cap_marks:
		var edge := rng.randi() % 4
		var at := Vector2(
			rng.randf_range(-outer_half.x + 10.0, outer_half.x - 10.0),
			rng.randf_range(-outer_half.y + 10.0, outer_half.y - 10.0))
		match edge:
			0: at.y = -outer_half.y + rng.randf_range(2.0, cap_width - 2.0)
			1: at.y = outer_half.y - rng.randf_range(2.0, cap_width - 2.0)
			2: at.x = -outer_half.x + rng.randf_range(2.0, cap_width - 2.0)
			3: at.x = outer_half.x - rng.randf_range(2.0, cap_width - 2.0)
		draw_circle(at, rng.randf_range(0.8, 1.8), SNOW_GLINT)
	# Crumbling lip: short cracks split out into the road snow.
	var cracks := 5 + rng.randi() % 4
	for i in cracks:
		var a := rng.randf_range(0.0, TAU)
		var dir := Vector2.RIGHT.rotated(a)
		var start := Vector2(dir.x * outer_half.x, dir.y * outer_half.y) * 0.98
		var mid := start + dir * rng.randf_range(6.0, 12.0) \
			+ dir.orthogonal() * rng.randf_range(-5.0, 5.0)
		var tip := mid + dir * rng.randf_range(5.0, 10.0) \
			+ dir.orthogonal() * rng.randf_range(-4.0, 4.0)
		draw_line(start, mid, CRACK, 2.0)
		draw_line(mid, tip, CRACK, 1.4)
	var closed := outer.duplicate()
	closed.append(outer[0])
	draw_polyline(closed, RIM, 3.0)

func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + offset)
	return moved

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
