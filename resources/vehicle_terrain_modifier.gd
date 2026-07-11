class_name VehicleTerrainModifier
extends Resource
## Optional per-ride factors layered over the global terrain table. Defaults are
## deliberately neutral: adding this Resource to a future car changes nothing
## until an author moves a multiplier away from 1.0.

@export var terrain: StringName = &"road"
@export_range(0.05, 3.0, 0.01) var accel := 1.0
@export_range(0.05, 3.0, 0.01) var top := 1.0
@export_range(0.05, 3.0, 0.01) var grip := 1.0
@export_range(0.05, 3.0, 0.01) var steer := 1.0
@export_range(0.05, 3.0, 0.01) var dash_damage := 1.0

func factor(property: StringName) -> float:
	match property:
		&"accel":
			return accel
		&"top":
			return top
		&"grip":
			return grip
		&"steer":
			return steer
		&"dash_damage":
			return dash_damage
	return 1.0
