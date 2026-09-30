extends Control
## Paint-only PIT STOP menu. The garage shell owns selection, input, pricing,
## purchase rules, and Economy; this view only reflects the shell it receives.

const UiStyle := preload("res://ui/ui_style.gd")
const CarPaint := preload("res://vehicles/car_paint.gd")

const ALIVE := Color(0.8, 0.82, 0.86)
const LOCKED := Color(0.32, 0.34, 0.37)
const RED := Color(0.75, 0.2, 0.2)
const SOFT_RED := Color(0.88, 0.54, 0.54)
const GOOD := Color(0.5, 0.84, 0.59)
const EMPTY_BAR := Color(0.16, 0.16, 0.2)
const MPH_PER_PXS := 0.15
const BAR_STATS := ["acceleration", "top_speed", "handling", "armor"]
const BAR_LABELS := {
	"acceleration": "ACC", "top_speed": "TOP", "handling": "HND", "armor": "ARM",
}

var _wallet: Label
var _tabs: Array = []
var _tabs_row: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _art: TextureRect
var _part_name: Label
var _blurb: Label
var _effect: Label
var _tradeoff: Label
var _part_state: Label
var _ride_name: Label
var _turntable: Node2D
var _bar_rows: Dictionary = {}
var _bar_values: Dictionary = {}
var _installed: Label
var _mo: Label

func _ready() -> void:
	_build()
	_ignore_controls(self)

func refresh(shell) -> void:
	_wallet.text = "⚙ %s" % shell.fmt(shell.wallet())
	_ensure_tabs(shell.categories.size())
	for index in _tabs.size():
		var category: String = shell.categories[index]
		var total := 0
		var owned_count := 0
		for item in shell.items:
			if String(item.category) != category:
				continue
			total += 1
			if String(item.id) in shell.owned:
				owned_count += 1
		var tab: Label = _tabs[index]
		tab.text = "%s %d/%d" % [category, owned_count, total]
		tab.modulate = UiStyle.AMBER if index == shell.category_index else ALIVE
	_paint_list(shell)
	_paint_detail(shell)
	_paint_ride(shell)
	_mo.text = "SLO MO: " + shell.mo_line
	_mo.modulate = UiStyle.AMBER if shell.is_confirming() else ALIVE
	_ignore_controls(self)

func _paint_list(shell) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var selected: Control
	var pool: Array = shell.category_items()
	for index in pool.size():
		var item: Dictionary = pool[index]
		var state: StringName = shell.item_state(item)
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 46)
		row.add_theme_stylebox_override("panel", _row_style(index == shell.item_index))
		var margin := MarginContainer.new()
		_set_margin(margin, 8)
		row.add_child(margin)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		margin.add_child(line)
		var name_label := Label.new()
		name_label.text = String(item.display_name)
		name_label.clip_text = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.modulate = LOCKED if state == &"locked" else \
			(UiStyle.DIM_TEXT if state == &"owned" else ALIVE)
		line.add_child(name_label)
		var price_label := Label.new()
		price_label.add_theme_font_size_override("font_size", 14)
		match state:
			&"owned":
				price_label.text = "OWNED"
				price_label.modulate = GOOD
			&"short":
				price_label.text = "⚙ %s" % shell.fmt(shell.price_for(item))
				price_label.modulate = RED
			_:
				price_label.text = "⚙ %s" % shell.fmt(shell.price_for(item))
				price_label.modulate = UiStyle.AMBER if state == &"buyable" else LOCKED
		line.add_child(price_label)
		_list.add_child(row)
		if index == shell.item_index:
			selected = row
	if selected != null:
		_scroll_to.call_deferred(selected)

