extends Resource
class_name StatRanges

## Resource defining min/max ranges for vehicle stat scaling
## Used to convert 1-10 scale stats from roster.json to actual gameplay values

@export_group("Max Speed")
@export var max_speed_min: float = 170.0
@export var max_speed_max: float = 285.0

@export_group("Acceleration")
@export var accel_min: float = 450.0
@export var accel_max: float = 1200.0

@export_group("Deceleration")
@export var decel_min: float = 320.0
@export var decel_max: float = 800.0

@export_group("Brake Force")
@export var brake_min: float = 900.0
@export var brake_max: float = 1500.0

@export_group("Handling Lock Duration")
@export var handling_lock_min: float = 0.22
@export var handling_lock_max: float = 0.05

@export_group("Handling Drag Multiplier")
@export var handling_drag_min: float = 1.25
@export var handling_drag_max: float = 0.7

@export_group("Handling Snap Smoothing")
@export var handling_snap_min: float = 0.35
@export var handling_snap_max: float = 0.9

@export_group("Armor")
@export var armor_min: float = 55.0
@export var armor_max: float = 155.0

@export_group("Special Power")
@export var special_min: float = 0.8
@export var special_max: float = 1.2