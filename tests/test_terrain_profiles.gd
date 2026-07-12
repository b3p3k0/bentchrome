extends RefCounted
## Typed per-vehicle terrain factors compose over the mutable global table. Ice
## locks the intended feel: eager nose, lazy momentum, stable straight entry.

const ModifierScript := preload("res://resources/vehicle_terrain_modifier.gd")
const StatsScript := preload("res://resources/vehicle_stats.gd")
const CtrlScript := preload("res://vehicles/driving_controller.gd")
const Importer := preload("res://tools/import_roster.gd")
const Dashboard := preload("res://ui/dev_dashboard.gd")

const DT := 1.0 / 60.0

var t

class StubVehicle:
	var heading := 0.0
	var velocity := Vector2.ZERO
	var current_terrain: StringName = &"road"
	var stats: VehicleStats = null
	func get_speed_scale() -> float:
		return 1.0

func _init(runner) -> void:
	t = runner

func test_modifier_defaults_and_neutral_lookup() -> void:
	var modifier := ModifierScript.new()
	t.check(modifier.terrain == &"road", "terrain profile: modifier defaults to road")
	for property in [&"accel", &"top", &"grip", &"steer", &"dash_damage"]:
		t.check_approx(modifier.factor(property), 1.0,
			"terrain profile: %s defaults neutral" % property)
	var stats := StatsScript.new()
	t.check_approx(stats.terrain_factor(&"dirt", &"accel"), 1.0,
		"terrain profile: unconfigured surface stays neutral")

func test_importer_validates_and_builds_typed_entries() -> void:
	var valid := {"dirt": {"accel": 1.4, "steer": 1.15}}
	t.check(Importer.terrain_profile_errors(valid).is_empty(),
		"terrain profile: valid authoring object accepted")
	var built: Array[VehicleTerrainModifier] = Importer.build_terrain_modifiers(valid)
	t.check(built.size() == 1 and built[0].terrain == &"dirt",
		"terrain profile: importer builds typed surface entry")
	t.check_approx(built[0].accel, 1.4, "terrain profile: importer copies accel factor")
	t.check(not Importer.terrain_profile_errors({"lava": {"grip": 1.0}}).is_empty(),
		"terrain profile: unknown terrain rejected")
	t.check(not Importer.terrain_profile_errors({"dirt": {"magic": 2.0}}).is_empty(),
		"terrain profile: unknown property rejected")
	t.check(not Importer.terrain_profile_errors({"dirt": {"grip": 0.0}}).is_empty(),
		"terrain profile: non-positive factor rejected")

func test_effective_surface_composes_global_and_profile() -> void:
	var stats := StatsScript.new()
	var modifier := ModifierScript.new()
	modifier.terrain = &"dirt"
	modifier.accel = 1.4
	modifier.top = 1.2
	stats.terrain_modifiers = [modifier]
	var vehicle := StubVehicle.new()
	vehicle.stats = stats
	var effective: Dictionary = CtrlScript.effective_terrain(vehicle, &"dirt")
	t.check_approx(effective.accel, CtrlScript.TERRAIN[&"dirt"].accel * 1.4,
		"terrain profile: accel multiplies global surface")
	t.check_approx(effective.top, CtrlScript.TERRAIN[&"dirt"].top * 1.2,
		"terrain profile: top multiplies global surface")
	t.check_approx(effective.grip, CtrlScript.TERRAIN[&"dirt"].grip,
		"terrain profile: omitted property stays global")

func test_authored_vehicle_profiles_hit_effective_targets() -> void:
	var expected := {
		&"cricket": {
			&"dirt": [1.12, 1.08, 0.81, 1.15],
			&"grass": [1.01, 1.01, 0.92, 1.08],
		},
		&"hammertoe": {
			&"grass": [0.97, 0.97, 0.88, 1.0],
			&"snow": [0.94, 0.95, 0.56, 1.0],
			&"dirt": [0.94, 0.95, 0.72, 1.0],
			&"water": [0.66, 0.70, 0.77, 1.0],
		},
		&"smoky": {
			&"grass": [0.95, 0.95, 0.86, 1.0],
			&"snow": [0.90, 0.94, 0.53, 1.0],
			&"dirt": [0.88, 0.92, 0.67, 1.0],
			&"water": [0.50, 0.55, 0.74, 1.0],
		},
		&"razorback": {
			&"grass": [0.95, 0.95, 0.86, 1.0],
			&"snow": [0.90, 0.94, 0.53, 1.0],
			&"dirt": [0.88, 0.92, 0.67, 1.0],
			&"water": [0.50, 0.55, 0.74, 1.0],
		},
	}
	for car_id in expected:
		var stats: VehicleStats = load("res://data/vehicles/%s.tres" % String(car_id))
		var vehicle := StubVehicle.new()
		vehicle.stats = stats
		for surface in expected[car_id]:
			var got: Dictionary = CtrlScript.effective_terrain(vehicle, surface)
			var want: Array = expected[car_id][surface]
			for i in 4:
				var property: String = ["accel", "top", "grip", "steer"][i]
				t.check(absf(float(got[property]) - float(want[i])) < 0.0002,
					"terrain profile: %s %s %s effective target" % [car_id, surface, property])
		t.check_approx(stats.terrain_factor(&"ice", &"accel"), 1.0,
			"terrain profile: %s gets no ice exemption" % car_id)

