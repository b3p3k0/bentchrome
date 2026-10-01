class_name Signage
extends Node2D
## Paint-only words for roadside boards, pylon heads, and storefront bands.
## Level placement owns depth: overhead signs belong at z 1, bands at z 0.

const UnderFade := preload("res://environment/under_fade.gd")

const GRIME := Color(0.06, 0.055, 0.065, 0.42)
const PEEL := Color(0.68, 0.65, 0.61, 0.72)
const DEAD_LETTER := Color(0.22, 0.20, 0.16, 0.78)
const CATWALK := Color(0.18, 0.18, 0.21)
const POLE_CAP := Color(0.21, 0.21, 0.24)

const PADDING := 12.0
const TEXT_GAP := 4.0
const LINE_GAP := 4.0
const MIN_FONT_SIZE := 18
const MIN_SUB_FONT_SIZE := 14

@export var kind: StringName = &"billboard"
@export var size := Vector2(384, 160)
@export var text := "BENT CHROME"
@export var sub_text := ""
@export var face_color := Color(0.16, 0.15, 0.17)
@export var text_color := Color(0.92, 0.85, 0.55)
@export var frame_color := Color(0.30, 0.30, 0.34)
@export_range(0.0, 1.0) var weathering := 0.5
@export var dead_letters := 0
@export var paint_seed := 0

var _under_area: Area2D = null

func _ready() -> void:
	if kind == &"billboard" or kind == &"pylon":
		_under_area = UnderFade.build_area(size)
		add_child(_under_area)
	set_process(_under_area != null)
	var holder := get_parent()
	if holder == null:
		return
	if holder.has_signal(&"flattened"):
		holder.connect(&"flattened", hide)
		if holder.has_signal(&"restored"):
			holder.connect(&"restored", show)
		return
	var health := holder.get_node_or_null(^"Health")
	if health != null and health.has_signal(&"died"):
		health.connect(&"died", hide)

func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a,
		UnderFade.target_alpha(_under_area, z_index), UnderFade.SPEED * delta)

func text_font_size() -> int:
	var largest := maxi(MIN_FONT_SIZE, int(floor(size.y - PADDING * 2.0)))
	for font_size in range(largest, MIN_FONT_SIZE - 1, -1):
		if _candidate_fits(font_size):
			return font_size
	return MIN_FONT_SIZE

func text_fits() -> bool:
	return _candidate_fits(text_font_size())

func dead_letter_indices() -> PackedInt32Array:
	var candidates: Array[int] = []
	for i in text.length():
		if _is_letter(text.substr(i, 1)):
			candidates.append(i)
	var offset := text.length()
	for i in sub_text.length():
		if _is_letter(sub_text.substr(i, 1)):
			candidates.append(offset + i)
	var rng := _rng(0x4d31)
	for i in range(candidates.size() - 1, 0, -1):
		var swap := rng.randi_range(0, i)
		var held := candidates[i]
		candidates[i] = candidates[swap]
		candidates[swap] = held
	var result := PackedInt32Array()
	for i in mini(maxi(dead_letters, 0), candidates.size()):
		result.append(candidates[i])
	result.sort()
	return result

func _candidate_fits(font_size: int) -> bool:
	var available := size - Vector2(PADDING * 2.0, PADDING * 2.0)
	if available.x < 0.0 or available.y < 0.0:
		return false
	if _string_width(text, font_size) > available.x:
		return false
	var sub_size := _sub_font_size(font_size)
	if _string_width(sub_text, sub_size) > available.x:
		return false
	return _text_block_height(font_size) <= available.y

func _text_block_height(font_size: int) -> float:
	var font := ThemeDB.fallback_font
	var height := 0.0
	if not text.is_empty():
		height += font.get_height(font_size)
	if not sub_text.is_empty():
		if height > 0.0:
			height += LINE_GAP
		height += font.get_height(_sub_font_size(font_size))
	return height

func _sub_font_size(font_size: int) -> int:
	return maxi(MIN_SUB_FONT_SIZE, int(floor(float(font_size) * 0.6)))

func _string_width(value: String, font_size: int) -> float:
	if value.is_empty():
		return 0.0
	var font := ThemeDB.fallback_font
	var width := 0.0
	for ch in value:
		width += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	width += TEXT_GAP * float(value.length() - 1)
	return width

func _is_letter(ch: String) -> bool:
	return not ch.is_empty() and ch.to_lower() != ch.to_upper()

func _resolved_seed() -> int:
	return paint_seed if paint_seed != 0 else hash(Vector2i(global_position))

func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _resolved_seed() ^ salt
	return rng

func _draw() -> void:
	match kind:
		&"pylon":
			_draw_pylon()
		&"band":
			_draw_band()
		_:
			_draw_billboard()

