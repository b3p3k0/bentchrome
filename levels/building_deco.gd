extends StaticBody2D
## Paint-only ROOFTOP decoration for rectangular building bodies — this is a
## top-down game, so buildings read as roofs, not facades: drop shadow (fake
## height), gravel-speckled roof fill, HVAC units with fans, vent caps, and a
## double parapet lip. All deterministic per building. Size comes from the Col
## shape; the plain Vis polygon is hidden at runtime (kept as editor preview).
## No collision or gameplay here — pure paint.

const SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const FACE := Color(0.2, 0.2, 0.25)        # south wall face (fake height)
const FACE_SEAM := Color(0.13, 0.13, 0.17)
const ROOF := Color(0.28, 0.28, 0.34)
const GRAVEL_DARK := Color(0.24, 0.24, 0.29)
const GRAVEL_LIGHT := Color(0.33, 0.33, 0.39)
const HVAC := Color(0.4, 0.4, 0.46)
const HVAC_SHADOW := Color(0.0, 0.0, 0.0, 0.25)
const HVAC_EDGE := Color(0.5, 0.5, 0.56)
const FAN_WELL := Color(0.2, 0.2, 0.25)
const FAN_BLADE := Color(0.45, 0.45, 0.52)
const VENT := Color(0.22, 0.22, 0.27)
const PARAPET := Color(0.42, 0.42, 0.5)
const PARAPET_LIP := Color(0.18, 0.18, 0.22, 0.7)
const MIN_FURNITURE_DIM := 192.0  # smaller slabs (statue, court walls) stay bare

@export var furniture := true  # false = bare gravel + parapet (driveable roofs)
@export var wall_face := 0.0   # px of south facade painted below the footprint
							   # (fake storeys — tall buildings loom over the lane)
@export var shadow_offset := Vector2(10, 14)  # taller buildings cast longer

var _size := Vector2.ZERO
var _rng_seed := 0

func _ready() -> void:
	var col := get_node_or_null(^"Col") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return
	_size = col.shape.size
	_rng_seed = int(absf(position.x * 7.0 + position.y * 13.0))
	var vis := get_node_or_null(^"Vis") as CanvasItem
	if vis:
		vis.visible = false
	queue_redraw()

func _draw() -> void:
	if _size == Vector2.ZERO:
		return
	var half := _size * 0.5
	draw_rect(Rect2(-half + shadow_offset, _size), SHADOW)
	draw_rect(Rect2(-half, _size), ROOF)

	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	# Roof gravel: sparse two-tone grit.
	var dots := int(_size.x * _size.y / 3500.0)
	for i in dots:
		var p := Vector2(rng.randf_range(-half.x + 8.0, half.x - 11.0),
			rng.randf_range(-half.y + 8.0, half.y - 11.0))
		draw_rect(Rect2(p, Vector2(3, 3)), GRAVEL_DARK if rng.randf() < 0.6 else GRAVEL_LIGHT)

	if furniture and _size.x >= MIN_FURNITURE_DIM and _size.y >= MIN_FURNITURE_DIM:
		# HVAC units: boxed, edge-lit, big ones get a fan well.
		for i in 2 + _rng_seed % 3:
			var w := rng.randf_range(38.0, 66.0)
			var h := rng.randf_range(32.0, 54.0)
			var c := Vector2(rng.randf_range(-half.x + 32.0 + w * 0.5, half.x - 32.0 - w * 0.5),
				rng.randf_range(-half.y + 32.0 + h * 0.5, half.y - 32.0 - h * 0.5))
			var rect := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
			draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), HVAC_SHADOW)
			draw_rect(rect, HVAC)
			draw_rect(rect, HVAC_EDGE, false, 1.5)
			if w >= 48.0 and h >= 40.0:
				draw_circle(c, minf(w, h) * 0.3, FAN_WELL)
				var blades := minf(w, h) * 0.24
				draw_line(c - Vector2(blades, 0), c + Vector2(blades, 0), FAN_BLADE, 2.0)
				draw_line(c - Vector2(0, blades), c + Vector2(0, blades), FAN_BLADE, 2.0)
		# Vent caps: little dark stacks.
		for i in 3 + _rng_seed % 4:
			var p := Vector2(rng.randf_range(-half.x + 24.0, half.x - 24.0),
				rng.randf_range(-half.y + 24.0, half.y - 24.0))
			draw_circle(p, 5.0, VENT)
			draw_circle(p, 2.5, GRAVEL_LIGHT)

	# Parapet: bright outer edge + dark inner lip = raised roof rim.
	draw_rect(Rect2(-half, _size), PARAPET, false, 3.0)
	draw_rect(Rect2(-half + Vector2(6, 6), _size - Vector2(12, 12)), PARAPET_LIP, false, 2.0)

	# South wall face: paneled facade painted past the footprint onto the lane
	# below — the classic top-down "this thing has storeys" cheat. Cars draw
	# over it, so they read as driving up to the wall's base.
	if wall_face > 0.0:
		var face_rect := Rect2(Vector2(-half.x, half.y), Vector2(_size.x, wall_face))
		draw_rect(face_rect, FACE)
		var panels := maxi(int(_size.x / 96.0), 2)
		for i in range(1, panels):
			var x := -half.x + _size.x * i / panels
			draw_line(Vector2(x, half.y + 2.0), Vector2(x, half.y + wall_face - 2.0), FACE_SEAM, 1.5)
		draw_line(Vector2(-half.x, half.y + wall_face), Vector2(half.x, half.y + wall_face),
			FACE_SEAM, 2.5)
