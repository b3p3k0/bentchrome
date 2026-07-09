extends RefCounted
## AI floor navigator: connector picking, the committed two-phase waypoint
## run, timeout/exit handling, the roof-sniper vantage hold, tracking-def
## detection, and the cross-floor targeting penalty. Pure logic on the
## FakeCar pattern — real driving is HI-verified on the dock.

const DriverScript := preload("res://vehicles/drivers/enemy_driver.gd")
const ConnectorScript := preload("res://environment/floor_connector.gd")

var t

class FakeCar extends Node2D:
	var floor_index := -1
	var hpf := 1.0
	var heading := 0.0
	func get_hp_fraction() -> float:
		return hpf

class FakeRack extends Node:
	var def: WeaponDef = null
	var armed := true
	func selected_def() -> WeaponDef:
		return def
	func can_consume() -> bool:
		return armed

func _init(runner) -> void:
	t = runner

func _tracking_def() -> WeaponDef:
	var d := WeaponDef.new()
	d.turn_rate_deg = 200.0
	d.acquisition_radius = 900.0
	return d

func _rig() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var hunter := FakeCar.new()
	hunter.floor_index = 2
	container.add_child(hunter)
	var target := FakeCar.new()
	target.floor_index = 3
	target.global_position = Vector2(1000, 0)
	container.add_child(target)
	return {"container": container, "hunter": hunter, "target": target}

func _connector(container: Node, pos: Vector2, from: int, to: int, kind := &"ramp") -> Node2D:
	var c = ConnectorScript.new()
	c.from_floor = from
	c.to_floor = to
	c.kind = kind
	c.position = pos
	container.add_child(c)
	return c

func _done(rig: Dictionary) -> void:
	t.root.remove_child(rig.container)
	rig.container.free()

func test_connector_pick_prefers_right_route() -> void:
	var rig := _rig()
	var right := _connector(rig.container, Vector2(200, 0), 2, 3)
	var _far_away := _connector(rig.container, Vector2(2400, 0), 2, 3)
	var _wrong_dir := _connector(rig.container, Vector2(100, 0), 2, 1)
	var _wrong_from := _connector(rig.container, Vector2(150, 0), 3, 2)
	var d = DriverScript.new()
	t.check(d._enter_navigate(rig.hunter, rig.target, 2, 3), "nav: a route exists")
	t.check(d._nav_connector == right, "nav: picks the near connector going the right way")
	t.check(d._mode == DriverScript.Mode.NAVIGATE, "nav: enters NAVIGATE")
	d.free()
	_done(rig)

func test_no_route_stays_in_pursue() -> void:
	var rig := _rig()
	var _wrong := _connector(rig.container, Vector2(100, 0), 2, 1)
	var d = DriverScript.new()
	t.check(not d._enter_navigate(rig.hunter, rig.target, 2, 3), "nav: no upward route found")
	t.check(d._mode == DriverScript.Mode.PURSUE, "nav: falls back to pursue, never parks")
	d.free()
	_done(rig)

func test_two_phase_run_and_ramp_boost() -> void:
	var rig := _rig()
	var _ramp := _connector(rig.container, Vector2(200, 0), 2, 3)  # approach +x
	var d = DriverScript.new()
	d._enter_navigate(rig.hunter, rig.target, 2, 3)
	# Far from the entry lead point (-20, 0): approach phase, no boost.
	rig.hunter.global_position = Vector2(-600, 0)
	var intent: Dictionary = d._navigate_intent(rig.hunter, rig.target, 2, true, Vector2(100, 0), 0.016)
	t.check(not intent.is_empty(), "nav: approach phase drives")
	t.check(not intent["fire_mg"] and not intent["fire_selected"], "nav: holds fire while routing")
	t.check(not intent["boost"], "nav: no boost on approach")
	t.check(d._nav_phase == 0, "nav: still approaching")
	# On the entry point: phase flips to COMMIT, ramps get the boost run-up.
	rig.hunter.global_position = Vector2(-25, 5)
	intent = d._navigate_intent(rig.hunter, rig.target, 2, true, Vector2(100, 0), 0.016)
	t.check(d._nav_phase == 1, "nav: entry reached, committed")
	t.check(intent["boost"], "nav: ramp commit boosts (launch needs speed)")
	t.check_approx(intent["throttle"], 1.0, "nav: commit is full throttle")
	d.free()
	_done(rig)

