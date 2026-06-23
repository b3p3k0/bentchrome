class_name TerrainZone
extends Area2D
## A painted surface region (road/dirt/ice/water). The vehicle's TerrainSensor
## reads terrain_type to modulate grip, acceleration, and top speed.

@export var terrain_type: StringName = &"road"
