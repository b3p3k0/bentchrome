extends SubViewportContainer

@onready var sub_viewport := $SubViewport

func _ready():
	if sub_viewport:
		_update_viewport_size()
		resized.connect(_update_viewport_size)

func _update_viewport_size():
	if sub_viewport:
		sub_viewport.size = Vector2i(size)