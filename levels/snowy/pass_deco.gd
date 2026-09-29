extends Node2D
## Paint-only Mountainside set pieces. `kind` picks the piece and `size`
## describes its exact grid footprint; travel on the bridge runs along local Y.

const ASPHALT := Color(0.13, 0.13, 0.16)
const SLAB := Color(0.34, 0.35, 0.38)
const KERB := Color(0.46, 0.47, 0.49)
const JOINT := Color(0.16, 0.16, 0.18)
const DRAIN := Color(0.12, 0.13, 0.15)
const GIRDER := Color(0.15, 0.16, 0.18)
const RIVET := Color(0.38, 0.39, 0.41)
const SIDE_SHADOW := Color(0.02, 0.025, 0.035, 0.62)
const SNOW_DUST := Color(0.86, 0.89, 0.94, 0.32)

const ROAD_WIDTH := 256.0
const SIDE_OVERHANG := 14.0
const ABUTMENT_OVERLAP := 10.0
const SIDE_SHADOW_OFFSET := Vector2(8.0, 0.0)
const SIDE_SHADOW_WIDTH := 18.0
const GIRDER_WIDTH := 9.0
const GRAVEL_DARK := Color(0.18, 0.16, 0.14, 0.58)
const GRAVEL_LIGHT := Color(0.62, 0.58, 0.52, 0.44)
const TYRE_RUT := Color(0.11, 0.10, 0.09, 0.24)
const WORN_YELLOW := Color(0.82, 0.66, 0.22, 0.58)

@export var kind: StringName = &"bridge_deck"
@export var size := Vector2(384, 256)

func _ready() -> void:
	queue_redraw()

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0)) + 31
	return rng

func _draw() -> void:
	match kind:
		&"bridge_deck":
			_draw_bridge_deck()
		&"runaway_bed":
			_draw_runaway_bed()

func _draw_bridge_deck() -> void:
	var half := size * 0.5
	var slab_size := size + Vector2(SIDE_OVERHANG * 2.0, ABUTMENT_OVERLAP * 2.0)
	var slab_half := slab_size * 0.5
	_draw_side_shadows(slab_half)
	draw_rect(Rect2(-slab_half, slab_size), SLAB)
	_draw_carriageway(slab_half.y)
	_draw_kerbs(half, slab_half.y)
	_draw_expansion_joints(half, slab_half.x)
	_draw_girders(half, slab_half)
	_draw_snow(half)

func _draw_side_shadows(slab_half: Vector2) -> void:
	var band_size := Vector2(SIDE_SHADOW_WIDTH, size.y)
	var west := Vector2(-slab_half.x - SIDE_SHADOW_WIDTH, -size.y * 0.5) \
		+ SIDE_SHADOW_OFFSET
	var east := Vector2(slab_half.x - SIDE_SHADOW_OFFSET.x, -size.y * 0.5) \
		+ SIDE_SHADOW_OFFSET
	draw_rect(Rect2(west, band_size), SIDE_SHADOW)
	draw_rect(Rect2(east, band_size), SIDE_SHADOW)

func _draw_carriageway(slab_half_y: float) -> void:
	draw_rect(Rect2(-ROAD_WIDTH * 0.5, -slab_half_y,
		ROAD_WIDTH, slab_half_y * 2.0), ASPHALT)

func _draw_kerbs(half: Vector2, slab_half_y: float) -> void:
	var kerb_width := (size.x - ROAD_WIDTH) * 0.5
	for side: float in [-1.0, 1.0]:
		var x := -half.x if side < 0.0 else ROAD_WIDTH * 0.5
		draw_rect(Rect2(x, -slab_half_y, kerb_width, slab_half_y * 2.0), KERB)
		for y in range(-int(half.y) + 32, int(half.y), 64):
			var slot_x := x + kerb_width * 0.5 - 10.0
			draw_rect(Rect2(slot_x, float(y) - 2.0, 20.0, 4.0), DRAIN)

func _draw_expansion_joints(half: Vector2, slab_half_x: float) -> void:
	for side: float in [-1.0, 1.0]:
		var y := half.y * side
		draw_line(Vector2(-slab_half_x, y), Vector2(slab_half_x, y), JOINT, 4.0)

func _draw_girders(half: Vector2, slab_half: Vector2) -> void:
	for side: float in [-1.0, 1.0]:
		var x := -slab_half.x if side < 0.0 else slab_half.x - GIRDER_WIDTH
		draw_rect(Rect2(x, -slab_half.y, GIRDER_WIDTH, slab_half.y * 2.0), GIRDER)
		var rivet_x := x + GIRDER_WIDTH * 0.5
		for y in range(-int(half.y), int(half.y) + 1, 32):
			draw_circle(Vector2(rivet_x, float(y)), 2.0, RIVET)

func _draw_snow(half: Vector2) -> void:
	var rng := _rng()
	for i in 9:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var point := Vector2(
			side * rng.randf_range(44.0, half.x - 20.0),
			rng.randf_range(-half.y + 16.0, half.y - 34.0))
		var streak := Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(12.0, 26.0))
		draw_line(point, point + streak, SNOW_DUST, rng.randf_range(2.0, 4.0))

func _draw_runaway_bed() -> void:
	var half := size * 0.5
	var rng := _rng()
	var pebble_count := maxi(int(size.x * size.y / 2400.0), 24)
	for i in pebble_count:
		var point := Vector2(
			rng.randf_range(-half.x + 8.0, half.x - 8.0),
			rng.randf_range(-half.y + 8.0, half.y - 8.0))
		var tangent := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		var length := rng.randf_range(2.0, 6.0)
		var color := GRAVEL_LIGHT if rng.randf() < 0.38 else GRAVEL_DARK
		draw_line(point - tangent * length * 0.5, point + tangent * length * 0.5,
			color, rng.randf_range(1.0, 2.2))
	_draw_tyre_ruts(half, rng)
	var mouth_x := half.x - 30.0
	for y: float in [-size.y * 0.28, 0.0, size.y * 0.28]:
		_draw_worn_chevron(Vector2(mouth_x, y))

func _draw_tyre_ruts(half: Vector2, rng: RandomNumberGenerator) -> void:
	var steps := maxi(int(size.x / 40.0), 2)
	for side: float in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for i in steps + 1:
			var x := lerpf(-half.x + 12.0, half.x - 12.0, float(i) / steps)
			var y := side * size.y * 0.22 + rng.randf_range(-2.5, 2.5)
			points.append(Vector2(x, y))
		draw_polyline(points, TYRE_RUT, 5.0, true)

func _draw_worn_chevron(center: Vector2) -> void:
	var tip := center + Vector2(-12.0, 0.0)
	for side: float in [-1.0, 1.0]:
		var outer := center + Vector2(12.0, side * 15.0)
		var gap_outer := center + Vector2(2.0, side * 5.2)
		var gap_inner := center + Vector2(-1.0, side * 2.7)
		draw_line(outer, gap_outer, WORN_YELLOW, 4.0)
		draw_line(gap_inner, tip, WORN_YELLOW, 4.0)
