class_name VehicleStats
extends Resource
## Per-vehicle identity + design stats (1-10). StatCurves maps the stats to engine
## units so each car's feel comes from data, not code. Generated from
## assets/data/roster.json by tools/import_roster.gd (the authoring source).

@export var id: StringName = &""
@export var car_name: String = ""
@export var driver_name: String = ""
@export_multiline var flavor: String = ""
@export var special_name: String = ""
@export_multiline var special_desc: String = ""

@export_range(1, 10) var acceleration: int = 5
@export_range(1, 10) var top_speed: int = 5
@export_range(1, 10) var handling: int = 5
@export_range(1, 10) var armor: int = 5
@export_range(1, 10) var special_power: int = 5

@export var primary_color := Color(0.85, 0.2, 0.3)
@export var accent_color := Color(1, 1, 1)

@export var special: WeaponDef  # signature secondary weapon
