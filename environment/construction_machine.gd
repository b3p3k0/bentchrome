class_name ConstructionMachine
extends StaticBody2D
## Permanent floor-stamped site cover. The silhouette is procedural and the
## collision owner never scales; parked machinery is topology, not loot.
## Paint follows the fleet vocabulary: OUTLINE seams, GLASS canopies, lugged
## TIRE running gear, chrome hardware, and seeded rust/mud weathering.

const Floors := preload("res://game/floors.gd")

const OUTLINE := Color(0.08, 0.08, 0.1)
const GLASS := Color(0.3, 0.42, 0.52)
const TIRE := Color(0.09, 0.09, 0.11)
const LUG := Color(0.18, 0.18, 0.21)
const CHROME := Color(0.78, 0.8, 0.84)
const CAB_FRAME := Color(0.24, 0.30, 0.32)
const RUST := Color(0.42, 0.24, 0.10, 0.5)
const MUD_SPAT := Color(0.28, 0.19, 0.11, 0.5)

@export_enum("bulldozer", "dump_truck", "cement_truck") var kind := "bulldozer"
@export var size := Vector2(256, 128)
@export var floor_index := 1
@export var beacon_enabled := true

var _phase := 0.0

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	_phase = fposmod(absf(position.x * 0.01 + position.y * 0.017), TAU)
	queue_redraw()

func _process(delta: float) -> void:
	if not beacon_enabled:
		return
	_phase = fposmod(_phase + delta * 2.2, TAU)
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(11, 14), size), Color(0, 0, 0, 0.32))
	match kind:
		"dump_truck":
			_draw_dump(half)
		"cement_truck":
			_draw_cement(half)
		_:
			_draw_dozer(half)
	_grime(half)
	if beacon_enabled:
		var at := Vector2(half.x * 0.32, -half.y * 0.28)
		var glow := 0.35 + 0.35 * (0.5 + 0.5 * sin(_phase))
		draw_circle(at, 5.5, CHROME)
		draw_circle(at, 5.5, OUTLINE, false, 1.2)
		draw_circle(at, 9.0, Color(1.0, 0.55, 0.05, glow * 0.24))
		draw_circle(at, 3.5, Color(1.0, 0.7, 0.12, glow))

## Lugged road wheels, half proud of the hull line, with rim outlines.
func _wheels(half: Vector2, count: int) -> void:
	for i in count:
		var x := lerpf(-half.x * 0.62, half.x * 0.62, float(i) / maxf(float(count - 1), 1.0))
		for side: float in [-1.0, 1.0]:
			var at := Vector2(x, side * half.y)
			draw_rect(Rect2(at - Vector2(13, 9), Vector2(26, 18)), TIRE)
			for lug in 3:
				draw_rect(Rect2(at + Vector2(-10.0 + float(lug) * 8.0, -7.0), Vector2(4, 14)), LUG)
			draw_rect(Rect2(at - Vector2(13, 9), Vector2(26, 18)), OUTLINE, false, 1.2)

## Chassis rail peeking between the axles.
func _chassis(half: Vector2) -> void:
	draw_rect(Rect2(Vector2(-half.x * 0.55, -4.0), Vector2(size.x * 0.72, 8.0)), Color(0.16, 0.16, 0.18))

## Two-tone cab with a GLASS band facing the work end and mirror stubs.
func _cab(rect: Rect2, paint: Color, glass_on_end: bool) -> void:
	draw_rect(rect, paint)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.4, rect.size.y)), paint.darkened(0.14))
	if glass_on_end:
		draw_rect(Rect2(Vector2(rect.end.x - 12.0, rect.position.y + 5.0),
			Vector2(8.0, rect.size.y - 10.0)), GLASS)
	draw_rect(rect, OUTLINE, false, 2.0)
	for side: float in [-1.0, 1.0]:
		var my := rect.position.y - 4.0 if side < 0.0 else rect.end.y + 4.0
		draw_circle(Vector2(rect.position.x + 8.0, my), 3.0, CAB_FRAME)

