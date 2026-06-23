class_name Ramp
extends Area2D
## Launches a vehicle that drives over it into the air (fake depth).

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Vehicle:
		body.launch_from_ramp()
