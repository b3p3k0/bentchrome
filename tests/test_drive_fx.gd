extends RefCounted
## Skidmark priority at the shared global cap: the viewpoint car always paints,
## rivals never displace its live marks, and carried tracks use the same rule.

const DriveFXScript := preload("res://vehicles/drive_fx.gd")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")

var t

class FxCar extends CharacterBody2D:
	var current_terrain: StringName = &"road"
	var heading := 0.0
	var height := 0.0

	func body_metrics() -> Dictionary:
		return {"skid_points": [Vector2(-8, -5), Vector2(-8, 5)]}

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var previous_scene: Node = t.current_scene
	t.current_scene = container
	return {"container": container, "previous_scene": previous_scene}

func _finish(fixture: Dictionary) -> void:
	t.current_scene = fixture.previous_scene
	var container: Node2D = fixture.container
	t.root.remove_child(container)
	container.free()

func _car(container: Node2D, group := &"") -> Dictionary:
	var car := FxCar.new()
	if not group.is_empty():
		car.add_to_group(group)
	container.add_child(car)
	var fx = DriveFXScript.new()
	fx.name = "DriveFX"
	car.add_child(fx)
	return {"car": car, "fx": fx}

func _fill_cap(container: Node2D, owner: Node) -> Array[Line2D]:
	var marks: Array[Line2D] = []
	for i in DriveFXScript.MAX_SKID_NODES:
		var line := Line2D.new()
		line.set_meta(DriveFXScript.SKID_OWNER_META, owner)
		line.set_meta(DriveFXScript.SKID_ORDER_META, -1000 + i)
		line.add_to_group(&"skidmarks")
		container.add_child(line)
		marks.append(line)
	return marks

func test_local_skid_retires_oldest_rival_marks_at_the_cap() -> void:
	var fixture := _fixture()
	var container: Node2D = fixture.container
	var rival: Node = _car(container).car
	var rival_marks := _fill_cap(container, rival)
	var local := _car(container, VehiclesHelper.GROUP_LOCAL)
	local.fx._start_skid()
	t.check(local.fx._skids.size() == 2,
		"drive fx: local player receives both skid lines at the cap")
	t.check(t.get_nodes_in_group(&"skidmarks").size()
			<= DriveFXScript.MAX_SKID_NODES + 2,
		"drive fx: local priority never grows the group beyond one pair")
	t.check(not rival_marks[0].is_in_group(&"skidmarks")
			and not rival_marks[1].is_in_group(&"skidmarks")
			and rival_marks[2].is_in_group(&"skidmarks"),
		"drive fx: the oldest rival marks retire first")
	for line in local.fx._skids:
		t.check(line.get_meta(DriveFXScript.SKID_OWNER_META) == local.car,
			"drive fx: each local skid line records its owner")
	_finish(fixture)

func test_rival_skid_still_gets_nothing_at_the_cap() -> void:
	var fixture := _fixture()
	var container: Node2D = fixture.container
	var owner: Node = _car(container).car
	_fill_cap(container, owner)
	var rival := _car(container)
	rival.fx._start_skid()
	t.check(rival.fx._skids.is_empty(),
		"drive fx: a rival still receives no skid lines at the cap")
	t.check(t.get_nodes_in_group(&"skidmarks").size()
			== DriveFXScript.MAX_SKID_NODES,
		"drive fx: a rival cannot push the shared cap higher")
	_finish(fixture)

func test_rival_skid_never_retires_a_live_player_mark() -> void:
	var fixture := _fixture()
	var container: Node2D = fixture.container
	var local: Node = _car(container, VehiclesHelper.GROUP_LOCAL).car
	var player_line := Line2D.new()
	player_line.set_meta(DriveFXScript.SKID_OWNER_META, local)
	player_line.set_meta(DriveFXScript.SKID_ORDER_META, -2000)
	player_line.add_to_group(&"skidmarks")
	container.add_child(player_line)
	var owner: Node = _car(container).car
	for i in DriveFXScript.MAX_SKID_NODES - 1:
		var line := Line2D.new()
		line.set_meta(DriveFXScript.SKID_OWNER_META, owner)
		line.add_to_group(&"skidmarks")
		container.add_child(line)
	var rival := _car(container)
	rival.fx._start_skid()
	t.check(rival.fx._skids.is_empty() and player_line.is_in_group(&"skidmarks")
			and is_equal_approx(player_line.modulate.a, 1.0),
		"drive fx: a rival cannot retire a live local-player mark")
	_finish(fixture)

func test_local_carried_tracks_use_player_group_fallback() -> void:
	var fixture := _fixture()
	var container: Node2D = fixture.container
	var rival: Node = _car(container).car
	_fill_cap(container, rival)
	var local := _car(container, &"player")
	local.fx.carry_splat()
	t.check(local.fx._blood_tracks.size() == 2,
		"drive fx: local carried tracks receive both lines at the cap")
	t.check(t.get_nodes_in_group(&"skidmarks").size()
			<= DriveFXScript.MAX_SKID_NODES + 2,
		"drive fx: player-group fallback uses the same bounded priority")
	_finish(fixture)
