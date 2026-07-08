extends CanvasLayer
## F2 tuning editor (dev mode): slider rows over the tuning deck's registry.
## Sections: WEAPONS (per-def), TERRAIN (per-surface), COMBAT (ram/bounce/
## boost). Every change applies live and saves to user://tuning.json; EXPORT
## writes the hand-back file. Sits top-right; F1's handling dashboard keeps
## the top-left corner.

const PANEL_BG := Color(0.07, 0.07, 0.09, 0.92)
const AMBER := Color(1.0, 0.85, 0.2)

var _panel: PanelContainer
var _rows_box: VBoxContainer
var _section_pick: OptionButton
var _target_pick: OptionButton
var _status: Label
var _sections := ["WEAPONS", "TERRAIN", "COMBAT"]

func _deck():
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.has_method("_ensure_tuning"):
		dev._ensure_tuning()
	return dev.tuning if dev else null

func _ready() -> void:
	layer = 55
	_build_ui()
	_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F2:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_rebuild_rows()

func _section() -> String:
	return _sections[_section_pick.selected]

func _on_section_changed(_i: int) -> void:
	_fill_targets()
	_rebuild_rows()

func _fill_targets() -> void:
	var deck = _deck()
	_target_pick.clear()
	match _section():
		"WEAPONS":
			for f in deck.DEF_FILES:
				_target_pick.add_item(f)
			_target_pick.visible = true
		"TERRAIN":
			for t in deck.TERRAIN_TYPES:
				_target_pick.add_item(String(t))
			_target_pick.visible = true
		"COMBAT":
			_target_pick.visible = false

func _rebuild_rows() -> void:
	var deck = _deck()
	if deck == null:
		return
	for c in _rows_box.get_children():
		c.queue_free()
	match _section():
		"WEAPONS":
			var def_name: String = deck.DEF_FILES[maxi(_target_pick.selected, 0)]
			for prop in deck.DEF_PROPS:
				var r: Array = deck.DEF_PROPS[prop]
				_row(prop, deck.get_def(def_name, prop), r,
					func(v: float) -> void: deck.set_def(def_name, prop, v))
		"TERRAIN":
			var terrain: StringName = deck.TERRAIN_TYPES[maxi(_target_pick.selected, 0)]
			for prop in deck.TERRAIN_PROPS:
				var r: Array = deck.TERRAIN_PROPS[prop]
				_row(prop, deck.get_terrain(terrain, prop), r,
					func(v: float) -> void: deck.set_terrain(terrain, prop, v))
		"COMBAT":
			for prop in deck.VEHICLE_PROPS:
				var r: Array = deck.VEHICLE_PROPS[prop]
				var current: float = deck.overrides.vehicle.get(prop, _live_vehicle_value(prop, r))
				_row(prop, current, r, func(v: float) -> void:
					deck.set_vehicle(prop, v)
					_apply_combat())
			for prop in deck.CONTROLLER_PROPS:
				var r: Array = deck.CONTROLLER_PROPS[prop]
				var current: float = deck.overrides.controller.get(prop, _live_controller_value(prop, r))
				_row(prop, current, r, func(v: float) -> void:
					deck.set_controller(prop, v)
					_apply_combat())

func _live_vehicle_value(prop: String, r: Array) -> float:
	var p := get_tree().get_first_node_in_group(&"player")
	return float(p.get(prop)) if p else float(r[0])

func _live_controller_value(prop: String, r: Array) -> float:
	var p := get_tree().get_first_node_in_group(&"player")
	var ctrl = p.get_controller() if p and p.has_method("get_controller") else null
	return float(ctrl.get(prop)) if ctrl else float(r[0])

func _apply_combat() -> void:
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.has_method("apply_combat_overrides_now"):
		dev.apply_combat_overrides_now()

func _row(prop: String, value: float, range_def: Array, on_change: Callable) -> void:
	var deck = _deck()
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = prop
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = float(range_def[0])
	slider.max_value = float(range_def[1])
	slider.step = float(range_def[2])
	slider.value = value
	slider.custom_minimum_size = Vector2(170, 0)
	hbox.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % value
	val_lbl.custom_minimum_size = Vector2(56, 0)
	val_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(val_lbl)
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		val_lbl.text = "%.2f" % v
		deck.save()
		_status.text = "saved -> user://tuning.json")
	_rows_box.add_child(hbox)

func _on_export() -> void:
	var deck = _deck()
	var path: String = deck.export_tuning()
	deck.save()
	_status.text = "EXPORTED -> " + path
	print("[tuning] exported: ", path)

func _on_reset() -> void:
	var deck = _deck()
	match _section():
		"WEAPONS":
			deck.reset_defs()
		"TERRAIN":
			deck.reset_terrain()
		"COMBAT":
			deck.reset_combat()
			_status.text = "combat reset applies fully on next level"
	deck.save()
	_rebuild_rows()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -420.0
	_panel.offset_right = -8.0
	_panel.offset_top = 8.0
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "TUNING DECK  (F2)"
	title.modulate = AMBER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var pickers := HBoxContainer.new()
	_section_pick = OptionButton.new()
	for s in _sections:
		_section_pick.add_item(s)
	_section_pick.item_selected.connect(_on_section_changed)
	pickers.add_child(_section_pick)
	_target_pick = OptionButton.new()
	_target_pick.item_selected.connect(func(_i: int) -> void: _rebuild_rows())
	pickers.add_child(_target_pick)
	vbox.add_child(pickers)

	_rows_box = VBoxContainer.new()
	vbox.add_child(_rows_box)

	var buttons := HBoxContainer.new()
	var export_btn := Button.new()
	export_btn.text = "Export"
	export_btn.pressed.connect(_on_export)
	buttons.add_child(export_btn)
	var reset_btn := Button.new()
	reset_btn.text = "Reset section"
	reset_btn.pressed.connect(_on_reset)
	buttons.add_child(reset_btn)
	vbox.add_child(buttons)

	_status = Label.new()
	_status.text = "changes apply live + save immediately"
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(0.55, 0.58, 0.62)
	vbox.add_child(_status)

	_fill_targets()
