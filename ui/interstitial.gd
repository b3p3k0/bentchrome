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
const DIM_TEXT := Color(0.55, 0.58, 0.62)
# Loading-card art keyed by SCENE FILE, not campaign position — reordering or
# renaming a level can never mismatch its card. Levels without an entry fall to
# the boss banner (by scene name) or the blocky panel. Add a line per new card.
const CARDS := {
	"arena.tscn": "level_1.png",
	"freeway.tscn": "level_2.png",
	"suburbs.tscn": "level_3.png",
	"snowy.tscn": "level_4.png",
}
# Temporary skip prompt for the under-construction chase level (The Buzzard
# Run). Delete the buzzard_run branch in _build_ui() once the level ships.
const DETOUR_CAPTION := "THIS ROAD IS UNDER CONSTRUCTION"
const DETOUR_SUB := "You don't need to play it to finish the game"
const DETOUR_OPTIONS := ["STAY ON ROUTE", "DETOUR"]

var _armed := false
var _hint: Label
var _chooser := false
var _choice_index := 0
var _choice_entries: Array[Label] = []

func _ready() -> void:
	layer = 60
	_build_ui()
	get_tree().create_timer(INPUT_LOCK).timeout.connect(_arm, CONNECT_ONE_SHOT)

func _arm() -> void:
	_armed = true
	if _chooser:
		return
	if _hint:
		_hint.text = "press any key to roll out"
		_hint.modulate = AMBER

func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if _chooser:
		_chooser_input(event)
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

## Two-option skip prompt: nav keys toggle STAY/DETOUR, confirm activates.
func _chooser_input(event: InputEvent) -> void:
	var toggle: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down") \
		or event.is_action_pressed(&"select_prev") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if toggle:
		get_viewport().set_input_as_handled()
		_choice_index = 1 - _choice_index
		_choice_highlight()
	elif confirm:
		get_viewport().set_input_as_handled()
		var flow := get_node_or_null(^"/root/SceneFlow")
		var gs := get_node_or_null(^"/root/GameState")
		if not (flow and gs):
			return
		if _choice_index == 0:  # STAY ON ROUTE — play the level as normal
			flow.to_level(gs.level_index)
		else:  # DETOUR — skip ahead; re-show interstitial for the next level
			gs.level_index = gs.level_index + 1
			flow.to_interstitial()

func _choice_highlight() -> void:
	for i in _choice_entries.size():
		_choice_entries[i].modulate = AMBER if i == _choice_index else DIM_TEXT
		_choice_entries[i].text = ("[ %s ]" if i == _choice_index else "%s") % DETOUR_OPTIONS[i]

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

	if next_scene.ends_with("buzzard_run.tscn"):
		_build_detour(_card_for(next_scene))
		return

	var card := _card_for(next_scene)
	if card:
		_build_card(card, "NEXT STOP:  %s" % next_name.to_upper(), Color.WHITE)
	else:
		_build_panel(next_index, next_name)

## The loading-card art for a scene path, or null if the level has none.
func _card_for(scene: String) -> Texture2D:
	var file: String = CARDS.get(scene.get_file(), "")
	return TextureLoader.load_texture("%s/%s" % [CARD_DIR, file]) if file else null

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

## Under-construction skip prompt over the level card: caption + sub-line +
## a two-option STAY/DETOUR row instead of the plain "press any key" hint.
func _build_detour(card: Texture2D) -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if card:
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
	strip.offset_top = -132.0
	add_child(strip)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	strip.add_child(vbox)

	var caption_lbl := Label.new()
	caption_lbl.text = DETOUR_CAPTION
	caption_lbl.add_theme_font_size_override("font_size", 24)
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.modulate = AMBER
	vbox.add_child(caption_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = DETOUR_SUB
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.modulate = Color(0.75, 0.78, 0.82)
	vbox.add_child(sub_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	vbox.add_child(row)
	_choice_entries.clear()
	for option in DETOUR_OPTIONS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(lbl)
		_choice_entries.append(lbl)
	_choice_index = 0
	_choice_highlight()
	_chooser = true

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