func _draw_dozer(half: Vector2) -> void:
	# Tracks: dark pads, tread bars, rim outline — the hubcap lug idiom.
	for side: float in [-1.0, 1.0]:
		var track := Rect2(Vector2(-half.x * 0.65, side * half.y * 0.58 - 14.0),
			Vector2(size.x * 0.68, 28.0))
		draw_rect(track, TIRE)
		var x := track.position.x + 6.0
		while x < track.end.x - 4.0:
			draw_rect(Rect2(Vector2(x, track.position.y + 2.0), Vector2(4, 24)), LUG)
			x += 12.0
		draw_rect(track, OUTLINE, false, 1.5)
	# Hull: two-tone engine deck with radiator grille toward the blade.
	var body := Rect2(-half * Vector2(0.72, 0.72), size * Vector2(0.72, 0.72))
	draw_rect(body, Color(0.86, 0.58, 0.08))
	draw_rect(Rect2(body.position, Vector2(body.size.x * 0.45, body.size.y)),
		Color(0.86, 0.58, 0.08).darkened(0.12))
	for gy in 4:
		var y := body.position.y + body.size.y * (0.2 + 0.15 * float(gy))
		draw_line(Vector2(body.position.x + 6.0, y),
			Vector2(body.position.x + body.size.x * 0.32, y), Color(0.55, 0.36, 0.05), 2.0)
	draw_rect(body, OUTLINE, false, 2.0)
	# Canopy: frame, glass, center pillar.
	var cab := Rect2(Vector2(half.x * 0.18, -half.y * 0.42), Vector2(half.x * 0.45, half.y * 0.84))
	draw_rect(cab, CAB_FRAME)
	draw_rect(cab.grow(-5.0), GLASS)
	draw_line(Vector2(cab.position.x + cab.size.x * 0.5, cab.position.y + 4.0),
		Vector2(cab.position.x + cab.size.x * 0.5, cab.end.y - 4.0), CAB_FRAME, 3.0)
	draw_rect(cab, OUTLINE, false, 2.0)
	# Chrome exhaust stack ahead of the cab.
	draw_circle(Vector2(half.x * 0.06, -half.y * 0.30), 6.0, CHROME)
	draw_circle(Vector2(half.x * 0.06, -half.y * 0.30), 3.0, Color(0.12, 0.12, 0.13))
	# Blade: worn steel face, bright cutting edge, moldboard ribs.
	var blade := Rect2(Vector2(-half.x, -half.y * 0.64), Vector2(18.0, half.y * 1.28))
	draw_rect(blade, Color(0.62, 0.65, 0.63))
	draw_rect(Rect2(blade.position, Vector2(5.0, blade.size.y)), Color(0.85, 0.87, 0.85))
	for ry in 3:
		var y := blade.position.y + blade.size.y * 0.25 * float(ry + 1)
		draw_line(Vector2(blade.position.x + 5.0, y), Vector2(blade.end.x - 2.0, y),
			Color(0.45, 0.47, 0.46), 2.0)
	draw_rect(blade, OUTLINE, false, 1.5)
	# Hydraulic push arms with chrome pistons.
	for side: float in [-1.0, 1.0]:
		var root := Vector2(-half.x * 0.55, side * half.y * 0.28)
		var tip := Vector2(-half.x + 18.0, side * half.y * 0.5)
		draw_line(root, tip, Color(0.35, 0.26, 0.06), 6.0)
		draw_line(root.lerp(tip, 0.15), root.lerp(tip, 0.55), CHROME, 3.0)

func _draw_dump(half: Vector2) -> void:
	_chassis(half)
	_wheels(half, 3)
	var cab := Rect2(Vector2(-half.x * 0.78, -half.y * 0.55), Vector2(size.x * 0.42, size.y * 0.55))
	_cab(cab, Color(0.9, 0.55, 0.08), true)
	draw_circle(Vector2(cab.end.x + 6.0, -half.y * 0.3), 5.0, CHROME)
	draw_circle(Vector2(cab.end.x + 6.0, -half.y * 0.3), 2.5, Color(0.12, 0.12, 0.13))
	# Bed: ribbed box, darker floor, seeded payload mound, hinged tailgate.
	var bed := PackedVector2Array([
		Vector2(-half.x * 0.2, -half.y * 0.68), Vector2(half.x * 0.82, -half.y * 0.58),
		Vector2(half.x * 0.82, half.y * 0.58), Vector2(-half.x * 0.2, half.y * 0.68),
	])
	draw_colored_polygon(bed, Color(0.72, 0.42, 0.06))
	var center := (bed[0] + bed[1] + bed[2] + bed[3]) * 0.25
	var floor_poly := PackedVector2Array()
	for p in bed:
		floor_poly.append(p.lerp(center, 0.18))
	draw_colored_polygon(floor_poly, Color(0.5, 0.30, 0.05))
	var rng := _grime_rng()
	for i in 7:
		var at := center + Vector2(rng.randf_range(-half.x * 0.35, half.x * 0.35),
			rng.randf_range(-half.y * 0.3, half.y * 0.3))
		draw_circle(at, rng.randf_range(6.0, 14.0), Color(0.40, 0.29, 0.17))
	for r in 5:
		var t := float(r + 1) / 6.0
		draw_line(bed[0].lerp(bed[1], t), bed[3].lerp(bed[2], t), Color(0.4, 0.24, 0.05), 2.0)
	draw_line(bed[1], bed[2], Color(0.32, 0.19, 0.04), 5.0)
	for hs: float in [-0.8, 0.8]:
		draw_circle(bed[1].lerp(bed[2], 0.5 + hs * 0.5), 3.0, Color(0.2, 0.12, 0.03))
	draw_polyline(PackedVector2Array([bed[0], bed[1], bed[2], bed[3], bed[0]]),
		Color(0.4, 0.24, 0.05), 3.0)
	# Mud flaps behind the rear axle.
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(half.x * 0.68, side * half.y - 8.0), Vector2(6.0, 16.0)), TIRE)

