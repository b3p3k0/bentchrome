class_name WeaponDef
extends Resource
## A secondary weapon, including each car's signature special. The machine gun
## and every secondary share this one shape; behavior is data, not code:
## turn_rate_deg + acquisition_radius = homing, spread_deg + pellets = salvo.
## Specials that need systems we don't have yet (burn, slow, dash, channel,
## collision-trigger) are marked stub = true and fire nothing until built.

enum Kind { PROJECTILE, BEAM, DASH, TRIGGER, FLAME, DROP }

@export var display_name: String = "Special"
@export var kind := Kind.PROJECTILE     # dispatched by SpecialController
@export var on_hit_effects: Array[StatusEffectSpec] = []  # applied to what a projectile hits
@export var cooldown := 1.0             # seconds between uses (recharge)
@export var damage := 25.0
@export var projectile_speed := 650.0
@export var projectile_lifetime := 3.0
@export var turn_rate_deg := 0.0        # >0 = homing
@export var acquisition_radius := 0.0   # homing lock range
@export var spread_deg := 0.0           # fan width for multi-pellet salvos
@export var pellets := 1
@export var projectile_scene: PackedScene
@export var pierces_cover := false      # projectile ignores obstacles (layer 3)
@export var stub := false               # not implemented yet — fires nothing
@export_multiline var note := ""        # design intent (esp. for stubs)
