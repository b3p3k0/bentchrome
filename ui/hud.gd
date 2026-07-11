extends CanvasLayer
## Gameplay HUD. The 1280x720 frame is a centered 720x720 play square with a
## 280px opaque gutter each side: left = dash (vitals, MG heat, weapon slots,
## keyguide), right = radar (ui/radar.gd). Poll-driven — reads the viewer's
## car each frame (Vehicles.local: "local_player" group with a "player"
## fallback); survives player death/restart by re-binding.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")

const GUTTER := 280
const VIEW_H := 720
const PANEL_BG := Color(0.07, 0.07, 0.09)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const SELECTED := Color(1.0, 0.85, 0.2)
const ALIVE_TEXT := Color(0.8, 0.82, 0.86)   # soft white — pure white glares
const DEAD_TEXT := Color(0.55, 0.14, 0.14)   # dark red for the wrecked
const MPH_PER_PXS := 0.15  # display-only px/s -> mph (368 px/s reads ~55 mph)

var _player: Vehicle
var _rack: WeaponRack
var _opponents: Array = []  # each: {ref: Vehicle, label: Label}; snapshot at round start
var _opponents_box: VBoxContainer

var _hp_bar: ProgressBar
var _hp_label: Label
var _god_label: Label
var _life_pips: Array = []
var _speed_label: Label
var _floor_label: Label  # multi-floor levels only; hidden on legacy (floor -1)
var _heat_bar: ProgressBar
var _heat_label: Label
var _boost_bar: ProgressBar
var _slot_labels: Array = []

func _ready() -> void:
	layer = 10
	_build_ui()

func _process(_delta: float) -> void:
	_update_opponents()
	if _player == null or not is_instance_valid(_player):
		_bind_player()
		if _player == null:
			return
	_hp_bar.value = _player.get_hp_fraction() * 100.0
	_hp_label.text = "HP %3.0f" % _player.get_hp()
	if _god_label:
		var gs := get_node_or_null(^"/root/GameState")
		_god_label.visible = gs != null and gs.devgod
	_speed_label.text = "SPEED %3.0f MPH" % (_player.get_speed() * MPH_PER_PXS)
	if _floor_label:
		_floor_label.visible = _player.floor_index >= 1
		if _floor_label.visible:
			_floor_label.text = "FLOOR %d" % _player.floor_index
	var mg := _player.get_mg_mount()
	if mg:
		_heat_bar.value = mg.heat_fraction() * 100.0
		_heat_label.text = "MG HEAT — LOCKED" if mg.is_locked() else "MG HEAT"
		_heat_label.modulate = Color(1.0, 0.35, 0.3) if mg.is_locked() else Color.WHITE
	var ctrl := _player.get_controller()
	if ctrl:
		_boost_bar.value = ctrl.boost_fuel
	var gs := get_node_or_null(^"/root/GameState")
	if gs:
		for i in _life_pips.size():
			_life_pips[i].color = SELECTED if i < gs.lives else Color(0.2, 0.2, 0.24)
	if _rack:
		for i in _slot_labels.size():
			var lbl: Label = _slot_labels[i]
			# Empty slots vanish (matching the wheel's skip); the special always
			# shows — it recharges — and the selection is never hidden.
			lbl.visible = i == WeaponRack.Slot.SPECIAL \
				or _rack.ammo(i) > 0 or i == _rack.selected_index()
			if not lbl.visible:
				continue
			var name_txt := "—"
			match i:
				WeaponRack.Slot.SPECIAL:
					var def: WeaponDef = _player.stats.special if _player.stats else null
					name_txt = def.display_name if def else "Special"
				WeaponRack.Slot.STANDARD:
					name_txt = "Fire Missile"
				WeaponRack.Slot.HOMING:
					name_txt = "Homing"
				WeaponRack.Slot.POWER:
					name_txt = "Power Missile"
				WeaponRack.Slot.REAR:
					name_txt = "Rear Missile"
				WeaponRack.Slot.MINE:
					name_txt = "Mine"
				WeaponRack.Slot.JUMP_MINE:
					name_txt = "Jump Mine"
			var count := "x%d" % _rack.ammo(i)
			if i == WeaponRack.Slot.SPECIAL and _rack.recharge_fraction() < 1.0:
				count += "  %d%%" % int(_rack.recharge_fraction() * 100.0)
			var marker := "> " if i == _rack.selected_index() else "  "
			lbl.text = "%s%-18s %s" % [marker, name_txt, count]
			lbl.modulate = SELECTED if i == _rack.selected_index() else Color.WHITE

func _bind_player() -> void:
	_player = VehiclesHelper.local(get_tree()) as Vehicle
	_rack = _player.get_rack() if _player else null

