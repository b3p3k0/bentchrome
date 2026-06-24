class_name StatusEffectSpec
extends Resource
## A status effect applied to a vehicle. The kind drives behavior; new kinds slot
## into StatusReceiver. magnitude meaning per kind:
##   burn   - damage per second (damage-over-time)
##   slow   - speed multiplier (e.g. 0.5 = half speed)
##   invuln - ignores incoming damage (magnitude unused)
##   stun   - reserved

@export var kind: StringName = &"burn"
@export var duration := 3.0
@export var magnitude := 1.0
