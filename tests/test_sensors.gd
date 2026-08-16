extends RefCounted
## The sensor predicate behind radar blips and edge arrows:
## d <= BASE_SENSOR_RANGE x viewer radar_range_scale x target detectability.
## Locks the base bound, both garage scale axes (Extended Radar / Radar
## Jammer), their composition, and the stats-less-stub neutral read.
## Driven by run_tests.gd.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")

var t

class StubCar extends Node2D:
	var hp := 100.0
	var stats = null  # optionally a VehicleStats — sensor scales read off it
	func get_hp() -> float:
		return hp

func _init(runner) -> void:
	t = runner

func _stats(field: StringName, value: float) -> VehicleStats:
	var s := VehicleStats.new()
	s.set(field, value)
	return s

func _car(pos: Vector2, stats: VehicleStats = null) -> StubCar:
	var car := StubCar.new()
	car.position = pos
	car.stats = stats
	car.add_to_group(&"vehicles")
	t.root.add_child(car)
	return car

func _sensed(viewer: Node, target: Node) -> bool:
	return target in VehiclesHelper.sensed_others(t.root.get_tree(), viewer)

func _done(cars: Array) -> void:
	for car in cars:
		t.root.remove_child(car)
		car.free()

func test_base_bound() -> void:
	var viewer := _car(Vector2.ZERO)
	var near := _car(Vector2(2100, 0))
	var far := _car(Vector2(2300, 0))
	t.check(_sensed(viewer, near), "sensors: 2100px paints under the 2200 base")
	t.check(not _sensed(viewer, far), "sensors: 2300px is past the base bound")
	_done([viewer, near, far])

func test_viewer_radar_range_scale_extends_reach() -> void:
	var viewer := _car(Vector2.ZERO, _stats(&"radar_range_scale", 1.5))
	var near := _car(Vector2(3200, 0))
	var far := _car(Vector2(3400, 0))
	t.check(_sensed(viewer, near), "extended radar: 1.5x viewer reaches 3200")
	t.check(not _sensed(viewer, far), "extended radar: 3400 is past 3300")
	_done([viewer, near, far])

func test_target_detectability_shrinks_paint_distance() -> void:
	var viewer := _car(Vector2.ZERO)
	var sneaky_near := _car(Vector2(1700, 0), _stats(&"detectability", 0.8))
	var sneaky_far := _car(Vector2(1850, 0), _stats(&"detectability", 0.8))
	t.check(_sensed(viewer, sneaky_near), "jammer: 0.8x target still paints at 1700")
	t.check(not _sensed(viewer, sneaky_far), "jammer: 1850 is past 1760")
	_done([viewer, sneaky_near, sneaky_far])

func test_scales_compose_across_viewer_and_target() -> void:
	var viewer := _car(Vector2.ZERO, _stats(&"radar_range_scale", 1.5))
	var sneaky_near := _car(Vector2(2500, 0), _stats(&"detectability", 0.8))
	var sneaky_far := _car(Vector2(2700, 0), _stats(&"detectability", 0.8))
	t.check(_sensed(viewer, sneaky_near), "sensors: 1.5 x 0.8 reach = 2640, 2500 in")
	t.check(not _sensed(viewer, sneaky_far), "sensors: 2700 past the composed bound")
	_done([viewer, sneaky_near, sneaky_far])

func test_stats_less_stub_reads_neutral() -> void:
	t.check(is_equal_approx(VehiclesHelper.stat_scale(null, &"detectability"), 1.0),
		"stat_scale: null node is neutral")
	var bare := Node2D.new()
	t.root.add_child(bare)
	t.check(is_equal_approx(VehiclesHelper.stat_scale(bare, &"radar_range_scale"), 1.0),
		"stat_scale: node without stats is neutral")
	t.root.remove_child(bare)
	bare.free()
