extends RefCounted
## The jacked-card drop-in folder (assets/img/jacked/): every card is named
## for a real roster car (or is the shared _generic card), and every roster
## car always has SOMETHING to show — its own card or its bio portrait. The
## folder may be empty; art is a drop-in, never a requirement. Likeness is a
## human review (docs/art_briefs/jacked_cards.md) — this only lints names.

const ScreenScript := preload("res://ui/robbery_screen.gd")
const ROSTER := "res://assets/data/roster.json"

var t

func _init(runner) -> void:
	t = runner

func _roster_ids() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER))
	var ids: Array = []
	if typeof(data) == TYPE_DICTIONARY:
		for entry in data.get("characters", []):
			ids.append(String(entry.get("id", "")))
	return ids

func test_cards_are_named_for_real_cars() -> void:
	var ids := _roster_ids()
	t.check(ids.size() >= 14, "jacked: the roster loads (%d cars)" % ids.size())
	var dir := DirAccess.open(ScreenScript.ART_DIR)
	if dir == null:
		t.check(true, "jacked: no art folder yet — every car rides its portrait")
		return
	var cards := 0
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		cards += 1
		var stem := file.get_basename()
		t.check(stem in ids or stem == ScreenScript.GENERIC_ART,
			"jacked: %s is a roster car's card (or the generic one)" % file)
	t.check(cards >= 0, "jacked: %d card(s) in the folder" % cards)

func test_every_car_has_something_to_show() -> void:
	for id in _roster_ids():
		var path: String = ScreenScript.art_path(id)
		t.check(path != "", "jacked: %s has a splash (%s)" % [id, path.get_file()])
		var own := "%s/%s.png" % [ScreenScript.ART_DIR, id]
		if ResourceLoader.exists(own) or FileAccess.file_exists(own):
			t.check(path == own, "jacked: %s's own card outranks every fallback" % id)

func test_the_ladder_bottoms_out_quietly() -> void:
	var generic := "%s/%s.png" % [ScreenScript.ART_DIR, ScreenScript.GENERIC_ART]
	var has_generic: bool = ResourceLoader.exists(generic) or FileAccess.file_exists(generic)
	var path: String = ScreenScript.art_path("definitely_not_a_car")
	t.check(path == (generic if has_generic else ""),
		"jacked: an unknown car gets the generic card or nothing — never an error")
