extends RefCounted
## Freeway expansion paint contract: every kind stands alone, overhead pieces
## share the fade seam, and seeded grime stays reproducible.

const FreewayDeco := preload("res://levels/freeway/freeway_deco.gd")
const UnderFade := preload("res://environment/under_fade.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

const KINDS := [
	&"overpass_deck", &"overpass_shadow", &"canopy",
	&"embankment", &"lot_marks", &"crop_rows",
]
const SIZES := {
	&"overpass_deck": Vector2(768, 160),
	&"overpass_shadow": Vector2(768, 160),
	&"canopy": Vector2(384, 192),
	&"embankment": Vector2(720, 192),
	&"lot_marks": Vector2(672, 256),
	&"crop_rows": Vector2(640, 320),
}

var t

func _init(runner) -> void:
	t = runner

func _deco(piece_kind: StringName) -> Node2D:
	var deco := FreewayDeco.new()
	deco.kind = piece_kind
	deco.size = SIZES[piece_kind]
	deco.paint_seed = 919
	return deco

func _settle(frames: int) -> void:
	for i in frames:
		await t.physics_frame

func test_every_kind_draws_in_isolation() -> void:
	for piece_kind: StringName in KINDS:
		var deco := _deco(piece_kind)
		t.root.add_child(deco)
		await t.process_frame
		t.check(deco.is_inside_tree(),
			"freeway deco: %s draws for one frame in isolation" % piece_kind)
		t.root.remove_child(deco)
		deco.free()

func test_only_overhead_kinds_build_fade_geometry() -> void:
	for piece_kind: StringName in KINDS:
		var deco := _deco(piece_kind)
		t.root.add_child(deco)
		var overhead := piece_kind == &"overpass_deck" or piece_kind == &"canopy"
		var collisions := deco.find_children("*", "CollisionObject2D", true, false)
		t.check(deco.get_child_count() == (1 if overhead else 0),
			"freeway deco: %s has only its expected fade child" % piece_kind)
		t.check(collisions.size() == (1 if overhead else 0),
			"freeway deco: %s has no gameplay collider" % piece_kind)
		if overhead:
			var area := deco.get_child(0) as Area2D
			var collision := area.get_child(0) as CollisionShape2D
			var shape := collision.shape as RectangleShape2D
			t.check(area != null and area.collision_layer == 0
					and area.collision_mask == 1,
				"freeway deco: %s fade area is query-only on vehicle bit" % piece_kind)
			t.check(shape != null and shape.size == deco.size
					and collision.position == Vector2.ZERO,
				"freeway deco: %s fade rect exactly equals size" % piece_kind)
		t.root.remove_child(deco)
		deco.free()

func test_deck_fades_for_a_lower_car_and_recovers() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var deck := _deco(&"overpass_deck")
	deck.z_index = 1
	container.add_child(deck)
	var car := VehicleScene.instantiate()
	car.z_index = 0
	container.add_child(car)
	await _settle(20)
	var faded_alpha := deck.modulate.a
	car.global_position = Vector2(2000, 0)
	await _settle(20)
	t.check_approx(faded_alpha, UnderFade.ALPHA,
		"freeway deco: deck reaches the shared under-fade alpha")
	t.check_approx(deck.modulate.a, 1.0,
		"freeway deco: deck returns fully opaque once the car leaves")
	t.root.remove_child(container)
	container.free()

func test_only_overhead_kinds_process() -> void:
	var deck := _deco(&"overpass_deck")
	var canopy := _deco(&"canopy")
	var embankment := _deco(&"embankment")
	t.root.add_child(deck)
	t.root.add_child(canopy)
	t.root.add_child(embankment)
	t.check(deck.is_processing() and canopy.is_processing(),
		"freeway deco: deck and canopy process their fade")
	t.check(not embankment.is_processing(),
		"freeway deco: ground paint does not process")
	for deco in [deck, canopy, embankment]:
		t.root.remove_child(deco)
		deco.free()

func test_seeded_detail_points_are_deterministic() -> void:
	for piece_kind: StringName in [&"embankment", &"lot_marks", &"crop_rows"]:
		var a := _deco(piece_kind)
		var b := _deco(piece_kind)
		a.position = Vector2(123, 456)
		b.position = a.position
		var a_points: PackedVector2Array = a.detail_points()
		var b_points: PackedVector2Array = b.detail_points()
		t.check(not a_points.is_empty() and a_points == b_points,
			"freeway deco: %s scatter repeats for the same seed and size" % piece_kind)
		b.paint_seed += 1
		t.check(a_points != b.detail_points(),
			"freeway deco: %s scatter responds to paint_seed" % piece_kind)
		a.free()
		b.free()
	var plain := _deco(&"overpass_deck")
	t.check(plain.detail_points().is_empty(),
		"freeway deco: kinds without scatter expose no detail points")
	plain.free()
