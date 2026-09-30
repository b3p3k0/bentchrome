extends Control
## Bumper Sticker gallery. Locked rows expose no catalog copy outside the
## explicit Developer Mode readout.

const StickerPaint := preload("res://ui/sticker_paint.gd")
const UiStyle := preload("res://ui/ui_style.gd")

const COLUMNS := 4
const CELL_SIZE := Vector2(240, 80)
const PAINT_SIZE := Vector2(222, 70)

var _done := false
var _index := 0
var _rows: Array = []
var _cells: Array[PanelContainer] = []
var _new_ids: Array = []
var _store: Node

@onready var _collected: Label = $Collected
@onready var _scroll: ScrollContainer = $StickerScroll
@onready var _grid: GridContainer = $StickerScroll/Grid
@onready var _detail: PanelContainer = $Detail
@onready var _detail_name: Label = $Detail/Margin/Box/Name
@onready var _detail_blurb: Label = $Detail/Margin/Box/Blurb
@onready var _detail_earned: Label = $Detail/Margin/Box/Earned
@onready var _detail_dev: Label = $Detail/Margin/Box/Dev


func _ready() -> void:
	$Header.modulate = UiStyle.AMBER
	_collected.modulate = UiStyle.DIM_TEXT
	$Footer.modulate = UiStyle.DIM_TEXT
	_detail.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_detail_name.modulate = UiStyle.AMBER
	_detail_earned.modulate = UiStyle.DIM_TEXT
	_detail_dev.modulate = UiStyle.DIM_TEXT
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.focus_mode = Control.FOCUS_NONE

	_store = get_node_or_null(^"/root/Stickers")
	if _store:
		_store.ensure_catalog()
		_rows = _store.catalog()
		_new_ids = _store.unseen()
	_build_grid()
	_refresh_selection()
	if _store:
		_store.mark_seen()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"select_confirm"):
		get_viewport().set_input_as_handled()
		_exit_to_title()
		return
	var left := event.is_action_pressed(&"move_left") \
		or event.is_action_pressed(&"select_prev")
	var right := event.is_action_pressed(&"move_right") \
		or event.is_action_pressed(&"select_next")
	if left:
		_move_horizontal(-1)
	elif right:
		_move_horizontal(1)
	elif event.is_action_pressed(&"move_up"):
		_move_vertical(-1)
	elif event.is_action_pressed(&"move_down"):
		_move_vertical(1)


func _build_grid() -> void:
	var earned_count := 0
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var id := StringName(row.get("id", ""))
		var earned: bool = _store != null and bool(_store.is_unlocked(id))
		if earned:
			earned_count += 1
		var cell := _make_cell(row, earned, id in _new_ids, i)
		_grid.add_child(cell)
		_cells.append(cell)
	_collected.text = "%d / %d COLLECTED" % [earned_count, _rows.size()]


func _make_cell(row: Dictionary, earned: bool, is_new: bool,
		index: int) -> PanelContainer:
	var id := StringName(row.get("id", ""))
	var cell := PanelContainer.new()
	cell.name = "Sticker%02d" % index
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.set_meta(&"sticker_id", id)
	cell.set_meta(&"locked", not earned)

	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(body)
	var paint: Control
	if earned:
		paint = StickerPaint.make(id, String(row.get("name", "")), PAINT_SIZE)
		paint.rotation_degrees = _tilt(id)
	else:
		paint = StickerPaint.make_blank(PAINT_SIZE)
	paint.set_anchors_preset(Control.PRESET_CENTER)
	paint.offset_left = -PAINT_SIZE.x * 0.5
	paint.offset_top = -PAINT_SIZE.y * 0.5
	paint.offset_right = PAINT_SIZE.x * 0.5
	paint.offset_bottom = PAINT_SIZE.y * 0.5
	paint.pivot_offset = PAINT_SIZE * 0.5
	body.add_child(paint)

	if is_new:
		var tag := Label.new()
		tag.name = "NewTag"
		tag.text = "NEW"
		tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -46.0
		tag.offset_top = 3.0
		tag.offset_right = -7.0
		tag.offset_bottom = 23.0
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", UiStyle.AMBER)
		tag.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.025))
		tag.add_theme_constant_override("outline_size", 4)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(tag)
	return cell


func _tilt(id: StringName) -> float:
	return float(posmod(hash(String(id)), 601)) / 100.0 - 3.0


func _move_horizontal(direction: int) -> void:
	if _rows.is_empty():
		return
	_index = wrapi(_index + direction, 0, _rows.size())
	UiSfx.move(self)
	_refresh_selection()


func _move_vertical(direction: int) -> void:
	if _rows.is_empty():
		return
	var next := clampi(_index + direction * COLUMNS, 0, _rows.size() - 1)
	if next == _index:
		return
	_index = next
	UiSfx.move(self)
	_refresh_selection()


func _refresh_selection() -> void:
	for i in _cells.size():
		_cells[i].add_theme_stylebox_override("panel", _cell_style(i == _index))
	_refresh_detail()
	if _index < _cells.size():
		_scroll_to.call_deferred(_cells[_index])


func _cell_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = UiStyle.AMBER if selected else Color(0, 0, 0, 0)
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		style.set("corner_radius_" + corner, 8)
	return style


func _refresh_detail() -> void:
	if _rows.is_empty() or _store == null:
		_detail_name.text = "???"
		_detail_blurb.text = "Keep driving."
		_detail_earned.visible = false
		_detail_dev.visible = false
		return
	var row: Dictionary = _rows[_index]
	var id := StringName(row.get("id", ""))
	var earned: bool = bool(_store.is_unlocked(id))
	if earned:
		_detail_name.text = String(row.get("name", "")).to_upper()
		_detail_blurb.text = String(row.get("blurb", ""))
		var stamp := int(_store.unlocked.get(String(id), 0))
		_detail_earned.text = "EARNED " + Time.get_date_string_from_unix_time(stamp)
		_detail_earned.visible = true
	else:
		_detail_name.text = "???"
		_detail_blurb.text = "Keep driving."
		_detail_earned.text = ""
		_detail_earned.visible = false

	var gs := get_node_or_null(^"/root/GameState")
	var dev_mode := gs != null and bool(gs.get("dev_mode"))
	_detail_dev.visible = dev_mode
	if dev_mode:
		var progress: Vector2i = _store.progress(id)
		_detail_dev.text = "[DEV] %s — %d/%d" % [String(row.get("name", "")),
			progress.x, progress.y]
	else:
		_detail_dev.text = ""


func _scroll_to(cell: Control) -> void:
	if is_instance_valid(cell) and _scroll:
		_scroll.ensure_control_visible(cell)


func _exit_to_title() -> void:
	if _done:
		return
	_done = true
	UiSfx.back(self)
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.to_title()
