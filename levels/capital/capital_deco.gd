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

## Greek temple in plan: stepped plinth, peristyle column ring, dark cella
## with the seated figure glowing at its heart.
func _draw_lincoln() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(12, 16), size), SHADOW)
	draw_rect(Rect2(-half, size), MARBLE)
	draw_rect(Rect2(-half * 0.88, size * 0.88), MARBLE_LIGHT)
	draw_rect(Rect2(-half * 0.88, size * 0.88), MARBLE_DARK, false, 2.0)
	# Peristyle: column dots marching the inner rectangle's edge.
	var inner := size * 0.72
	var cols_x := maxi(int(inner.x / 30.0), 3)
	var cols_y := maxi(int(inner.y / 30.0), 5)
	for i in cols_x + 1:
		var x := -inner.x * 0.5 + inner.x * i / cols_x
		draw_circle(Vector2(x, -inner.y * 0.5), 5.0, MARBLE_DARK)
		draw_circle(Vector2(x, inner.y * 0.5), 5.0, MARBLE_DARK)
	for i in range(1, cols_y):
		var y := -inner.y * 0.5 + inner.y * i / cols_y
		draw_circle(Vector2(-inner.x * 0.5, y), 5.0, MARBLE_DARK)
		draw_circle(Vector2(inner.x * 0.5, y), 5.0, MARBLE_DARK)
	# Cella: the dark chamber, opening east toward the pool.
	draw_rect(Rect2(-size.x * 0.22, -size.y * 0.3, size.x * 0.38, size.y * 0.6), GRANITE)
	draw_circle(Vector2(-size.x * 0.06, 0), 7.0, MARBLE_LIGHT)  # the seated figure
	# Entrance stair band on the east face.
	for i in 3:
		var x := half.x * 0.88 + i * 5.0
		draw_line(Vector2(x, -half.y * 0.5), Vector2(x, half.y * 0.5),
			MARBLE_DARK if i % 2 == 0 else MARBLE, 4.0)

## The monument in plan is tiny — the READ is its enormous SE shadow and the
## flag ring. Sits atop the knoll summit; the solid core is authored apart.
func _draw_obelisk() -> void:
	var s := size.x
	# Storm-light shadow: a long tapered blade falling southeast.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.2, s * 0.2), Vector2(s * 0.2, -s * 0.2),
		Vector2(s * 5.2, s * 4.6), Vector2(s * 4.6, s * 5.2),
	]), Color(0, 0, 0, 0.22))
	# Flag ring: fifty stars abbreviated to a ring of white dots.
	for i in 10:
		var a := TAU * i / 10.0
		draw_circle(Vector2(s * 1.6, 0).rotated(a), 3.5, MARBLE_LIGHT)
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), MARBLE)          # base
	draw_rect(Rect2(-s * 0.34, -s * 0.34, s * 0.68, s * 0.68), MARBLE_LIGHT)
	draw_rect(Rect2(-s * 0.14, -s * 0.14, s * 0.28, s * 0.28), MARBLE_DARK)  # the point
	draw_circle(Vector2.ZERO, 2.5, Color(0.9, 0.2, 0.2))        # aircraft beacon

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
	var r := minf(size.x, size.y) * 0.34
	draw_circle(Vector2.ZERO, r, MARBLE_LIGHT)
	draw_circle(Vector2.ZERO, r * 0.7, MARBLE)
	draw_circle(Vector2.ZERO, r * 0.4, MARBLE_LIGHT)
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(Vector2(r * 0.4, 0).rotated(a), Vector2(r, 0).rotated(a), MARBLE_DARK, 1.2)
	draw_circle(Vector2.ZERO, r * 0.16, MARBLE_DARK)
	draw_circle(Vector2.ZERO, 3.0, BRONZE)  # Freedom, from directly above
	# West portico steps band.
	for i in 3:
		var x := -half.x - 4.0 - i * 5.0
		draw_line(Vector2(x, -half.y * 0.4), Vector2(x, half.y * 0.4),
			MARBLE_DARK if i % 2 == 0 else MARBLE, 4.0)

## The residence in plan: white block, north portico stub, south bow.
func _draw_white_house() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(10, 14), size), SHADOW)
	draw_rect(Rect2(-half, size), MARBLE_LIGHT)
	draw_rect(Rect2(-half, size), MARBLE_DARK, false, 2.0)
	# Roof ridges + the flag.
	for i in range(1, 4):
		var x := -half.x + size.x * i / 4.0
		draw_line(Vector2(x, -half.y + 6), Vector2(x, half.y - 6), MARBLE, 2.0)
	draw_rect(Rect2(Vector2(-size.x * 0.09, -half.y - 8), Vector2(size.x * 0.18, 10)), MARBLE)  # north portico
	draw_circle(Vector2(0, half.y), size.y * 0.28, MARBLE_LIGHT)  # south bow
	draw_arc(Vector2(0, half.y), size.y * 0.28, PI, TAU, 14, MARBLE_DARK, 2.0)
	draw_circle(Vector2(size.x * 0.28, 0), 3.0, Color(0.75, 0.15, 0.15))  # the flag

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

## Oval of pillar dots around a fountain pair — the WWII plaza.
func _draw_ww2_ring() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(MARBLE.r, MARBLE.g, MARBLE.b, 0.55))
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector2(cos(a) * half.x * 0.86, sin(a) * half.y * 0.86)
		draw_circle(p, 4.0, MARBLE_DARK)
	draw_circle(Vector2(-half.x * 0.3, 0), half.y * 0.34, WATER)
	draw_circle(Vector2(half.x * 0.3, 0), half.y * 0.34, WATER)

## The black granite V, sunk into the lawn, names catching the light.
func _draw_vietnam_wall() -> void:
	var half := size * 0.5
	var apex := Vector2(0, half.y * 0.6)
	draw_line(Vector2(-half.x, -half.y * 0.6), apex, GRANITE, 10.0)
	draw_line(Vector2(half.x, -half.y * 0.6), apex, GRANITE, 10.0)
	var rng := _rng()
	for i in 14:  # the names, abbreviated to glints
		var t := rng.randf()
		var side := rng.randf() < 0.5
		var from := Vector2(-half.x, -half.y * 0.6) if side else Vector2(half.x, -half.y * 0.6)
		var p := from.lerp(apex, t)
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 1.5)), Color(0.55, 0.57, 0.62, 0.8))

## Nineteen steel soldiers on patrol through the juniper.
func _draw_korean_patrol() -> void:
	var half := size * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2(half.x * 0.2, -half.y),
	]), Color(0.32, 0.4, 0.3, 0.6))
	var rng := _rng()
	for i in 19:
		var p := Vector2(rng.randf_range(-half.x * 0.8, half.x * 0.7),
			rng.randf_range(-half.y * 0.6, half.y * 0.8))
		draw_circle(p + Vector2(2, 3), 4.0, SHADOW)
		draw_circle(p, 4.0, Color(0.5, 0.53, 0.5))
		draw_circle(p + Vector2(0, -2), 2.0, Color(0.6, 0.63, 0.6))

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
