class_name TerrainSensor
extends Area2D
## Reports which terrain the vehicle is currently over; defaults to road when
## not overlapping any zone.

var current_terrain: StringName = &"road"

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area is TerrainZone:
		current_terrain = area.terrain_type

func _on_area_exited(_area: Area2D) -> void:
	current_terrain = &"road"
	for area in get_overlapping_areas():
		if area is TerrainZone:
			current_terrain = area.terrain_type
			return
