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
@export_range(1, 10) var mass: int = 5  # 1 = motorcycle, 8 = monster truck; >8 reserved

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
