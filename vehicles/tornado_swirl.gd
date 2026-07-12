extends Node2D
## The wind that says ATTACK MODE: rotating arc strokes drawn exactly at the
## tornado's AoE radius — the telegraph and the hitbox can never disagree —
## with counter-rotating inner gusts and trailing streak tips. Pure paint;
## SpecialController owns the lifecycle, parented to the axis-aligned
## vehicle root so the whirl is its own motion, not the car's.

const OUTER_COLOR := Color(0.92, 0.95, 1.0, 0.75)
const UNDER_COLOR := Color(0.05, 0.05, 0.08, 0.45)  # dark under-arc: readable on snow
const INNER_COLOR := Color(0.85, 0.9, 0.98, 0.5)
const SPIN_RATE := -3.4   # rad/s — counter to the hull whirl reads as a vortex
const INNER_RATE := 4.6
const SWEEP := deg_to_rad(85.0)

var radius := 60.0  # set by SpecialController from _tornado_radius()

var _outer_a := 0.0
var _inner_a := 0.0

func _process(delta: float) -> void:
	_outer_a = wrapf(_outer_a + SPIN_RATE * delta, 0.0, TAU)
	_inner_a = wrapf(_inner_a + INNER_RATE * delta, 0.0, TAU)
	queue_redraw()

func _draw() -> void:
	var flutter := 0.85 + 0.15 * sin(_inner_a * 3.0)
	for k in 3:
		var start := _outer_a + TAU * float(k) / 3.0
		draw_arc(Vector2.ZERO, radius, start, start + SWEEP, 18, UNDER_COLOR, 5.0)
		draw_arc(Vector2.ZERO, radius, start, start + SWEEP, 18,
			Color(OUTER_COLOR, OUTER_COLOR.a * flutter), 3.5)
		var tip := Vector2.RIGHT.rotated(start + SWEEP) * radius
		var tail := Vector2.RIGHT.rotated(start + SWEEP + 0.22) * (radius * 0.94)
		draw_line(tip, tail, Color(OUTER_COLOR, OUTER_COLOR.a * 0.5 * flutter), 2.0)
	for k in 3:
		var start := _inner_a + TAU * float(k) / 3.0 + 0.5
		draw_arc(Vector2.ZERO, radius * 0.55, start, start + deg_to_rad(70.0), 12,
			INNER_COLOR, 2.5)
