extends Node2D
## Capital City landmark paint — the stadium_deco/dock_deco idiom: pure
## cosmetics, AI-blind, non-colliding. Solids underneath stay building_deco /
## raw statics with proper floor bits; this layer only makes them read as the
## postcard. One node per landmark, `kind` picks the plan, `size` scales it.

@export var kind: StringName = &"fountain"
@export var size := Vector2(256, 256)

const MARBLE := Color(0.82, 0.81, 0.77)
const MARBLE_LIGHT := Color(0.9, 0.89, 0.85)
const MARBLE_DARK := Color(0.62, 0.61, 0.57)
const GRANITE := Color(0.1, 0.1, 0.12)
const BRONZE := Color(0.38, 0.36, 0.28)
const SHADOW := Color(0, 0, 0, 0.28)
const WATER := Color(0.2, 0.38, 0.6, 0.75)
const FLAME := Color(1.0, 0.62, 0.15)
const PLAZA := Color(0.56, 0.53, 0.46, 0.85)   # pale gravel pad under a landmark
const PLAZA_EDGE := Color(0.42, 0.4, 0.35)
const ALGAE := Color(0.3, 0.46, 0.2, 0.8)      # the pool nobody has cleaned
const ALGAE_DARK := Color(0.2, 0.33, 0.13, 0.9)

## Pale gravel plaza pad — memorials sit ON something, not on raw lawn.
func _draw_plaza(pad: Vector2) -> void:
	draw_rect(Rect2(-pad * 0.5, pad), PLAZA)
	draw_rect(Rect2(-pad * 0.5, pad), PLAZA_EDGE, false, 2.0)

func _ready() -> void:
	queue_redraw()

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0)) + 31
	return rng

func _draw() -> void:
	match kind:
		&"lincoln":
			_draw_lincoln()
		&"obelisk":
			_draw_obelisk()
		&"capitol":
			_draw_capitol()
		&"white_house":
			_draw_white_house()
		&"pentagon":
			_draw_pentagon()
		&"ww2_ring":
			_draw_ww2_ring()
		&"vietnam_wall":
			_draw_vietnam_wall()
		&"korean_patrol":
			_draw_korean_patrol()
		&"headstone_rows":
			_draw_headstone_rows()
		&"eternal_flame":
			_draw_eternal_flame()
		&"fountain":
			_draw_fountain()
		&"bridge_deck":
			_draw_bridge_deck()
		&"pool_surround":
			_draw_pool_surround()

## Greek temple in plan: gravel plaza, stepped plinth, a real peristyle of
## paired column dots, dark cella with the seated figure glowing inside,
## and a broad east stair cascade toward the pool.
func _draw_lincoln() -> void:
	var half := size * 0.5
	_draw_plaza(size * Vector2(1.7, 1.45))
	draw_rect(Rect2(-half + Vector2(12, 16), size), SHADOW)
	# Stepped plinth: three shrinking marble courses.
	draw_rect(Rect2(-half, size), MARBLE_DARK)
	draw_rect(Rect2(-half * 0.94, size * 0.94), MARBLE)
	draw_rect(Rect2(-half * 0.86, size * 0.86), MARBLE_LIGHT)
	draw_rect(Rect2(-half * 0.86, size * 0.86), MARBLE_DARK, false, 2.0)
	# Peristyle: bold column pairs marching the inner rectangle's edge.
	var inner := size * 0.7
	var cols_x := maxi(int(inner.x / 26.0), 4)
	var cols_y := maxi(int(inner.y / 26.0), 6)
	for i in cols_x + 1:
		var x := -inner.x * 0.5 + inner.x * i / cols_x
		for yy: float in [-inner.y * 0.5, inner.y * 0.5]:
			draw_circle(Vector2(x, yy), 6.5, MARBLE_DARK)
			draw_circle(Vector2(x, yy), 4.0, MARBLE)
	for i in range(1, cols_y):
		var y := -inner.y * 0.5 + inner.y * i / cols_y
		for xx: float in [-inner.x * 0.5, inner.x * 0.5]:
			draw_circle(Vector2(xx, y), 6.5, MARBLE_DARK)
			draw_circle(Vector2(xx, y), 4.0, MARBLE)
	# Cella: the dark chamber, opening east toward the pool.
	draw_rect(Rect2(-size.x * 0.24, -size.y * 0.3, size.x * 0.4, size.y * 0.6), GRANITE)
	draw_rect(Rect2(-size.x * 0.24, -size.y * 0.3, size.x * 0.4, size.y * 0.6),
		MARBLE_DARK, false, 2.0)
	draw_circle(Vector2(-size.x * 0.06, 0), 9.0, MARBLE_LIGHT)  # the seated figure
	draw_circle(Vector2(-size.x * 0.06, 0), 4.0, MARBLE)
	# East stair cascade: five broad steps falling toward the Mall.
	for i in 5:
		var x := half.x * 0.86 + 4.0 + i * 7.0
		draw_line(Vector2(x, -half.y * (0.62 - i * 0.06)),
			Vector2(x, half.y * (0.62 - i * 0.06)),
			MARBLE_DARK if i % 2 == 0 else MARBLE_LIGHT, 6.0)

