extends CanvasLayer
## Gameplay HUD. The 1280x720 frame is a centered 720x720 play square with a
## 280px opaque gutter each side: left = dash (vitals, MG heat, weapon slots,
## keyguide), right = radar (ui/radar.gd). Poll-driven — reads the player each
## frame via the "player" group; survives player death/restart by re-binding.

const GUTTER := 280
const VIEW_H := 720
const PANEL_BG := Color(0.07, 0.07, 0.09)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const SELECTED := Color(1.0, 0.85, 0.2)
const ALIVE_TEXT := Color(0.8, 0.82, 0.86)   # soft white — pure white glares
const DEAD_TEXT := Color(0.55, 0.14, 0.14)   # dark red for the wrecked

var _player: Vehicle
var _rack: WeaponRack
var _opponents: Array = []  # each: {ref: Vehicle, label: Label}; snapshot at round start
var _opponents_box: VBoxContainer

var _hp_bar: ProgressBar
var _hp_label: Label
var _speed_label: Label
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
	_speed_label.text = "SPEED %4.0f" % _player.get_speed()
	var mg := _player.get_mg_mount()
	if mg:
		_heat_bar.value = mg.heat_fraction() * 100.0
		_heat_label.text = "MG HEAT — LOCKED" if mg.is_locked() else "MG HEAT"
		_heat_label.modulate = Color(1.0, 0.35, 0.3) if mg.is_locked() else Color.WHITE
	var ctrl := _player.get_controller()
	if ctrl:
		_boost_bar.value = ctrl.boost_fuel * 100.0
	if _rack:
		for i in _slot_labels.size():
			var lbl: Label = _slot_labels[i]
			var def: WeaponDef = null
			var name_txt := "—"
			if i == WeaponRack.Slot.SPECIAL:
				def = _player.stats.special if _player.stats else null
				name_txt = def.display_name if def else "Special"
			elif i == WeaponRack.Slot.STANDARD:
				name_txt = "Missile"
			else:
				name_txt = "Homing"
			var count := "x%d" % _rack.ammo(i)
			if i == WeaponRack.Slot.SPECIAL and _rack.recharge_fraction() < 1.0:
				count += "  %d%%" % int(_rack.recharge_fraction() * 100.0)
			var marker := "> " if i == _rack.selected_index() else "  "
			lbl.text = "%s%-18s %s" % [marker, name_txt, count]
			lbl.modulate = SELECTED if i == _rack.selected_index() else Color.WHITE

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Vehicle
	_rack = _player.get_rack() if _player else null

func _build_ui() -> void:
	add_child(_gutter_panel(0))
	add_child(_gutter_panel(1280 - GUTTER))
	_build_dash()
	_build_radar()
	_build_opponents()

## Names snapshot once from the first non-empty "enemies" frame (after the
## arena's car re-roll); freed nodes then flip their label to DEAD_TEXT.
func _update_opponents() -> void:
	if _opponents.is_empty():
		for enemy in get_tree().get_nodes_in_group(&"enemies"):
			var lbl := Label.new()
			var stats = enemy.get("stats")
			lbl.text = stats.car_name if stats and stats.car_name != "" else String(enemy.name)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.modulate = ALIVE_TEXT
			_opponents_box.add_child(lbl)
			_opponents.append({"ref": enemy, "label": lbl})
		return
	for o in _opponents:
		o.label.modulate = ALIVE_TEXT if is_instance_valid(o.ref) else DEAD_TEXT

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
	hdr.text = "RADAR"
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

	_hp_label = _label(vbox, "HP", 20)
	_hp_bar = _bar(vbox, Color(0.75, 0.2, 0.2))
	_hp_bar.value = 100.0
	_speed_label = _label(vbox, "SPEED", 20)
	vbox.add_child(_spacer(8))
	_heat_label = _label(vbox, "MG HEAT", 14)
	_heat_bar = _bar(vbox, Color(0.95, 0.55, 0.15))
	var boost_label := _label(vbox, "BOOST", 14)
	boost_label.modulate = DIM_TEXT
	_boost_bar = _bar(vbox, Color(0.25, 0.65, 0.9))
	_boost_bar.value = 100.0
	vbox.add_child(_spacer(12))

	var weapons_hdr := _label(vbox, "WEAPONS  (Q/E)", 14)
	weapons_hdr.modulate = DIM_TEXT
	for i in 3:
		_slot_labels.append(_label(vbox, "", 15))

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(fill)

	var guide := _label(vbox, "WASD  drive
SHIFT  boost
Q/E/wheel  weapon
LMB  fire selected
RMB  machine gun
ESC  menu", 13)
	guide.modulate = DIM_TEXT

func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _bar(parent: Node, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
