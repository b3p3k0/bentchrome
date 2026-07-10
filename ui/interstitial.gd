extends CanvasLayer
## Between-levels breather. Shows the upcoming level's loading card
## (assets/img/cards/level_<n>.png, 1-based campaign index) when the art
## exists; falls back to the blocky panel otherwise. Waits for ANY
## key/button/click. GameState.level_index already points at the NEXT level
## (the end screen advances it before coming here).

const AMBER := Color(1.0, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const INPUT_LOCK := 1.2  # players arrive here still hammering fire
const CARD_DIR := "res://assets/img/cards"

var _armed := false
var _hint: Label

func _ready() -> void:
	layer = 60
	_build_ui()
	get_tree().create_timer(INPUT_LOCK).timeout.connect(_arm, CONNECT_ONE_SHOT)

func _arm() -> void:
	_armed = true
	if _hint:
		_hint.text = "press any key to roll out"
		_hint.modulate = AMBER

func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var flow := get_node_or_null(^"/root/SceneFlow")
	var gs := get_node_or_null(^"/root/GameState")
	if flow and gs:
		flow.to_level(gs.level_index)

func _build_ui() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	var flow := get_node_or_null(^"/root/SceneFlow")
	var next_index: int = gs.level_index if gs else 0
	var next_name: String = "?"
	var next_scene := ""
	if flow and next_index < flow.CAMPAIGN.size():
		next_name = flow.CAMPAIGN[next_index].name
		next_scene = String(flow.CAMPAIGN[next_index].scene)

	if next_scene.ends_with("depot.tscn"):
		var portrait := TextureLoader.load_texture("res://assets/img/bios/lackey.png")
		if portrait:
			_build_card(portrait, "PREPARE TO MEET LAST YEAR'S WINNER — LACKEY", AMBER)
			return
	if next_scene.ends_with("stadium.tscn"):
		var portrait := TextureLoader.load_texture("res://assets/img/bios/goliath.png")
		if portrait:
			_build_card(portrait, "THE COLISEUM'S UNDEFEATED KING AWAITS — GOLIATH", AMBER)
			return

	var card := TextureLoader.load_texture("%s/level_%d.png" % [CARD_DIR, next_index + 1])
	if card:
		_build_card(card, "NEXT STOP:  %s" % next_name.to_upper(), Color.WHITE)
	else:
		_build_panel(next_index, next_name)

## Full-screen loading card: letterboxed art over black, caption strip pinned
## to the bottom edge.
func _build_card(card: Texture2D, caption: String, caption_color: Color) -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var art := TextureRect.new()
	art.texture = card
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	var strip := ColorRect.new()
	strip.color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.85)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -84.0
	add_child(strip)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	strip.add_child(vbox)

	var caption_lbl := Label.new()
	caption_lbl.text = caption
	caption_lbl.add_theme_font_size_override("font_size", 24)
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.modulate = caption_color
	vbox.add_child(caption_lbl)

	_hint = Label.new()
	_hint.text = "..."
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(0.55, 0.58, 0.62)
	vbox.add_child(_hint)

## The original blocky panel — kept as the fallback when no card art exists.
func _build_panel(next_index: int, next_name: String) -> void:
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
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "LEVEL %d CLEAR" % next_index  # 1-based: cleared = next_index
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = AMBER
	vbox.add_child(title)

	var trim := HBoxContainer.new()
	trim.alignment = BoxContainer.ALIGNMENT_CENTER
	trim.add_theme_constant_override("separation", 8)
	for i in 9:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(14, 14)
		block.color = AMBER if i % 2 == 0 else AMBER.darkened(0.55)
		trim.add_child(block)
	vbox.add_child(trim)

	var next_lbl := Label.new()
	next_lbl.text = "NEXT STOP:  %s" % next_name.to_upper()
	next_lbl.add_theme_font_size_override("font_size", 22)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(next_lbl)

	_hint = Label.new()
	_hint.text = "..."
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(0.55, 0.58, 0.62)
	vbox.add_child(_hint)