## The monument in plan is tiny — the READ is its enormous SE shadow and the
## flag ring. Sits atop the knoll summit; the solid core is authored apart.
func _draw_obelisk() -> void:
	var s := size.x
	# Storm-light shadow: a long tapered blade falling southeast, with the
	# pyramidion tip drawn sharp at the far end.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.26, s * 0.26), Vector2(s * 0.26, -s * 0.26),
		Vector2(s * 6.6, s * 5.7), Vector2(s * 6.1, s * 6.6),
	]), Color(0, 0, 0, 0.24))
	draw_colored_polygon(PackedVector2Array([
		Vector2(s * 6.1, s * 6.6), Vector2(s * 6.6, s * 5.7),
		Vector2(s * 7.3, s * 6.9),
	]), Color(0, 0, 0, 0.28))
	# The 50-flag ring on its paved circle.
	draw_circle(Vector2.ZERO, s * 1.95, Color(PLAZA.r, PLAZA.g, PLAZA.b, 0.5))
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector2(s * 1.7, 0).rotated(a)
		draw_circle(p, 3.0, MARBLE_DARK)
		draw_rect(Rect2(p + Vector2(1.0, -6.0), Vector2(5.0, 3.5)), Color(0.75, 0.2, 0.2))
	# The shaft seen from above: bright marble courses stepping to the point.
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), MARBLE)
	draw_rect(Rect2(-s * 0.36, -s * 0.36, s * 0.72, s * 0.72), MARBLE_LIGHT)
	draw_rect(Rect2(-s * 0.22, -s * 0.22, s * 0.44, s * 0.44), Color(0.95, 0.94, 0.9))
	draw_rect(Rect2(-s * 0.1, -s * 0.1, s * 0.2, s * 0.2), MARBLE_DARK)  # pyramidion
	draw_line(Vector2(-s * 0.5, -s * 0.5), Vector2(s * 0.5, s * 0.5), MARBLE_DARK, 1.5)
	draw_line(Vector2(s * 0.5, -s * 0.5), Vector2(-s * 0.5, s * 0.5), MARBLE_DARK, 1.5)
	draw_circle(Vector2.ZERO, 2.5, Color(0.9, 0.2, 0.2))  # aircraft beacon

## Rotunda + wings in plan: the dome is concentric rings over the crossing.
func _draw_capitol() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(12, 16), size), SHADOW)
	draw_rect(Rect2(-half, size), MARBLE)
	# North and south wings proud of the body.
	draw_rect(Rect2(Vector2(-half.x * 0.7, -half.y), Vector2(size.x * 0.7, size.y * 0.26)), MARBLE_LIGHT)
	draw_rect(Rect2(Vector2(-half.x * 0.7, half.y * 0.74), Vector2(size.x * 0.7, size.y * 0.26)), MARBLE_LIGHT)
	draw_rect(Rect2(-half, size), MARBLE_DARK, false, 2.5)
	# The dome: concentric rings, lantern dot, radial seams.
	# The dome: a real drum — shaded rings, radial ribs, colonnade dots.
	var r := minf(size.x, size.y) * 0.44
	draw_circle(Vector2(6, 8), r, SHADOW)
	draw_circle(Vector2.ZERO, r, MARBLE_LIGHT)
	draw_circle(Vector2.ZERO, r * 0.82, MARBLE)
	draw_circle(Vector2.ZERO, r * 0.58, MARBLE_LIGHT)
	draw_circle(Vector2.ZERO, r * 0.34, Color(0.95, 0.94, 0.9))
	for i in 16:
		var a := TAU * i / 16.0
		draw_line(Vector2(r * 0.34, 0).rotated(a), Vector2(r * 0.97, 0).rotated(a),
			MARBLE_DARK, 1.4)
		draw_circle(Vector2(r * 0.9, 0).rotated(a), 2.5, MARBLE_DARK)
	draw_circle(Vector2.ZERO, r * 0.14, MARBLE_DARK)
	draw_circle(Vector2.ZERO, 3.5, BRONZE)  # Freedom, from directly above
	# West plaza + a broad step cascade falling toward the Mall.
	draw_rect(Rect2(Vector2(-half.x - size.x * 1.1, -half.y * 0.75),
		Vector2(size.x * 1.1, size.y * 0.75 * 2.0)), PLAZA)
	draw_rect(Rect2(Vector2(-half.x - size.x * 1.1, -half.y * 0.75),
		Vector2(size.x * 1.1, size.y * 0.75 * 2.0)), PLAZA_EDGE, false, 2.0)
	for i in 5:
		var x := -half.x - 6.0 - i * 8.0
		draw_line(Vector2(x, -half.y * (0.6 - i * 0.05)),
			Vector2(x, half.y * (0.6 - i * 0.05)),
			MARBLE_DARK if i % 2 == 0 else MARBLE_LIGHT, 6.0)

