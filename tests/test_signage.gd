extends RefCounted
## Paint-only signage: fitted fallback-font words, deterministic wear choices,
## and the destructible-parent lifecycle. Driven by tests/run_tests.gd.

const SignageScript := preload("res://environment/signage.gd")
const UnderFade := preload("res://environment/under_fade.gd")
const BlockScene := preload("res://environment/destructible_block.tscn")

var t

func _init(runner) -> void:
	t = runner

func _settle(frames: int) -> void:
	for i in frames:
		await t.physics_frame

func test_each_kind_fits_long_and_short_text() -> void:
	for kind in [&"billboard", &"pylon", &"band"]:
		var long_sign = SignageScript.new()
		long_sign.kind = kind
		long_sign.text = "HATE'S TRAVEL STOP"
		var short_sign = SignageScript.new()
		short_sign.kind = kind
		short_sign.text = "EXIT"
		var long_size: int = long_sign.text_font_size()
		var short_size: int = short_sign.text_font_size()
		t.check(long_sign.text_fits() and short_sign.text_fits(),
			"signage %s: long and short copy fit" % kind)
		t.check(long_size >= 18 and long_size <= int(long_sign.size.y - 24.0)
			and short_size >= 18 and short_size <= int(short_sign.size.y - 24.0),
			"signage %s: font sizes stay inside the readable clamp" % kind)
		t.check(long_size < short_size,
			"signage %s: long copy scales below short copy" % kind)
		long_sign.free()
		short_sign.free()

func test_unfittable_text_reports_false_at_minimum() -> void:
	var sign = SignageScript.new()
	sign.text = "W".repeat(200)
	t.check(sign.text_font_size() == 18, "signage: impossible copy stops at the minimum")
	t.check(not sign.text_fits(), "signage: impossible copy reports false without raising")
	sign.free()

func test_seed_repeats_font_size_and_dead_letters() -> void:
	var a = SignageScript.new()
	a.text = "BENT CHROME FOREVER"
	a.sub_text = "OPEN ALL NIGHT"
	a.dead_letters = 5
	a.paint_seed = 4242
	var b = SignageScript.new()
	b.text = a.text
	b.sub_text = a.sub_text
	b.dead_letters = a.dead_letters
	b.paint_seed = a.paint_seed
	t.check(a.text_font_size() == b.text_font_size(),
		"signage: same seed and copy repeat the font size")
	t.check(a.dead_letter_indices() == b.dead_letter_indices()
		and a.dead_letter_indices().size() == 5,
		"signage: same seed repeats the dead-letter set")
	a.free()
	b.free()

func test_destructible_parent_hides_and_restores_sign() -> void:
	var block = BlockScene.instantiate()
	var sign = SignageScript.new()
	block.add_child(sign)
	t.root.add_child(block)
	block.get_node("Health").take_damage(999.0)
	t.check(not sign.visible, "signage: flattened parent hides its painted name")
	block.apply_arena_state({"flags": 1, "hp": 1.0}, false)
	t.check(sign.visible, "signage: arena resurrection restores its painted name")
	t.root.remove_child(block)
	block.free()

func test_only_overhead_kinds_build_panel_fade_geometry() -> void:
	for kind in [&"billboard", &"pylon", &"band"]:
		var sign = SignageScript.new()
		sign.kind = kind
		sign.size = Vector2(300, 110)
		t.root.add_child(sign)
		var overhead: bool = kind == &"billboard" or kind == &"pylon"
		var area := sign.get_node_or_null(^"Underpass") as Area2D
		t.check((area != null) == overhead,
			"signage: %s owns only its expected fade area" % kind)
		t.check(sign.is_processing() == overhead,
			"signage: %s processes only when it can fade" % kind)
		if area != null:
			var collision := area.get_child(0) as CollisionShape2D
			var shape := collision.shape as RectangleShape2D
			t.check(area.collision_layer == 0 and area.collision_mask == 1,
				"signage: %s fade area is query-only on the vehicle bit" % kind)
			t.check(shape != null and shape.size == sign.size
					and collision.position == Vector2.ZERO,
				"signage: %s fade rect covers the panel, not its supports" % kind)
		t.root.remove_child(sign)
		sign.free()

func test_overhead_signs_fade_for_a_lower_body_and_recover() -> void:
	for kind in [&"billboard", &"pylon"]:
		var container := Node2D.new()
		t.root.add_child(container)
		var sign = SignageScript.new()
		sign.kind = kind
		sign.size = Vector2(300, 110)
		sign.z_index = 1
		container.add_child(sign)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.z_index = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(20, 20)
		collision.shape = shape
		body.add_child(collision)
		container.add_child(body)
		await _settle(20)
		t.check_approx(sign.modulate.a, UnderFade.ALPHA,
			"signage: %s fades over a lower body" % kind)
		body.global_position = Vector2(1000, 0)
		await _settle(20)
		t.check_approx(sign.modulate.a, 1.0,
			"signage: %s returns opaque once clear" % kind)
		t.root.remove_child(container)
		container.free()

func test_ground_level_overhead_sign_stays_opaque() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var sign = SignageScript.new()
	sign.z_index = 0
	container.add_child(sign)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.z_index = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	collision.shape = shape
	body.add_child(collision)
	container.add_child(body)
	await _settle(20)
	t.check_approx(sign.modulate.a, 1.0,
		"signage: a z 0 sign finds nothing rendered beneath it")
	t.root.remove_child(container)
	container.free()

func test_all_kinds_draw_for_a_frame() -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	for kind in [&"billboard", &"pylon", &"band"]:
		var sign = SignageScript.new()
		sign.kind = kind
		sign.sub_text = "ALL NIGHT"
		sign.dead_letters = 2
		sign.paint_seed = 77
		holder.add_child(sign)
	await t.process_frame
	t.check(holder.get_child_count() == 3, "signage: every kind draws for one frame")
	t.root.remove_child(holder)
	holder.free()
