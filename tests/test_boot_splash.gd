extends RefCounted
## Boot sequence contracts: the satire copy is letter-exact and in order; the
## timeline stays inside the sting's length; a card without art builds its
## fallback without a load error; the any-key skip respects the input lock and
## key echo; the hand-off fires exactly once; headless runs and the BOOT INTRO
## setting both bypass the cards. The scene is load()ed at test
## time and built with autoplay/handoff OFF — the real scene swap stays
## untested here (house rule), the human launch covers it.

const MusicScript := preload("res://game/music_director.gd")

var t
var flow: Node

func _init(runner) -> void:
	t = runner
	flow = runner.root.get_node("/root/SceneFlow")

func _fresh() -> Control:
	var splash: Control = (load("res://ui/boot_splash.tscn") as PackedScene).instantiate()
	splash.autoplay = false
	splash.handoff = false
	t.root.add_child(splash)
	return splash

func _done(splash: Control) -> void:
	t.root.remove_child(splash)
	splash.free()

func _key(echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	ev.echo = echo
	return ev

func _copy(card: Dictionary) -> Array:
	var out: Array = []
	for line in card.lines:
		if String(line[0]) != "":
			out.append(String(line[0]))
	return out

func test_satire_copy_is_exact() -> void:
	var splash := _fresh()
	t.check(splash.CARDS.size() == 2, "boot: two cards")
	t.check(splash.CARDS[0].matte == Color.WHITE and splash.CARDS[1].matte == Color.BLACK,
		"boot: white publisher card plays before the black console card")
	t.check(_copy(splash.CARDS[0]) == ["FONY", "COMPUTER", "ENTERTAINMENT"],
		"boot: publisher card copy")
	t.check(_copy(splash.CARDS[1]) == ["FanStation", "not Licensed by Anyone", "IPACRAO"],
		"boot: console card copy — the acronym is never spelled out")
	_done(splash)

func test_timeline_fits_the_sting() -> void:
	var splash := _fresh()
	t.check(splash.TIMING.size() == splash.CARDS.size(), "boot: one timing row per card")
	var total: float = splash.total_duration()
	t.check(total >= 10.0 and total <= 18.0, "boot: unskipped run is 10-18s, got %.1f" % total)
	t.check(splash.INPUT_LOCK > 0.0 and splash.INPUT_LOCK < 1.5,
		"boot: input lock is a beat, not a wait")
	_done(splash)

func test_fallback_card_builds_without_art() -> void:
	var splash := _fresh()
	t.check(is_equal_approx(splash._curtain.modulate.a, 1.0), "boot: opens on black")
	for i in splash.CARDS.size():
		splash._show_card(i)
		var card: Dictionary = splash.CARDS[i]
		t.check(splash._index == i and splash._matte.color == card.matte,
			"boot: card %d sets its matte" % i)
		if splash._art_for(card) == null:
			t.check(splash._fallback.visible and not splash._art.visible,
				"boot: card %d falls back to text while art is absent" % i)
			t.check(splash._fallback.get_child_count() == card.lines.size(),
				"boot: card %d fallback carries every line" % i)
		else:
			t.check(splash._art.visible and not splash._fallback.visible,
				"boot: card %d shows its art" % i)
	_done(splash)

func test_skip_respects_lock_and_echo() -> void:
	var splash := _fresh()
	splash._unhandled_input(_key())
	t.check(not splash._skipping, "boot: a press inside the input lock is ignored")
	splash._arm()
	splash._unhandled_input(_key(true))
	t.check(not splash._skipping, "boot: key echo never skips")
	var release := _key()
	release.pressed = false
	splash._unhandled_input(release)
	t.check(not splash._skipping, "boot: a release never skips")
	splash._unhandled_input(_key())
	t.check(splash._skipping, "boot: an armed press skips")
	_done(splash)

func test_hand_off_fires_once() -> void:
	var splash := _fresh()
	var hits := [0]
	splash.finished.connect(func() -> void: hits[0] += 1)
	splash._arm()
	splash.skip()
	splash._finish()
	splash._finish()
	splash.skip()
	t.check(hits[0] == 1, "boot: finished emits exactly once")
	splash._unhandled_input(_key())
	t.check(hits[0] == 1, "boot: input after the hand-off is inert")
	_done(splash)

func test_bypass_gate() -> void:
	var splash := _fresh()
	t.check(not splash.wants_intro(true, true), "boot: headless runs skip straight to title")
	t.check(splash.wants_intro(false, true), "boot: a real launch plays the cards")
	t.check(not splash.wants_intro(false, false), "boot: BOOT INTRO off skips the cards")
	_done(splash)

func test_boot_intro_setting_defaults_on() -> void:
	var fresh: Node = (load("res://game/game_state.gd") as Script).new()
	t.check(fresh.boot_intro, "boot: fresh installs play the cards")
	t.check(fresh.SETTINGS_KEYS.has("boot_intro"), "boot: the toggle is a persisted setting")
	fresh.free()

func test_boot_scene_is_the_main_scene() -> void:
	t.check(String(ProjectSettings.get_setting("application/run/main_scene")) == flow.BOOT,
		"boot: the boot sequence is the main scene")
	t.check(ResourceLoader.exists(flow.BOOT), "boot: main scene exists")
	t.check(MusicScript.TRACKS.get(flow.BOOT) == MusicScript.SILENT,
		"boot: no menu music under the sting")