## The residence in plan: executive drive sweeping the south face, wing
## stubs, white block with roof ridges, both porticos, the flag.
func _draw_white_house() -> void:
	var half := size * 0.5
	# Executive drive: a paved semicircular sweep on the lawn side.
	var drive_r := size.x * 0.42
	draw_circle(Vector2(0, half.y + 8), drive_r, Color(PLAZA.r, PLAZA.g, PLAZA.b, 0.7))
	draw_circle(Vector2(0, half.y + 8), drive_r * 0.62, Color(0.28, 0.42, 0.24, 0.9))  # inner lawn
	draw_arc(Vector2(0, half.y + 8), drive_r * 0.8, 0.15, PI - 0.15, 18,
		Color(0.85, 0.86, 0.88, 0.4), 3.0)
	# Wing stubs east and west (the EEOB/Treasury neighbors, abbreviated).
	draw_rect(Rect2(Vector2(-half.x - 26, -half.y * 0.6), Vector2(26, size.y * 0.6)), MARBLE_DARK)
	draw_rect(Rect2(Vector2(half.x, -half.y * 0.6), Vector2(26, size.y * 0.6)), MARBLE_DARK)
	draw_rect(Rect2(-half + Vector2(10, 14), size), SHADOW)
	draw_rect(Rect2(-half, size), MARBLE_LIGHT)
	draw_rect(Rect2(-half, size), MARBLE_DARK, false, 2.5)
	# Roof ridges + skylight row.
	for i in range(1, 4):
		var x := -half.x + size.x * i / 4.0
		draw_line(Vector2(x, -half.y + 6), Vector2(x, half.y - 6), MARBLE, 2.0)
	draw_rect(Rect2(Vector2(-size.x * 0.12, -6), Vector2(size.x * 0.24, 12)), MARBLE)
	# North portico stub + the bold south portico bow.
	draw_rect(Rect2(Vector2(-size.x * 0.09, -half.y - 10), Vector2(size.x * 0.18, 12)), MARBLE)
	draw_circle(Vector2(0, half.y), size.y * 0.34, MARBLE_LIGHT)
	draw_arc(Vector2(0, half.y), size.y * 0.34, PI, TAU, 14, MARBLE_DARK, 2.5)
	for i in 5:  # portico columns
		var a := PI + PI * (i + 0.5) / 5.0
		draw_circle(Vector2(0, half.y) + Vector2(size.y * 0.3, 0).rotated(a), 2.5, MARBLE_DARK)
	draw_circle(Vector2(size.x * 0.3, -half.y * 0.4), 3.5, Color(0.75, 0.15, 0.15))  # the flag

## The pool's raised coping and its neglected water. Node sits over the
## water zone; size = the water rect. Coping reads as the low marble wall
## the asphalt-to-water jump was missing; algae is seeded and rimmed.
func _draw_pool_surround() -> void:
	var half := size * 0.5
	var band := 18.0
	# Coping: a pale marble band proud of the water on all four sides.
	draw_rect(Rect2(-half - Vector2(band, band), size + Vector2(band * 2.0, band * 2.0)),
		MARBLE, false, band)
	draw_rect(Rect2(-half - Vector2(band, band), size + Vector2(band * 2.0, band * 2.0)),
		MARBLE_DARK, false, 2.0)
	draw_rect(Rect2(-half, size), MARBLE_DARK, false, 2.0)
	# Stone seams along the long runs.
	var seams := maxi(int(size.x / 96.0), 4)
	for i in range(1, seams):
		var x := -half.x + size.x * i / seams
		draw_line(Vector2(x, -half.y - band), Vector2(x, -half.y), MARBLE_DARK, 1.5)
		draw_line(Vector2(x, half.y), Vector2(x, half.y + band), MARBLE_DARK, 1.5)
	# The algae: nasty green blobs, several hugging the coping line.
	var rng := _rng()
	for i in 12:
		var edge := rng.randf() < 0.55
		var p := Vector2(rng.randf_range(-half.x * 0.9, half.x * 0.9),
			(half.y - rng.randf_range(6.0, 20.0)) * (1.0 if rng.randf() < 0.5 else -1.0)) \
			if edge else Vector2(rng.randf_range(-half.x * 0.85, half.x * 0.85),
			rng.randf_range(-half.y * 0.6, half.y * 0.6))
		var r := rng.randf_range(8.0, 22.0)
		draw_circle(p, r, ALGAE_DARK)
		draw_circle(p + Vector2(-r * 0.15, -r * 0.15), r * 0.75, ALGAE)
		if rng.randf() < 0.5:
			draw_circle(p + Vector2(r * 0.5, r * 0.3), r * 0.35, ALGAE_DARK)