func test_unconfigured_car_and_driver_identity_stay_neutral() -> void:
	var ghost: VehicleStats = load("res://data/vehicles/ghost.tres")
	var player := StubVehicle.new()
	var ai := StubVehicle.new()
	player.stats = ghost
	ai.stats = ghost
	var player_mod: Dictionary = CtrlScript.effective_terrain(player, &"dirt")
	var ai_mod: Dictionary = CtrlScript.effective_terrain(ai, &"dirt")
	t.check(player_mod == CtrlScript.TERRAIN[&"dirt"],
		"terrain profile: ordinary ride keeps global modifiers")
	t.check(player_mod == ai_mod, "terrain profile: driver identity cannot change composition")

func test_dashboard_reports_current_effective_surface() -> void:
	var cricket: VehicleStats = load("res://data/vehicles/cricket.tres")
	var vehicle := StubVehicle.new()
	vehicle.stats = cricket
	vehicle.current_terrain = &"dirt"
	var text := Dashboard.terrain_readout(vehicle)
	t.check(text.contains("dirt") and text.contains("accel 1.12")
		and text.contains("top 1.08") and text.contains("steer 1.15"),
		"terrain profile: dashboard exposes current effective values")

func test_terrain_sensor_priority_and_legacy_entry_order() -> void:
	var sensor := TerrainSensor.new()
	var grass := TerrainZone.new()
	grass.terrain_type = &"grass"
	var snow := TerrainZone.new()
	snow.terrain_type = &"snow"
	var ramp_road := TerrainZone.new()
	ramp_road.terrain_type = &"road"
	ramp_road.terrain_priority = Ramp.TERRAIN_PRIORITY
	sensor._on_area_entered(grass)
	sensor._on_area_entered(snow)
	t.check(sensor.current_terrain == &"snow",
		"terrain sensor: latest legacy zone wins an equal-priority overlap")
	sensor._on_area_entered(ramp_road)
	t.check(sensor.current_terrain == &"road",
		"terrain sensor: ramp-local asphalt overrides broad terrain")
	sensor._on_area_exited(ramp_road)
	t.check(sensor.current_terrain == &"snow",
		"terrain sensor: leaving a ramp restores the latest broad surface")
	sensor.free()
	grass.free()
	snow.free()
	ramp_road.free()

func test_cricket_dash_damage_is_authored_as_a_generic_terrain_factor() -> void:
	var cricket: VehicleStats = load("res://data/vehicles/cricket.tres")
	t.check_approx(cricket.terrain_factor(&"dirt", &"dash_damage"), 1.15,
		"terrain profile: Cricket dirt authors the generic dash factor")
	t.check_approx(cricket.terrain_factor(&"road", &"dash_damage"), 1.0,
		"terrain profile: road dash damage remains neutral")
	t.check_approx(cricket.terrain_factor(&"grass", &"dash_damage"), 1.0,
		"terrain profile: omitted grass dash damage remains neutral")

func test_ice_straight_entry_stays_on_line_and_spins_tires() -> void:
	var ice := CtrlScript.new()
	var straight := StubVehicle.new()
	straight.current_terrain = &"ice"
	straight.velocity = Vector2(400.0, 0.0)
	for i in 60:
		ice.apply(straight, {"throttle": 0.0, "steer": 0.0}, DT)
	t.check(absf(straight.velocity.y) < 0.001 and absf(straight.heading) < 0.001,
		"ice: aligned no-steer crossing stays straight")
	var road_ctrl := CtrlScript.new()
	var ice_ctrl := CtrlScript.new()
	var road := StubVehicle.new()
	var spin := StubVehicle.new()
	spin.current_terrain = &"ice"
	for i in 60:
		road_ctrl.apply(road, {"throttle": 1.0, "steer": 0.0}, DT)
		ice_ctrl.apply(spin, {"throttle": 1.0, "steer": 0.0}, DT)
	t.check(spin.velocity.length() < road.velocity.length() * 0.75,
		"ice: spinning tires build speed much slower than road")
	ice.free()
	road_ctrl.free()
	ice_ctrl.free()

func test_ice_turns_nose_faster_than_movement_path() -> void:
	var road_ctrl := CtrlScript.new()
	var ice_ctrl := CtrlScript.new()
	var road := StubVehicle.new()
	var ice := StubVehicle.new()
	road.velocity = Vector2(400.0, 0.0)
	ice.velocity = Vector2(400.0, 0.0)
	ice.current_terrain = &"ice"
	for i in 15:
		road_ctrl.apply(road, {"throttle": 0.0, "steer": 1.0}, DT)
		ice_ctrl.apply(ice, {"throttle": 0.0, "steer": 1.0}, DT)
	t.check(absf(ice.heading) > absf(road.heading) * 1.15,
		"ice: steer multiplier rotates the nose faster")
	t.check(absf(ice.velocity.angle()) < absf(ice.heading) * 0.35,
		"ice: momentum bearing lags far behind facing")
	t.check(absf(ice.velocity.angle()) < absf(road.velocity.angle()) * 0.3,
		"ice: path responds far less than pavement")
	road_ctrl.free()
	ice_ctrl.free()
