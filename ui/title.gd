extends Control
## Title screen: splash art + SINGLE PLAYER/STORY menu. SINGLE PLAYER -> mode select;
## STORY -> full-screen story art (placeholder copy until the real text lands).
## ESC pops the quit confirm ("Awww, giving up so soon?") — NO is the default;
## quitting takes intent.

const IR := preload("res://game/input_router.gd")  # consts, not the autoload

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const STORY_ART := "res://assets/img/story/mambo.png"
const QUIT_PROMPT := "Awww, giving up so soon?"
const QUIT_OPTIONS := ["YES", "NO"]

var _done := false
var _index := 0
var _story: Control
var _quit: Control
var _quit_index := 1  # NO
var _quit_entries: Array[Label] = []

const ENTRY_NAMES := ["SINGLE PLAYER", "MULTIPLAYER", "STORY", "SETTINGS"]

@onready var _entries: Array[Label] = [$Menu/Start, $Menu/Multiplayer, $Menu/Story, $Menu/Settings]

func _ready() -> void:
	var bg := $Bg as TextureRect
	if bg:
		bg.texture = TextureLoader.load_texture("res://assets/img/story/splashscreen.png")
	_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if _quit:
		_quit_input(event)
		return
	if _story:
		var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
		if pressed:
			get_viewport().set_input_as_handled()
			_story.queue_free()
			_story = null
		return
	if event.is_action_pressed(IR.ACTION_PAUSE):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_open_quit_confirm()
		return
	var up: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"select_prev")
	var down: bool = event.is_action_pressed(&"move_down") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if up:
		_index = wrapi(_index - 1, 0, _entries.size())
		UiSfx.move(self)
		_highlight()
	elif down:
		_index = wrapi(_index + 1, 0, _entries.size())
		UiSfx.move(self)
		_highlight()
	elif confirm:
		UiSfx.select(self)
		_activate()

func _highlight() -> void:
	for i in _entries.size():
		_entries[i].modulate = AMBER if i == _index else DIM_TEXT
		_entries[i].text = ("[ %s ]" if i == _index else "%s") % ENTRY_NAMES[i]

func _activate() -> void:
	# Autoload fetched by path: bare identifiers fail to compile when this
	# script rides a test's -s preload chain (house rule — see vehicle.gd).
	var flow := get_node_or_null(^"/root/SceneFlow")
	match _index:
		0:
			_done = true
			if flow:
				flow.to_mode_select()
		1:
			_done = true
			if flow:
				flow.to_mp_menu()
		2:
			_open_story()
		3:
			_done = true
			if flow:
				flow.to_settings()

## The quit confirm's own input loop: any nav key toggles YES/NO, confirm
## activates, a second ESC backs out.
func _quit_input(event: InputEvent) -> void:
	if event.is_action_pressed(IR.ACTION_PAUSE):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_close_quit()
		return
	var toggle: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down") \
		or event.is_action_pressed(&"select_prev") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if toggle:
		get_viewport().set_input_as_handled()
		_quit_index = 1 - _quit_index
		UiSfx.move(self)
		_quit_highlight()
	elif confirm:
		get_viewport().set_input_as_handled()
		UiSfx.select(self)
		if _quit_index == 0:
			get_tree().quit()
		else:
			_close_quit()

func _open_quit_confirm() -> void:
	_quit = Control.new()
	_quit.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_quit)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09)
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var caption := Label.new()
	caption.text = QUIT_PROMPT
	caption.add_theme_font_size_override("font_size", 26)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate = AMBER
	vbox.add_child(caption)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	vbox.add_child(row)
	_quit_entries.clear()
	for option in QUIT_OPTIONS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(lbl)
		_quit_entries.append(lbl)
	_quit_index = 1  # NO — quitting takes intent
	_quit_highlight()

func _quit_highlight() -> void:
	for i in _quit_entries.size():
		_quit_entries[i].modulate = AMBER if i == _quit_index else DIM_TEXT
		_quit_entries[i].text = ("[ %s ]" if i == _quit_index else "%s") % QUIT_OPTIONS[i]

func _close_quit() -> void:
	if _quit:
		_quit.queue_free()
		_quit = null

func _open_story() -> void:
	_story = Control.new()
	_story.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_story)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story.add_child(bg)

	var art := TextureRect.new()
	art.texture = TextureLoader.load_texture(STORY_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story.add_child(art)

	var strip := ColorRect.new()
	strip.color = Color(0.07, 0.07, 0.09, 0.85)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -110.0
	_story.add_child(strip)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	strip.add_child(vbox)

	var copy := Label.new()
	copy.text = "The chrome bends at midnight. [ story copy TBD ]"
	copy.add_theme_font_size_override("font_size", 20)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.modulate = AMBER
	vbox.add_child(copy)

	var hint := Label.new()
	hint.text = "press any key to return"
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)
