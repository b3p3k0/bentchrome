extends RefCounted
## Pit hazard: sheer-face target geometry, inward fall choreography, distant
## impact punctuation, lethal landing, and airborne clearance. Pumps real
## physics frames (the runner awaits test methods).

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const PitScene := preload("res://environment/pit_zone.tscn")
const PitFallFXScript := preload("res://environment/pit_fall_fx.gd")

var t

func _init(runner) -> void:
	t = runner

func _fixture(pit_size := Vector2(400, 400), car_at := Vector2.ZERO) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var pit = PitScene.instantiate()
	pit.size = pit_size
	container.add_child(pit)
	var car: Vehicle = VehicleScene.instantiate()
	car.faction = &"enemies"  # never shadow the live player autoload/group lookup
	car.global_position = car_at
	var died := [false]
	var health := car.get_node(^"Health") as Health
	health.died.connect(func() -> void: died[0] = true)
	container.add_child(car)
	return {"container": container, "pit": pit, "car": car,
		"health": health, "died": died}

func _done(f: Dictionary) -> void:
	var container: Node2D = f.container
	if is_instance_valid(container):
		t.root.remove_child(container)
		container.free()

func test_fall_target_uses_short_axis_centerline() -> void:
	var vertical := _fixture(Vector2(256, 704))
	var vertical_pit: Node2D = vertical.pit
	vertical_pit.global_position = Vector2(300, -120)
	var vertical_entry: Vector2 = vertical_pit.to_global(Vector2(70, 245))
	var vertical_target: Vector2 = vertical_pit.fall_target_for(vertical_entry)
	t.check(vertical_pit.to_local(vertical_target).is_equal_approx(Vector2(0, 245)),
		"pit target: vertical cliff centers X and preserves the long Y lane")
	_done(vertical)

	var horizontal := _fixture(Vector2(384, 256))
	var horizontal_pit: Node2D = horizontal.pit
	horizontal_pit.global_position = Vector2(-200, 80)
	var horizontal_entry: Vector2 = horizontal_pit.to_global(Vector2(145, -60))
	var horizontal_target: Vector2 = horizontal_pit.fall_target_for(horizontal_entry)
	t.check(horizontal_pit.to_local(horizontal_target).is_equal_approx(Vector2(145, 0)),
		"pit target: horizontal chasm centers Y and preserves the long X lane")
	_done(horizontal)

func test_square_target_uses_dominant_entry_axis() -> void:
	var f := _fixture(Vector2(400, 400))
	var pit: Node2D = f.pit
	var x_dominant: Vector2 = pit.to_local(pit.fall_target_for(Vector2(150, 40)))
	var y_dominant: Vector2 = pit.to_local(pit.fall_target_for(Vector2(25, -160)))
	t.check(x_dominant.is_equal_approx(Vector2(0, 40)),
		"pit target: square centers dominant X displacement")
	t.check(y_dominant.is_equal_approx(Vector2(25, 0)),
		"pit target: square centers dominant Y displacement")
	_done(f)

func test_bottom_snow_carries_miniature_pine_scale_cues() -> void:
	var vertical := _fixture(Vector2(256, 704))
	var vertical_pit = vertical.pit
	var vertical_pines: PackedVector2Array = vertical_pit.bottom_pine_positions()
	var corridor: float = vertical_pit.BOTTOM_PINE_MAX_RADIUS * 1.8
	t.check(vertical_pines.size() >= 10,
		"pit floor: long cliff carries a readable miniature forest")
	for pine in vertical_pines:
		t.check(absf(pine.x - vertical_pit.OCCLUSION_OFFSET.x) >= corridor,
			"pit floor: vertical fall centerline stays open for the car and impact")
	t.check(vertical_pit.BOTTOM_SNOW_COLOR.get_luminance()
			< vertical_pit.SNOW_CAP.get_luminance(),
		"pit floor: bottom snow is familiar but shaded well below surface snow")
	_done(vertical)

	var horizontal := _fixture(Vector2(384, 256))
	var horizontal_pit = horizontal.pit
	var horizontal_pines: PackedVector2Array = horizontal_pit.bottom_pine_positions()
	t.check(horizontal_pines.size() >= 5,
		"pit floor: wide chasm carries miniature pines too")
	for pine in horizontal_pines:
		t.check(absf(pine.y - horizontal_pit.OCCLUSION_OFFSET.y) >= corridor,
			"pit floor: horizontal fall centerline stays open for the car and impact")
	var pit_script = load("res://environment/pit_zone.gd")
	var clutter_script = load("res://environment/clutter.gd")
	t.check(pit_script.PinePaint == clutter_script.PinePaint,
		"pit floor: miniature and drive-level pines share one silhouette painter")
	_done(horizontal)

func test_grounded_car_pulls_in_and_shrinks_visuals_only() -> void:
	var f := _fixture(Vector2(400, 200), Vector2(120, 50))
	var car: Vehicle = f.car
	var body_scale_before: Vector2 = car.scale
	for i in 20:
		await t.physics_frame
	var visual := car.get_node(^"Visual") as Node2D
	var shadow := car.get_node(^"Shadow") as Node2D
	t.check(car.global_position.x > 119.0 and car.global_position.y < 48.0
			and car.global_position.y > 1.0,
		"pit fall: car moves across the short axis without a long-axis vacuum")
	t.check(visual.scale.x < 0.98 and visual.scale.x > Vehicle.PIT_MIN_VISUAL_SCALE,
		"pit fall: car paint shrinks progressively toward the distant floor")
	t.check(shadow.modulate.a < 1.0 and shadow.scale.x < 1.0,
		"pit fall: shadow fades and tightens while the car drops")
	t.check(car.scale == body_scale_before,
		"pit fall: physics body node scale never changes")
	_done(f)

func test_repeated_trigger_does_not_retarget_or_restart() -> void:
	var f := _fixture(Vector2(400, 200), Vector2(120, 40))
	var car: Vehicle = f.car
	car.fall_into_pit(Vector2(120, 0))
	car.fall_into_pit(Vector2(-160, -70))
	for i in 20:
		await t.physics_frame
	t.check(car.global_position.x > 119.0 and car.global_position.y < 39.0,
		"pit fall: repeated overlap keeps the first target and tween")
	_done(f)

func test_impact_star_precedes_lethal_finish() -> void:
	var f := _fixture(Vector2(400, 200), Vector2(120, 40))
	for i in 38:  # just past the 0.60s sound/impact cue at 60 physics Hz
		await t.physics_frame
	var found_fx := false
	var container: Node2D = f.container
	for child in container.get_children():
		if child.get_script() == PitFallFXScript:
			found_fx = true
			break
	t.check(found_fx, "pit fall: tiny distant impact lands with the muted thud")
	t.check(not bool(f.died[0]), "pit fall: impact punctuation precedes the lethal finish")
	_done(f)

func test_grounded_car_falls_and_dies() -> void:
	var f := _fixture()
	var health: Health = f.health
	health.invulnerable = true  # cliffs don't care
	for i in 55:  # 0.7s fall + margin
		await t.physics_frame
	t.check(bool(f.died[0]), "pit: grounded car dies, invulnerability ignored")
	_done(f)

func test_airborne_car_sails_over() -> void:
	var f := _fixture()
	var car: Vehicle = f.car
	car.height = 500.0  # mid ramp-jump
	for i in 20:  # still airborne this whole window
		await t.physics_frame
	var health: Health = f.health
	t.check(health.hp >= health.max_hp, "pit: airborne car passes over untouched")
	_done(f)