func _build_ui() -> void:
	add_child(_gutter_panel(0))
	add_child(_gutter_panel(1280 - GUTTER))
	_build_dash()
	_build_radar()
	_build_opponents()

## Names snapshot once from the first non-empty "enemies" frame (after the
## arena's car re-roll); freed nodes then flip their label to DEAD_TEXT and
## their bar to empty. Bars poll hp fraction while the enemy lives.
func _update_opponents() -> void:
	if _opponents.is_empty():
		for enemy in get_tree().get_nodes_in_group(&"enemies"):
			var lbl := Label.new()
			var stats = enemy.get("stats")
			lbl.text = stats.car_name if stats and stats.car_name != "" else String(enemy.name)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.modulate = ALIVE_TEXT
			_opponents_box.add_child(lbl)
			var bar := _bar(_opponents_box, Color(0.75, 0.2, 0.2), 6)
			bar.value = 100.0
			_opponents.append({"ref": enemy, "label": lbl, "bar": bar})
		return
	for o in _opponents:
		if is_instance_valid(o.ref):
			o.label.modulate = ALIVE_TEXT
			o.bar.value = o.ref.get_hp_fraction() * 100.0
		else:
			o.label.modulate = DEAD_TEXT
			o.bar.value = 0.0

func _build_opponents() -> void:
	var hdr := Label.new()
	hdr.text = "OPPONENTS"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.modulate = DIM_TEXT
	hdr.position = Vector2(1280 - GUTTER + 16, 300)
	add_child(hdr)
	_opponents_box = VBoxContainer.new()
	_opponents_box.position = Vector2(1280 - GUTTER + 20, 324)
	_opponents_box.size = Vector2(GUTTER - 40, 0)
	_opponents_box.add_theme_constant_override("separation", 4)
	add_child(_opponents_box)

func _build_radar() -> void:
	var hdr := Label.new()
	hdr.text = "MAP"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.modulate = DIM_TEXT
	hdr.position = Vector2(1280 - GUTTER + 16, 16)
	add_child(hdr)
	var radar := preload("res://ui/radar.gd").new()
	radar.position = Vector2(1280 - GUTTER + 20, 44)
	radar.size = Vector2(240, 240)
	add_child(radar)

func _gutter_panel(x: int) -> ColorRect:
	var p := ColorRect.new()
	p.color = PANEL_BG
	p.position = Vector2(x, 0)
	p.size = Vector2(GUTTER, VIEW_H)
	return p

func _build_dash() -> void:
	var margin := MarginContainer.new()
	margin.position = Vector2.ZERO
	margin.size = Vector2(GUTTER, VIEW_H)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_god_label = _label(vbox, "DEVGOD", 14)
	_god_label.modulate = Color(1.0, 0.35, 0.3)
	_god_label.visible = false
	_hp_label = _label(vbox, "HP", 20)
	_hp_bar = _bar(vbox, Color(0.75, 0.2, 0.2))
	_hp_bar.value = 100.0
	_speed_label = _label(vbox, "SPEED", 20)
	_floor_label = _label(vbox, "FLOOR", 14)
	_floor_label.modulate = DIM_TEXT
	_floor_label.visible = false  # legacy levels stay pixel-identical
	var lives_hdr := _label(vbox, "LIVES", 14)
	lives_hdr.modulate = DIM_TEXT
	var lives_row := HBoxContainer.new()
	lives_row.add_theme_constant_override("separation", 6)
	vbox.add_child(lives_row)
	for i in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(20, 12)
		pip.color = SELECTED
		_life_pips.append(pip)
		lives_row.add_child(pip)
	vbox.add_child(_spacer(8))
	_heat_label = _label(vbox, "MG HEAT", 14)
	_heat_bar = _bar(vbox, Color(0.95, 0.55, 0.15))
	var boost_label := _label(vbox, "BOOST", 14)
	boost_label.modulate = DIM_TEXT
	_boost_bar = _bar(vbox, Color(0.25, 0.65, 0.9))
	_boost_bar.value = 100.0
	vbox.add_child(_spacer(12))

	var weapons_hdr := _label(vbox, "WEAPONS  (wheel)", 14)
	weapons_hdr.modulate = DIM_TEXT
	for i in 7:
		_slot_labels.append(_label(vbox, "", 15))

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(fill)

	var guide := _label(vbox, "WASD  drive
SHIFT  boost
LCTRL  handbrake
wheel / /  weapon
LMB  machine gun
RMB  fire selected
G  zoom
ESC  menu", 13)
	guide.modulate = DIM_TEXT

func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _bar(parent: Node, color: Color, height := 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
