extends Node2D
## Level editor shell: world preview (grid floor + canvas) under an editor
## camera, with toolbar, inspector, and file dialogs built in code (house
## style — see ui/pause_menu.gd). Launch standalone:
##   godot --path . res://editor/editor_main.tscn     (or tools/editor.sh)

const DocumentScript := preload("res://editor/editor_document.gd")
const CanvasScript := preload("res://editor/editor_canvas.gd")
const CameraScript := preload("res://editor/editor_camera.gd")
const PaletteScript := preload("res://editor/palette.gd")
const EntityInspectorScript := preload("res://editor/entity_inspector.gd")
const GridFloorScript := preload("res://levels/grid_floor.gd")
const Loader := preload("res://levels/level_loader.gd")
const Schema := preload("res://levels/level_schema.gd")

const LEVELS_DIR := "user://levels"
const PLAYTEST_PATH := "user://levels/_playtest.json"

var document: EditorDocument

var _floor: GridFloor
var _canvas: Node2D
var _title_label: Label
var _status_label: Label
var _open_dialog: FileDialog
var _save_dialog: FileDialog
var _report_dialog: AcceptDialog
var _name_edit: LineEdit
var _author_edit: LineEdit
var _desc_edit: LineEdit
var _width_spin: SpinBox
var _height_spin: SpinBox

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(LEVELS_DIR)
	document = DocumentScript.new()
	_build_world()
	_build_ui()
	document.changed.connect(_refresh)
	_restore_from_playtest()
	_refresh()
	print("[boot] editor ready")

## Booted via the pause menu's "Return to Editor": reopen the playtested state.
func _restore_from_playtest() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null or not gs.playtest_return_to_editor:
		return
	document.restore_playtest(PLAYTEST_PATH, gs.editor_open_path)
	gs.playtest_return_to_editor = false
	gs.pending_level_path = ""
	gs.editor_open_path = ""
	_status("Back from playtest")

func _build_world() -> void:
	_floor = GridFloorScript.new()
	_floor.name = "GridFloor"
	add_child(_floor)
	_canvas = CanvasScript.new()
	_canvas.name = "Canvas"
	add_child(_canvas)
	_canvas.bind(document)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.set_script(CameraScript)
	camera.zoom = Vector2(0.25, 0.25)
	add_child(camera)

func _refresh() -> void:
	_floor.set_extent(document.bounds_half() + Vector2(Loader.FLOOR_OVERSCAN, Loader.FLOOR_OVERSCAN))
	var file_name := document.path.get_file() if not document.path.is_empty() else "(unsaved)"
	_title_label.text = "%s%s" % [file_name, " *" if document.dirty else ""]
	_sync_inspector()

func _sync_inspector() -> void:
	if _name_edit.text != String(document.level.name):
		_name_edit.text = document.level.name
	if _author_edit.text != String(document.level.author):
		_author_edit.text = document.level.author
	if _desc_edit.text != String(document.level.description):
		_desc_edit.text = document.level.description
	_width_spin.set_value_no_signal(document.level.bounds.width)
	_height_spin.set_value_no_signal(document.level.bounds.height)

func _status(message: String) -> void:
	_status_label.text = message

# --- file actions -----------------------------------------------------------

func _on_new() -> void:
	document.new_level()
	_status("New level")

func _on_open_selected(path: String) -> void:
	var problems := document.open(path)
	if problems.is_empty():
		_status("Opened " + path.get_file())
	else:
		_status("%s — %d issue(s): %s" % [path.get_file(), problems.size(), problems[0]])

func _on_save() -> void:
	if document.path.is_empty():
		_save_dialog.popup_centered()
	else:
		_save_to(document.path)

func _on_save_as_selected(path: String) -> void:
	if path.get_extension() != "json":
		path += ".json"
	_save_to(path)

func _save_to(path: String) -> void:
	var err := document.save_as(path)
	if err == OK:
		_status("Saved " + path.get_file())
	else:
		_status("Save failed: %s (%s)" % [path, error_string(err)])

func _on_validate() -> void:
	var errors := document.validate()
	if errors.is_empty():
		_report("Validation", "Level is valid — ready to play.")
	else:
		_report("Validation — %d problem(s)" % errors.size(), "\n".join(errors))