## Five nested rings and the courtyard — unmistakable from above.
func _draw_pentagon() -> void:
	var r := minf(size.x, size.y) * 0.5
	var shadow_pts := PackedVector2Array()
	for i in 5:
		shadow_pts.append(Vector2(r, 0).rotated(-PI * 0.5 + TAU * i / 5.0) + Vector2(12, 16))
	draw_colored_polygon(shadow_pts, SHADOW)
	for ring in 5:
		var rr := r * (1.0 - ring * 0.16)
		var pts := PackedVector2Array()
		for i in 5:
			pts.append(Vector2(rr, 0).rotated(-PI * 0.5 + TAU * i / 5.0))
		draw_colored_polygon(pts, MARBLE_DARK if ring % 2 == 0 else MARBLE)
	var court := PackedVector2Array()
	for i in 5:
		court.append(Vector2(r * 0.24, 0).rotated(-PI * 0.5 + TAU * i / 5.0))
	draw_colored_polygon(court, Color(0.3, 0.42, 0.26))  # ground-zero cafe lawn

## Oval of proud pillar dots around twin fountain pools — the WWII plaza.
func _draw_ww2_ring() -> void:
	var half := size * 0.5
	_draw_plaza(size * Vector2(1.2, 1.25))
	draw_rect(Rect2(-half, size), Color(MARBLE.r, MARBLE.g, MARBLE.b, 0.7))
	draw_rect(Rect2(-half, size), MARBLE_DARK, false, 2.0)
	for i in 28:
		var a := TAU * i / 28.0
		var p := Vector2(cos(a) * half.x * 0.86, sin(a) * half.y * 0.82)
		draw_circle(p + Vector2(2, 3), 6.0, SHADOW)
		draw_circle(p, 6.0, MARBLE_DARK)
		draw_circle(p, 3.5, MARBLE_LIGHT)
	draw_circle(Vector2(-half.x * 0.32, 0), half.y * 0.4, MARBLE_DARK)
	draw_circle(Vector2(-half.x * 0.32, 0), half.y * 0.34, WATER)
	draw_circle(Vector2(half.x * 0.32, 0), half.y * 0.4, MARBLE_DARK)
	draw_circle(Vector2(half.x * 0.32, 0), half.y * 0.34, WATER)
	draw_circle(Vector2.ZERO, 5.0, MARBLE_LIGHT)  # the central star

## The black granite V, sunk into a cut lawn, names catching the light.
func _draw_vietnam_wall() -> void:
	var half := size * 0.5
	_draw_plaza(size * Vector2(1.15, 1.5))
	var apex := Vector2(0, half.y * 0.6)
	var arm_w := maxf(size.y * 0.16, 12.0)
	# The sunken cut: a darker earth wedge behind each arm.
	for sgn: float in [-1.0, 1.0]:
		var top := Vector2(sgn * half.x, -half.y * 0.6)
		var n := (apex - top).normalized().orthogonal() * (arm_w * 0.9)
		draw_colored_polygon(PackedVector2Array([top - n, apex - n, apex + n, top + n]),
			Color(0.16, 0.2, 0.14))
	draw_line(Vector2(-half.x, -half.y * 0.6), apex, GRANITE, arm_w)
	draw_line(Vector2(half.x, -half.y * 0.6), apex, GRANITE, arm_w)
	draw_line(Vector2(-half.x, -half.y * 0.6), apex, Color(0.2, 0.2, 0.24), arm_w * 0.35)
	var rng := _rng()
	for i in 26:  # the names, abbreviated to glints
		var t := rng.randf()
		var side := rng.randf() < 0.5
		var from := Vector2(-half.x, -half.y * 0.6) if side else Vector2(half.x, -half.y * 0.6)
		var p := from.lerp(apex, t)
		draw_rect(Rect2(p - Vector2(2.5, 1), Vector2(5, 1.8)), Color(0.55, 0.57, 0.62, 0.85))

