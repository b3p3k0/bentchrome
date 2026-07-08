extends Area2D
## Drop-off hazard: a grounded vehicle that strays in falls off the map —
## shrinks into the void, then dies (no explosion; gravity doesn't pop).
## Airborne cars (ramp jumps) sail straight over. The kill area is inset from
## the painted edge so clipping the rim doesn't instantly doom you. Exported
## size, like the destructible block, so one scene serves any cliff.

const VOID := Color(0.02, 0.02, 0.04)
const RIM := Color(0.55, 0.5, 0.2, 0.8)  # hazard-yellow lip
const KILL_INSET := 48.0

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
	var pts := _rounded_rect(size * 0.5, 32.0)
	draw_colored_polygon(pts, VOID)
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
