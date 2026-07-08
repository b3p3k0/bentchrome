extends RefCounted
## Car paint styles: every roster car + Lackey has one, collision radii follow
## the roster's smallest->largest ordering (Kevin's canon), unknown ids fall
## back to the classic box, and the vehicle syncs radius/muzzle from the style.
## Driven by tests/run_tests.gd.

const PaintScript := preload("res://vehicles/car_paint.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

# Canon size order, smallest first. Lackey sits above via depot body_scale 1.5.
const ORDER := [&"mrghastly", &"cricket", &"ghost", &"splatcat", &"bumper",
	&"smoky", &"razorback", &"kandykane", &"hammertoe"]

var t

func _init(runner) -> void:
	t = runner

func test_every_car_has_a_style() -> void:
	for id in ORDER + [&"lackey"]:
		t.check(PaintScript.STYLES.has(id), "style exists: %s" % id)

func test_radii_follow_the_size_canon() -> void:
	var prev := 0.0
	for id in ORDER:
		var r: float = PaintScript.STYLES[id].radius
		t.check(r > prev, "radius ordering: %s (%s) > previous (%s)" % [id, r, prev])
		prev = r
	var lackey_effective: float = PaintScript.STYLES[&"lackey"].radius * 1.5
	t.check(lackey_effective > prev, "lackey (x1.5 depot scale) is the biggest thing rolling")

func test_metrics_sane_and_fallback() -> void:
	for id in PaintScript.STYLES:
		var m: Dictionary = PaintScript.STYLES[id]
		t.check(float(m.half_len) > 0.0 and float(m.half_wid) > 0.0 and float(m.radius) > 0.0,
			"positive metrics: %s" % id)
		t.check((m.skid_points as Array).size() >= 1, "has skid contact: %s" % id)
	t.check((PaintScript.STYLES[&"mrghastly"].skid_points as Array).size() == 1,
		"the bike lays a single line")
	var paint = PaintScript.new()
	paint.apply(&"not_a_car", Color.RED, Color.WHITE)
	t.check(paint.style_id == &"box", "unknown id falls back to the box")
	paint.free()

func test_vehicle_syncs_style_metrics() -> void:
	var v = VehicleScene.instantiate()
	t.root.add_child(v)
	for id in ORDER:
		v.set_stats(load("res://data/vehicles/%s.tres" % id))
		var m: Dictionary = PaintScript.STYLES[id]
		var col: CollisionShape2D = v.get_node("CollisionShape2D")
		t.check(is_equal_approx(col.shape.radius, float(m.radius)),
			"collision radius follows style: %s" % id)
		var muzzle: Marker2D = v.get_node("Visual/Muzzle")
		t.check(is_equal_approx(muzzle.position.x, float(m.half_len) + 4.0),
			"muzzle rides the nose: %s" % id)
	t.root.remove_child(v)
	v.free()
