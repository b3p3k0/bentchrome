extends RefCounted
## Bumper Sticker gallery: hidden-copy contract, NEW acknowledgement, manual
## grid navigation, procedural fallback, and title-door state.

const TMP_PROFILE := "user://_test_sticker_book.json"

var t


class FlowStub extends Node:
	var title_calls := 0

	func to_title() -> void:
		title_calls += 1


func _init(runner) -> void:
	t = runner


func _begin() -> Dictionary:
	DirAccess.remove_absolute(TMP_PROFILE)
	var store: Node = t.root.get_node(^"/root/Stickers")
	var gs: Node = t.root.get_node(^"/root/GameState")
	var keep := {
		"counters": store.counters.duplicate(true),
		"sets": store.sets.duplicate(true),
		"unlocked": store.unlocked.duplicate(true),
		"seen": store.seen.duplicate(),
		"fresh": store._fresh.duplicate(),
		"profile_path": store._profile_path,
		"catalog_rows": store._catalog_rows.duplicate(true),
		"catalog_by_id": store._catalog_by_id.duplicate(true),
		"roster_path": store.roster_path,
		"required_cache": store._required_cache.duplicate(true),
		"dev_mode": gs.dev_mode,
	}
	store.load_catalog()
	store.load_profile(TMP_PROFILE)
	gs.dev_mode = false
	return keep


func _restore(keep: Dictionary) -> void:
	var store: Node = t.root.get_node(^"/root/Stickers")
	var gs: Node = t.root.get_node(^"/root/GameState")
	store.counters = keep.counters
	store.sets = keep.sets
	store.unlocked = keep.unlocked
	store.seen = keep.seen
	store._fresh = keep.fresh
	store._profile_path = keep.profile_path
	store._catalog_rows = keep.catalog_rows
	store._catalog_by_id = keep.catalog_by_id
	store.roster_path = keep.roster_path
	store._required_cache = keep.required_cache
	gs.dev_mode = keep.dev_mode
	DirAccess.remove_absolute(TMP_PROFILE)


func _open_book() -> Control:
	var book: Control = (load("res://ui/sticker_book.tscn") as PackedScene).instantiate()
	t.root.add_child(book)
	return book


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		t.root.remove_child(node)
		node.free()


