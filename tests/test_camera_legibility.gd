extends RefCounted
## Combat camera legibility: persistent toggle zoom, tunable velocity lead, Route 666's
## authored exception, LAN-puppet compatibility, and the on-demand locator.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const ChasePlayerScene := preload("res://levels/chase/chase_player.tscn")

var t

func _init(runner) -> void:
	t = runner

func _vehicle() -> Vehicle:
	var car := VehicleScene.instantiate()
	t.root.add_child(car)
	return car

func _done(car: Node) -> void:
	t.root.remove_child(car)
	car.free()

func test_driving_camera_persistent_toggle() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var keep_combat: float = gs.zoom_combat
	var keep_overview: float = gs.zoom_overview
	var keep_state: bool = gs.overview
	gs.zoom_combat = 0.55
	gs.zoom_overview = 0.42
	gs.overview = false
	Input.action_release(&"zoom_toggle")
	var car := _vehicle()
	var camera := car.get_node(^"Camera2D") as Camera2D
	t.check(is_equal_approx(camera.zoom.x, 0.55),
		"camera zoom: combat state boots at the configured depth")
	Input.action_press(&"zoom_toggle")
	car._process(0.2)
	t.check(is_equal_approx(camera.zoom.x, 0.42),
		"camera zoom: pressing G toggles to overview")
	Input.action_release(&"zoom_toggle")
	car._process(0.2)
	t.check(is_equal_approx(camera.zoom.x, 0.42) and gs.overview,
		"camera zoom: releasing G leaves the toggle state unchanged")
	_done(car)
	car = _vehicle()
	camera = car.get_node(^"Camera2D") as Camera2D
	t.check(is_equal_approx(camera.zoom.x, 0.42),
		"camera zoom: a new gameplay scene boots at the persisted overview depth")
	_done(car)
	gs.zoom_combat = keep_combat
	gs.zoom_overview = keep_overview
	gs.overview = keep_state

func test_velocity_look_ahead_curve_and_recenter() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var keep_enabled: bool = gs.camera_look_ahead_enabled
	var keep_distance: float = gs.camera_look_ahead_distance
	gs.camera_look_ahead_enabled = true
	gs.camera_look_ahead_distance = 140.0
	t.check(Vehicle.camera_look_ahead_for(Vector2(30, 0), 140.0) == Vector2.ZERO,
		"camera lead: dead-speed band stays centered")
	t.check_approx(Vehicle.camera_look_ahead_for(Vector2(215, 0), 140.0).x, 70.0,
		"camera lead: half-speed produces half lead")
	t.check_approx(Vehicle.camera_look_ahead_for(Vector2(400, 0), 140.0).x, 140.0,
		"camera lead: the new default reaches 140px at full speed")
	t.check_approx(Vehicle.camera_look_ahead_for(Vector2(400, 0), 200.0).x, 200.0,
		"camera lead: the user-facing maximum reaches 200px")
	t.check(Vehicle.camera_look_ahead_for(Vector2(400, 0), 0.0) == Vector2.ZERO,
		"camera lead: zero distance disables displacement")
	t.check_approx(Vehicle.camera_look_ahead_for(Vector2(0, -800), 140.0).y, -140.0,
		"camera lead: direction follows world velocity")

	var car := VehicleScene.instantiate()
	var camera := car.get_node(^"Camera2D") as Camera2D
	camera.position = Vector2(20, -10)
	t.root.add_child(car)
	car.velocity = Vector2(400, 0)
	car._process(0.25)
	t.check(camera.position.is_equal_approx(Vector2(160, -10)),
		"camera lead: composes onto an authored base position")
	gs.camera_look_ahead_enabled = false
	car._process(0.25)
	t.check(camera.position.is_equal_approx(Vector2(20, -10)),
		"camera lead: the global graphics toggle recenters the camera")
	gs.camera_look_ahead_enabled = true
	car.velocity = Vector2.ZERO
	car._process(0.25)
	t.check(camera.position.is_equal_approx(Vector2(20, -10)),
		"camera lead: stopping recenters on the authored base")
	car.velocity = Vector2(400, 0)
	car._process(0.25)
	(car.get_node(^"Health") as Health).hp = 0.0
	car._process(0.25)
	t.check(camera.position.is_equal_approx(Vector2(20, -10)),
		"camera lead: the respawn delay recenters despite stale velocity")
	_done(car)
	gs.camera_look_ahead_enabled = keep_enabled
	gs.camera_look_ahead_distance = keep_distance

