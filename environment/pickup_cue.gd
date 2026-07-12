class_name PickupCue
extends Node2D
## Shared pickup readability: a soft pink ring around the real collection
## surface. Pure paint — no collision, light, or gameplay state lives here.

const DEFAULT_RADIUS := 36.0
const DEFAULT_COLOR := Color(1.0, 0.22, 0.62, 0.5)
const PULSE_REACH := 1.5
const PULSE_SPEED := 2.4

@export var radius := DEFAULT_RADIUS
@export var color := DEFAULT_COLOR

var _phase := 0.0

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
	queue_redraw()

func current_radius() -> float:
	return radius + sin(_phase) * PULSE_REACH

func current_alpha() -> float:
	return color.a * lerpf(0.72, 1.0, (sin(_phase) + 1.0) * 0.5)

func _draw() -> void:
	var ink := color
	ink.a = current_alpha()
	draw_arc(Vector2.ZERO, current_radius(), 0.0, TAU, 48, ink, 2.0, true)