## Playtest: refuse invalid levels, save the working state to _playtest.json
## (explicit Save still owns the real file), then drive into the game. The
## pause menu's "Return to Editor" brings this exact state back.
func _on_playtest() -> void:
	var errors := document.validate()
	if not errors.is_empty():
		_report("Can't playtest — %d problem(s)" % errors.size(), "\n".join(errors))
		return
	var file := FileAccess.open(PLAYTEST_PATH, FileAccess.WRITE)
	if file == null:
		_status("Playtest failed: can't write " + PLAYTEST_PATH)
		return
	file.store_string(Schema.serialize(document.level))
	file.close()
	var gs := get_node_or_null(^"/root/GameState")
	var flow := get_node_or_null(^"/root/SceneFlow")
	if gs == null or flow == null:
		_status("Playtest failed: game autoloads missing")
		return
	gs.playtest_return_to_editor = true
	gs.editor_open_path = document.path
	flow.to_custom_level(PLAYTEST_PATH)

func _report(title: String, body: String) -> void:
	_report_dialog.title = title
	_report_dialog.dialog_text = body
	_report_dialog.popup_centered()

# --- UI assembly -------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	ui.add_child(_build_toolbar())
	ui.add_child(_build_inspector())
	ui.add_child(_build_status_bar())
	var palette: PanelContainer = PaletteScript.new()
	palette.setup(document)
	palette.tool_changed.connect(_canvas.set_tool)
	ui.add_child(palette)
	var entity_inspector: PanelContainer = EntityInspectorScript.new()
	entity_inspector.setup(document)
	ui.add_child(entity_inspector)
	_canvas.selection_changed.connect(entity_inspector.set_selection)
	_canvas.tool_cancelled.connect(palette.reset_to_select)
	_open_dialog = _make_dialog(FileDialog.FILE_MODE_OPEN_FILE, _on_open_selected)
	_save_dialog = _make_dialog(FileDialog.FILE_MODE_SAVE_FILE, _on_save_as_selected)
	ui.add_child(_open_dialog)
	ui.add_child(_save_dialog)
	_report_dialog = AcceptDialog.new()
	ui.add_child(_report_dialog)

func _build_toolbar() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	panel.add_child(bar)
	_add_button(bar, "New", _on_new)
	_add_button(bar, "Open", func() -> void: _open_dialog.popup_centered())
	_add_button(bar, "Save", _on_save)
	_add_button(bar, "Save As", func() -> void: _save_dialog.popup_centered())
	_add_button(bar, "Validate", _on_validate)
	_add_button(bar, "Playtest", _on_playtest)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_title_label)
	return panel

func _build_inspector() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_top = 48  # clear the toolbar
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(240, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "Level"
	box.add_child(heading)
	_name_edit = _add_line(box, "Name", func(v: String) -> void: document.set_field("name", v))
	_author_edit = _add_line(box, "Author", func(v: String) -> void: document.set_field("author", v))
	_desc_edit = _add_line(box, "Description", func(v: String) -> void: document.set_field("description", v))
	_width_spin = _add_spin(box, "Width")
	_height_spin = _add_spin(box, "Height")
	return panel

func _build_status_bar() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_label = Label.new()
	_status_label.text = "Bent Chrome level editor — levels save to " \
			+ ProjectSettings.globalize_path(LEVELS_DIR)
	panel.add_child(_status_label)
	return panel

func _make_dialog(mode: FileDialog.FileMode, on_selected: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = ProjectSettings.globalize_path(LEVELS_DIR)
	dialog.filters = PackedStringArray(["*.json ; Bent Chrome levels"])
	dialog.size = Vector2i(720, 480)
	dialog.file_selected.connect(on_selected)
	return dialog

func _add_button(parent: Node, text: String, pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	parent.add_child(button)

func _add_line(parent: Node, label_text: String, on_changed: Callable) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var line := LineEdit.new()
	line.text_changed.connect(on_changed)
	parent.add_child(line)
	return line

func _add_spin(parent: Node, label_text: String) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = Schema.MIN_SIDE
	spin.max_value = Schema.MAX_SIDE
	spin.step = Schema.GRID
	spin.value_changed.connect(func(_v: float) -> void:
		document.set_bounds(_width_spin.value, _height_spin.value))
	parent.add_child(spin)
	return spin
