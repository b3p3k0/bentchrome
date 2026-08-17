class_name VehicleStats
extends Resource
## Per-vehicle identity + design stats (1-20; odd values = the migrated legacy
## 1-10 line). StatCurves maps the stats to engine units so each car's feel
## comes from data, not code. Generated from assets/data/roster.json by
## tools/import_roster.gd (the authoring source).

@export var id: StringName = &""
@export var car_name: String = ""
@export var driver_name: String = ""
@export_multiline var flavor: String = ""
@export var special_name: String = ""
@export_multiline var special_desc: String = ""

@export_range(1, 20) var acceleration: int = 9
@export_range(1, 20) var top_speed: int = 9
@export_range(1, 20) var handling: int = 9
@export_range(1, 20) var armor: int = 9
@export_range(1, 20) var special_power: int = 9  # display-only today; future special axis
@export_range(1, 20) var mass: int = 9  # 1 = motorcycle, 15 = monster truck; 17+ boss
@export_range(0, 20) var launch: int = 0  # standing-start torque; 0 = derive from mass

@export var primary_color := Color(0.85, 0.2, 0.3)
@export var accent_color := Color(1, 1, 1)

@export var special: WeaponDef  # signature secondary weapon
@export var special_ammo_cap := 1            # rounds held at once
@export var special_recharge_seconds := 12.0 # time to regrow one round
@export var turret: WeaponDef  # bosses: auto-aiming hull turret (weapons/turret.gd);
							   # null = none. Fires autonomously at the player.
@export var special_b: WeaponDef  # twin special: shares the SPECIAL slot's ammo
								  # pool — using either barrel depletes both.
								  # SpecialController picks per activation.
@export var no_mines := false  # this car never arms mines, crates included
@export var burn_taken := 1.0  # burn-DoT multiplier (air-cooled engines pay extra)

## Slide-move identity (Car Tuner columns; roster-authorable, defaults neutral).
@export var whip_scale := 1.0      # multiplies the mass-lerped handbrake-180 rate
@export var side_slam_bonus := 1.5 # this car's broadside ram premium

## Garage-wired multipliers (all 1.0 stock; VehicleLoadout composes them
## MULTIPLICATIVELY so co-owned electronics stack order-free).
@export var mg_heat_scale := 1.0      # MG heat gain per shot (MG Cooling)
@export var tracking_scale := 1.0    # shooter-side lock reach AND homing turn (Improved Lock)
@export var radar_range_scale := 1.0 # viewer-side sensor reach (Extended Radar)
@export var detectability := 1.0     # target-side: how far others' sensors/AI notice you

## Optional, multiplicative surface identity. The shared DrivingController
## composes these over its global terrain table; missing entries stay neutral.
@export var terrain_modifiers: Array[VehicleTerrainModifier] = []

# Per-car raw handling-knob overrides (knob name -> value) applied after
# StatCurves, so hand-tuning wins while StatCurves stays the default. Written by
# the dev dashboard's Export.
@export var handling_overrides: Dictionary = {}

func terrain_factor(surface: StringName, property: StringName) -> float:
	for modifier in terrain_modifiers:
		if modifier != null and modifier.terrain == surface:
			return modifier.factor(property)
	return 1.0
