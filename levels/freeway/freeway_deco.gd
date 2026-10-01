extends Node2D
## Paint-only Freeway expansion set pieces. Long runs follow local x; gameplay
## surfaces, walls, and columns are authored separately.

const UnderFade := preload("res://environment/under_fade.gd")
const RoadMarks := preload("res://environment/road_marks.gd")

const ASPHALT := Color(0.13, 0.13, 0.15)
const CONCRETE := Color(0.48, 0.47, 0.45)
const CONCRETE_DARK := Color(0.31, 0.3, 0.3)
const CANOPY_ROOF := Color(0.76, 0.77, 0.75)
const CANOPY_LIGHT := Color(0.9, 0.88, 0.82)
const COLUMN_CAP := Color(0.19, 0.18, 0.18)
const GRASS_WALL := Color(0.22, 0.32, 0.17)
const GRASS_FOOT := Color(0.34, 0.46, 0.25)
const GRASS_TUFT := Color(0.16, 0.27, 0.12, 0.72)
const EROSION := Color(0.28, 0.24, 0.16, 0.48)
const SCUFF := Color(0.08, 0.08, 0.09, 0.34)
const HANDICAP := Color(0.25, 0.45, 0.62, 0.32)
const FIELD_DIRT := Color(0.35, 0.25, 0.15)
const HEADLAND := Color(0.42, 0.3, 0.18)
const CROP := Color(0.16, 0.31, 0.12)
const SHADOW := Color(0.0, 0.0, 0.0)

@export var kind: StringName = &"overpass_deck"
@export var size := Vector2(768, 160)
@export var paint_seed: int = 0
@export var accent := Color(0.72, 0.16, 0.14)

var _under_area: Area2D = null

func _ready() -> void:
	queue_redraw()
	if kind == &"overpass_deck" or kind == &"canopy":
		_under_area = UnderFade.build_area(size)
		add_child(_under_area)
	set_process(_under_area != null)

func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a,
		UnderFade.target_alpha(_under_area, z_index), UnderFade.SPEED * delta)

func _rng(salt := 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (paint_seed if paint_seed != 0 else hash(position)) + salt
	return rng

func detail_points() -> PackedVector2Array:
	match kind:
		&"embankment":
			return _embankment_tufts()
		&"lot_marks":
			return _lot_scuffs()
		&"crop_rows":
			return _crop_tufts()
	return PackedVector2Array()

func _draw() -> void:
	match kind:
		&"overpass_deck":
			_draw_overpass_deck()
		&"overpass_shadow":
			_draw_overpass_shadow()
		&"canopy":
			_draw_canopy()
		&"embankment":
			_draw_embankment()
		&"lot_marks":
			_draw_lot_marks()
		&"crop_rows":
			_draw_crop_rows()

func _draw_overpass_deck() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), CONCRETE)
	draw_rect(Rect2(Vector2(-half.x, -half.y + 16.0),
		Vector2(size.x, size.y - 32.0)), ASPHALT)
	var joint_x := -half.x + 256.0
	while joint_x < half.x:
		draw_line(Vector2(joint_x, -half.y), Vector2(joint_x, half.y),
			CONCRETE_DARK, 2.0)
		joint_x += 256.0
	var dash_x := -half.x
	while dash_x < half.x:
		var dash_end := minf(dash_x + RoadMarks.DASH_LEN, half.x)
		draw_line(Vector2(dash_x, 0.0), Vector2(dash_end, 0.0),
			RoadMarks.YELLOW, RoadMarks.LINE_W)
		dash_x += RoadMarks.DASH_LEN + RoadMarks.DASH_GAP
	for side: float in [-1.0, 1.0]:
		var y := side * (half.y - 3.0)
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), CONCRETE_DARK, 3.0)

func _draw_overpass_shadow() -> void:
	var center := Vector2(14.0, 18.0)
	for i in range(2, -1, -1):
		var spread := float(i) * 10.0
		var alpha := 0.12 + float(2 - i) * 0.07
		draw_rect(Rect2(center - size * 0.5 - Vector2.ONE * spread,
			size + Vector2.ONE * spread * 2.0), Color(SHADOW, alpha))

func _draw_canopy() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), CANOPY_ROOF)
	var seam := -maxf(size.x, size.y) * 0.5 + 128.0
	while seam < maxf(size.x, size.y) * 0.5:
		var from := _axis_point(seam, -minf(size.x, size.y) * 0.5)
		var to := _axis_point(seam, minf(size.x, size.y) * 0.5)
		draw_line(from, to, CONCRETE_DARK, 2.0)
		seam += 128.0
	var unit_size := Vector2.ONE * 40.0
	var unit_corner := half - Vector2.ONE * 18.0 - unit_size
	draw_rect(Rect2(unit_corner, unit_size), CONCRETE_DARK)
	draw_rect(Rect2(unit_corner + Vector2.ONE * 6.0,
		unit_size - Vector2.ONE * 12.0), CONCRETE)
	var rng := _rng(91)
	for i in rng.randi_range(3, 5):
		var along := rng.randf_range(-maxf(size.x, size.y) * 0.42,
			maxf(size.x, size.y) * 0.42)
		var cross := rng.randf_range(-minf(size.x, size.y) * 0.38,
			minf(size.x, size.y) * 0.38)
		var streak := rng.randf_range(18.0, 52.0)
		draw_line(_axis_point(along - streak * 0.5, cross),
			_axis_point(along + streak * 0.5, cross + rng.randf_range(-4.0, 4.0)),
			SCUFF, rng.randf_range(2.0, 5.0))
	draw_rect(Rect2(-half, size), accent, false, 12.0)
	var logo_size := minf(size.x, size.y) * 0.22
	draw_rect(Rect2(-half + Vector2(18.0, 18.0), Vector2.ONE * logo_size),
		CANOPY_LIGHT)
	var cap := Vector2.ONE * 18.0
	for x: float in [-half.x + 18.0, half.x - 18.0]:
		for y: float in [-half.y + 18.0, half.y - 18.0]:
			draw_rect(Rect2(Vector2(x, y) - cap * 0.5, cap), COLUMN_CAP)