func _paint_detail(shell) -> void:
	var item: Dictionary = shell.selected_item()
	if item.is_empty():
		_art.texture = null
		_part_name.text = ""
		return
	var state: StringName = shell.item_state(item)
	var texture: Texture2D = TextureLoader.load_texture(
		"res://assets/img/garage/items/%s.png" % String(item.id))
	_art.texture = texture
	_art.visible = texture != null
	_art.modulate = Color(0.45, 0.45, 0.5) if state in [&"locked", &"owned"] else Color.WHITE
	_part_name.text = String(item.display_name)
	_part_name.modulate = LOCKED if state == &"locked" else \
		(UiStyle.DIM_TEXT if state == &"owned" else ALIVE)
	_blurb.text = String(item.get("blurb", ""))
	_blurb.modulate = LOCKED if state == &"locked" else UiStyle.DIM_TEXT
	_set_optional(_effect, String(item.get("effect_text", "")),
		LOCKED if state == &"locked" else UiStyle.AMBER)
	_set_optional(_tradeoff, String(item.get("tradeoff_text", "")),
		LOCKED if state == &"locked" else SOFT_RED)
	match state:
		&"locked":
			var required: Dictionary = shell.by_id.get(String(item.get("requires", "")), {})
			_part_state.text = "REQUIRES %s" % String(required.get("display_name", "?"))
			_part_state.modulate = LOCKED
		&"short":
			_part_state.text = "SHORT ⚙ %s" % \
				shell.fmt(shell.price_for(item) - shell.wallet())
			_part_state.modulate = RED
		&"owned":
			_part_state.text = "OWNED — bolted on"
			_part_state.modulate = GOOD
		_:
			_part_state.text = "⚙ %s — READY" % shell.fmt(shell.price_for(item))
			_part_state.modulate = UiStyle.AMBER

func _paint_ride(shell) -> void:
	_ride_name.text = "%s\n%s" % [shell.stats.car_name.to_upper(), shell.next_level_name]
	_turntable.apply(shell.stats.id, shell.stats.primary_color, shell.stats.accent_color)
	var current: VehicleStats = shell.composed()
	var preview: VehicleStats = shell.composed(shell.selected_item())
	for stat in BAR_STATS:
		var base_value := int(current.get(stat))
		var preview_value := int(preview.get(stat))
		var cells: Array = _bar_rows[stat]
		for index in cells.size():
			var level := index + 1
			var cell: ColorRect = cells[index]
			if level <= mini(base_value, preview_value):
				cell.color = ALIVE
			elif level <= preview_value:
				cell.color = UiStyle.AMBER
			elif level <= base_value:
				cell.color = RED
			else:
				cell.color = EMPTY_BAR
		var value_text := str(base_value) if preview_value == base_value else \
			"%d→%d" % [base_value, preview_value]
		if stat == "top_speed":
			var mph: float = StatCurves._slot(StatCurves.TOP_SPEED, preview_value) * MPH_PER_PXS
			value_text += "  (%.0f mph)" % mph
		var value_label: Label = _bar_values[stat]
		value_label.text = value_text
		value_label.modulate = UiStyle.AMBER if preview_value != base_value else UiStyle.DIM_TEXT
	var names: Array = []
	for id in shell.owned:
		if shell.by_id.has(id):
			names.append(String(shell.by_id[id].display_name))
	_installed.text = "INSTALLED: " + (", ".join(names) if not names.is_empty() else "— stock ride —")

func _scroll_to(row: Control) -> void:
	# A repaint between the call and this deferred run replaces the rows.
	if is_instance_valid(row) and is_instance_valid(_scroll) and _scroll.is_ancestor_of(row):
		_scroll.ensure_control_visible(row)

