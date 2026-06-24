extends Control
## Title screen: splash art + "press any key" -> car select.

var _done := false

func _ready() -> void:
	var bg := $Bg as TextureRect
	if bg:
		bg.texture = TextureLoader.load_texture("res://assets/img/story/splashscreen.png")

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var go := event.is_action_pressed(&"select_confirm")
	go = go or (event is InputEventKey and event.pressed and not event.echo)
	go = go or (event is InputEventMouseButton and event.pressed)
	if go:
		_done = true
		SceneFlow.to_select()
