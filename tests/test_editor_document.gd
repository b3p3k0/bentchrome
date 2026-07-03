extends RefCounted
## EditorDocument tests: new/open/save file state, dirty tracking, and the
## mutation equality guards. Driven by tests/run_tests.gd.

const DocumentScript := preload("res://editor/editor_document.gd")
const Schema := preload("res://levels/level_schema.gd")
const TEMP_PATH := "user://levels/_test_editor_document.json"

var t  # the runner: check()/check_approx() helpers + root access

func _init(runner) -> void:
	t = runner

func _doc() -> RefCounted:
	DirAccess.make_dir_recursive_absolute("user://levels")
	return DocumentScript.new()

func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))

func test_new_document_state() -> void:
	var doc := _doc()
	t.check(doc.path.is_empty() and not doc.dirty, "fresh doc: no path, not dirty")
	t.check(doc.level.name == "Untitled", "fresh doc: schema defaults")
	t.check(doc.save() != OK, "save without a path refuses")

func test_mutations_set_dirty_and_signal() -> void:
	var doc := _doc()
	var signals := [0]
	doc.changed.connect(func() -> void: signals[0] += 1)
	doc.set_field("name", "Scrap Bowl")
	t.check(doc.dirty, "set_field marks dirty")
	t.check(signals[0] == 1, "set_field emits changed once")
	doc.set_field("name", "Scrap Bowl")
	t.check(signals[0] == 1, "same value doesn't re-emit")
	doc.set_bounds(3200.0, 3200.0)
	t.check(signals[0] == 2, "set_bounds emits changed")
	doc.set_bounds(3200.0, 3200.0)
	t.check(signals[0] == 2, "same bounds don't re-emit")
	t.check_approx(doc.bounds_half().x, 1600.0, "bounds_half tracks bounds")

func test_save_and_reopen_round_trip() -> void:
	var doc := _doc()
	doc.set_field("name", "Round Trip")
	doc.level.enemy_spawns.append({"pos": [448.0, -256.0]})
	t.check(doc.save_as(TEMP_PATH) == OK, "save_as succeeds")
	t.check(not doc.dirty and doc.path == TEMP_PATH, "save clears dirty, keeps path")
	var doc2 := _doc()
	var problems: Array = doc2.open(TEMP_PATH)
	t.check(problems.is_empty(), "reopen: no problems (%s)" % [problems])
	t.check(doc2.level.name == "Round Trip", "reopen: content survived")
	t.check(doc2.level.enemy_spawns.size() == 1, "reopen: entities survived")
	_cleanup()

func test_entity_ops() -> void:
	var doc := _doc()
	var index: int = doc.add_entity("blocks", {"pos": [128.0, 128.0], "size": [128.0, 128.0]})
	t.check(index == 0 and doc.count("blocks") == 1, "add_entity appends and counts")
	t.check(doc.dirty, "add_entity marks dirty")
	doc.move_entity("blocks", 0, Vector2(256.0, -128.0))
	t.check(doc.level.blocks[0].pos == [256.0, -128.0], "move_entity updates pos")
	doc.set_entity_prop("blocks", 0, "size", [256.0, 128.0])
	t.check(doc.level.blocks[0].size == [256.0, 128.0], "set_entity_prop updates value")
	doc.remove_entity("blocks", 0)
	t.check(doc.count("blocks") == 0, "remove_entity deletes")

func test_player_spawn_ops() -> void:
	var doc := _doc()
	var signals := [0]
	doc.changed.connect(func() -> void: signals[0] += 1)
	doc.move_player_spawn(Vector2(320.0, 0.0))
	t.check(doc.level.player_spawn.pos == [320.0, 0.0], "player spawn moves")
	doc.move_player_spawn(Vector2(320.0, 0.0))
	t.check(signals[0] == 1, "same position doesn't re-emit")
	doc.set_player_heading(90.0)
	t.check_approx(doc.level.player_spawn.heading_deg, 90.0, "heading set")

