extends PanelContainer
## Placement palette: one toggle per placeable entity plus the Select tool.
## Arms the canvas tool; live-disables entries at their placement caps.
## Terrain painting tools join in the terrain card.

signal tool_changed(tool_id: String)

const Catalog := preload("res://levels/entity_catalog.gd")

const PLACEABLE := [
	"player_spawn", "enemy_spawn", "block", "pickup_standard", "pickup_homing", "pickup_rear", "dummy",
	"terrain_dirt", "terrain_mud", "terrain_ice", "terrain_water",  # drag-rect tools
]

var document: EditorDocument
var _select_button: Button
var _buttons := {}  # tool_id -> Button

func setup(doc: EditorDocument) -> void:
	document = doc
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var heading := Label.new()
	heading.text = "Palette"
	box.add_child(heading)
	var group := ButtonGroup.new()
	_select_button = _tool_button(box, group, "select", "Select / Move")
	for id in PLACEABLE:
		_buttons[id] = _tool_button(box, group, id, Catalog.by_id(id).display)
	_select_button.button_pressed = true
	document.changed.connect(_update_caps)
	_update_caps()

func reset_to_select() -> void:
	_select_button.button_pressed = true
	tool_changed.emit("select")

func _tool_button(parent: Node, group: ButtonGroup, id: String, text: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: tool_changed.emit(id))
	parent.add_child(button)
	return button

func _update_caps() -> void:
	for id in _buttons:
		var entry := Catalog.by_id(id)
		if not entry.has("max_count"):
			continue
		var count := document.count(entry.list_key)
		var button: Button = _buttons[id]
		button.text = "%s (%d/%d)" % [entry.display, count, entry.max_count]
		button.disabled = count >= entry.max_count
		if button.disabled and button.button_pressed:
			reset_to_select()
