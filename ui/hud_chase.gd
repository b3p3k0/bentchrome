extends "res://ui/hud.gd"
## The Buzzard Run HUD: the left dash is untouched; the right gutter swaps
## the arena radar for the dashboard GPS and the opponents roster for a
## threat panel — the 3:00 countdown, kill tally, live-pack count, and a
## horde-gap meter. Polls the chase host duck-typed via the &"chase_host"
## group (time_left / wall_gap / kills).

const GPSScript := preload("res://ui/chase_gps.gd")
const SpeedLinesScript := preload("res://ui/speed_lines.gd")

var _clock_label: Label
var _wrecked_label: Label
var _pack_label: Label
var _wall_bar: ProgressBar

func _build_ui() -> void:
	super()
	var lines := SpeedLinesScript.new()
	lines.name = "SpeedLines"
	lines.position = Vector2(GUTTER, 0)
	lines.size = Vector2(1280 - GUTTER * 2, VIEW_H)
	add_child(lines)

## The arena radar never fits an unbounded course — the GPS owns the slot.
func _build_radar() -> void:
	var hdr := Label.new()
	hdr.text = "GPS"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.modulate = DIM_TEXT
	hdr.position = Vector2(1280 - GUTTER + 16, 16)
	add_child(hdr)
	var gps := GPSScript.new()
	gps.position = Vector2(1280 - GUTTER + 20, 44)
	gps.size = Vector2(240, 380)
	add_child(gps)

func _build_opponents() -> void:
	_clock_label = _label_at(Vector2(1280 - GUTTER + 20, 444), "3:00", 40)
	_clock_label.modulate = SELECTED
	_wrecked_label = _label_at(Vector2(1280 - GUTTER + 20, 500), "WRECKED 0", 16)
	_pack_label = _label_at(Vector2(1280 - GUTTER + 150, 500), "PACK 0", 16)
	var wall_hdr := _label_at(Vector2(1280 - GUTTER + 20, 530), "THE HORDE", 14)
	wall_hdr.modulate = DIM_TEXT
	_wall_bar = ProgressBar.new()
	_wall_bar.max_value = 100.0
	_wall_bar.show_percentage = false
	_wall_bar.position = Vector2(1280 - GUTTER + 20, 552)
	_wall_bar.custom_minimum_size = Vector2(GUTTER - 40, 12)
	_wall_bar.size = Vector2(GUTTER - 40, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.3, 0.15)
	_wall_bar.add_theme_stylebox_override("fill", fill)
	add_child(_wall_bar)

## The threat panel polls live state — no round-start snapshot to go blind on.
func _update_opponents() -> void:
	var host := get_tree().get_first_node_in_group(&"chase_host")
	if host == null:
		return
	var left: float = host.time_left()
	_clock_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	if left <= 20.0:
		_clock_label.modulate = Color(0.9, 0.25, 0.2) if int(left * 2.0) % 2 == 0 else SELECTED
	_wrecked_label.text = "WRECKED %d" % host.kills
	_pack_label.text = "PACK %d" % get_tree().get_nodes_in_group(&"enemies").size()
	_wall_bar.value = clampf(1.0 - host.wall_gap() / 2400.0, 0.0, 1.0) * 100.0

func _label_at(pos: Vector2, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l
