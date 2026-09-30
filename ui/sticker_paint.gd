extends RefCounted
## Bumper-sticker art ladder. Authored PNGs win; the deterministic vinyl paint
## keeps every catalog row presentable before bespoke art lands.
##
## No class_name on purpose — consumers preload this script by path.

const UiStyle := preload("res://ui/ui_style.gd")

const ART_DIR := "res://assets/img/stickers/"


static func make(id: StringName, name: String, requested_size: Vector2) -> Control:
	var path := ART_DIR + String(id) + ".png"
	var texture: Texture2D = null
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		texture = TextureLoader.load_texture(path)
	if texture:
		var art := TextureRect.new()
		art.name = "StickerArt"
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_fit(art, requested_size)
		return art
	var sticker := ProceduralSticker.new()
	sticker.name = "ProceduralSticker"
	sticker.configure(id, name, requested_size)
	return sticker


static func make_blank(requested_size: Vector2) -> Control:
	var blank := BlankSticker.new()
	blank.name = "BlankSticker"
	blank.configure(requested_size)
	var question := Label.new()
	question.name = "QuestionMark"
	question.text = "???"
	question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 26)
	question.add_theme_color_override("font_color", UiStyle.DIM_TEXT)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.add_child(question)
	return blank


static func _fit(control: Control, requested_size: Vector2) -> void:
	control.custom_minimum_size = requested_size
	control.size = requested_size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


class ProceduralSticker extends Control:
	var sticker_id := &""
	var sticker_name := ""

	func configure(id: StringName, title: String, requested_size: Vector2) -> void:
		sticker_id = id
		sticker_name = title.to_upper()
		custom_minimum_size = requested_size
		size = requested_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 16.0 or size.y < 16.0:
			return
		var seed := hash(String(sticker_id))
		var hue := float(posmod(seed, 3600)) / 3600.0
		var vinyl := Color.from_hsv(hue, 0.76, 0.68)
		var accent := Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.82, 0.86)
		var outer := Rect2(Vector2.ZERO, size - Vector2(2.0, 2.0))
		var shadow := Rect2(Vector2(2.0, 2.0), outer.size)
		_draw_box(shadow, Color(0.01, 0.01, 0.015, 0.42), 13)
		_draw_box(outer, Color(0.96, 0.96, 0.92), 13)
		var field := outer.grow(-5.0)
		_draw_box(field, vinyl, 9)

		var stripe_h := field.size.y * 0.2
		var stripe_y := field.position.y + 2.0 if posmod(seed, 2) == 0 \
			else field.end.y - stripe_h - 2.0
		draw_rect(Rect2(Vector2(field.position.x + 2.0, stripe_y),
			Vector2(field.size.x - 4.0, stripe_h)), accent)

		var font: Font = ThemeDB.fallback_font
		var font_size := mini(28, floori(field.size.y * 0.46))
		var available := field.size.x - 18.0
		while font_size > 10 and font.get_string_size(sticker_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
			font_size -= 1
		var baseline := field.position.y + (field.size.y - font.get_height(font_size)) * 0.5 \
			+ font.get_ascent(font_size)
		var origin := Vector2(field.position.x + 9.0, baseline)
		draw_string_outline(font, origin, sticker_name, HORIZONTAL_ALIGNMENT_CENTER,
			available, font_size, 3, Color(0.02, 0.02, 0.025, 0.82))
		draw_string(font, origin, sticker_name, HORIZONTAL_ALIGNMENT_CENTER,
			available, font_size, Color(0.98, 0.98, 0.95))

	func _draw_box(rect: Rect2, color: Color, radius: int) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.corner_radius_top_left = radius
		box.corner_radius_top_right = radius
		box.corner_radius_bottom_left = radius
		box.corner_radius_bottom_right = radius
		draw_style_box(box, rect)


class BlankSticker extends Control:
	const PAPER := Color(0.18, 0.19, 0.21)
	const EDGE := Color(0.34, 0.35, 0.38)

	func configure(requested_size: Vector2) -> void:
		custom_minimum_size = requested_size
		size = requested_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 16.0 or size.y < 16.0:
			return
		var shadow_box := StyleBoxFlat.new()
		shadow_box.bg_color = Color(0.01, 0.01, 0.015, 0.32)
		for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			shadow_box.set("corner_radius_" + corner, 11)
		draw_style_box(shadow_box, Rect2(Vector2(2.0, 2.0), size - Vector2(2.0, 2.0)))

		var paper_box := StyleBoxFlat.new()
		paper_box.bg_color = PAPER
		for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			paper_box.set("corner_radius_" + corner, 11)
		draw_style_box(paper_box, Rect2(Vector2.ZERO, size - Vector2(2.0, 2.0)))

		var left := 7.0
		var right := size.x - 9.0
		var top := 6.0
		var bottom := size.y - 8.0
		draw_dashed_line(Vector2(left + 8.0, top), Vector2(right - 8.0, top), EDGE,
			1.5, 7.0)
		draw_dashed_line(Vector2(left + 8.0, bottom), Vector2(right - 8.0, bottom), EDGE,
			1.5, 7.0)
		draw_dashed_line(Vector2(left, top + 8.0), Vector2(left, bottom - 8.0), EDGE,
			1.5, 7.0)
		draw_dashed_line(Vector2(right, top + 8.0), Vector2(right, bottom - 8.0), EDGE,
			1.5, 7.0)
		draw_arc(Vector2(left + 8.0, top + 8.0), 8.0, PI, PI * 1.5, 5, EDGE, 1.0)
		draw_arc(Vector2(right - 8.0, top + 8.0), 8.0, PI * 1.5, TAU, 5, EDGE, 1.0)
		draw_arc(Vector2(right - 8.0, bottom - 8.0), 8.0, 0.0, PI * 0.5, 5, EDGE, 1.0)
		draw_arc(Vector2(left + 8.0, bottom - 8.0), 8.0, PI * 0.5, PI, 5, EDGE, 1.0)
