extends RefCounted
## Shared paint vocabulary for the procedural fleet: the palette plus the
## hull/outline/wheel/headlight primitives every style file draws with.
## Style files preload this; car_paint.gd preloads the style files — never
## the reverse (no cycles). NEVER references Vehicle.

const OUTLINE := Color(0.08, 0.08, 0.1)
const NOSE_ACCENT := Color(1.0, 0.85, 0.2)  # dummy/fallback bumper strip
const GLASS := Color(0.3, 0.42, 0.52)
const TIRE := Color(0.09, 0.09, 0.11)
const CHROME := Color(0.78, 0.8, 0.84)
const CLOTH := Color(0.93, 0.91, 0.86)   # bumper's convertible roof
const LIVERY := Color(0.88, 0.9, 0.92)   # smoky's white door panels
const LIGHT_RED := Color(1.0, 0.18, 0.12)
const LIGHT_BLUE := Color(0.25, 0.45, 1.0)

## Octagonal hull: a rect with chamfered nose/tail corners. Nose at +X.
static func hull(l: float, w: float, nose_cut: float, tail_cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-l, -w + tail_cut), Vector2(-l + tail_cut, -w),
		Vector2(l - nose_cut, -w), Vector2(l, -w + nose_cut),
		Vector2(l, w - nose_cut), Vector2(l - nose_cut, w),
		Vector2(-l + tail_cut, w), Vector2(-l, w - tail_cut),
	])

static func outline(c: CanvasItem, pts: PackedVector2Array) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, OUTLINE, 1.5)

static func wheel(c: CanvasItem, center: Vector2, size: Vector2, angle := 0.0) -> void:
	c.draw_set_transform(center, angle, Vector2.ONE)
	c.draw_rect(Rect2(-size * 0.5, size), TIRE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func headlights(c: CanvasItem, nose_x: float, w: float) -> void:
	c.draw_rect(Rect2(nose_x - 3, -w + 1, 3, 3), NOSE_ACCENT)
	c.draw_rect(Rect2(nose_x - 3, w - 4, 3, 3), NOSE_ACCENT)
