class_name TerrainSensor
extends Area2D
## Reports which terrain the vehicle is currently over; defaults to road when
## not overlapping any zone.

var current_terrain: StringName = &"road"
var _zones: Array[TerrainZone] = []  # entry order; later wins equal priority

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area is TerrainZone:
		_zones.erase(area)
		_zones.append(area)
		_refresh()

func _on_area_exited(area: Area2D) -> void:
	if area is TerrainZone:
		_zones.erase(area)
	# Reconcile physics overlaps in case this sensor entered the tree already
	# touching a zone before its signal connections settled.
	for overlap in get_overlapping_areas():
		if overlap is TerrainZone and overlap not in _zones:
			_zones.append(overlap)
	_refresh()

func _refresh() -> void:
	current_terrain = &"road"
	var best_priority := -2147483648
	var valid: Array[TerrainZone] = []
	for zone in _zones:
		if not is_instance_valid(zone):
			continue
		valid.append(zone)
		if zone.terrain_priority >= best_priority:
			best_priority = zone.terrain_priority
			current_terrain = zone.terrain_type
	_zones = valid