func test_undo_redo() -> void:
	var doc := _doc()
	doc.add_entity("blocks", {"pos": [128.0, 128.0], "size": [128.0, 128.0]})
	doc.set_field("name", "After")
	t.check(doc.undo(), "undo the rename")
	t.check(doc.level.name == "Untitled", "rename undone")
	t.check(doc.undo(), "undo the add")
	t.check(doc.count("blocks") == 0, "add undone")
	t.check(not doc.dirty, "back to pristine -> not dirty")
	t.check(not doc.undo(), "empty stack refuses")
	t.check(doc.redo(), "redo the add")
	t.check(doc.count("blocks") == 1 and doc.dirty, "add redone, dirty again")
	t.check(doc.redo(), "redo the rename")
	t.check(doc.level.name == "After", "rename redone")
	doc.set_field("author", "kevin")
	t.check(not doc.redo(), "new mutation clears the redo stack")

func test_undo_coalesces_drags() -> void:
	var doc := _doc()
	doc.add_entity("dummies", {"pos": [0.0, 0.0], "max_hp": 60.0})
	# One drag = many move_entity calls; must be a single undo step.
	doc.move_entity("dummies", 0, Vector2(64.0, 0.0))
	doc.move_entity("dummies", 0, Vector2(128.0, 0.0))
	doc.move_entity("dummies", 0, Vector2(192.0, 0.0))
	doc.end_action()
	doc.move_entity("dummies", 0, Vector2(512.0, 0.0))  # a second drag
	t.check(doc.undo(), "undo second drag")
	t.check(doc.level.dummies[0].pos == [192.0, 0.0], "second drag undone as one step")
	t.check(doc.undo(), "undo first drag")
	t.check(doc.level.dummies[0].pos == [0.0, 0.0], "first drag undone as one step")

func test_open_clears_history() -> void:
	var doc := _doc()
	doc.set_field("name", "History")
	doc.level.enemy_spawns.append({"pos": [448.0, -256.0]})
	t.check(doc.save_as(TEMP_PATH) == OK, "saved")
	var doc2 := _doc()
	doc2.set_field("name", "Other")
	doc2.open(TEMP_PATH)
	t.check(not doc2.undo(), "open wipes undo history")
	_cleanup()

func test_restore_playtest() -> void:
	var playtest_path := "user://levels/_test_playtest.json"
	var doc := _doc()
	doc.set_field("name", "Playtested")
	doc.level.enemy_spawns.append({"pos": [448.0, -256.0]})
	t.check(doc.save_as(TEMP_PATH) == OK, "original saved")
	# Unsaved edit, then playtest snapshot written (as _on_playtest does).
	doc.move_player_spawn(Vector2(320.0, 320.0))
	t.check(doc.save_as(playtest_path) == OK, "playtest snapshot written")
	var back := _doc()
	back.restore_playtest(playtest_path, TEMP_PATH)
	t.check(back.path == TEMP_PATH, "restore points back at the real file")
	t.check(back.level.player_spawn.pos == [320.0, 320.0], "unsaved edit survived the loop")
	t.check(back.dirty, "differs from disk -> dirty")
	# A clean playtest (no edits since save) restores not-dirty.
	var clean := _doc()
	clean.open(TEMP_PATH)
	t.check(clean.save_as(playtest_path) == OK, "clean snapshot written")
	var back2 := _doc()
	back2.restore_playtest(playtest_path, TEMP_PATH)
	t.check(not back2.dirty, "matches disk -> not dirty")
	# Never-saved level: restore keeps it pathless and dirty.
	var back3 := _doc()
	back3.restore_playtest(playtest_path, "")
	t.check(back3.path.is_empty() and back3.dirty, "unsaved original stays pathless + dirty")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(playtest_path))
	_cleanup()

func test_open_reports_problems() -> void:
	var doc := _doc()
	t.check(not doc.open("user://levels/_no_such_file.json").is_empty(), "missing file reported")
	# WIP levels (validation errors) still open, but report their issues.
	var wip := _doc()
	wip.set_field("name", "WIP")  # default level: zero enemy spawns = invalid
	t.check(wip.save_as(TEMP_PATH) == OK, "invalid WIP level still saves")
	var reopened := _doc()
	var problems: Array = reopened.open(TEMP_PATH)
	t.check(not problems.is_empty(), "WIP validation issues reported on open")
	t.check(reopened.level.name == "WIP", "WIP level content still loaded")
	_cleanup()