func _draw_cement(half: Vector2) -> void:
	_chassis(half)
	_wheels(half, 3)
	var cab := Rect2(Vector2(-half.x * 0.82, -half.y * 0.48), Vector2(size.x * 0.38, size.y * 0.48))
	_cab(cab, Color(0.82, 0.48, 0.08), true)
	# Water tank between cab and drum.
	draw_rect(Rect2(Vector2(-half.x * 0.28, -half.y * 0.3), Vector2(half.x * 0.22, half.y * 0.6)), CHROME.darkened(0.2))
	draw_rect(Rect2(Vector2(-half.x * 0.28, -half.y * 0.3), Vector2(half.x * 0.22, half.y * 0.6)), OUTLINE, false, 1.5)
	# Drum: two-tone barrel with spiral wraps, hub hatch, ring seam.
	var hub := Vector2(half.x * 0.18, 0.0)
	var r := half.y * 0.62
	draw_circle(hub, r, Color(0.72, 0.74, 0.72))
	draw_circle(hub + Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color(0.80, 0.82, 0.80))
	for i in 3:
		var a0 := 0.5 + float(i) * 2.1
		draw_arc(hub, r * 0.78, a0, a0 + 1.5, 14, Color(0.92, 0.5, 0.08), 4.0)
	draw_circle(hub, r * 0.2, Color(0.5, 0.52, 0.5))
	draw_circle(hub, r * 0.2, OUTLINE, false, 1.5)
	draw_circle(hub, r, Color(0.32, 0.34, 0.34), false, 3.0)
	# Ladder along the drum's north face.
	var l0 := hub + Vector2(-r * 0.2, -r - 8.0)
	var l1 := hub + Vector2(r * 0.55, -r * 0.55)
	draw_line(l0, l1, Color(0.4, 0.42, 0.42), 2.0)
	for i in 4:
		var p := l0.lerp(l1, 0.2 + 0.2 * float(i))
		draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), Color(0.4, 0.42, 0.42), 2.0)
	# Discharge chute reaching off the tail.
	draw_colored_polygon(PackedVector2Array([
		hub + Vector2(r * 0.9, -8.0), Vector2(half.x - 2.0, -6.0),
		Vector2(half.x - 2.0, 6.0), hub + Vector2(r * 0.9, 8.0),
	]), Color(0.55, 0.57, 0.55))
	# Seeded concrete spatter on and around the drum.
	var rng := _grime_rng()
	for i in 6:
		var a := rng.randf_range(0.0, TAU)
		draw_circle(hub + Vector2.RIGHT.rotated(a) * rng.randf_range(r * 0.4, r * 1.15),
			rng.randf_range(2.0, 5.0), Color(0.66, 0.67, 0.65, 0.6))

func _grime_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	return rng

## Seeded weathering: rust streaks off the panels, mud spatter at the
## running gear — parked machines wear the site they built.
func _grime(half: Vector2) -> void:
	var rng := _grime_rng()
	for i in 4:
		var p := Vector2(rng.randf_range(-half.x * 0.6, half.x * 0.6),
			rng.randf_range(-half.y * 0.5, half.y * 0.5))
		draw_line(p, p + Vector2(rng.randf_range(6.0, 14.0), rng.randf_range(4.0, 10.0)), RUST, 2.5)
	for i in 10:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := Vector2(rng.randf_range(-half.x * 0.8, half.x * 0.8),
			side * half.y * rng.randf_range(0.55, 0.95))
		draw_circle(p, rng.randf_range(2.0, 4.5), MUD_SPAT)
