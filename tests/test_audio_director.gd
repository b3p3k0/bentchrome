extends RefCounted
## AudioDirector's never-crash contract: with ZERO assets present, every
## catalog event must play/loop as a silent no-op — missing sound files can
## never take the game down. (Asset-present behavior is HI-verified by ear.)

const DirectorScript := preload("res://game/audio_director.gd")

var t

func _init(runner) -> void:
	t = runner

func test_zero_assets_never_crash() -> void:
	var director = DirectorScript.new()
	t.root.add_child(director)  # _ready resolves the catalog (all absent = fine)
	for event in DirectorScript.CATALOG:
		director.play(event)
		director.play_at(event, Vector2(100, 100))
		director.loop_set(event, true)
		director.loop_gain(event, 0.5)
		director.loop_set(event, false)
	director.play(&"not_even_a_real_event")
	director.loop_gain(&"not_even_a_real_event", 0.5)
	director.loop_gain(&"horde_roar", -3.0)   # out-of-range gains clamp, never crash
	director.loop_gain(&"horde_roar", 99.0)
	for event in [&"horde_roar", &"horde_horn", &"jacked"]:
		t.check(DirectorScript.CATALOG.has(event), "sfx: Route 666's %s is catalogued" % event)
	t.check(DirectorScript.CATALOG[&"horde_roar"].get("loop", false), "sfx: the horde's engines are a loop")
	t.check(DirectorScript.UI_EVENTS.has(&"jacked"),
		"sfx: the robbery sting rides the pause-immune pool (the card freezes the tree)")
	t.check(DirectorScript.CATALOG.has(&"sticker_earned")
		and is_equal_approx(float(DirectorScript.CATALOG[&"sticker_earned"].volume_db), -2.0)
		and is_zero_approx(float(DirectorScript.CATALOG[&"sticker_earned"].pitch_jitter)),
		"sfx: sticker earned is catalogued at -2 dB with no pitch jitter")
	t.check(DirectorScript.UI_EVENTS.has(&"sticker_earned"),
		"sfx: sticker earned rides the pause-immune pool")
	for event in [&"shop_enter", &"shop_buy", &"shop_deny", &"shop_hum"]:
		t.check(DirectorScript.CATALOG.has(event) and DirectorScript.UI_EVENTS.has(event),
			"sfx: Slo Mo's %s is catalogued and pause-immune (the shop runs paused)" % event)
	t.check(DirectorScript.CATALOG[&"shop_hum"].get("loop", false), "sfx: the shop's room tone is a loop")
	t.check(true, "sfx: full catalog no-ops cleanly with zero assets")
	t.root.remove_child(director)
	director.free()
