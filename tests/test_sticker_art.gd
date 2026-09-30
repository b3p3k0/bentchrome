extends RefCounted
## The bumper-sticker drop-in folder (assets/img/stickers/): every file is named
## for a real catalog sticker, every shipped file is the 768x256 cutout the
## pipeline makes, and the brief tool covers exactly the catalog. The folder may
## be partial; art is a drop-in, never a requirement (ui/sticker_paint.gd paints
## a stand-in). Spelling is a human review (docs/art_briefs/bumper_stickers.md).

const CATALOG := "res://assets/data/stickers.json"
const ART_DIR := "res://assets/img/stickers"
const BRIEF_TOOL := "res://tools/sticker_brief.py"

var t

func _init(runner) -> void:
	t = runner

func _catalog_ids() -> Array:
	var json := JSON.new()
	var ids: Array = []
	if json.parse(FileAccess.get_file_as_string(CATALOG)) == OK and json.data is Dictionary:
		for row in json.data.get("stickers", []):
			ids.append(String(row.get("id", "")))
	return ids

func test_art_is_named_for_real_stickers() -> void:
	var ids := _catalog_ids()
	t.check(ids.size() >= 20, "sticker art: the catalog loads (%d stickers)" % ids.size())
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		t.check(true, "sticker art: no art folder yet — every sticker paints its stand-in")
		return
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var stem := file.get_basename()
		t.check(stem in ids, "sticker art: %s is a catalog sticker's art" % file)
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [ART_DIR, file]))
		t.check(img != null and img.get_width() == 768 and img.get_height() == 256,
			"sticker art: %s is the 768x256 cutout" % file)

## Every catalog id has a brief, and the brief's exact slogan IS the catalog
## name upper-cased — the lettering the review reads letter by letter.
func test_brief_tool_covers_the_catalog() -> void:
	var src := FileAccess.get_file_as_string(BRIEF_TOOL)
	t.check(src != "", "sticker art: the brief tool exists")
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(CATALOG))
	for row in json.data.get("stickers", []):
		var id := String(row.get("id", ""))
		var slogan := String(row.get("name", "")).to_upper()
		t.check(src.contains('"%s": (\n        "%s",' % [id, slogan]),
			"sticker art: brief for %s carries the slogan \"%s\"" % [id, slogan])
