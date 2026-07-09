class_name FloorSensor
extends Area2D
## Reports the floor tag under the vehicle. Sticky on purpose: keeps the last
## known floor while crossing untagged seams (no flicker), -1 until the first
## zone contact. Where tag zones overlap, the highest floor wins — abutting
## authoring is the mechanism, this tiebreak just absorbs seam slop.

var current_floor := -1
var on_ramp := false  # the CURRENT winning overlap is a driveable ramp half.
					  # Never sticky: leaving all zones clears it, so a car
					  # that drove off a ramp can't keep grade-adopting.

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area is FloorZone:
		_rescan(area.floor_index, area.ramp)

func _on_area_exited(_area: Area2D) -> void:
	_rescan(-1, false)

func _rescan(incoming: int, incoming_ramp: bool) -> void:
	# `incoming` covers the enter-order race (the new area may not be in
	# get_overlapping_areas() yet on the entered signal).
	var best := incoming
	var best_ramp := incoming_ramp
	for area in get_overlapping_areas():
		if not (area is FloorZone):
			continue
		var f: int = area.floor_index
		if f > best:
			best = f
			best_ramp = area.ramp
		elif f == best and area.ramp:
			best_ramp = true  # equal-floor tie: standing on ramp surface wins
	if best >= 1:
		current_floor = best
		on_ramp = best_ramp
	else:
		on_ramp = false  # sticky floor memory never carries the ramp flag
