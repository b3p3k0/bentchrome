extends RefCounted
## Shooting gallery, card G-1 — the shared target pieces: the dummy's opt-in
## respawn (default still frees), the one HP label, the lap driver's
## per-instance throttle, and the reusable exit prompt. Tree-entered fixtures
## live under t.root, release the tree unpaused, and free every node.

const DummyScene := preload("res://environment/target_dummy.tscn")
const HpLabel := preload("res://environment/hp_label.gd")
const LapDriver := preload("res://vehicles/goliath/victory_lap_driver.gd")
const ConfirmScript := preload("res://levels/tutorial/exit_confirm.gd")
const HealthScript := preload("res://vehicles/health.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

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