func test_respawn_discards_pit_camera_smoothing_history() -> void:
	var car := _vehicle()
	var camera := car.get_node(^"Camera2D") as Camera2D
	camera.make_current()
	var pit_center := Vector2(1200, 700)
	var spawn_point := Vector2(-600, -350)
	car.global_position = pit_center
	camera.reset_smoothing()
	camera.force_update_scroll()
	t.check(camera.get_screen_center_position().is_equal_approx(pit_center),
		"camera respawn: fixture begins with the smoothed view down in the pit")
	car.respawn(spawn_point, 0.0, 0.0)
	camera.force_update_scroll()
	t.check(camera.get_screen_center_position().is_equal_approx(spawn_point),
		"camera respawn: pit history cannot whip the view away from the spawn point")
	_done(car)

func test_chase_exception_and_lan_puppet_lead() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var keep_enabled: bool = gs.camera_look_ahead_enabled
	var keep_distance: float = gs.camera_look_ahead_distance
	gs.camera_look_ahead_enabled = true
	gs.camera_look_ahead_distance = 140.0
	var chase := ChasePlayerScene.instantiate()
	t.root.add_child(chase)
	var chase_camera := chase.get_node(^"Camera2D") as Camera2D
	chase.velocity = Vector2(400, 0)
	chase._process(0.25)
	t.check(not chase.camera_look_ahead_enabled,
		"camera lead: Route 666 explicitly disables ordinary look-ahead")
	t.check(chase_camera.position.is_equal_approx(Vector2(0, -260)),
		"camera lead: Route 666 keeps its authored chase offset")
	_done(chase)

	var puppet := _vehicle()
	puppet.set_net_puppet(true)
	puppet.velocity = Vector2(0, 400)
	puppet._process(0.25)
	var puppet_camera := puppet.get_node(^"Camera2D") as Camera2D
	t.check(puppet_camera.position.is_equal_approx(Vector2(0, 140)),
		"camera lead: a local LAN puppet uses streamed velocity")
	_done(puppet)
	gs.camera_look_ahead_enabled = keep_enabled
	gs.camera_look_ahead_distance = keep_distance

func test_locator_is_local_temporary_and_composable() -> void:
	var car := _vehicle()
	car.add_to_group(&"local_player")
	var visual := car.get_node(^"Visual") as Node2D
	var paint := car.get_node(^"Visual/Body") as Node2D
	visual.modulate = Color(0.5, 0.7, 0.9, 0.4)
	var parent_tint := visual.modulate
	t.check(car.trigger_locator_pulse(), "locator: the local viewer can start a pulse")
	t.check(paint.self_modulate.r > 2.3 and visual.modulate == parent_tint,
		"locator: paint brightens without replacing parent tint/opacity")
	car._update_locator_pulse(0.08)
	t.check(paint.self_modulate == Color.WHITE,
		"locator: strobe returns to normal on the alternating beat")
	t.check(car.trigger_locator_pulse() and car._locator_left >= 0.59,
		"locator: repeated presses restart the full pulse")
	car._update_locator_pulse(0.61)
	t.check(paint.self_modulate == Color.WHITE and car._locator_left == 0.0,
		"locator: completion restores neutral paint")
	car.trigger_locator_pulse()
	t.root.remove_child(car)
	t.check(paint.self_modulate == Color.WHITE,
		"locator: leaving the tree cannot strand bright paint")
	car.free()

	var local_anchor := Node2D.new()
	local_anchor.add_to_group(&"local_player")
	t.root.add_child(local_anchor)
	var other := _vehicle()
	t.check(not other.trigger_locator_pulse(),
		"locator: a non-local vehicle ignores the client input")
	_done(other)
	t.root.remove_child(local_anchor)
	local_anchor.free()
