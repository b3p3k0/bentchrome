extends Control
## The playable-garage SIM HARNESS (feature/garage phase 1): a fake 9-stop
## campaign that rolls level outcomes through the REAL economy math, prints
## an itemized BOLTS receipt with the % arithmetic visible, then offers the
## KEEP ROLLIN' / PIT STOP fork into the real shop. Difficulty selector,
## force-toggles, and an economy knob panel (export -> user://econ_export.json)
## make this the tune-by-playing bench. Launch it scene-direct:
##   godot --path . res://ui/garage/garage_playable.tscn
## Nothing in the live game references this scene.

const Economy := preload("res://game/economy.gd")
const Difficulty := preload("res://game/difficulty.gd")
const UiStyle := preload("res://ui/ui_style.gd")
const GarageScene := preload("res://ui/garage/garage.tscn")

const AMBER := Color(1.0, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const ALIVE := Color(0.8, 0.82, 0.86)
const DIM := Color(0.55, 0.58, 0.62)
const RED := Color(0.75, 0.2, 0.2)
const GOOD := Color(0.5, 0.84, 0.59)

# smashable size pool: [max_hp, name] — mirrors the live destructible zoo
const SMASH_POOL := [[1.0, "mailbox"], [1.0, "bystander"], [12.0, "chain-link"],
	[15.0, "picket fence"], [25.0, "crate"], [40.0, "fuel barrel"],
	[50.0, "derelict car"], [80.0, "kiosk"], [140.0, "container"], [220.0, "generator"]]

var _cars: Array = []
var _car_index := 0
var _owned: Array = []
var _stop := 0            # index into the campaign name list
var _levels: Array = []
var _fork_panel: Control
var _receipt: RichTextLabel
var _headline: Label
var _wallet: Label
var _shop: Control
var _car_pick: OptionButton
var _diff_pick: OptionButton
var _toggles := {}        # &"destroyed"/&"fall"/&"station" -> CheckBox
var _knob_boxes := {}
var _knob_status: Label
var _pit_btn: Button
var _roll_btn: Button

func _ready() -> void:
	_levels = _campaign_names()
	_load_cars()
	Economy.enabled = true  # the sim harness IS an economy consumer
	Economy.reset_run()
	_build_ui()
	_refresh()

func _campaign_names() -> Array:
	var flow := get_node_or_null(^"/root/SceneFlow")
	var names: Array = []
	if flow != null and "CAMPAIGN" in flow:
		for entry in flow.CAMPAIGN:
			names.append(String(entry.name))
	if names.is_empty():  # headless-safe fallback
		names = ["Downtown Derby", "Freeway Firefight", "Suburban Slaughter",
			"Mountainside Mayhem", "Lackey's Arena", "Route 666 Roulette",
			"Piers of Pain", "Ground Floor Gore", "Goliath's Arena"]
	return names

func _load_cars() -> void:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/data/roster.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return
	for c in data.get("characters", []):
		var vs: Variant = load("res://data/vehicles/%s.tres" % c.get("id", ""))
		if vs:
			_cars.append(vs)

## --- the level roll ------------------------------------------------------------

func _run_level() -> void:
	Economy.reset_level()
	var lines: Array = []
	var name: String = _levels[_stop]
	var is_boss := name.contains("Lackey") or name.contains("Goliath")
	var is_chase := name.contains("Route 666")

	if is_chase:
		for i in randi_range(8, 14):
			lines.append(["+%d" % Economy.award_kill(&"chase"), "KILL — buzzard"])
	else:
		for i in randi_range(4, 7):
			lines.append(["+%d" % Economy.award_kill(&"mook"), "KILL — mook"])
	if is_boss:
		lines.append(["+%d" % Economy.award_kill(&"boss"), "KILL — %s" % ("LACKEY" if name.contains("Lackey") else "GOLIATH")])

	var tapped := false
	for i in randi_range(6, 14):
		var pick: Array = SMASH_POOL[randi_range(0, SMASH_POOL.size() - 1)]
		var paid := Economy.award_salvage(pick[0])
		if paid > 0:
			lines.append(["+%d" % paid, "SALVAGE — %s (%d hp)" % [pick[1], int(pick[0])]])
		elif not tapped:
			lines.append(["", "SALVAGE TAPPED — cap %d reached" % Economy.SALVAGE_CAP])
			tapped = true

	# misfortune: manual toggles always fire; otherwise dice
	_misfortune(lines, &"destroyed", "DESTROYED", Economy.PENALTY_DESTROYED, 0.30)
	_misfortune(lines, &"fall", "FELL/SANK", Economy.PENALTY_FALL, 0.12)
	_misfortune(lines, &"station", "HEALTH STATION", Economy.PENALTY_STATION, 0.35)

	_show_receipt(name, lines)

func _misfortune(lines: Array, kind: StringName, label: String, frac: float, chance: float) -> void:
	var forced: bool = _toggles[kind].button_pressed
	if not forced and randf() > chance:
		return
	var before := Economy.funds
	var taken := Economy.apply_penalty(kind)
	var pct := int(round(frac * Difficulty.knob(&"penalty_scale") * 100.0))
	lines.append(["-%d" % taken, "%s (−%d%% of %s)%s" % [label, pct, _fmt(before),
		"  [forced]" if forced else ""]])

func _show_receipt(level_name: String, lines: Array) -> void:
	_headline.text = "STOP %d/%d — %s CLEARED" % [_stop + 1, _levels.size(), level_name.to_upper()]
	_receipt.clear()
	for line in lines:
		var amount: String = line[0]
		var color := "#7fd696" if amount.begins_with("+") else ("#e08a8a" if amount.begins_with("-") else "#8c949e")
		_receipt.append_text("[color=%s]%6s[/color]  [color=#ccd1d9]%s[/color]\n" % [color, amount, line[1]])
	_receipt.append_text("\n[color=#ffd833]WALLET: ⚙ %s[/color]\n" % _fmt(Economy.funds))
	_refresh()

## --- flow -----------------------------------------------------------------------

func _keep_rolling() -> void:
	if _stop + 1 >= _levels.size():
		_headline.text = "RUN COMPLETE — ⚙ %s banked, %d parts bolted on" % \
			[_fmt(Economy.funds), _owned.size()]
		_receipt.clear()
		_receipt.append_text("[color=#8c949e]RESET RUN to go again with fresh knobs.[/color]\n")
		return
	_stop += 1
	_run_level()

func _open_shop() -> void:
	_shop.setup(_cars[_car_index], _owned, "NEXT: %s" %
		_levels[mini(_stop + 1, _levels.size() - 1)].to_upper())
	_shop.visible = true
	_fork_panel.visible = false

func _close_shop() -> void:
	_shop.visible = false
	_fork_panel.visible = true
	_refresh()

func _reset_run() -> void:
	Economy.reset_run()
	_owned.clear()
	_stop = 0
	_headline.text = "FRESH RUN — hit RUN LEVEL to clear %s" % _levels[0].to_upper()
	_receipt.clear()
	_refresh()

func _refresh() -> void:
	_wallet.text = "⚙ %s" % _fmt(Economy.funds)

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

## --- knobs -----------------------------------------------------------------------

func _apply_knobs() -> void:
	Economy.KILL_REWARDS[&"mook"] = int(_knob_boxes["mook"].value)
	Economy.SALVAGE_CAP = int(_knob_boxes["cap"].value)
	Economy.PENALTY_DESTROYED = _knob_boxes["destroyed"].value / 100.0
	Economy.PENALTY_FALL = _knob_boxes["fall"].value / 100.0
	Economy.PENALTY_STATION = _knob_boxes["station"].value / 100.0
	_knob_status.text = "knobs live — next receipt uses them"

func _export_knobs() -> void:
	var f := FileAccess.open("user://econ_export.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(Economy.snapshot(), "\t"))
		f.close()
	var path := ProjectSettings.globalize_path("user://econ_export.json")
	_knob_status.text = "EXPORTED -> " + path
	print("[garage sim] exported: ", path)

## --- build -----------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_fork_panel = MarginContainer.new()
	_fork_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_fork_panel.add_theme_constant_override("margin_" + side, 24)
	add_child(_fork_panel)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 20)
	_fork_panel.add_child(main)

	# left: receipt
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	main.add_child(left_col)
	var head_row := HBoxContainer.new()
	_headline = Label.new()
	_headline.text = "GARAGE SIM — hit RUN LEVEL to clear %s" % _levels[0].to_upper()
	_headline.add_theme_font_size_override("font_size", 22)
	_headline.modulate = AMBER
	_headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(_headline)
	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 22)
	_wallet.modulate = AMBER
	head_row.add_child(_wallet)
	left_col.add_child(head_row)

	var receipt_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	receipt_panel.add_theme_stylebox_override("panel", style)
	receipt_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(receipt_panel)
	_receipt = RichTextLabel.new()
	_receipt.bbcode_enabled = true
	_receipt.add_theme_font_size_override("normal_font_size", 15)
	_receipt.append_text("[color=#8c949e]The receipt prints here — every bolt itemized.[/color]\n")
	receipt_panel.add_child(_receipt)

	var fork_row := HBoxContainer.new()
	fork_row.add_theme_constant_override("separation", 10)
	_roll_btn = _btn(fork_row, "RUN LEVEL", _run_level)
	_btn(fork_row, "KEEP ROLLIN' →", _keep_rolling)
	_pit_btn = _btn(fork_row, "PIT STOP (garage)", _open_shop)
	_btn(fork_row, "RESET RUN", _reset_run)
	left_col.add_child(fork_row)

	# right: controls
	var ctl := VBoxContainer.new()
	ctl.custom_minimum_size = Vector2(340, 0)
	ctl.add_theme_constant_override("separation", 8)
	main.add_child(ctl)
	_label(ctl, "RIDE", AMBER, 16)
	_car_pick = OptionButton.new()
	for car in _cars:
		_car_pick.add_item(car.car_name)
	_car_pick.item_selected.connect(func(i: int) -> void:
		_car_index = i
		_owned.clear())  # new ride = fresh build (sim convenience)
	ctl.add_child(_car_pick)
	_label(ctl, "DIFFICULTY", AMBER, 16)
	_diff_pick = OptionButton.new()
	for tier in [Difficulty.Tier.EASY, Difficulty.Tier.MEDIUM, Difficulty.Tier.HARD]:
		_diff_pick.add_item(Difficulty.NAMES[tier])
	_diff_pick.select(2)
	_diff_pick.item_selected.connect(func(i: int) -> void: Difficulty.tier = i)
	ctl.add_child(_diff_pick)

	_label(ctl, "FORCE MISFORTUNE (per run)", AMBER, 16)
	for entry in [[&"destroyed", "get destroyed"], [&"fall", "fall in a pit / sink"],
			[&"station", "use a health station"]]:
		var cb := CheckBox.new()
		cb.text = entry[1]
		ctl.add_child(cb)
		_toggles[entry[0]] = cb

	_label(ctl, "ECONOMY KNOBS", AMBER, 16)
	_knob(ctl, "mook", "mook kill ⚙", 100, 5000, 50, Economy.KILL_REWARDS[&"mook"])
	_knob(ctl, "cap", "salvage cap ⚙", 0, 10000, 250, Economy.SALVAGE_CAP)
	_knob(ctl, "destroyed", "destroyed %", 0, 90, 1, Economy.PENALTY_DESTROYED * 100.0)
	_knob(ctl, "fall", "fall/sink %", 0, 90, 1, Economy.PENALTY_FALL * 100.0)
	_knob(ctl, "station", "station %", 0, 90, 1, Economy.PENALTY_STATION * 100.0)
	var knob_row := HBoxContainer.new()
	knob_row.add_theme_constant_override("separation", 8)
	_btn(knob_row, "APPLY KNOBS", _apply_knobs)
	_btn(knob_row, "EXPORT", _export_knobs)
	ctl.add_child(knob_row)
	_knob_status = Label.new()
	_knob_status.add_theme_font_size_override("font_size", 12)
	_knob_status.modulate = DIM
	_knob_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctl.add_child(_knob_status)

	# the shop, hidden until PIT STOP
	_shop = GarageScene.instantiate()
	_shop.visible = false
	_shop.left.connect(_close_shop)
	add_child(_shop)
	_roll_btn.grab_focus()  # keyboard-only from the first frame

func _btn(parent: Node, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UiStyle.theme_button(b)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b

func _label(parent: Node, text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	parent.add_child(l)

func _knob(parent: Node, key: String, text: String, lo: float, hi: float, step: float, value: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = ALIVE
	row.add_child(l)
	var box := SpinBox.new()
	box.min_value = lo
	box.max_value = hi
	box.step = step
	box.value = value
	row.add_child(box)
	_knob_boxes[key] = box
	parent.add_child(row)
