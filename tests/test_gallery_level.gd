extends RefCounted
## Shooting gallery. Card G-1 — the shared target pieces: the dummy's opt-in
## respawn (default still frees), the one HP label, the lap driver's
## per-instance throttle, and the reusable exit prompt. Card G-2 — the gallery
## nodes: the target car scene, the lane spawner/respawner, the prop reset
## helper, and the range-tick paint. Tree-entered fixtures live under t.root,
## release the tree unpaused, and free every node. Target cars are faction
## `targets`, so no fixture ever shadows a player-group lookup.

const DummyScene := preload("res://environment/target_dummy.tscn")
const HpLabel := preload("res://environment/hp_label.gd")
const LapDriver := preload("res://vehicles/goliath/victory_lap_driver.gd")
const ConfirmScript := preload("res://levels/tutorial/exit_confirm.gd")
const HealthScript := preload("res://vehicles/health.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const VehicleScript := preload("res://vehicles/vehicle.gd")
const TargetScene := preload("res://vehicles/target_vehicle.tscn")
const LaneScript := preload("res://levels/gallery/target_lane.gd")
const ResetScript := preload("res://levels/gallery/target_reset.gd")
const DecoScript := preload("res://levels/gallery/gallery_deco.gd")
const BlockScene := preload("res://environment/destructible_block.tscn")
const DerelictScene := preload("res://environment/derelict_car.tscn")

var t

func _init(runner) -> void:
	t = runner

## Live Vehicle children of a lane (the inherited target scene's root script
## IS vehicle.gd); a car mid-queue_free is not counted.
func _cars(lane: Node) -> Array:
	var out := []
	for child in lane.get_children():
		if child.get_script() == VehicleScript and not child.is_queued_for_deletion():
			out.append(child)
	return out

func _labels(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is Label:
			out.append(child)
	return out

## First Label in document order: _build_ui adds the caption before the
## option row, so a depth-first walk lands on it.
func _first_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child as Label
		var found := _first_label(child)
		if found != null:
			return found
	return null

func _drop(node: Node) -> void:
	t.root.remove_child(node)
	node.free()

## respawn_seconds = 0 is today's dummy: died -> queue_free.
func test_dummy_default_frees_on_death() -> void:
	var dummy: Node = DummyScene.instantiate()
	t.root.add_child(dummy)
	t.check(dummy.is_in_group(&"dummies"), "dummy: default joins dummies")
	t.check(dummy.get_node(^"Label").text == "60", "dummy: label reads max hp on boot")
	dummy.get_node(^"Health").kill()
	await t.process_frame
	await t.process_frame
	t.check(not is_instance_valid(dummy), "dummy: respawn 0 is freed on death")

## respawn_seconds > 0: gone from sight, physics, and the radar group for the
## delay, then back whole with the label caught up.
func test_dummy_respawns_after_delay() -> void:
	var dummy: Node = DummyScene.instantiate()
	dummy.respawn_seconds = 0.2
	t.root.add_child(dummy)
	var health: Node = dummy.get_node(^"Health")
	var col: CollisionShape2D = dummy.get_node(^"Col")
	var label: Label = dummy.get_node(^"Label")
	health.take_damage(10.0)
	t.check(label.text == "50", "respawn: label follows damage (50)")
	health.kill()
	await t.process_frame
	await t.process_frame
	t.check(is_instance_valid(dummy), "respawn: the dummy survives its death")
	t.check(not dummy.visible, "respawn: hidden during the delay")
	t.check(col.disabled, "respawn: Col disabled during the delay")
	t.check(not dummy.is_in_group(&"dummies"), "respawn: out of dummies during the delay")
	t.check(health.hp <= 0.0, "respawn: hp stays 0 during the delay")
	await t.create_timer(0.3).timeout
	await t.process_frame
	t.check(dummy.visible, "respawn: visible after the delay")
	t.check(not col.disabled, "respawn: Col re-enabled after the delay")
	t.check(dummy.is_in_group(&"dummies"), "respawn: back in dummies after the delay")
	t.check(is_equal_approx(health.hp, health.max_hp), "respawn: hp == max_hp after the delay")
	t.check(label.text == "%d" % roundi(health.max_hp), "respawn: label reads max_hp after the delay")
	_drop(dummy)

## The timer must not resurrect a dummy that left the world meanwhile.
func test_dummy_respawn_skips_when_out_of_tree() -> void:
	var dummy: Node = DummyScene.instantiate()
	dummy.respawn_seconds = 0.2
	t.root.add_child(dummy)
	var health: Node = dummy.get_node(^"Health")
	health.kill()
	await t.process_frame
	t.root.remove_child(dummy)
	await t.create_timer(0.3).timeout
	t.check(is_instance_valid(dummy), "respawn: detached dummy is untouched by the timer")
	t.check(health.hp <= 0.0, "respawn: no refill off the tree")
	t.check(not dummy.visible, "respawn: stays hidden off the tree")
	dummy.free()

## hp_label.attach: one centered Label above the parent, bound live.
func test_hp_label_attach_binds_live() -> void:
	var host := Node2D.new()
	var health: Node = HealthScript.new()
	health.name = "Health"
	health.max_hp = 80.0
	host.add_child(health)
	t.root.add_child(host)
	var label: Label = HpLabel.attach(host, health, -70.0)
	t.check(label != null and label.get_parent() == host, "label: attached under the parent")
	var labels := 0
	for child in host.get_children():
		if child is Label:
			labels += 1
	t.check(labels == 1, "label: exactly one Label created")
	t.check(label.text == "80", "label: reads the current hp")
	t.check(is_equal_approx(label.offset_top, -70.0), "label: offset_top = y")
	t.check(label.grow_horizontal == Control.GROW_DIRECTION_BOTH
		and is_zero_approx(label.offset_left) and is_zero_approx(label.offset_right),
		"label: centered on the parent origin")
	health.take_damage(12.5)
	t.check(label.text == "68", "label: updates after take_damage (roundi 67.5)")
	label.refresh()
	t.check(label.text == "68", "label: refresh is idempotent")
	_drop(host)

## victory_lap_driver: an untouched instance parades at LAP_THROTTLE; a set
## throttle (0 included) wins per instance without touching the static.
func test_lap_driver_per_instance_throttle() -> void:
	var car: Node = VehicleScene.instantiate()
	car.faction = &"enemies"  # never shadow player-group lookups
	t.root.add_child(car)
	var ring := PackedVector2Array([Vector2(10000, 0), Vector2(10000, 10000)])
	var stock: Node = LapDriver.new()
	stock.set_loop(ring)
	var intent: Dictionary = stock.get_intent(car, 1.0 / 60.0)
	t.check(is_equal_approx(float(intent.get("throttle", -9.0)), LapDriver.LAP_THROTTLE),
		"lap: untouched instance reports LAP_THROTTLE")
	var tuned: Node = LapDriver.new()
	tuned.throttle = 0.45
	tuned.set_loop(ring)
	intent = tuned.get_intent(car, 1.0 / 60.0)
	t.check(is_equal_approx(float(intent.get("throttle", -9.0)), 0.45),
		"lap: throttle = 0.45 reports 0.45")
	var parked: Node = LapDriver.new()
	parked.throttle = 0.0
	parked.set_loop(ring)
	intent = parked.get_intent(car, 1.0 / 60.0)
	t.check(is_zero_approx(float(intent.get("throttle", -9.0))), "lap: throttle = 0 is honored, not LAP_THROTTLE")
	t.check(is_equal_approx(LapDriver.LAP_THROTTLE, 0.8), "lap: the static is untouched")
	t.check(is_equal_approx(stock.throttle, -1.0), "lap: the default is negative (use the static)")
	stock.free()
	tuned.free()
	parked.free()
	_drop(car)

## exit_confirm: the Driver's Ed caption by default, any caption on request;
## the tree is handed back unpaused.
func test_exit_confirm_prompt() -> void:
	var confirm: CanvasLayer = ConfirmScript.new()
	t.root.add_child(confirm)
	t.check(t.paused, "confirm: freezes the tree")
	var caption := _first_label(confirm)
	t.check(caption != null and caption.text == "LEAVE DRIVER'S ED?", "confirm: default caption")
	t.check(confirm._index == 1, "confirm: KEEP PRACTICING is the default")
	t.paused = false
	_drop(confirm)

	var custom: CanvasLayer = ConfirmScript.new()
	custom.prompt = "X"
	t.root.add_child(custom)
	caption = _first_label(custom)
	t.check(caption != null and caption.text == "X", "confirm: prompt set before add_child shows")
	t.paused = false
	_drop(custom)
	t.check(not t.paused, "confirm: tree released unpaused")

# ---------------------------------------------------------------- card G-2

## target_vehicle.tscn: the enemy-scene shape with the targets faction, the
## lap driver seated, the camera dark, and no stats baked (the lane's job).
func test_target_vehicle_scene_shape() -> void:
	var car: Node = TargetScene.instantiate()
	t.check(car.faction == &"targets", "target scene: faction is targets")
	var drv: Script = car.get_node(^"Driver").get_script()
	t.check(drv != null and drv.resource_path.ends_with("victory_lap_driver.gd"),
		"target scene: Driver runs victory_lap_driver.gd")
	t.check(not (car.get_node(^"Camera2D") as Camera2D).enabled, "target scene: Camera2D disabled")
	t.check(car.stats == null, "target scene: no stats authored — the lane supplies them")
	t.check(car.get_script() == VehicleScript, "target scene: root script is vehicle.gd")
	car.free()

## A parked lane (no markers): one car on the lane's own transform, the
## lane's child, in targets + vehicles and nowhere hostile, labelled, idle;
## death frees it and the lane hands over a NEW instance after the delay.
func test_parked_lane_spawns_and_respawns() -> void:
	var lane: Node2D = LaneScript.new()
	lane.car_id = &"ghost"
	lane.respawn_seconds = 0.05
	lane.position = Vector2(-560, 760)
	t.root.add_child(lane)
	var cars := _cars(lane)
	t.check(cars.size() == 1, "parked lane: exactly one Vehicle child on boot")
	if cars.is_empty():
		_drop(lane)
		return
	var car: Node2D = cars[0]
	t.check(car.get_parent() == lane, "parked lane: the car is the LANE's child")
	t.check(lane.target() == car, "parked lane: target() is the live car")
	t.check(car.is_in_group(&"targets"), "parked lane: car in targets")
	t.check(car.is_in_group(&"vehicles"), "parked lane: car in vehicles")
	t.check(not car.is_in_group(&"enemies"), "parked lane: car NOT in enemies")
	t.check(not car.is_in_group(&"player"), "parked lane: car NOT in player")
	t.check(car.stats != null and car.stats.id == &"ghost", "parked lane: stats.id == ghost")
	t.check(car.global_position.is_equal_approx(lane.global_position),
		"parked lane: car sits on the lane's transform")
	t.check(is_zero_approx(car.rotation), "parked lane: root rotation stays 0 (heading is separate)")
	var health: Node = car.get_node(^"Health")
	var labels := _labels(car)
	t.check(labels.size() == 1, "parked lane: exactly one Label child")
	t.check(not labels.is_empty() and (labels[0] as Label).text == "%d" % roundi(health.max_hp),
		"parked lane: label reads the car's max hp")
	t.check(not labels.is_empty() and is_equal_approx((labels[0] as Label).offset_top, -70.0),
		"parked lane: label at the default label_y")
	var driver: Node = car.get_driver()
	t.check(driver.get_script() == LapDriver, "parked lane: the seated driver is the lap driver")
	t.check(is_equal_approx(driver.throttle, 0.6), "parked lane: driver.throttle = lane default 0.6")
	var intent: Dictionary = driver.get_intent(car, 1.0 / 60.0)
	t.check(is_zero_approx(float(intent.get("throttle", -9.0))),
		"parked lane: no loop → get_intent throttle 0 (parked)")
	await t.process_frame
	t.check(_cars(lane).size() == 1, "parked lane: still one car after a frame")
	var first_id := car.get_instance_id()
	health.kill()
	await t.process_frame
	await t.process_frame
	t.check(not is_instance_valid(car), "parked lane: the dead car frees itself")
	t.check(_cars(lane).is_empty(), "parked lane: no live car during the delay")
	t.check(lane.target() == null, "parked lane: target() is null during the delay")
	await t.create_timer(0.1).timeout
	await t.process_frame
	cars = _cars(lane)
	t.check(cars.size() == 1, "parked lane: exactly one Vehicle child after the respawn")
	if not cars.is_empty():
		var fresh: Node2D = cars[0]
		t.check(fresh.get_instance_id() != first_id, "parked lane: the respawn is a NEW instance")
		t.check(fresh.get_parent() == lane, "parked lane: the respawn is the lane's child")
		t.check(lane.target() == fresh, "parked lane: target() is the respawned car")
		t.check(fresh.is_in_group(&"targets") and fresh.is_in_group(&"vehicles"),
			"parked lane: respawn in targets + vehicles")
		t.check(not fresh.is_in_group(&"enemies"), "parked lane: respawn NOT in enemies")
		t.check(fresh.stats != null and fresh.stats.id == &"ghost", "parked lane: respawn keeps the car id")
		var fhealth: Node = fresh.get_node(^"Health")
		t.check(fhealth.hp > 0.0 and is_equal_approx(fhealth.hp, fhealth.max_hp),
			"parked lane: respawn at full hp")
		t.check(_labels(fresh).size() == 1, "parked lane: respawn carries its own label")
	_drop(lane)

## A parked car faces `facing_deg` through its OWN rotation (seated as the
## heading by Vehicle._ready, root rotation zeroed) — never through a rotated
## lane, which vehicle.gd could not see.
func test_parked_lane_facing_is_the_heading() -> void:
	var lane: Node2D = LaneScript.new()
	lane.car_id = &"warpig"
	lane.facing_deg = 180.0
	lane.position = Vector2(560, 760)
	t.root.add_child(lane)
	t.check(is_zero_approx(lane.rotation), "facing: the lane itself stays unrotated")
	var cars := _cars(lane)
	t.check(cars.size() == 1, "facing: one car spawned")
	if cars.is_empty():
		_drop(lane)
		return
	var car: Node2D = cars[0]
	t.check(absf(angle_difference(car.heading, PI)) < 0.001, "facing: facing_deg 180 → heading PI")
	t.check(is_zero_approx(car.rotation), "facing: root rotation handed to heading (0)")
	t.check(is_zero_approx(car.global_rotation), "facing: no inherited rotation under the Vehicle root")
	t.check(car.global_position.is_equal_approx(lane.global_position), "facing: still parked on the lane origin")
	_drop(lane)
	var east: Node2D = LaneScript.new()
	east.car_id = &"warpig"
	t.root.add_child(east)
	cars = _cars(east)
	t.check(cars.size() == 1 and is_zero_approx((cars[0] as Node2D).heading),
		"facing: default facing_deg 0 → heading 0")
	_drop(east)

## A loop lane: GLOBAL marker positions, spawn at marker[0] facing marker[1],
## the authored throttle on the pedal, the ring painted from the same points.
func test_loop_lane_spawns_at_first_marker() -> void:
	var lane: Node2D = LaneScript.new()
	lane.car_id = &"hammertoe"
	lane.throttle = 0.9
	lane.position = Vector2(960, -200)
	var offsets: Array[Vector2] = [Vector2(0, -800), Vector2(260, -400), Vector2(260, 400),
		Vector2(0, 800), Vector2(-260, 400), Vector2(-260, -400)]
	for off in offsets:
		var m := Marker2D.new()
		m.position = off
		lane.add_child(m)
	t.root.add_child(lane)
	var cars := _cars(lane)
	t.check(cars.size() == 1, "loop lane: exactly one Vehicle child")
	if cars.is_empty():
		_drop(lane)
		return
	var car: Node2D = cars[0]
	var m0: Marker2D = lane.get_child(0)
	var m1: Marker2D = lane.get_child(1)
	t.check(car.get_parent() == lane, "loop lane: the car is the lane's child")
	t.check(car.global_position.is_equal_approx(m0.global_position),
		"loop lane: spawns at marker[0]'s GLOBAL position")
	var want := (m1.global_position - m0.global_position).angle()
	t.check(absf(angle_difference(car.heading, want)) < 0.001, "loop lane: heading faces marker[1]")
	t.check(is_zero_approx(car.rotation), "loop lane: root rotation handed to heading")
	t.check(car.is_in_group(&"targets") and not car.is_in_group(&"enemies"),
		"loop lane: targets, never enemies")
	var driver: Node = car.get_driver()
	t.check(is_equal_approx(driver.throttle, 0.9), "loop lane: driver.throttle = 0.9")
	var intent: Dictionary = driver.get_intent(car, 1.0 / 60.0)
	t.check(is_equal_approx(float(intent.get("throttle", -9.0)), 0.9),
		"loop lane: get_intent reports 0.9 on the authored loop")
	var pts: PackedVector2Array = lane._points
	t.check(pts.size() == offsets.size(), "loop lane: every Marker2D collected")
	t.check(pts.size() > 2 and pts[2].is_equal_approx(lane.global_position + offsets[2]),
		"loop lane: points are GLOBAL positions")
	await t.process_frame
	t.check(_cars(lane).size() == 1, "loop lane: one car after a frame")
	t.check(lane.target() == car, "loop lane: target() is the live car")
	_drop(lane)

## No .tres for the id: push_error, nothing spawned, nothing to respawn.
func test_lane_without_stats_spawns_nothing() -> void:
	var lane: Node2D = LaneScript.new()
	lane.car_id = &"no_such_car"
	t.root.add_child(lane)
	await t.process_frame
	t.check(_cars(lane).is_empty(), "missing stats: no car spawned")
	t.check(lane.target() == null, "missing stats: target() is null")
	t.check(lane.get_child_count() == 0, "missing stats: the lane stays empty")
	_drop(lane)

## target_reset: group props die into remains and come back whole through
## apply_arena_state after `delay`; a prop outside the group stays dead.
func test_target_reset_revives_group_props() -> void:
	var world := Node2D.new()
	var crate: Node = BlockScene.instantiate()
	crate.deco = &"crate"
	crate.size = Vector2(96, 96)
	crate.max_hp = 60.0
	crate.position = Vector2(0, -700)
	crate.add_to_group(&"gallery_reset")
	world.add_child(crate)
	var wreck: Node = DerelictScene.instantiate()
	wreck.position = Vector2(600, 320)
	wreck.add_to_group(&"gallery_reset")
	world.add_child(wreck)
	var bystander: Node = BlockScene.instantiate()  # NOT in the group
	bystander.deco = &"barrel"
	bystander.max_hp = 30.0
	bystander.position = Vector2(-640, 60)
	world.add_child(bystander)
	var reset: Node = ResetScript.new()
	reset.delay = 0.05
	world.add_child(reset)
	t.root.add_child(world)
	t.check(reset.watch_group == &"gallery_reset", "reset: default group is gallery_reset")
	await t.process_frame  # deferred collection
	for prop in [crate, wreck, bystander]:
		prop.get_node(^"Health").kill()
	await t.process_frame
	await t.process_frame
	t.check(is_instance_valid(crate) and is_instance_valid(wreck), "reset: props survive death as remains")
	t.check(crate.collision_layer == 0 and wreck.collision_layer == 0,
		"reset: props are collisionless remains during the delay")
	t.check((int(crate.capture_arena_state([])["flags"]) & 1) == 0, "reset: crate reads dead during the delay")
	t.check((int(wreck.capture_arena_state([])["flags"]) & 1) == 0, "reset: wreck reads dead during the delay")
	await t.create_timer(0.1).timeout
	await t.process_frame
	t.check(crate.collision_layer != 0, "reset: crate collision restored")
	t.check((int(crate.capture_arena_state([])["flags"]) & 1) != 0, "reset: crate reads alive")
	t.check(is_equal_approx(crate.get_node(^"Health").hp, 60.0), "reset: crate hp refilled")
	t.check(crate.visible, "reset: crate visible")
	t.check(wreck.collision_layer != 0, "reset: wreck collision restored")
	t.check((int(wreck.capture_arena_state([])["flags"]) & 1) != 0, "reset: wreck reads alive")
	t.check(is_equal_approx(wreck.get_node(^"Health").hp, 50.0), "reset: wreck hp refilled")
	t.check(bystander.collision_layer == 0
		and (int(bystander.capture_arena_state([])["flags"]) & 1) == 0,
		"reset: a prop outside the group stays dead")
	_drop(world)

## gallery_deco: paint only — defaults per the card, no collision, no children.
func test_gallery_deco_range_tick_is_paint_only() -> void:
	var deco: Node2D = DecoScript.new()
	deco.text = "400"
	t.root.add_child(deco)
	await t.process_frame
	t.check(deco.kind == &"range_tick", "deco: range_tick is the default kind")
	t.check(deco.size == Vector2(896, 8), "deco: default size 896x8")
	t.check(deco.text == "400", "deco: text export holds the distance")
	t.check(not (deco is CollisionObject2D) and deco.get_child_count() == 0,
		"deco: paint only — no collision body, no children")
	_drop(deco)

# ---------------------------------------------------------------- card G-3

## Structural locks on the yard scene itself — instantiated, never tree-
## entered (no physics, no _ready side effects), freed after inspection.
const SCENE := "res://levels/gallery/shooting_gallery.tscn"

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

func _script_path(n: Node) -> String:
	var sc: Script = n.get_script() as Script
	return sc.resource_path if sc else ""

## The combat_level shell with a player, the HUD, and nothing hostile: zero
## Enemy* children, no FloorZone (flat yard), no GoliathLoop for the lap
## driver's sibling scan to stumble on, the tunnel open (no ExitGate) with
## the ExitZone listening for cars.
func test_scene_shell_structure() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var player: Node = scene.get_node_or_null("Vehicle")
	t.check(player != null, "gallery: has a Vehicle spawn")
	t.check(scene.get_node_or_null("HUD") != null, "gallery: bakes the HUD")
	var n := scene.get_child_count()
	t.check(n >= 2 and scene.get_child(n - 2).name == "Vehicle" and scene.get_child(n - 1).name == "HUD",
		"gallery: the last two children are Vehicle then HUD")
	if player != null:
		t.check((player as Node2D).position.is_equal_approx(Vector2(0, 1000)), "gallery: player spawns at (0, 1000)")
		t.check(absf(angle_difference((player as Node2D).rotation, -PI * 0.5)) < 0.001,
			"gallery: player authored facing north")
	var enemies := 0
	for child in scene.get_children():
		if String(child.name).begins_with("Enemy"):
			enemies += 1
	t.check(enemies == 0, "gallery: bakes zero enemies")
	var script: Script = scene.get_script()
	t.check(script != null and String(script.get(&"EXIT_PROMPT")) == "LEAVE THE GALLERY?",
		"gallery: the exit prompt asks about the gallery")
	var reaches_shell := false
	while script != null:
		if script.resource_path == "res://levels/combat_level.gd":
			reaches_shell = true
			break
		script = script.get_base_script()
	t.check(reaches_shell, "gallery: root extends combat_level.gd")
	var nodes: Array = []
	_walk(scene, nodes)
	var floor_zones := 0
	var loops := 0
	for node in nodes:
		if _script_path(node).ends_with("floor_zone.gd") or String(node.scene_file_path).ends_with("floor_zone.tscn"):
			floor_zones += 1
		if node.name == "GoliathLoop":
			loops += 1
	t.check(floor_zones == 0, "gallery: no FloorZone anywhere (flat yard)")
	t.check(loops == 0, "gallery: no GoliathLoop node for the lap driver to adopt")
	var zone: Node = scene.get_node_or_null("ExitZone")
	t.check(zone is Area2D and zone.collision_mask == 1, "gallery: ExitZone listens for cars")
	t.check(scene.get_node_or_null("ExitGate") == null, "gallery: no ExitGate — the tunnel is always open")
	for deco_name in ["TunnelDeco", "ExitText", "ExitSign", "Helipad"]:
		t.check(scene.get_node_or_null(deco_name) != null, "gallery: has %s" % deco_name)
	scene.free()

func test_scene_boundary_segments() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var boundary: Node = scene.get_node_or_null("Boundary")
	t.check(boundary is StaticBody2D and boundary.collision_layer == 2, "gallery: Boundary rides the wall layer")
	if boundary != null:
		for wall_name in ["SouthCol", "WestCol", "EastCol", "NorthWCol", "NorthECol", "JambWCol", "JambECol", "CapCol"]:
			t.check(boundary.get_node_or_null(wall_name) != null, "gallery: Boundary has %s" % wall_name)
	scene.free()

## Every dummy comes back: four or more, all respawning.
func test_scene_dummies_respawn() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var dummies := 0
	for child in scene.get_children():
		if _script_path(child).ends_with("target_dummy.gd"):
			dummies += 1
			t.check(float(child.respawn_seconds) > 0.0, "gallery: %s respawns" % child.name)
	t.check(dummies >= 4, "gallery: fields %d dummies (>=4)" % dummies)
	scene.free()

## The yardage painted on each tick IS its distance from the firing line.
func test_scene_range_ticks_measure_from_firing_line() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var ticks := 0
	for child in scene.get_children():
		if not String(child.name).begins_with("Tick"):
			continue
		ticks += 1
		t.check(child.get_script() == DecoScript and child.kind == &"range_tick",
			"gallery: %s is a range_tick" % child.name)
		var want := str(roundi(absf((child as Node2D).position.y - 700.0)))
		t.check(String(child.text) == want, "gallery: %s reads %s (text '%s')" % [child.name, want, child.text])
	t.check(ticks >= 3, "gallery: %d range ticks (>=3)" % ticks)
	scene.free()

## Exactly four lanes: two ovals with their markers, two parked, four distinct
## real roster cars, every lane unrotated with a pedal in (0, 1].
func test_scene_lanes() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var lanes: Array = []
	for child in scene.get_children():
		if child.get_script() == LaneScript:
			lanes.append(child)
	t.check(lanes.size() == 4, "gallery: exactly 4 target lanes (%d)" % lanes.size())
	var ids := {}
	var looped := 0
	var parked := 0
	for lane in lanes:
		ids[lane.car_id] = true
		t.check(ResourceLoader.exists("res://data/vehicles/%s.tres" % lane.car_id),
			"gallery: %s car '%s' has stats" % [lane.name, lane.car_id])
		t.check(is_zero_approx((lane as Node2D).rotation), "gallery: %s authored unrotated" % lane.name)
		t.check(float(lane.throttle) > 0.0 and float(lane.throttle) <= 1.0,
			"gallery: %s throttle in (0, 1]" % lane.name)
		t.check(float(lane.respawn_seconds) > 0.0, "gallery: %s respawns" % lane.name)
		var markers := 0
		for m in lane.get_children():
			if m is Marker2D:
				markers += 1
		if markers >= 6:
			looped += 1
		elif markers == 0:
			parked += 1
		else:
			t.check(false, "gallery: %s has %d markers — neither a loop nor parked" % [lane.name, markers])
	t.check(ids.size() == 4, "gallery: lane car ids are distinct (%d)" % ids.size())
	t.check(looped == 2, "gallery: exactly 2 loop lanes (%d)" % looped)
	t.check(parked == 2, "gallery: exactly 2 parked lanes (%d)" % parked)
	var east: Node = scene.get_node_or_null("LaneParkE")
	var west: Node = scene.get_node_or_null("LaneParkW")
	t.check(east != null and is_equal_approx(float(east.facing_deg), 180.0), "gallery: LaneParkE faces west (180)")
	t.check(west != null and is_zero_approx(float(west.facing_deg)), "gallery: LaneParkW faces east (0)")
	scene.free()

## The cover comes back through target_reset: a barrel chain and a wreck row
## in the group, every block carrying a deco (the plain slab never shows).
func test_scene_reset_group_and_decos() -> void:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var barrels := 0
	var wrecks := 0
	var blocks := 0
	var reset := 0
	for child in scene.get_children():
		var path := _script_path(child)
		if child.get_script() == ResetScript:
			reset += 1
		if path.ends_with("destructible_block.gd"):
			blocks += 1
			t.check(String(child.deco) != "", "gallery: %s has a deco" % child.name)
			if child.deco == &"barrel" and child.is_in_group(&"gallery_reset"):
				barrels += 1
		elif path.ends_with("derelict_car.gd") and child.is_in_group(&"gallery_reset"):
			wrecks += 1
			# The wreck row lives in the alley between the tick bars (end x 448)
			# and LaneSlow's west leg (x 700): ≥ 40 px past the bars, ≥ 100 px
			# body-edge clearance to the loop line, or the lapping heavy rams
			# a wreck every circuit and the bench reads as noise.
			var wx: float = (child as Node2D).position.x
			t.check(wx >= 448.0 + 40.0 and wx <= 700.0 - 100.0,
				"gallery: %s x %.0f sits in the wreck alley [488, 600]" % [child.name, wx])
	t.check(reset == 1, "gallery: one TargetReset node")
	t.check(blocks >= 5, "gallery: %d destructible blocks (>=5, the cover wall)" % blocks)
	t.check(barrels >= 3, "gallery: %d barrels in gallery_reset (>=3)" % barrels)
	t.check(wrecks >= 3, "gallery: %d derelicts in gallery_reset (>=3)" % wrecks)
	scene.free()
