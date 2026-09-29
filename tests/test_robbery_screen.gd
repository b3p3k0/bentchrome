extends RefCounted
## The robbery card (ui/robbery_screen.gd) and its wheel (ui/robbery_wheel.gd):
## the wheel's landing math, the three beats (wheel -> verdict -> splash),
## the input lock, the art fallback ladder, and `finished` firing exactly
## once. The screen pauses the tree on open — every test releases it.

const ScreenScript := preload("res://ui/robbery_screen.gd")
const WheelScript := preload("res://ui/robbery_wheel.gd")
const Robbery := preload("res://game/robbery.gd")

var t

func _init(runner) -> void:
	t = runner

func _outcome() -> Dictionary:
	return {"kind": Robbery.Kind.BOLTS, "bolts": 1000, "part": "",
		"headline": "THEY TOOK YOUR BOLTS", "detail": "-1000 of 4000 bolts"}

func _screen() -> Node:
	var screen = ScreenScript.new()
	t.root.add_child(screen)
	return screen

func _done(screen: Node) -> void:
	t.paused = false
	t.root.remove_child(screen)
	screen.free()

func test_wheel_lands_on_the_rolled_wedge() -> void:
	const COUNT := 10
	for index in COUNT:
		var angle: float = WheelScript.landing_angle(index, COUNT, WheelScript.SPIN_TURNS)
		t.check(WheelScript.wedge_under_pointer(angle, COUNT) == index,
			"wheel: the landing angle parks wedge %d under the pointer" % index)
	t.check(WheelScript.wedge_under_pointer(0.0, COUNT) == 0, "wheel: at rest, wedge 0 starts at the pointer")
	t.check(WheelScript.wedge_under_pointer(0.0, 0) == -1, "wheel: no wedges, nothing under the pointer")
	var wheel = WheelScript.new()
	t.root.add_child(wheel)
	var hits: Array = []
	wheel.landed.connect(func(i: int) -> void: hits.append(i))
	wheel.setup(Robbery.WHEEL, 6)
	wheel.finish_now()
	wheel.finish_now()
	t.check(hits == [6], "wheel: lands once, on the wedge it was given (%s)" % str(hits))
	t.check(WheelScript.wedge_under_pointer(wheel.spin_angle, Robbery.WHEEL.size()) == 6,
		"wheel: and the paint agrees")
	wheel.spin()
	t.check(not wheel.is_spinning(), "wheel: a landed wheel doesn't spin again")
	t.root.remove_child(wheel)
	wheel.free()

func test_three_beats_one_exit() -> void:
	var screen = _screen()
	var exits: Array = []
	screen.finished.connect(func() -> void: exits.append(true))
	screen.open(&"caught", _outcome(), Robbery.WHEEL, 0, "hornet")
	t.check(t.paused, "card: the world freezes")
	t.check(screen.stage == ScreenScript.Stage.WHEEL, "card: opens on the wheel")
	t.check(not screen.is_armed(), "card: input is locked on arrival — combat fire mustn't skip it")
	t.check(screen.get_node_or_null(^"Panel") != null, "card: the panel is up")
	var headline := screen.find_child("Headline", true, false) as Label
	t.check(headline != null and headline.text.strip_edges() == "", "card: the verdict is hidden while the wheel turns")
	# Beat 1 -> 2: stopping the wheel lands it and reads the verdict.
	screen.advance()
	t.check(screen.stage == ScreenScript.Stage.VERDICT, "card: the wheel lands into the verdict")
	t.check(headline.text == "THEY TOOK YOUR BOLTS", "card: the verdict says what they took")
	t.check(not screen.is_armed(), "card: each beat re-locks input")
	# Beat 2 -> 3: hornet has a bio portrait, so there is always SOMETHING to show.
	t.check(ScreenScript.art_path("hornet") != "", "card: a roster car always has a picture to fall back on")
	screen.advance()
	t.check(screen.stage == ScreenScript.Stage.SPLASH, "card: the verdict gives way to the splash")
	t.check(screen.get_node_or_null(^"Splash") != null, "card: the splash card is up")
	t.check(exits.is_empty(), "card: nothing has rolled on yet")
	# Beat 3 -> out.
	screen.advance()
	screen.advance()
	screen.roll_on()
	t.check(exits.size() == 1, "card: finished fires exactly once (%d)" % exits.size())
	t.check(screen.stage == ScreenScript.Stage.DONE, "card: and the card is done")
	_done(screen)

func test_no_picture_no_splash() -> void:
	var screen = _screen()
	var exits: Array = []
	screen.finished.connect(func() -> void: exits.append(true))
	t.check(ScreenScript.art_path("") == ScreenScript.art_path("no_such_car"),
		"art: an unknown car and no car fall to the same rung")
	screen.open(&"wrecked", _outcome(), [], -1, "no_such_car")
	t.check(screen.stage == ScreenScript.Stage.VERDICT, "card: no wheel = straight to the verdict")
	var cause := screen.find_child("Cause", true, false) as Label
	t.check(cause != null and cause.text == ScreenScript.CAUSE_LINES[&"wrecked"], "card: the cause line matches the cause")
	screen.advance()
	if ScreenScript.art_path("no_such_car") == "":
		t.check(exits.size() == 1, "card: no art anywhere = the verdict rolls straight on")
	else:
		t.check(screen.stage == ScreenScript.Stage.SPLASH, "card: the generic card stands in")
		screen.advance()
		t.check(exits.size() == 1, "card: and then it rolls on")
	_done(screen)

func test_input_lock_then_any_key() -> void:
	var screen = _screen()
	var exits: Array = []
	screen.finished.connect(func() -> void: exits.append(true))
	screen.open(&"caught", _outcome(), [], -1, "")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	screen._unhandled_input(key)
	t.check(screen.stage == ScreenScript.Stage.VERDICT and exits.is_empty(),
		"card: a key inside the lock does nothing")
	var waited := 0
	while not screen.is_armed() and waited < 200:
		await t.process_frame
		waited += 1
	t.check(screen.is_armed(), "card: the lock lifts on its own, through the pause")
	var hint := screen.find_child("Hint", true, false) as Label
	t.check(hint != null and hint.text != "...", "card: the hint wakes up with it")
	var release := InputEventKey.new()
	release.pressed = false
	release.keycode = KEY_SPACE
	screen._unhandled_input(release)
	t.check(screen.stage == ScreenScript.Stage.VERDICT, "card: a key RELEASE is not a press")
	screen._unhandled_input(key)
	t.check(screen.stage != ScreenScript.Stage.VERDICT, "card: any key moves the beat on")
	_done(screen)
