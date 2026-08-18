extends RefCounted
## SpectatorRig: FOLLOW cycling skips wrecked/freed subjects and wraps, FREE
## ROAM engages on pan and disengages on cycle, and an empty floor hovers.

const RigScene := preload("res://levels/mp/spectator_rig.tscn")

var t

func _init(runner) -> void:
	t = runner

func _rig_with(n: int) -> Array:
	var rig: Node2D = RigScene.instantiate()
	var targets: Array = []
	for i in n:
		var car := Node2D.new()
		car.position = Vector2(i * 100, 0)
		t.root.add_child(car)
		targets.append(car)
	rig.targets = targets
	rig.actor_names = ["A", "B", "C", "D"].slice(0, n)
	t.root.add_child(rig)
	return [rig, targets]

func _teardown(rig: Node2D, targets: Array) -> void:
	t.root.remove_child(rig)
	rig.free()
	for car in targets:
		if is_instance_valid(car):
			t.root.remove_child(car)
			car.free()

func test_cycle_and_roam() -> void:
	var pair := _rig_with(3)
	var rig: Node2D = pair[0]
	var targets: Array = pair[1]

	t.check(rig._follow == 0 and not rig._free, "rig: opens following the first car")
	rig.cycle(1)
	t.check(rig._follow == 1, "rig: cycle advances")
	targets[2].visible = false  # wrecked — puppets hide on death
	rig.cycle(1)
	t.check(rig._follow == 0, "rig: cycle skips the hidden wreck and wraps")

	rig.pan(Vector2.RIGHT, 1.0)
	t.check(rig._free, "rig: panning breaks into free roam")
	t.check(rig.global_position.x > 0.0, "rig: free roam actually moves")
	rig.cycle(1)
	t.check(not rig._free, "rig: cycling snaps back to follow")

	targets[0].visible = false
	targets[1].visible = false
	rig.cycle(1)
	t.check(rig._free, "rig: an empty floor hovers in free roam")

	_teardown(rig, targets)

func test_persistent_toggle_zoom() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var keep_combat: float = gs.zoom_combat
	var keep_overview: float = gs.zoom_overview
	var keep_state: bool = gs.overview
	gs.zoom_combat = 0.55
	gs.zoom_overview = 0.42
	gs.overview = false
	Input.action_release(&"zoom_toggle")
	var pair := _rig_with(1)
	var rig: Node2D = pair[0]
	t.check(is_equal_approx(rig._cam.zoom.x, 0.55),
		"spectator zoom: boots at combat depth")
	Input.action_press(&"zoom_toggle")
	rig._process(0.2)
	t.check(is_equal_approx(rig._cam.zoom.x, 0.42),
		"spectator zoom: pressing G toggles overview")
	Input.action_release(&"zoom_toggle")
	rig._process(0.2)
	t.check(is_equal_approx(rig._cam.zoom.x, 0.42) and gs.overview,
		"spectator zoom: release preserves overview state")
	_teardown(rig, pair[1])
	gs.zoom_combat = keep_combat
	gs.zoom_overview = keep_overview
	gs.overview = keep_state