func _draw_billboard() -> void:
	var panel := Rect2(-size * 0.5, size)
	var half := size * 0.5
	draw_rect(Rect2(Vector2(-half.x + 12.0, half.y), Vector2(16.0, 28.0)), POLE_CAP)
	draw_rect(Rect2(Vector2(half.x - 28.0, half.y), Vector2(16.0, 28.0)), POLE_CAP)
	draw_rect(panel, frame_color)
	draw_rect(_inset(panel, 6.0), face_color)
	draw_line(Vector2(-half.x, half.y + 4.0), Vector2(half.x, half.y + 4.0),
		CATWALK, 3.0)
	_draw_text()
	_draw_panel_weather()

func _draw_pylon() -> void:
	var panel := Rect2(-size * 0.5, size)
	var half := size * 0.5
	draw_rect(Rect2(Vector2(-9.0, half.y), Vector2(18.0, 34.0)), POLE_CAP)
	draw_style_box(_round_box(frame_color, 18), panel)
	draw_style_box(_round_box(frame_color.lightened(0.2), 14), _inset(panel, 5.0))
	draw_style_box(_round_box(face_color, 10), _inset(panel, 10.0))
	_draw_text()
	_draw_panel_weather()

func _draw_band() -> void:
	var panel := Rect2(-size * 0.5, size)
	draw_rect(panel, face_color.darkened(0.32))
	draw_rect(panel, frame_color.lightened(0.28), false, 2.0)
	_draw_text()
	_draw_band_chips()

func _draw_text() -> void:
	var font_size := text_font_size()
	if not _candidate_fits(font_size):
		return
	var font := ThemeDB.fallback_font
	var block_height := _text_block_height(font_size)
	var top := -block_height * 0.5
	var dead := dead_letter_indices()
	if not text.is_empty():
		var baseline := top + font.get_ascent(font_size)
		_draw_text_line(text, font_size, baseline, 0, dead)
		top += font.get_height(font_size)
	if not sub_text.is_empty():
		if not text.is_empty():
			top += LINE_GAP
		var sub_size := _sub_font_size(font_size)
		var baseline := top + font.get_ascent(sub_size)
		_draw_text_line(sub_text, sub_size, baseline, text.length(), dead)

func _draw_text_line(value: String, font_size: int, baseline: float, index_offset: int,
		dead: PackedInt32Array) -> void:
	var font := ThemeDB.fallback_font
	var x := -_string_width(value, font_size) * 0.5
	var left := -size.x * 0.5 + PADDING
	var right := size.x * 0.5 - PADDING
	for i in value.length():
		var ch := value.substr(i, 1)
		var width := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if x >= left and x + width <= right:
			var ink := DEAD_LETTER if dead.has(index_offset + i) else text_color
			draw_char(font, Vector2(x, baseline), ch, font_size, ink)
		x += width + TEXT_GAP

func _draw_panel_weather() -> void:
	var wear := clampf(weathering, 0.0, 1.0)
	var inner := _inset(Rect2(-size * 0.5, size), PADDING)
	var rng := _rng(0x7731)
	for i in int(round(wear * 9.0)):
		var x := rng.randf_range(inner.position.x, inner.end.x)
		var length := rng.randf_range(size.y * 0.08, size.y * 0.34) * wear
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + length),
			GRIME, rng.randf_range(1.0, 4.0))
	var peel_color := face_color.lerp(PEEL, 0.58)
	for i in int(round(wear * 11.0)):
		var fleck := Vector2(rng.randf_range(2.0, 8.0), rng.randf_range(2.0, 5.0))
		var at := Vector2(rng.randf_range(inner.position.x, inner.end.x - fleck.x),
			rng.randf_range(inner.position.y, inner.end.y - fleck.y))
		draw_rect(Rect2(at, fleck), peel_color)

func _draw_band_chips() -> void:
	var wear := clampf(weathering, 0.0, 1.0)
	var half := size * 0.5
	var rng := _rng(0x2b19)
	for i in int(round(wear * 14.0)):
		var horizontal := rng.randi() % 2 == 0
		var at := Vector2(rng.randf_range(-half.x, half.x),
			(-half.y if rng.randi() % 2 == 0 else half.y))
		var chip := Vector2(rng.randf_range(3.0, 9.0), 3.0)
		if not horizontal:
			at = Vector2((-half.x if rng.randi() % 2 == 0 else half.x),
				rng.randf_range(-half.y, half.y))
			chip = Vector2(3.0, rng.randf_range(3.0, 9.0))
		draw_rect(Rect2(at - chip * 0.5, chip), GRIME)

func _inset(rect: Rect2, amount: float) -> Rect2:
	var inset_size := Vector2(maxf(rect.size.x - amount * 2.0, 0.0),
		maxf(rect.size.y - amount * 2.0, 0.0))
	return Rect2(rect.position + Vector2(amount, amount), inset_size)

func _round_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
