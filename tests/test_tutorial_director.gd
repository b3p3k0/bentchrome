extends RefCounted
## Driver's Ed director: the lesson card gates input behind its arm timer and
## restores the pause state on dismissal; lessons advance in order off REAL
## input and physics (Input.action_press + frame pumping — the same seam the
## player uses); the test-drive boot skips the syllabus entirely. The vehicle
## fixture keeps its default "player" faction — the player IS the subject.
## Every path that pauses the tree unpauses before the test returns: a paused
## runner stalls every suite after this one.

const DirectorScript := preload("res://levels/tutorial/tutorial_director.gd")
const CardScript := preload("res://levels/tutorial/tutorial_card.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]

var t

func _init(runner) -> void:
	t = runner

func _key(node: Node) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	node._unhandled_input(ev)

func _dismiss(card: Node) -> void:
	card._arm()
	_key(card)

## Fixture world: bare plane, one real vehicle, one director wired to it and
## to a stub gate. begin() is the caller's — tests drive both boot modes.
func _world() -> Dictionary:
	var world := Node2D.new()
	var car: Node = VehicleScene.instantiate()
	world.add_child(car)
	var gate := StaticBody2D.new()
	gate.name = "ExitGate"
	gate.position = Vector2(4000, 0)  # OFF the spawn — a body on the car pins it
	gate.collision_layer = 2
	var col := CollisionShape2D.new()
	col.name = "Col"
	col.shape = RectangleShape2D.new()
	gate.add_child(col)
	world.add_child(gate)
	var director: Node = DirectorScript.new()
	director.player = car
	director.gate = gate
	world.add_child(director)
	t.root.add_child(world)
	return {"world": world, "car": car, "gate": gate, "director": director}

func _teardown(world: Node) -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	Input.action_release(&"handbrake")
	Input.action_release(&"boost")
	t.paused = false
	t.root.remove_child(world)
	world.free()

func test_card_arm_timer_and_dismiss() -> void:
	var card: CanvasLayer = CardScript.new()
	t.root.add_child(card)
	var dismissed := [0]
	card.dismissed.connect(func() -> void: dismissed[0] += 1)
	card.show_card("T", "B")
	t.check(card.visible, "card: shows")
	t.check(t.paused, "card: freezes the tree for the read")
	_key(card)
	t.check(card.visible and dismissed[0] == 0, "card: keys bounce off before the arm timer")
	_dismiss(card)
	t.check(not card.visible and dismissed[0] == 1, "card: armed key dismisses")
	t.check(not t.paused, "card: dismissal unfreezes the tree")
	t.root.remove_child(card)
	card.free()

func test_lessons_advance_in_order() -> void:
	var w := _world()
	var director: Node = w["director"]
	director.begin(true)
	t.check(director.lesson_index == 0, "flow: begins on lesson 1")
	t.check(director._card.visible and t.paused, "flow: lesson 1 card up, world frozen")
	_dismiss(director._card)
	t.check(String(director._hint_label.text).begins_with("LESSON 1"),
		"flow: hint line names the live objective")

	# Lesson 1 — hold all four move keys (axes cancel; the latch reads keys,
	# not motion) past HOLD_MOVE.
	for action in MOVE_ACTIONS:
		Input.action_press(action)
	for i in 30:
		await t.physics_frame
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	t.check(director.lesson_index == 1, "flow: WASD held -> lesson 2")
	t.check(director._card.visible, "flow: lesson 2 card up")
	_dismiss(director._card)

	# Lesson 2 — real driving in three phases: nitro launch, service brake
	# against genuine momentum, then the handbrake. Separate phases matter:
	# the controller defines service_braking as NOT-handbrake AND opposing
	# pedal, so a player riding both at once never latches the brake.
	Input.action_press(&"move_up")
	Input.action_press(&"boost")
	for i in 70:
		await t.physics_frame
	Input.action_release(&"move_up")
	Input.action_release(&"boost")
	Input.action_press(&"move_down")
	for i in 40:
		await t.physics_frame
	Input.action_release(&"move_down")
	Input.action_press(&"handbrake")
	for i in 25:
		await t.physics_frame
	Input.action_release(&"handbrake")
	t.check(director.lesson_index == 2,
		"flow: brake/handbrake/boost held -> lesson 3 (index %d)" % director.lesson_index)
	if director._card.visible:
		_dismiss(director._card)
	_teardown(w["world"])

## Lessons 3-4 drive the director's seams directly: heat is a poll, cycle and
## bay-fire ride real rack signals, the fender ding lands on the lesson-4
## card dismissal, and completion needs a crate AND a full hull.
func test_weapons_and_pickup_lessons() -> void:
	var w := _world()
	var director: Node = w["director"]
	var car: Node = w["car"]
	director.begin(true)
	_dismiss(director._card)
	# Jump the syllabus to lesson 3 — lessons 1-2 hold their own test above.
	director.lesson_index = 2
	director._latch.clear()
	director._on_card_dismissed()
	t.check(String(director._hint_label.text).begins_with("LESSON 3"),
		"weapons: hint follows the jump")

	var mount: Node = car.get_node("MachineGunMount")
	mount.heat = 8.0  # a burst just left
	var rack: Node = car.get_node("WeaponRack")
	rack.selection_changed.emit(1)
	var seen0: int = rack.ammo(0)
	rack.ammo_changed.emit(0, seen0 - 1)  # bay shot: ammo fell
	await t.physics_frame
	await t.physics_frame
	t.check(director.lesson_index == 3,
		"weapons: MG heat + cycle + bay shot -> lesson 4 (index %d)" % director.lesson_index)
	t.check(director._card.visible, "pickups: lesson 4 card up")

	var hp_before: float = car.get_hp()
	_dismiss(director._card)
	t.check(car.get_hp() < hp_before, "pickups: fender ding lands on dismissal")
	rack.ammo_changed.emit(1, rack.ammo(1) + 1)  # crate landed: ammo rose
	await t.physics_frame
	t.check(director.lesson_index == 3, "pickups: crate alone is not enough")
	var health: Node = car.get_node("Health")
	health.heal(9999.0)
	await t.physics_frame
	await t.physics_frame
	t.check(director.lesson_index == 4,
		"pickups: crate + full hull -> lesson 5 (index %d)" % director.lesson_index)
	if director._card.visible:
		_dismiss(director._card)
	_teardown(w["world"])

func test_test_drive_boots_precompleted() -> void:
	var w := _world()
	var director: Node = w["director"]
	director.begin(false)
	t.check(director.completed, "test drive: syllabus stamped complete")
	t.check(director.lesson_index == director.LESSONS.size(), "test drive: no live lesson")
	t.check(not director._card.visible, "test drive: no card shown")
	t.check(not t.paused, "test drive: world never freezes")
	t.check(not director._hint_label.visible, "test drive: no hint line")
	var gate: StaticBody2D = w["gate"]
	t.check(not gate.visible, "test drive: gate drops its paint")
	await t.physics_frame  # collision flip rides set_deferred
	var col: CollisionShape2D = gate.get_node("Col")
	t.check(col.disabled, "test drive: gate collision stands down")
	_teardown(w["world"])
