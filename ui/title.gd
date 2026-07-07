extends Control
## Title screen: splash art + START/STORY menu. START -> car select;
## STORY -> full-screen story art (placeholder copy until the real text lands).

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const STORY_ART := "res://assets/img/story/mambo.png"

var _done := false
var _index := 0
var _story: Control

@onready var _entries: Array[Label] = [$Menu/Start, $Menu/Story]

func _ready() -> void:
	var bg := $Bg as TextureRect
	if bg:
		bg.texture = TextureLoader.load_texture("res://assets/img/story/splashscreen.png")
	_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if _done:
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
	var nav: bool = event.is_action_pressed(&"select_prev") or event.is_action_pressed(&"select_next") \
		or event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if nav:
		_index = (_index + 1) % _entries.size()  # two entries: any nav key flips
		_highlight()
	elif confirm:
		_activate()

func _highlight() -> void:
	for i in _entries.size():
		_entries[i].modulate = AMBER if i == _index else DIM_TEXT
		_entries[i].text = ("[ %s ]" if i == _index else "%s") % ["START", "STORY"][i]

func _activate() -> void:
	if _index == 0:
		_done = true
		SceneFlow.to_select()
	else:
		_open_story()

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