func _draw_embankment() -> void:
	var half := size * 0.5
	var band_depth := size.y * 0.25
	for i in 4:
		var color := GRASS_WALL.lerp(GRASS_FOOT, (float(i) + 0.5) / 4.0)
		draw_rect(Rect2(Vector2(-half.x, -half.y + band_depth * i),
			Vector2(size.x, band_depth + 1.0)), color)
	for point in detail_points():
		draw_line(point, point + Vector2(-3.0, -7.0), GRASS_TUFT, 2.0)
		draw_line(point, point + Vector2(4.0, -6.0), GRASS_TUFT, 2.0)
	var rng := _rng(73)
	var streaks := 2 + rng.randi_range(0, 1)
	for i in streaks:
		var x := rng.randf_range(-half.x * 0.78, half.x * 0.78)
		var points := PackedVector2Array([Vector2(x, -half.y + 5.0)])
		for step in range(1, 5):
			points.append(Vector2(x + rng.randf_range(-10.0, 10.0),
				-half.y + size.y * float(step) / 4.0))
		draw_polyline(points, EROSION, 3.0, true)

func _embankment_tufts() -> PackedVector2Array:
	var half := size * 0.5
	var rng := _rng(11)
	var points := PackedVector2Array()
	var count := clampi(int(size.x * size.y / 3200.0), 12, 72)
	for i in count:
		points.append(Vector2(rng.randf_range(-half.x + 8.0, half.x - 8.0),
			rng.randf_range(-half.y + 12.0, half.y - 5.0)))
	return points

func _axis_point(run: float, cross: float) -> Vector2:
	return Vector2(run, cross) if size.x >= size.y else Vector2(cross, run)

func _draw_lot_marks() -> void:
	var run := maxf(size.x, size.y)
	var cross := minf(size.x, size.y)
	var run_half := run * 0.5
	var cross_half := cross * 0.5
	var mark := -run_half + 96.0
	while mark < run_half:
		draw_line(_axis_point(mark, -cross_half), _axis_point(mark, cross_half),
			RoadMarks.WHITE, 5.0)
		mark += 96.0
	draw_line(_axis_point(-run_half + 8.0, -cross_half),
		_axis_point(-run_half + 8.0, cross_half), accent, 12.0)
	for point in detail_points():
		draw_line(point, point + _axis_point(18.0, 3.0), SCUFF, 4.0)
	var bay_count := maxi(int(run / 96.0), 1)
	var handicap_bay := _rng(31).randi_range(0, bay_count - 1)
	var center_run := -run_half + (float(handicap_bay) + 0.5) * run / bay_count
	var center := _axis_point(center_run, 0.0)
	draw_rect(Rect2(center - Vector2.ONE * 24.0, Vector2.ONE * 48.0), HANDICAP)
	draw_rect(Rect2(center - Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		RoadMarks.WHITE, false, 3.0)

func _lot_scuffs() -> PackedVector2Array:
	var run := maxf(size.x, size.y)
	var cross := minf(size.x, size.y)
	var rng := _rng(19)
	var points := PackedVector2Array()
	var count := clampi(int(run / 240.0), 2, 7)
	for i in count:
		points.append(_axis_point(rng.randf_range(-run * 0.42, run * 0.42),
			rng.randf_range(-cross * 0.36, cross * 0.36)))
	return points

func _draw_crop_rows() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), FIELD_DIRT)
	var run := maxf(size.x, size.y)
	var cross := minf(size.x, size.y)
	var strip := minf(48.0, run * 0.18)
	for side: float in [-1.0, 1.0]:
		var center_run := side * (run * 0.5 - strip * 0.5)
		var strip_size := Vector2(strip, cross) if size.x >= size.y \
			else Vector2(cross, strip)
		draw_rect(Rect2(_axis_point(center_run, 0.0) - strip_size * 0.5,
			strip_size), HEADLAND)
	for point in detail_points():
		draw_line(point + _axis_point(-4.0, 2.5), point, CROP, 2.0)
		draw_line(point, point + _axis_point(4.0, -2.5), CROP, 2.0)

func _crop_tufts() -> PackedVector2Array:
	var run := maxf(size.x, size.y)
	var cross := minf(size.x, size.y)
	var rng := _rng(47)
	var points := PackedVector2Array()
	var row := -cross * 0.5 + 16.0
	while row <= cross * 0.5 - 16.0:
		var along := -run * 0.5 + 52.0
		while along <= run * 0.5 - 52.0:
			if rng.randf() > 0.2:
				points.append(_axis_point(along + rng.randf_range(-2.5, 2.5),
					row + rng.randf_range(-2.0, 2.0)))
			along += 18.0
		row += 32.0
	return points
