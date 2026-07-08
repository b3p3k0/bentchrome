extends Control
## Settings screen (title menu -> SETTINGS). Keyboard-driven rows: up/down
## selects, left/right adjusts (Enter also nudges), ESC returns to the title.
## Every change persists immediately via GameState.save_settings().

const AMBER := Color(1.0, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const ALIVE_TEXT := Color(0.8, 0.82, 0.86)
const WARN := Color(1.0, 0.35, 0.3)

const ZOOM_MIN := 0.45
const ZOOM_MAX := 0.72
const ZOOM_STEP := 0.01

var _index := 0
var _rows: Array = []  # {name, adjust: Callable(dir), value: Callable() -> [text, color]}
var _name_labels: Array = []
var _value_labels: Array = []

@onready var _gs: Node = get_node(^"/root/GameState")
@onready var _flow: Node = get_node(^"/root/SceneFlow")

func _ready() -> void:
	_rows = [
		{"name": "DEVGOD", "adjust": _adj_devgod, "value": _val_devgod},
		{"name": "ZOOM DEPTH", "adjust": _adj_zoom, "value": _val_zoom},
		{"name": "START LEVEL", "adjust": _adj_level, "value": _val_level},
		{"name": "SCREEN SHAKE", "adjust": _adj_shake, "value": _val_shake},
		{"name": "DEVELOPER MODE", "adjust": _adj_dev, "value": _val_dev},
		{"name": "RESET TO DEFAULTS", "adjust": _adj_reset, "value": _val_blank},
		{"name": "BACK", "adjust": _adj_back, "value": _val_blank},
	]
	_build_ui()
	_refresh()

# --- row behaviors -----------------------------------------------------------

func _adj_devgod(_d: int) -> void:
	_gs.devgod = not _gs.devgod

func _val_devgod() -> Array:
	return ["ON — INVINCIBLE" if _gs.devgod else "OFF", WARN if _gs.devgod else DIM_TEXT]

func _adj_zoom(d: int) -> void:
	_gs.zoom_combat = clampf(_gs.zoom_combat + d * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

func _val_zoom() -> Array:
	return ["%.2f  %s" % [_gs.zoom_combat, _bar(_gs.zoom_combat, ZOOM_MIN, ZOOM_MAX)], DIM_TEXT]

func _adj_level(d: int) -> void:
	_gs.start_level_index = wrapi(_gs.start_level_index + (d if d != 0 else 1), 0, _flow.CAMPAIGN.size())

func _val_level() -> Array:
	return [String(_flow.CAMPAIGN[_gs.start_level_index].name).to_upper(), DIM_TEXT]

func _adj_shake(_d: int) -> void:
	_gs.screen_shake = not _gs.screen_shake

func _val_shake() -> Array:
	return ["ON" if _gs.screen_shake else "OFF", DIM_TEXT]

func _adj_dev(_d: int) -> void:
	_gs.dev_mode = not _gs.dev_mode
	_sync_dev()

func _val_dev() -> Array:
	return ["ON" if _gs.dev_mode else "OFF", AMBER if _gs.dev_mode else DIM_TEXT]

func _adj_reset(_d: int) -> void:
	_gs.reset_settings()
	_sync_dev()

func _adj_back(_d: int) -> void:
	_flow.to_title()

func _val_blank() -> Array:
	return ["", DIM_TEXT]

func _sync_dev() -> void:
	var dev := get_node_or_null(^"/root/Dev")
	if dev:
		dev.enabled = _gs.dev_mode

func _bar(v: float, lo: float, hi: float) -> String:
	var filled := int(round((v - lo) / (hi - lo) * 10.0))
	return "[" + "#".repeat(filled) + "-".repeat(10 - filled) + "]"

# --- input / paint -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_flow.to_title()
		return
	if event.is_action_pressed(&"move_up"):
		_index = wrapi(_index - 1, 0, _rows.size())
	elif event.is_action_pressed(&"move_down"):
		_index = wrapi(_index + 1, 0, _rows.size())
	elif event.is_action_pressed(&"select_prev"):
		_adjust(-1)
		return
	elif event.is_action_pressed(&"select_next") or event.is_action_pressed(&"select_confirm"):
		_adjust(1)
		return
	else:
		return
	_refresh()

func _adjust(dir: int) -> void:
	(_rows[_index].adjust as Callable).call(dir)
	_gs.save_settings()
	_refresh()

func _refresh() -> void:
	for i in _rows.size():
		var selected := i == _index
		_name_labels[i].modulate = AMBER if selected else ALIVE_TEXT
		var v: Array = (_rows[i].value as Callable).call()
		_value_labels[i].text = v[0]
		_value_labels[i].modulate = v[1]

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = AMBER
	vbox.add_child(title)

	for row in _rows:
		var hbox := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = row.name
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		var value_lbl := Label.new()
		value_lbl.add_theme_font_size_override("font_size", 22)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value_lbl)
		vbox.add_child(hbox)
		_name_labels.append(name_lbl)
		_value_labels.append(value_lbl)

	var hint := Label.new()
	hint.text = "W/S select    A/D adjust    ESC back  —  saved to user://settings.json"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)
