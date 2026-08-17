extends Control
## Car-select carousel: browse the 9 cars (portrait + stats + special), confirm
## to set the player's car (GameState) and enter the arena. A turntable in the
## corner spins the actual in-game body (same paint script the arena uses).
## W / west face button toggles the driver bio — the roster's flavor prose,
## resurrected from the old build's MoreInfoDialog.

const CarPaint := preload("res://vehicles/car_paint.gd")
const TURNTABLE_POS := Vector2(1120, 150)
const TURNTABLE_SCALE := 2.0  # paint self-scales by FLEET_SCALE; 2.0 holds the old footprint
const TURNTABLE_SPIN := 0.8  # rad/s, quantized to the same 16 steps as gameplay

const AMBER := Color(1.0, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const BIO_WIDTH := 620.0

var _cars: Array = []
var _index := 0
var _done := false
var _turntable: Node2D
var _spin := 0.0
var _bio: Control
var _bio_title: Label
var _bio_flavor: Label
var _bio_special: Label

@onready var _portrait: TextureRect = $Portrait
@onready var _name: Label = $Footer/Margin/VBox/Name
@onready var _driver: Label = $Footer/Margin/VBox/Driver
@onready var _stats: Label = $Footer/Margin/VBox/Stats
@onready var _special: Label = $Footer/Margin/VBox/Special

func _ready() -> void:
	_load_cars()
	if _cars.is_empty():
		push_warning("car_select: no cars loaded")
		return
	_turntable = CarPaint.new()
	_turntable.position = TURNTABLE_POS
	_turntable.scale = Vector2.ONE * TURNTABLE_SCALE
	add_child(_turntable)
	_build_bio()
	for i in _cars.size():
		if _cars[i].id == GameState.selected_vehicle_id:
			_index = i
	_show()

func _load_cars() -> void:
	var f := FileAccess.open("res://assets/data/roster.json", FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for c in data.get("characters", []):
		var vs: Variant = load("res://data/vehicles/%s.tres" % c.get("id", ""))
		if vs:
			_cars.append(vs)

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	# ESC steps back one layer: dossier -> carousel -> difficulty select (or
	# the fight card for SINGLE BATTLE, mode select when Driver's Ed skipped
	# the DMV, or the garage lobby when this is a LAN session's ride picker).
	# Once gameplay starts, ESC belongs to the pause menu instead.
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		if _bio and _bio.visible:
			_bio.visible = false
		elif _mp_session():
			SceneFlow.to_mp_lobby()
		elif GameState.game_mode == &"single_battle":
			SceneFlow.to_level_select()
		elif GameState.game_mode != &"campaign":
			SceneFlow.to_mode_select()
		else:
			SceneFlow.to_difficulty()
		return
	if _cars.is_empty():
		return
	if event.is_action_pressed(&"select_more_info"):
		get_viewport().set_input_as_handled()
		UiSfx.select(self)
		_toggle_bio()
	elif event.is_action_pressed(&"select_next"):
		_index = (_index + 1) % _cars.size()
		UiSfx.move(self)
		_show()
	elif event.is_action_pressed(&"select_prev"):
		_index = (_index - 1 + _cars.size()) % _cars.size()
		UiSfx.move(self)
		_show()
	elif event.is_action_pressed(&"select_confirm"):
		if _bio and _bio.visible:
			return  # reading, not racing — close the bio first
		if _mp_taken().has(String(_cars[_index].id)):
			return  # somebody's already in it — the [TAKEN] tag says so
		UiSfx.select(self)
		_done = true
		GameState.selected_vehicle_id = _cars[_index].id
		if _mp_session():
			# LAN ride picker: lock the pick on the roster, back to the lobby.
			var net := get_node_or_null(^"/root/Net")
			net.request_set_pick(String(_cars[_index].id))
			SceneFlow.to_mp_lobby()
			return
		GameState.reset_campaign()
		if GameState.game_mode == &"single_battle":
			# One-off brawl into the fight-card pick; the mode stamp keeps the
			# end screen off the campaign fork.
			SceneFlow.to_level(GameState.battle_level_index)
			return
		if GameState.game_mode != &"campaign":
			# Driver's Ed (lessons or test drive) — one-off yard, no campaign.
			SceneFlow.to_tutorial()
			return
		SceneFlow.to_level(0)

## Soft-coupled MP check: this stays a pure SP screen unless a session is live.
func _mp_session() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net != null and net.is_active()

## Rides claimed by OTHER drivers (seats + queue) — one of each on the floor.
func _mp_taken() -> Array:
	var net := get_node_or_null(^"/root/Net")
	if net == null or not net.is_active():
		return []
	return net.taken_cars(net.my_id())

func _toggle_bio() -> void:
	if _bio == null:
		return
	_bio.visible = not _bio.visible
	if _bio.visible:
		_update_bio()

func _update_bio() -> void:
	var car: Variant = _cars[_index]
	_bio_title.text = "%s — %s" % [car.car_name, car.driver_name]
	_bio_flavor.text = car.flavor
	_bio_special.text = "%s — %s" % [car.special_name, car.special_desc]

## The resurrected MoreInfoDialog, rebuilt in the house blocky-panel style.
func _build_bio() -> void:
	_bio = Control.new()
	_bio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bio.visible = false
	add_child(_bio)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bio.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bio.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(BIO_WIDTH, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_bio_title = Label.new()
	_bio_title.add_theme_font_size_override("font_size", 28)
	_bio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bio_title.modulate = AMBER
	vbox.add_child(_bio_title)

	_bio_flavor = Label.new()
	_bio_flavor.add_theme_font_size_override("font_size", 18)
	_bio_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_flavor.modulate = Color(0.8, 0.82, 0.86)
	vbox.add_child(_bio_flavor)

	var special_header := Label.new()
	special_header.text = "SPECIAL"
	special_header.add_theme_font_size_override("font_size", 14)
	special_header.modulate = DIM_TEXT
	vbox.add_child(special_header)

	_bio_special = Label.new()
	_bio_special.add_theme_font_size_override("font_size", 16)
	_bio_special.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_special.modulate = Color(0.8, 0.82, 0.86)
	vbox.add_child(_bio_special)

	var hint := Label.new()
	hint.text = "W / ESC to close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)

func _process(delta: float) -> void:
	if _turntable == null:
		return
	_spin += TURNTABLE_SPIN * delta
	_turntable.rotation = snappedf(_spin, TAU / 16)

func _show() -> void:
	var car: Variant = _cars[_index]
	if _bio and _bio.visible:
		_update_bio()  # browsing with the dossier open follows along
	if _turntable:
		_turntable.apply(car.id, car.primary_color, car.accent_color)
	_portrait.texture = TextureLoader.load_texture("res://assets/img/bios/%s.png" % car.id)
	if _mp_taken().has(String(car.id)):
		_name.text = "%s  [ TAKEN ]" % car.car_name
		_name.modulate = Color(1.0, 0.42, 0.32)
	else:
		_name.text = car.car_name
		_name.modulate = Color.WHITE
	_driver.text = car.driver_name
	_stats.text = "ACCEL %d    TOP %d    HANDLING %d    ARMOR %d    SPECIAL %d" % [
		car.acceleration, car.top_speed, car.handling, car.armor, car.special_power]
	_special.text = "%s — %s" % [car.special_name, car.special_desc]
