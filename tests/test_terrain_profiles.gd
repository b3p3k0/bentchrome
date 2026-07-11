extends RefCounted
## Typed per-vehicle terrain factors compose over the mutable global table. Ice
## locks the intended feel: eager nose, lazy momentum, stable straight entry.

const ModifierScript := preload("res://resources/vehicle_terrain_modifier.gd")
const StatsScript := preload("res://resources/vehicle_stats.gd")
const CtrlScript := preload("res://vehicles/driving_controller.gd")
const Importer := preload("res://tools/import_roster.gd")

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