func test_exit_on_timeout_and_floor_change() -> void:
	var rig := _rig()
	var _ramp := _connector(rig.container, Vector2(200, 0), 2, 3)
	var d = DriverScript.new()
	d._enter_navigate(rig.hunter, rig.target, 2, 3)
	d._nav_t = 0.01
	var intent: Dictionary = d._navigate_intent(rig.hunter, rig.target, 2, true, Vector2(100, 0), 0.1)
	t.check(intent.is_empty() and d._mode == DriverScript.Mode.PURSUE, "nav: timeout re-plans via pursue")
	# Fresh run; landing on the target's floor (cross=false) exits too.
	d._enter_navigate(rig.hunter, rig.target, 2, 3)
	intent = d._navigate_intent(rig.hunter, rig.target, 3, false, Vector2(100, 0), 0.016)
	t.check(intent.is_empty() and d._mode == DriverScript.Mode.PURSUE, "nav: arrival hands back to pursue")
	d.free()
	_done(rig)

func test_sniper_holds_vantage_then_descends() -> void:
	var rig := _rig()
	rig.hunter.floor_index = 3  # on the roof
	rig.target.floor_index = 2  # prey below
	var _edge := _connector(rig.container, Vector2(300, 0), 3, 2, &"edge")
	var rack := FakeRack.new()
	rack.def = _tracking_def()
	rig.container.add_child(rack)
	var d = DriverScript.new()
	d.mix = Vector3(0, 1, 0)  # ambusher: holds the high ground
	var out: Dictionary = d._navigate_gate(rig.hunter, rig.target, rack, false, Vector2(100, 0), 0.016)
	t.check(out.is_empty() and d._mode == DriverScript.Mode.PURSUE, "nav: sniper holds the vantage")
	t.check(d._snipe_t > 0.0, "nav: vantage meter runs")
	d._snipe_t = DriverScript.NAV_SNIPE_TIME  # patience spent
	out = d._navigate_gate(rig.hunter, rig.target, rack, false, Vector2(100, 0), 0.016)
	t.check(d._mode == DriverScript.Mode.NAVIGATE, "nav: timer forces the descent")
	# An aggressor with the same kit never lingers.
	var d2 = DriverScript.new()
	d2.mix = Vector3(1, 0, 0)
	d2._navigate_gate(rig.hunter, rig.target, rack, false, Vector2(100, 0), 0.016)
	t.check(d2._mode == DriverScript.Mode.NAVIGATE, "nav: aggressor routes down immediately")
	d.free()
	d2.free()
	_done(rig)

func test_selected_tracking_detection() -> void:
	var d = DriverScript.new()
	var rack := FakeRack.new()
	rack.def = _tracking_def()
	t.check(d._selected_tracking(rack), "nav: homing def reads as tracking")
	rack.def = WeaponDef.new()  # turn_rate 0 = straight
	t.check(not d._selected_tracking(rack), "nav: straight def is not tracking")
	t.check(not d._selected_tracking(null), "nav: no rack, no tracking")
	rack.free()
	d.free()

func test_cross_floor_targets_score_lower() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var hunter := FakeCar.new()
	hunter.floor_index = 2
	container.add_child(hunter)
	hunter.add_to_group(&"vehicles")
	var same_floor := FakeCar.new()
	same_floor.floor_index = 2
	same_floor.global_position = Vector2(500, 0)
	same_floor.add_to_group(&"vehicles")
	container.add_child(same_floor)
	var roof := FakeCar.new()
	roof.floor_index = 3
	roof.global_position = Vector2(450, 0)  # nearer, but a terrace away
	roof.add_to_group(&"vehicles")
	container.add_child(roof)
	var d = DriverScript.new()
	t.check(d._select_target(hunter) == same_floor, "nav: penalty tips near-ties to the same floor")
	roof.global_position = Vector2(120, 0)  # decisively closer: still a target
	t.check(d._select_target(hunter) == roof, "nav: penalty is a thumb, not a wall")
	d.free()
	t.root.remove_child(container)
	container.free()