func _set_optional(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.visible = not text.is_empty()
	label.modulate = color

func _row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.13) if selected else UiStyle.PANEL_BG
	style.border_color = UiStyle.AMBER if selected else Color(0.23, 0.23, 0.27)
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3 if selected else 1)
	return style

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 640)
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	_set_margin(margin, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	_build_header(column)
	_build_tabs(column)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(main)
	_build_list(main)
	_build_detail(main)
	_mo = Label.new()
	_mo.name = "MoLine"
	_mo.add_theme_font_size_override("font_size", 15)
	column.add_child(_mo)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "←/→ category    ↑/↓ browse    [ENTER] buy    [ESC] back"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = UiStyle.DIM_TEXT
	column.add_child(hint)

func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var title := Label.new()
	title.text = "SLO MO'S — PIT STOP"
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = UiStyle.AMBER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_wallet = Label.new()
	_wallet.name = "Wallet"
	_wallet.add_theme_font_size_override("font_size", 23)
	_wallet.modulate = UiStyle.AMBER
	header.add_child(_wallet)

func _build_tabs(parent: VBoxContainer) -> void:
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 12)
	parent.add_child(_tabs_row)

func _ensure_tabs(count: int) -> void:
	while _tabs.size() < count:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		_tabs_row.add_child(label)
		_tabs.append(label)
	while _tabs.size() > count:
		var label: Label = _tabs.pop_back()
		_tabs_row.remove_child(label)
		label.queue_free()

func _build_list(parent: HBoxContainer) -> void:
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(400, 0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_NONE
	parent.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

func _build_detail(parent: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	parent.add_child(right)
	var detail := HBoxContainer.new()
	detail.custom_minimum_size = Vector2(0, 288)
	detail.add_theme_constant_override("separation", 14)
	right.add_child(detail)
	var art_slot := Control.new()
	art_slot.custom_minimum_size = Vector2(384, 288)
	art_slot.clip_contents = true
	detail.add_child(art_slot)
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_slot.add_child(_art)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 8)
	detail.add_child(copy)
	_part_name = _detail_label(copy, 22, ALIVE)
	_blurb = _detail_label(copy, 14, UiStyle.DIM_TEXT)
	_effect = _detail_label(copy, 14, UiStyle.AMBER)
	_tradeoff = _detail_label(copy, 14, SOFT_RED)
	_part_state = _detail_label(copy, 14, UiStyle.AMBER)
	_build_ride(right)

func _build_ride(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "YOUR RIDE"
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = UiStyle.AMBER
	parent.add_child(title)
	var ride_row := HBoxContainer.new()
	ride_row.add_theme_constant_override("separation", 12)
	parent.add_child(ride_row)
	var car_column := VBoxContainer.new()
	car_column.custom_minimum_size = Vector2(210, 0)
	ride_row.add_child(car_column)
	_ride_name = Label.new()
	_ride_name.add_theme_font_size_override("font_size", 13)
	_ride_name.modulate = ALIVE
	car_column.add_child(_ride_name)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 84)
	car_column.add_child(stage)
	# CarPaint.apply() resets its own scale, so the size rides a holder.
	var holder := Node2D.new()
	holder.position = Vector2(105, 43)
	holder.scale = Vector2.ONE * 1.6
	stage.add_child(holder)
	_turntable = CarPaint.new()
	holder.add_child(_turntable)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 3)
	ride_row.add_child(bars)
	for stat in BAR_STATS:
		_build_bar(bars, stat)
	_installed = Label.new()
	_installed.add_theme_font_size_override("font_size", 12)
	_installed.modulate = UiStyle.DIM_TEXT
	_installed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_installed)

func _build_bar(parent: VBoxContainer, stat: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var label := Label.new()
	label.text = BAR_LABELS[stat]
	label.custom_minimum_size = Vector2(34, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = UiStyle.DIM_TEXT
	row.add_child(label)
	var cells: Array = []
	for index in 20:
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(8, 12)
		row.add_child(cell)
		cells.append(cell)
	_bar_rows[stat] = cells
	var value := Label.new()
	value.custom_minimum_size = Vector2(108, 0)
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	_bar_values[stat] = value

func _detail_label(parent: VBoxContainer, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = color
	parent.add_child(label)
	return label

func _set_margin(container: MarginContainer, amount: int) -> void:
	for side in ["left", "right", "top", "bottom"]:
		container.add_theme_constant_override("margin_" + side, amount)

func _ignore_controls(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(true):
		_ignore_controls(child)
