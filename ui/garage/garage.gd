extends Control
## The PIT STOP shop (Concept B, docs/garage/ui_concepts.md): category tabs,
## item cards with owned/locked/short states, and a YOUR RIDE panel whose
## stat bars preview the highlighted part in amber BEFORE you buy — the
## preview runs the real VehicleLoadout.compose seam, so what you see is
## exactly what the plug-in phase will apply. Wallet is game/economy.gd's
## BOLTS. Standalone on feature/garage: nothing in the live flow opens this.
##
## API: setup(stats, owned, next_level_name) — `owned` is the caller's array
## (mutated in place; the harness carries it between stops). ESC emits
## `left` (KEEP ROLLIN'). Mouse and W/S/A/D/arrows + ENTER both work
## (car-select convention, not the settings arrow contract).

signal left
signal bought(item_id: String)

const Economy := preload("res://game/economy.gd")
const Catalog := preload("res://ui/garage/garage_catalog.gd")
const UiStyle := preload("res://ui/ui_style.gd")
const CarPaint := preload("res://vehicles/car_paint.gd")  # no class_name — path per house rule

const AMBER := Color(1.0, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const ALIVE := Color(0.8, 0.82, 0.86)
const DIM := Color(0.55, 0.58, 0.62)
const LOCKED := Color(0.32, 0.34, 0.37)
const RED := Color(0.75, 0.2, 0.2)
const GOOD := Color(0.5, 0.84, 0.59)
const MPH_PER_PXS := 0.15
const BAR_STATS := ["acceleration", "top_speed", "handling", "armor"]
const BAR_LABELS := {"acceleration": "ACC", "top_speed": "TOP", "handling": "HND", "armor": "ARM"}

var stats: VehicleStats
var owned: Array = []
var next_level_name := ""

var _items: Array = []
var _by_id := {}
var _cat_index := 0
var _item_index := 0
var _wallet: Label
var _tab_buttons: Array = []
var _cards_box: VBoxContainer
var _cards_scroll: ScrollContainer
var _turntable: Node2D
var _ride_name: Label
var _bar_rows := {}   # stat -> Array[ColorRect]
var _bar_values := {} # stat -> Label
var _installed: Label
var _status: Label

func _ready() -> void:
	_items = Catalog.load_catalog()
	for item in _items:
		_by_id[String(item.id)] = item
	_build_ui()

func setup(ride: VehicleStats, owned_ref: Array, next_name: String) -> void:
	stats = ride
	owned = owned_ref
	next_level_name = next_name
	_item_index = 0
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			UiSfx.back(self)
			left.emit()
		KEY_S, KEY_DOWN:
			_move_item(1)
		KEY_W, KEY_UP:
			_move_item(-1)
		KEY_D, KEY_RIGHT:
			_move_cat(1)
		KEY_A, KEY_LEFT:
			_move_cat(-1)
		KEY_ENTER, KEY_KP_ENTER:
			_try_buy(_selected_item())

func _move_item(dir: int) -> void:
	var pool := _cat_items()
	if pool.is_empty():
		return
	_item_index = wrapi(_item_index + dir, 0, pool.size())
	UiSfx.move(self)
	_refresh()

func _move_cat(dir: int) -> void:
	_cat_index = wrapi(_cat_index + dir, 0, Catalog.categories().size())
	_item_index = 0
	UiSfx.move(self)
	_refresh()

func _cat_items() -> Array:
	var cat: String = Catalog.categories()[_cat_index]
	return _items.filter(func(i): return String(i.category) == cat)

func _selected_item() -> Dictionary:
	var pool := _cat_items()
	return pool[_item_index] if _item_index < pool.size() else {}

## --- purchase rules -----------------------------------------------------------

func item_state(item: Dictionary) -> StringName:
	if item.is_empty():
		return &"none"
	if String(item.id) in owned:
		return &"owned"
	var req := String(item.get("requires", ""))
	if not req.is_empty() and req not in owned:
		return &"locked"
	if Economy.price(int(item.price)) > Economy.funds:
		return &"short"
	return &"buyable"

func _try_buy(item: Dictionary) -> void:
	if item_state(item) != &"buyable":
		UiSfx.back(self)
		return
	Economy.funds -= Economy.price(int(item.price))
	var slot := String(item.get("exclusive_slot", ""))
	if not slot.is_empty():  # swaps replace each other; no refunds in the wasteland
		for other in _items:
			if String(other.get("exclusive_slot", "")) == slot and String(other.id) in owned:
				owned.erase(String(other.id))
	owned.append(String(item.id))
	UiSfx.select(self)
	bought.emit(String(item.id))
	_refresh()

## --- preview math (the real seam) ----------------------------------------------

func _owned_mods() -> Array:
	var mods: Array = []
	for id in owned:
		if _by_id.has(id):
			mods.append(Catalog.as_mod(_by_id[id]))
	return mods

func _composed(with_item: Dictionary = {}) -> VehicleStats:
	var mods := _owned_mods()
	if not with_item.is_empty() and item_state(with_item) in [&"buyable", &"short", &"locked"]:
		mods.append(Catalog.as_mod(with_item))
	return VehicleLoadout.compose(stats, mods)

## --- paint ---------------------------------------------------------------------

func _refresh() -> void:
	if stats == null:
		return
	_wallet.text = "⚙ %s" % _fmt(Economy.funds)
	_ride_name.text = "%s — %s" % [stats.car_name.to_upper(), next_level_name]
	_turntable.apply(stats.id, stats.primary_color, stats.accent_color)
	for i in _tab_buttons.size():
		var cat: String = Catalog.categories()[i]
		var owned_n := 0
		var total_n := 0
		for item in _items:
			if String(item.category) == cat:
				total_n += 1
				if String(item.id) in owned:
					owned_n += 1
		_tab_buttons[i].text = "%s  %d/%d" % [cat, owned_n, total_n]
		_tab_buttons[i].modulate = AMBER if i == _cat_index else ALIVE
	_paint_bars()
	_paint_cards()
	var names: Array = []
	for id in owned:
		if _by_id.has(id):
			names.append(String(_by_id[id].display_name))
	_installed.text = "INSTALLED: " + (", ".join(names) if names.size() > 0 else "— stock ride —")

func _paint_bars() -> void:
	var now := _composed()
	var preview := _composed(_selected_item())
	for stat in BAR_STATS:
		var base_v: int = int(now.get(stat))
		var prev_v: int = int(preview.get(stat))
		var cells: Array = _bar_rows[stat]
		for i in cells.size():
			var v := i + 1
			var c: ColorRect = cells[i]
			if v <= mini(base_v, prev_v):
				c.color = ALIVE
			elif v <= prev_v:
				c.color = AMBER          # gained by the highlighted part
			elif v <= base_v:
				c.color = RED            # lost to its tradeoff
			else:
				c.color = Color(0.16, 0.16, 0.2)
		var txt := str(base_v) if prev_v == base_v else "%d→%d" % [base_v, prev_v]
		if stat == "top_speed":
			var mph: float = StatCurves._slot(StatCurves.TOP_SPEED, prev_v) * MPH_PER_PXS
			txt += "  (%.0f mph)" % mph
		_bar_values[stat].text = txt
		_bar_values[stat].modulate = AMBER if prev_v != base_v else DIM

func _paint_cards() -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	var pool := _cat_items()
	var selected: Control = null
	for i in pool.size():
		var card := _card(pool[i], i == _item_index, i)
		_cards_box.add_child(card)
		if i == _item_index:
			selected = card
	if selected:  # cards land next frame; scroll once layout knows their rects
		_scroll_to.call_deferred(selected)

func _scroll_to(card: Control) -> void:
	if is_instance_valid(card) and _cards_scroll:
		_cards_scroll.ensure_control_visible(card)

func _card(item: Dictionary, selected: bool, index: int) -> PanelContainer:
	var state := item_state(item)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.13) if selected else PANEL_BG
	style.border_color = AMBER if selected else Color(0.23, 0.23, 0.27)
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	# Illustration slot: placeholder PNGs today (assets/img/garage/items/),
	# real art drops in by filename with zero code changes. Missing = skipped.
	var art_path := "res://assets/img/garage/items/%s.png" % String(item.id)
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.custom_minimum_size = Vector2(128, 96)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.modulate = Color(0.45, 0.45, 0.5) if state in [&"locked", &"owned"] else Color.WHITE
		row.add_child(art)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vbox)

	var head := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = String(item.display_name)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.modulate = LOCKED if state == &"locked" else (DIM if state == &"owned" else ALIVE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_lbl)
	var price_lbl := Label.new()
	price_lbl.add_theme_font_size_override("font_size", 17)
	match state:
		&"owned":
			price_lbl.text = "OWNED"
			price_lbl.modulate = GOOD
		&"short":
			price_lbl.text = "⚙ %s" % _fmt(Economy.price(int(item.price)))
			price_lbl.modulate = RED
		_:
			price_lbl.text = "⚙ %s" % _fmt(Economy.price(int(item.price)))
			price_lbl.modulate = AMBER if state == &"buyable" else LOCKED
	head.add_child(price_lbl)
	vbox.add_child(head)

	var blurb := Label.new()
	blurb.text = String(item.get("blurb", ""))
	blurb.add_theme_font_size_override("font_size", 13)
	blurb.modulate = DIM if state != &"locked" else LOCKED
	vbox.add_child(blurb)
	# The systems line: what the part actually does when the stat bars can't
	# show it (terrain overlays, sensor/heat/tracking scales, cap bonus).
	var effect := String(item.get("effect_text", ""))
	if not effect.is_empty():
		var fx_lbl := Label.new()
		fx_lbl.text = effect
		fx_lbl.add_theme_font_size_override("font_size", 13)
		fx_lbl.modulate = AMBER if state != &"locked" else LOCKED
		vbox.add_child(fx_lbl)
	var tradeoff := String(item.get("tradeoff_text", ""))
	if not tradeoff.is_empty():
		var trade_lbl := Label.new()
		trade_lbl.text = tradeoff
		trade_lbl.add_theme_font_size_override("font_size", 13)
		trade_lbl.modulate = Color(0.88, 0.54, 0.54) if state != &"locked" else LOCKED
		vbox.add_child(trade_lbl)

	var foot := Label.new()
	foot.add_theme_font_size_override("font_size", 12)
	match state:
		&"locked":
			var req: Dictionary = _by_id.get(String(item.get("requires", "")), {})
			foot.text = "REQUIRES: %s" % String(req.get("display_name", item.get("requires", "?")))
			foot.modulate = LOCKED
		&"short":
			foot.text = "SHORT %s ⚙ — smash something next level" % \
				_fmt(Economy.price(int(item.price)) - Economy.funds)
			foot.modulate = RED
		&"buyable":
			foot.text = "[ENTER] BUY" if selected else ""
			foot.modulate = AMBER
		&"owned":
			foot.text = "bolted on"
			foot.modulate = LOCKED
	vbox.add_child(foot)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			if _item_index == index:
				_try_buy(item)
			else:
				_item_index = index
				UiSfx.move(self)
				_refresh())
	return panel

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

