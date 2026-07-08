extends Node2D
## Procedural per-car body paint. One style per roster id (fallback &"box" —
## the classic placeholder square) drawn in true-footprint local px; the style
## table also carries the physics-facing metrics (collision radius, skid
## contact points, steering wheels) so visuals and gameplay agree per car.
## NEVER references Vehicle (projectile-side circular-load rule): the parent
## is duck-typed where needed.

const OUTLINE := Color(0.08, 0.08, 0.1)
const NOSE_ACCENT := Color(1.0, 0.85, 0.2)  # dummy/fallback bumper strip

# half_len/half_wid = true footprint halves (px); radius = collision circle;
# skid_points = rear tire contact offsets (bike = 1); steer_wheels = front
# wheel centers that pivot with steering (empty = none).
const STYLES := {
	&"box": {
		"half_len": 26.0, "half_wid": 22.0, "radius": 22.0,
		"skid_points": [Vector2(-20, -14), Vector2(-20, 14)],
		"steer_wheels": [],
	},
}

var style_id: StringName = &"box"
var primary := Color(0.85, 0.2, 0.3)
var accent := Color(1, 1, 1)

func apply(id: StringName, primary_color: Color, accent_color: Color) -> void:
	style_id = id if STYLES.has(id) else &"box"
	primary = primary_color
	accent = accent_color
	set_process(_animated())
	queue_redraw()

func metrics() -> Dictionary:
	return STYLES[style_id]

## Footprint rectangle for the drop shadow (applied by the vehicle).
func shadow_polygon() -> PackedVector2Array:
	var m: Dictionary = metrics()
	var l: float = m.half_len
	var w: float = m.half_wid
	return PackedVector2Array([
		Vector2(-l, -w), Vector2(l, -w), Vector2(l, w), Vector2(-l, w),
	])

func _animated() -> bool:
	return false  # light bar / steering styles arrive with their cards

func _draw() -> void:
	match style_id:
		_:
			_draw_box()

## The placeholder square — dummies and unknown ids keep the classic look.
func _draw_box() -> void:
	draw_rect(Rect2(-26, -22, 52, 44), primary)
	draw_rect(Rect2(20, -22, 6, 44), NOSE_ACCENT)
