extends PanelContainer
## Property panel for the selected entity: builds SpinBoxes from the catalog
## entry's props (ranges/steps come from there, ultimately from LevelSchema).
## Hidden when nothing is selected. Rebuilds only on selection change so
## spinner focus survives document edits.

const Catalog := preload("res://levels/entity_catalog.gd")

var document: EditorDocument
var _selection := {}
var _box: VBoxContainer

func setup(doc: EditorDocument) -> void:
	document = doc
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(240, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	visible = false

func set_selection(selection: Dictionary) -> void:
	_selection = selection
	_rebuild()

func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	if _selection.is_empty():
		visible = false
		return
	var entity := _entity()
	var entry := Catalog.for_entity(_selection.list_key, entity)
	visible = true
	var heading := Label.new()
	heading.text = entry.display
	_box.add_child(heading)
	for prop in entry.props:
		if entity.get(prop.key) is Array:
			_add_pair_spins(prop, entity)
		else:
			_add_spin(prop, prop.display, float(entity.get(prop.key, prop.default)),
					func(v: float) -> void: _apply(prop.key, v))

func _entity() -> Dictionary:
	if _selection.list_key == "player_spawn":
		return document.level.player_spawn
	return document.level[_selection.list_key][_selection.index]

func _apply(key: String, value: Variant) -> void:
	if _selection.list_key == "player_spawn":
		document.set_player_heading(float(value))
	else:
		document.set_entity_prop(_selection.list_key, _selection.index, key, value)

## Two spinners for [w, h]-style array props (block size).
func _add_pair_spins(prop: Dictionary, entity: Dictionary) -> void:
	var pair: Array = entity[prop.key]
	var spins: Array[SpinBox] = []
	var on_changed := func(_v: float) -> void:
		_apply(prop.key, [spins[0].value, spins[1].value])
	spins.append(_add_spin(prop, prop.display + " W", float(pair[0]), on_changed))
	spins.append(_add_spin(prop, prop.display + " H", float(pair[1]), on_changed))

func _add_spin(prop: Dictionary, label_text: String, value: float, on_changed: Callable) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	_box.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = prop.min
	spin.max_value = prop.max
	spin.step = prop.get("step", 1.0)
	spin.set_value_no_signal(value)
	spin.value_changed.connect(on_changed)
	_box.add_child(spin)
	return spin