func _press(target: Control, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._unhandled_input(event)


func _label_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	if root is Label:
		texts.append(root.text)
	for child in root.get_children():
		texts.append_array(_label_texts(child))
	return texts


func test_empty_profile_opens_full_catalog() -> void:
	var keep := _begin()
	var store: Node = t.root.get_node(^"/root/Stickers")
	var total: int = store.catalog().size()
	store._catalog_rows.clear()  # exercise ensure_catalog() on the headless path
	store._catalog_by_id.clear()
	var book := _open_book()
	t.check(book._cells.size() == total,
		"sticker book: empty profile still builds every catalog tile")
	t.check(book.get_node(^"Collected").text == "0 / %d COLLECTED" % total,
		"sticker book: empty profile header reports zero of catalog")
	_free_node(book)
	_restore(keep)


func test_locked_tiles_leak_no_catalog_copy() -> void:
	var keep := _begin()
	var store: Node = t.root.get_node(^"/root/Stickers")
	var book := _open_book()
	var texts := _label_texts(book)
	for row_v in store.catalog():
		var row: Dictionary = row_v
		var name := String(row.get("name", ""))
		var blurb := String(row.get("blurb", ""))
		var leaked := false
		for value in texts:
			leaked = leaked or value.contains(name) or value.contains(blurb)
		t.check(not leaked, "sticker book: locked '%s' leaks no name or blurb" % name)
	_free_node(book)
	_restore(keep)


func test_dev_mode_reveals_selected_locked_progress() -> void:
	var keep := _begin()
	var store: Node = t.root.get_node(^"/root/Stickers")
	var gs: Node = t.root.get_node(^"/root/GameState")
	gs.dev_mode = true
	var first: Dictionary = store.catalog()[0]
	var book := _open_book()
	var dev: Label = book.get_node(^"Detail/Margin/Box/Dev")
	t.check(dev.visible and dev.text.begins_with("[DEV] " + String(first.name) + " — "),
		"sticker book: Developer Mode identifies the selected locked goal")
	_free_node(book)
	_restore(keep)


func test_unlocked_tiles_count_and_acknowledge_new() -> void:
	var keep := _begin()
	var store: Node = t.root.get_node(^"/root/Stickers")
	var rows: Array = store.catalog()
	var first := String(rows[0].id)
	var second := String(rows[1].id)
	store.unlocked[first] = 1727654400
	store.unlocked[second] = 1727740800
	var book := _open_book()
	t.check(book.get_node(^"Collected").text == "2 / %d COLLECTED" % rows.size(),
		"sticker book: direct unlocks count in the header")
	t.check(not bool(book._cells[0].get_meta(&"locked"))
		and not bool(book._cells[1].get_meta(&"locked")),
		"sticker book: unlocked rows use earned paint, not blanks")
	t.check(book.find_children("NewTag", "Label", true, false).size() == 2,
		"sticker book: both unseen unlocks carry NEW tags")
	t.check(store.unseen().is_empty(),
		"sticker book: opening acknowledges every unseen unlock")
	_free_node(book)
	_restore(keep)


func test_navigation_wraps_steps_by_row_and_esc_exits() -> void:
	var keep := _begin()
	var real_flow: Node = t.root.get_node(^"/root/SceneFlow")
	t.root.remove_child(real_flow)
	var flow := FlowStub.new()
	flow.name = "SceneFlow"
	t.root.add_child(flow)
	var book := _open_book()
	book._index = book._rows.size() - 1
	book._refresh_selection()
	_press(book, &"move_right")
	t.check(book._index == 0, "sticker book: right from the last tile wraps to zero")
	book._index = 1
	book._refresh_selection()
	_press(book, &"move_down")
	t.check(book._index == 5, "sticker book: down moves one four-column row")
	_press(book, &"pause")
	t.check(book._done and flow.title_calls == 1,
		"sticker book: ESC guards the exit and routes to title")
	_free_node(book)
	t.root.remove_child(flow)
	flow.free()
	t.root.add_child(real_flow)
	_restore(keep)


func test_sticker_paint_fallback_and_blank_question_mark() -> void:
	var paint_script: Script = load("res://ui/sticker_paint.gd")
	var painted: Control = paint_script.make(&"__definitely_missing__", "Test Vinyl",
		Vector2(240, 80))
	t.check(not painted is TextureRect and painted.name == "ProceduralSticker",
		"sticker paint: missing art returns the procedural control")
	var blank: Control = paint_script.make_blank(Vector2(240, 80))
	var question := blank.get_node_or_null(^"QuestionMark") as Label
	t.check(question != null and question.text == "???",
		"sticker paint: blank carries only the question mark")
	painted.free()
	blank.free()


func test_title_has_sticker_entry_and_new_suffix_only_when_unseen() -> void:
	var keep := _begin()
	var store: Node = t.root.get_node(^"/root/Stickers")
	var title: Control = (load("res://ui/title.tscn") as PackedScene).instantiate()
	t.root.add_child(title)
	t.check(title._entries.size() == 6 and title.ENTRY_NAMES[3] == "BUMPER STICKERS",
		"title: BUMPER STICKERS is the fourth of six entries")
	t.check(not title._entries[3].text.contains("★NEW"),
		"title: sticker entry has no NEW suffix with nothing unseen")
	var id := String(store.catalog()[0].id)
	store.unlocked[id] = 1727654400
	title._highlight()
	var suffix_count := 0
	for entry in title._entries:
		if entry.text.contains("★NEW"):
			suffix_count += 1
	t.check(suffix_count == 1 and title._entries[3].text.contains("★NEW"),
		"title: only the unhighlighted sticker entry gains the NEW suffix")
	title._index = 3
	title._highlight()
	t.check(title._entries[3].text.begins_with("[ BUMPER STICKERS ★NEW ]"),
		"title: highlighted sticker entry keeps the NEW suffix")
	store.seen.append(id)
	title._highlight()
	t.check(not title._entries[3].text.contains("★NEW"),
		"title: suffix clears once the unlock is seen")
	_free_node(title)
	_restore(keep)
