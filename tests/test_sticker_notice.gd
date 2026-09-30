extends RefCounted
## Bumper-sticker break notice copy: count grammar, catalog names, and the
## forward-compatible raw-id fallback.

const StickerNotice := preload("res://ui/sticker_notice.gd")

var t


class CatalogStub extends Node:
	func ensure_catalog() -> void:
		pass

	func catalog() -> Array:
		return [
			{"id": "first", "name": "Road Rash"},
			{"id": "second", "name": "Chrome Dome"},
		]


func _init(runner) -> void:
	t = runner


func test_notice_line_copy() -> void:
	var stickers := CatalogStub.new()
	t.check(StickerNotice.line([], stickers) == "",
		"sticker notice: an empty drain has no copy")
	t.check(StickerNotice.line([&"first"], stickers) ==
		"NEW BUMPER STICKER: ROAD RASH — view your collection from the main menu",
		"sticker notice: singular copy uses the catalog name")
	t.check(StickerNotice.line([&"first", &"second"], stickers) ==
		"2 NEW BUMPER STICKERS: ROAD RASH, CHROME DOME — view your collection from the main menu",
		"sticker notice: plural copy carries the count and both names")
	t.check(StickerNotice.line([&"lost_id"], stickers) ==
		"NEW BUMPER STICKER: LOST_ID — view your collection from the main menu",
		"sticker notice: an unknown catalog id falls back to its raw uppercase id")
	stickers.free()