## Nineteen steel soldiers on patrol through the juniper wedge.
func _draw_korean_patrol() -> void:
	var half := size * 0.5
	_draw_plaza(size * Vector2(1.2, 1.2))
	# The triangular field, textured with juniper clumps.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2(half.x * 0.2, -half.y),
	]), Color(0.3, 0.38, 0.28, 0.9))
	var rng := _rng()
	for i in 20:
		var jp := Vector2(rng.randf_range(-half.x * 0.85, half.x * 0.8),
			rng.randf_range(-half.y * 0.5, half.y * 0.9))
		draw_circle(jp, rng.randf_range(4.0, 9.0), Color(0.22, 0.3, 0.2, 0.7))
	for i in 19:
		var p := Vector2(rng.randf_range(-half.x * 0.75, half.x * 0.65),
			rng.randf_range(-half.y * 0.55, half.y * 0.8))
		draw_circle(p + Vector2(3, 4), 5.5, SHADOW)
		draw_circle(p, 5.5, Color(0.5, 0.53, 0.5))
		draw_circle(p + Vector2(0, -2.5), 3.0, Color(0.63, 0.66, 0.63))
		draw_line(p + Vector2(-4, 2), p + Vector2(5, -3), Color(0.4, 0.42, 0.4), 1.5)  # rifle
	# The mirror-wall edge along the south side.
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, half.y), GRANITE, 6.0)

## Arlington's ranks: offset rows of white tablets, silent and exact.
func _draw_headstone_rows() -> void:
	var half := size * 0.5
	var pitch_x := 26.0
	var pitch_y := 34.0
	var rows := int(size.y / pitch_y)
	var cols := int(size.x / pitch_x)
	for r in rows:
		var y := -half.y + pitch_y * 0.5 + r * pitch_y
		var offset := pitch_x * 0.5 if r % 2 == 1 else 0.0
		for c in cols:
			var x := -half.x + pitch_x * 0.5 + c * pitch_x + offset
			if x > half.x - 4.0:
				continue
			draw_rect(Rect2(x - 1.0, y - 2.0, 5.0, 7.0), SHADOW)
			draw_rect(Rect2(x - 3.0, y - 5.0, 6.0, 9.0), MARBLE_LIGHT)

## The flame on the hillside — a small fire that never goes out.
func _draw_eternal_flame() -> void:
	var s := size.x
	draw_circle(Vector2.ZERO, s * 0.5, MARBLE_DARK)
	draw_circle(Vector2.ZERO, s * 0.36, GRANITE)
	draw_circle(Vector2.ZERO, s * 0.34, Color(FLAME.r, FLAME.g, FLAME.b, 0.25))
	draw_circle(Vector2(0, -2), s * 0.16, FLAME)
	draw_circle(Vector2(1, -4), s * 0.08, Color(1.0, 0.85, 0.4))

## Traffic-circle centerpiece: basin, water ring, the jet.
func _draw_fountain() -> void:
	var r := size.x * 0.5
	draw_circle(Vector2(6, 8), r, SHADOW)
	draw_circle(Vector2.ZERO, r, MARBLE_DARK)
	draw_circle(Vector2.ZERO, r * 0.86, WATER)
	draw_circle(Vector2.ZERO, r * 0.3, MARBLE)
	draw_circle(Vector2(0, -2), r * 0.12, Color(0.75, 0.85, 0.95))
	draw_arc(Vector2.ZERO, r * 0.6, 0.6, 2.2, 10, Color(0.8, 0.9, 1.0, 0.5), 2.0)

## Balustrade dots and lamp bases along both deck edges (rotate the node to
## the bridge's angle — the paint follows).
func _draw_bridge_deck() -> void:
	var half := size * 0.5
	var posts := maxi(int(size.x / 72.0), 4)
	for i in posts + 1:
		var x := -half.x + size.x * i / posts
		for side: float in [-1.0, 1.0]:
			var y := half.y * 0.92 * side
			draw_circle(Vector2(x, y), 4.0, MARBLE_DARK)
			if i % 2 == 0:
				draw_circle(Vector2(x, y), 7.0, Color(1.0, 0.9, 0.6, 0.14))  # lamp pool
				draw_circle(Vector2(x, y - 2.0 * side), 2.0, Color(1.0, 0.92, 0.7))
