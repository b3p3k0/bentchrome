class_name VehicleStats
extends Resource
## Per-vehicle identity + design stats (1-10). StatCurves maps these to engine
## units so each car's feel comes from data, not code. Authoring source is
## assets/data/roster.json (an importer can generate these later).

@export var id: StringName = &""
@export var car_name: String = ""
@export var driver_name: String = ""

@export_range(1, 10) var acceleration: int = 5
@export_range(1, 10) var top_speed: int = 5
@export_range(1, 10) var handling: int = 5
@export_range(1, 10) var armor: int = 5
@export_range(1, 10) var special_power: int = 5

@export var primary_color := Color(0.85, 0.2, 0.3)
