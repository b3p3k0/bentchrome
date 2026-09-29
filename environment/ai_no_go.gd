class_name AiNoGo
extends Node2D
## AI-only danger rect for a place that is lethal only to a driver unable to
## aim a jump. Like every hazard rect, it is axis-aligned.

@export var size := Vector2(256, 256)

func _ready() -> void:
	add_to_group(&"lethal_hazards")