## --- build ----------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Garage interior placeholder (assets/img/garage/bg.png) — real art drops
	# in by filename; the ColorRect beneath stays as the no-file fallback.
	if ResourceLoader.exists("res://assets/img/garage/bg.png"):
		var bg_art := TextureRect.new()
		bg_art.texture = load("res://assets/img/garage/bg.png")
		bg_art.stretch_mode = TextureRect.STRETCH_SCALE
		bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_art.modulate = Color(1, 1, 1, 0.5)  # keep the cards readable over it
		add_child(bg_art)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 32)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "PIT STOP — MOE'S PARTS CATALOG"
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = AMBER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 24)
	_wallet.modulate = AMBER
	header.add_child(_wallet)
	col.add_child(header)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(main)

	# left column: tabs + ride
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(430, 0)
	left_col.add_theme_constant_override("separation", 6)
	main.add_child(left_col)
	for i in Catalog.categories().size():
		var b := Button.new()
		UiStyle.theme_button(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Tabs never take GUI focus: focused Buttons eat arrows/Enter before
		# _unhandled_input, which is why W/S "stopped working" — the shop's
		# selection model owns the keyboard, buttons stay mouse-clickable.
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			_cat_index = i
			_item_index = 0
			UiSfx.move(self)
			_refresh())
		left_col.add_child(b)
		_tab_buttons.append(b)

	var ride_panel := PanelContainer.new()
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = PANEL_BG
	rp_style.border_color = Color(0.23, 0.23, 0.27)
	for side in ["left", "right", "top", "bottom"]:
		rp_style.set("border_width_" + side, 3)
	ride_panel.add_theme_stylebox_override("panel", rp_style)
	ride_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(ride_panel)
	var rp_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rp_margin.add_theme_constant_override("margin_" + side, 12)
	ride_panel.add_child(rp_margin)
	var ride_box := VBoxContainer.new()
	ride_box.add_theme_constant_override("separation", 6)
	rp_margin.add_child(ride_box)
	_ride_name = Label.new()
	_ride_name.add_theme_font_size_override("font_size", 15)
	_ride_name.modulate = ALIVE
	ride_box.add_child(_ride_name)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 120)
	ride_box.add_child(stage)
	_turntable = CarPaint.new()
	_turntable.position = Vector2(200, 60)
	_turntable.scale = Vector2.ONE * 2.4
	stage.add_child(_turntable)

	for stat in BAR_STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var lbl := Label.new()
		lbl.text = BAR_LABELS[stat]
		lbl.custom_minimum_size = Vector2(44, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.modulate = DIM
		row.add_child(lbl)
		var cells: Array = []
		for i in 20:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(11, 13)
			row.add_child(cell)
			cells.append(cell)
		_bar_rows[stat] = cells
		var val := Label.new()
		val.custom_minimum_size = Vector2(110, 0)
		val.add_theme_font_size_override("font_size", 13)
		row.add_child(val)
		_bar_values[stat] = val
		ride_box.add_child(row)

	_installed = Label.new()
	_installed.add_theme_font_size_override("font_size", 12)
	_installed.modulate = DIM
	_installed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ride_box.add_child(_installed)

	# right column: cards
	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_scroll.focus_mode = Control.FOCUS_NONE
	main.add_child(_cards_scroll)
	_cards_box = VBoxContainer.new()
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.add_theme_constant_override("separation", 8)
	_cards_scroll.add_child(_cards_box)

	_status = Label.new()
	_status.text = "W/S browse    A/D category    [ENTER] buy    [ESC] keep rollin' →"
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = DIM
	col.add_child(_status)
