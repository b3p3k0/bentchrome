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
		director.loop_set(event, false)
	director.play(&"not_even_a_real_event")
	t.check(true, "sfx: full catalog no-ops cleanly with zero assets")
	t.root.remove_child(director)
	director.free()
