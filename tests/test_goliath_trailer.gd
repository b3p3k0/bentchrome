extends RefCounted
## The tow model, headless: straight driving converges the trailer onto the
## cab's line, a hard yank swings the tail past the jackknife attack rate but
## never folds past the articulation clamp, and the two plates honor the rig
## contract (floor-1-bit collision, part_of stamps, never-dying proxies that
## launder quarter-scaled damage into the cab's pool). tow_tick is driven by
## hand — no physics frames, fully deterministic.

const TrailerScript := preload("res://vehicles/goliath/goliath_trailer.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var cab = VehicleScene.instantiate()
	container.add_child(cab)
	var trailer = TrailerScript.new()
	trailer.set_physics_process(false)  # the tests are the clock
	container.add_child(trailer)
	trailer.attach(cab)
	return {"container": container, "cab": cab, "trailer": trailer}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_straight_tow_tracks_the_cab() -> void:
	var f := _fixture()
	var pos := Vector2.ZERO
	for i in 120:  # a long straight pull heading north
		pos += Vector2(0, -10)
		f.trailer.tow_tick(pos, -PI / 2.0, 1.0 / 60.0)
	t.check(absf(angle_difference(f.trailer.yaw, -PI / 2.0)) < 0.05,
		"tow: trailer falls in line behind the cab (yaw %.2f)" % f.trailer.yaw)
	var main_pos: Vector2 = f.trailer.main_center
	t.check(main_pos.y > pos.y + 100.0,
		"tow: the box rides behind the cab (dy %.0f)" % (main_pos.y - pos.y))
	_done(f)

func test_hard_yank_swings_the_tail_and_clamps() -> void:
	var f := _fixture()
	var pos := Vector2.ZERO
	for i in 60:  # settle straight east
		pos += Vector2(12, 0)
		f.trailer.tow_tick(pos, 0.0, 1.0 / 60.0)
	var peak := 0.0
	var max_artic := 0.0
	for i in 60:  # yank the cab hard north — stegosaurus time
		pos += Vector2(0, -12)
		f.trailer.tow_tick(pos, -PI / 2.0, 1.0 / 60.0)
		peak = maxf(peak, absf(f.trailer.yaw_rate))
		# vs the DRIVEN heading — the fixture cab node never turned
		max_artic = maxf(max_artic, absf(angle_difference(-PI / 2.0, f.trailer.yaw)))
	t.check(peak > TrailerScript.SWING_ATTACK_RATE,
		"yank: the swing crosses the attack window (peak %.1f rad/s)" % peak)
	t.check(max_artic <= TrailerScript.MAX_ARTIC + 0.01,
		"yank: articulation clamps at the fold limit (max %.2f)" % max_artic)
	t.check(absf(angle_difference(f.trailer.yaw, -PI / 2.0)) < 0.2,
		"yank: the tail eventually falls back in line")
	_done(f)

func test_plates_wear_the_rig_contract() -> void:
	var f := _fixture()
	var main: AnimatableBody2D = f.trailer.get_node("TrailerMain")
	var nose: AnimatableBody2D = f.trailer.get_node("TrailerNose")
	t.check(main.collision_layer == 8 and nose.collision_layer == 8,
		"plates ride the floor-1 bit only (radar never snapshots them)")
	t.check(main.get_meta(&"part_of") == f.cab.get_path()
		and nose.get_meta(&"part_of") == f.cab.get_path(),
		"plates are stamped part_of the cab (own turret fire passes over)")
	var to_cab_nose: float = f.trailer.nose_center.distance_to(f.cab.global_position)
	var to_cab_main: float = f.trailer.main_center.distance_to(f.cab.global_position)
	t.check(to_cab_nose < to_cab_main, "the weak nose is the quarter nearest the hitch")
	var cab_health: Health = f.cab.get_node("Health")
	var before: float = cab_health.hp
	var nose_proxy: Health = nose.get_node("Health")
	nose_proxy.take_damage(100.0)
	var weak_bill: float = 100.0 * TrailerScript.TRAILER_DMG_FRAC * TrailerScript.TRAILER_WEAK_MULT
	t.check(is_equal_approx(before - cab_health.hp, weak_bill),
		"nose forwards weak-scaled damage to the cab pool (%.0f)" % (before - cab_health.hp))
	t.check(nose_proxy.hp >= nose_proxy.max_hp, "the proxy never dies")
	var mid: float = cab_health.hp
	(main.get_node("Health") as Health).take_damage(100.0)
	t.check(is_equal_approx(mid - cab_health.hp, 100.0 * TrailerScript.TRAILER_DMG_FRAC),
		"main forwards base-scaled damage (%.0f)" % (mid - cab_health.hp))
	_done(f)
