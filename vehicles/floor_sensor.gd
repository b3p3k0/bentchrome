class_name FloorSensor
extends Area2D
## Reports the floor tag under the vehicle. Sticky on purpose: keeps the last
## known floor while crossing untagged seams (no flicker), -1 until the first
## zone contact. Where tag zones overlap, the highest floor wins — abutting
## authoring is the mechanism, this tiebreak just absorbs seam slop.

var current_floor := -1

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area is FloorZone:
		_rescan(area.floor_index)

func _on_area_exited(_area: Area2D) -> void:
	_rescan(-1)

func _rescan(incoming: int) -> void:
	# `incoming` covers the enter-order race (the new area may not be in
	# get_overlapping_areas() yet on the entered signal).
	var best := incoming
	for area in get_overlapping_areas():
		if area is FloorZone:
			best = maxi(best, area.floor_index)
	if best >= 1:
		current_floor = best
