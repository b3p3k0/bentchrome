class_name PickupCue
extends Node2D
## Shared pickup readability: a soft pink ring around the real collection
## surface. Pure paint — no collision, light, or gameplay state lives here.

const DEFAULT_RADIUS := 36.0
const DEFAULT_COLOR := Color(1.0, 0.18, 0.62, 0.95)
const UNDER_COLOR := Color(0.12, 0.015, 0.07, 0.72)
const UNDER_WIDTH := 7.0
const PINK_WIDTH := 4.0
const PULSE_DEPTH := 4.0
const PULSES_PER_MINUTE := 18.0
const PULSE_SPEED := TAU * PULSES_PER_MINUTE / 60.0

@export var radius := DEFAULT_RADIUS
@export var color := DEFAULT_COLOR

var _phase := 0.0

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
	queue_redraw()

func current_radius() -> float:
	return radius - (1.0 - _outward_pulse()) * PULSE_DEPTH

func current_alpha() -> float:
	return color.a * lerpf(0.76, 1.0, _outward_pulse())

func _outward_pulse() -> float:
	return (cos(_phase) + 1.0) * 0.5

func _draw() -> void:
	var pulse := _outward_pulse()
	var under := UNDER_COLOR
	under.a *= lerpf(0.82, 1.0, pulse)
	draw_arc(Vector2.ZERO, current_radius(), 0.0, TAU, 48, under, UNDER_WIDTH, true)
	var ink := color
	ink.a = current_alpha()
	draw_arc(Vector2.ZERO, current_radius(), 0.0, TAU, 48, ink, PINK_WIDTH, true)
