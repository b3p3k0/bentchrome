extends Control
## Car tuner (dev mode): an editable grid of every roster car's authored
## values over game/car_deck.gd, hosted as a dialog inside Settings ->
## DEVELOPER OPTIONS -> CAR TUNER (the settings funnel owns ESC-to-close).
## Rows = roster order (bosses/buzzards are roster-external, so absent by
## construction); columns = the deck's COLUMNS registry. Every edit applies
## to the loaded .tres singletons (the next arena spawn drives them) and
## saves to user://car_tuner.json; EXPORT writes the hand-back file for
## `tools/migrate_roster_v2.py --fold` — the only path to game truth.
## Deliberately mouse-driven (SpinBoxes) — the one documented dev-tool
## exception to the settings screen's keyboard-only contract.

const PANEL_BG := Color(0.07, 0.07, 0.09, 0.92)
const AMBER := Color(1.0, 0.85, 0.2)
const MPH_PER_PXS := 0.15  # ui/hud.gd display anchor (US units)

# COLUMNS order -> short grid headers.
const HEADERS := {
	"acceleration": "ACC", "top_speed": "TOP", "handling": "HND", "armor": "ARM",
	"special_power": "SPC", "mass": "MASS", "launch": "LNCH",
	"special_ammo_cap": "CAP", "special_recharge_seconds": "RCHG",
	"whip_scale": "WHIP", "side_slide_bonus": "SLIDE",
}

var _grid: GridContainer
var _status: Label

func _deck():
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.has_method("_ensure_tuning"):
		dev._ensure_tuning()
	return dev.car_deck if dev else null

func _ready() -> void:
	_build_ui()
	_regrid()

func _regrid() -> void:
	var deck = _deck()
	if deck == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	_header_cell("CAR")
	for prop in deck.COLUMNS:
		_header_cell(HEADERS.get(prop, prop))
	for id in deck.car_ids:
		var name_lbl := Label.new()
		name_lbl.text = id
		name_lbl.custom_minimum_size = Vector2(96, 0)
		name_lbl.add_theme_font_size_override("font_size", 11)
		_grid.add_child(name_lbl)
		for prop in deck.COLUMNS:
			_grid.add_child(_cell(deck, String(id), String(prop)))

func _header_cell(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = AMBER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid.add_child(lbl)

func _cell(deck, id: String, prop: String) -> SpinBox:
	var box := SpinBox.new()
	var r: Array = deck.COLUMNS[prop]
	box.min_value = float(r[0])
	box.max_value = float(r[1])
	box.step = float(r[2])
	box.set_value_no_signal(deck.get_value(id, prop))
	box.update_on_text_changed = true
	box.custom_minimum_size = Vector2(62, 0)
	box.get_line_edit().add_theme_font_size_override("font_size", 11)
	box.get_line_edit().select_all_on_focus = true
	box.value_changed.connect(func(v: float) -> void:
		deck.set_value(id, prop, v)
		deck.save()
		var dev := get_node_or_null(^"/root/Dev")
		if dev and dev.has_method("reapply_car_stats"):
			dev.reapply_car_stats(id)  # no-op at the title screen; live in-arena
		_status.text = "%s %s = %s  %s   (saved -> user://car_tuner.json)" % [
			id, prop, _fmt(prop, v), _engine_feedback(prop, v)])
	return box

## What the authored int becomes in engine units — US vocabulary.
func _engine_feedback(prop: String, v: float) -> String:
	var s := int(v)
	match prop:
		"top_speed":
			var pxs: float = StatCurves._slot(StatCurves.TOP_SPEED, s)
			return "-> %.1f px/s (%.1f mph)" % [pxs, pxs * MPH_PER_PXS]
		"acceleration":
			return "-> %.1f px/s^2" % StatCurves._slot(StatCurves.ACCELERATION, s)
		"handling":
			return "-> %.1f deg/s, grip %.2f" % [
				StatCurves._slot(StatCurves.TURN_RATE, s), StatCurves._slot(StatCurves.GRIP, s)]
		"armor":
			return "-> %.1f hp" % StatCurves._slot(StatCurves.HP, s)
		"mass":
			return "-> engine mass %.1f" % ((v + 1.0) / 2.0)
		"launch":
			return "-> derived from mass" if s < 1 \
				else "-> launch factor %.2f" % StatCurves._slot(StatCurves.LAUNCH, s)
		"whip_scale":
			return "-> handbrake-180 rate x%.2f" % v
		"side_slide_bonus":
			return "-> broadside ram x%.2f" % v
	return ""

const FLOAT_PROPS := ["special_recharge_seconds", "whip_scale", "side_slide_bonus"]

func _fmt(prop: String, v: float) -> String:
	if prop == "special_recharge_seconds":
		return "%.1f" % v
	return "%.2f" % v if prop in FLOAT_PROPS else str(int(v))

func _on_export() -> void:
	var deck = _deck()
	var path: String = deck.export_file()
	deck.save()
	_status.text = "EXPORTED — make it game truth:  python3 tools/migrate_roster_v2.py --fold '%s'" % path
	print("[car tuner] exported: ", path)

func _on_reset() -> void:
	var deck = _deck()
	deck.reset_all()
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.has_method("reapply_car_stats"):
		for id in deck.car_ids:
			dev.reapply_car_stats(String(id))
	_regrid()
	_status.text = "reset every car to roster truth"

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CAR TUNER — roster stats, 1-20 scale"
	title.modulate = AMBER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 1 + HEADERS.size()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(_grid)

	var buttons := HBoxContainer.new()
	var export_btn := Button.new()
	export_btn.text = "Export"
	export_btn.pressed.connect(_on_export)
	buttons.add_child(export_btn)
	var reset_btn := Button.new()
	reset_btn.text = "Reset all to roster"
	reset_btn.pressed.connect(_on_reset)
	buttons.add_child(reset_btn)
	vbox.add_child(buttons)

	_status = Label.new()
	_status.text = "mouse edits apply + save immediately; Export hands values back for --fold; ESC closes"
	_status.add_theme_font_size_override("font_size", 11)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(680, 0)
	_status.modulate = Color(0.55, 0.58, 0.62)
	vbox.add_child(_status)
