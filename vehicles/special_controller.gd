class_name SpecialController
extends Node
## Routes a vehicle's "fire special" to the right behavior based on its
## WeaponDef.kind. PROJECTILE reuses the sibling SecondaryMount (WeaponMount);
## BEAM / DASH / TRIGGER are handler slots, filled when those specials are wired.
##
## This is the durable extension point: a new unusual special is a new kind +
## its handler here, while ordinary specials stay pure data on a projectile kind.

const Combat := preload("res://game/combat.gd")  # dependency-free damage rules

const BEAM_DURATION := 4.0        # seconds a zap stays latched
const BEAM_SLOW := 0.5            # handling cripple while zapped
const BEAM_HOLD_FACTOR := 2.0     # latch breaks beyond acquisition * this

const DASH_SPEED := 1400.0        # body-check velocity (well past any top speed)
const DASH_DURATION := 0.4        # ~560px of travel
const DASH_LOCK_RANGE := 700.0    # lock the nearest vehicle inside this
const DASH_INVULN_T := 2.0        # invulnerability after connecting
const DASH_SLOW := 0.5            # victim speed drain
const DASH_SLOW_T := 2.0

const FLAME_DURATION := 1.0       # seconds of column per ammo; hold to chain bursts
const FLAME_LENGTH := 300.0       # nose-forward reach
const FLAME_WIDTH := 70.0         # column thickness

var _def: WeaponDef = null
var _beam_target: Node2D = null
var _beam_t := 0.0
var _beam_line: Line2D = null
var _dash_t := 0.0
var _dash_target: Node2D = null
var _dash_dir := Vector2.RIGHT
var _armed := false
var _flame_t := 0.0
var _flame_vis: Polygon2D = null

@onready var _mount: WeaponMount = get_parent().get_node_or_null("SecondaryMount") if get_parent() else null

func set_weapon(def: WeaponDef) -> void:
	_def = def
	if _mount:
		_mount.set_weapon(def)   # projectile-kind firing lives in the mount

## Returns true when the weapon actually fired (ammo is consumed on true).
func activate(pressed: bool, origin: Vector2, direction: Vector2, shooter: Node) -> bool:
	if _def == null:
		return false
	match _def.kind:
		WeaponDef.Kind.PROJECTILE:
			if pressed and _mount:
				return _mount.try_fire(origin, direction, shooter)
		WeaponDef.Kind.BEAM:
			return _beam(pressed, origin, direction, shooter)
		WeaponDef.Kind.DASH:
			return _dash(pressed, origin, direction, shooter)
		WeaponDef.Kind.TRIGGER:
			return _trigger(pressed, origin, direction, shooter)
		WeaponDef.Kind.FLAME:
			return _flame(pressed)
	return false

## Taser: burst zap — latch the nearest vehicle in close range and shock it for
## BEAM_DURATION (light dps + slow), holding through turns. The latch breaks
## only when line of sight is blocked (wall/block/another car), the target
## strays far beyond range, or the target dies.
func _beam(pressed: bool, origin: Vector2, _direction: Vector2, shooter: Node) -> bool:
	if not pressed or _beam_t > 0.0 or _def == null:
		return false
	var tgt := Targeting.nearest_other(origin, shooter, _def.acquisition_radius)
	if tgt == null or not _los_clear(origin, tgt, shooter):
		return false
	_beam_target = tgt
	_beam_t = BEAM_DURATION
	_beam_line = Line2D.new()
	_beam_line.width = 3.0
	_beam_line.default_color = Color(0.45, 0.9, 1.0, 0.9)
	get_tree().current_scene.add_child(_beam_line)
	return true

func _physics_process(delta: float) -> void:
	if _beam_t > 0.0:
		_beam_tick(delta)
	if _dash_t > 0.0:
		_dash_tick(delta)
	if _flame_t > 0.0:
		_flame_tick(delta)

func _beam_tick(delta: float) -> void:
	var vehicle := get_parent() as Node2D
	if vehicle == null or _beam_target == null or not is_instance_valid(_beam_target):
		_end_beam()
		return
	var muzzle := vehicle.get_node_or_null("Visual/Muzzle") as Node2D
	var origin: Vector2 = muzzle.global_position if muzzle else vehicle.global_position
	var dist := origin.distance_to(_beam_target.global_position)
	if dist > _def.acquisition_radius * BEAM_HOLD_FACTOR or not _los_clear(origin, _beam_target, vehicle):
		_end_beam()
		return
	if _beam_target.has_method("take_ram_damage"):
		# Damage authored as dps; AI-on-AI runs through the governor.
		_beam_target.take_ram_damage(_def.damage * delta * Combat.scale(vehicle, _beam_target), vehicle)
	if _beam_target.has_method("apply_effect"):
		var slow := StatusEffectSpec.new()
		slow.kind = &"slow"
		slow.duration = 0.4  # refreshed every tick while latched
		slow.magnitude = BEAM_SLOW
		_beam_target.apply_effect(slow)
	_beam_line.points = PackedVector2Array([origin, _beam_target.global_position])
	_beam_t -= delta
	if _beam_t <= 0.0:
		_end_beam()

func _end_beam() -> void:
	_beam_target = null
	_beam_t = 0.0
	if _beam_line:
		_beam_line.queue_free()
		_beam_line = null

func _los_clear(from: Vector2, target: Node2D, shooter: Node) -> bool:
	var body := shooter as CollisionObject2D
	var target_body := target as CollisionObject2D
	if body == null or target_body == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(from, target.global_position, 7)  # ground|wall|obstacle
	query.exclude = [body.get_rid(), target_body.get_rid()]
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _exit_tree() -> void:
	_end_beam()   # don't leave an orphaned beam line if the car dies mid-zap
	_end_flame()  # same etiquette for the torch

## Leap: lock the nearest vehicle in range and full-throttle body-check it
## (straight ahead when nothing is in range). The dash overrides normal driving,
## sails over obstacles, and on connecting drains the victim's speed and grants
## the caster brief invulnerability. Ram damage itself comes from the existing
## ram loop — at dash speed that's already a massive hit.
func _dash(pressed: bool, _origin: Vector2, direction: Vector2, shooter: Node) -> bool:
	if not pressed or _dash_t > 0.0:
		return false
	_dash_target = Targeting.nearest_other((shooter as Node2D).global_position, shooter, DASH_LOCK_RANGE)
	_dash_dir = direction
	_dash_t = DASH_DURATION
	if shooter is CollisionObject2D:
		shooter.collision_mask &= ~4  # ignore obstacles mid-leap
	return true

func is_dashing() -> bool:
	return _dash_t > 0.0

func _dash_tick(delta: float) -> void:
	var vehicle := get_parent() as CharacterBody2D
	if vehicle == null:
		_dash_t = 0.0
		return
	if _dash_target and is_instance_valid(_dash_target):
		_dash_dir = (_dash_target.global_position - vehicle.global_position).normalized()
	vehicle.velocity = _dash_dir * DASH_SPEED
	vehicle.set("heading", _dash_dir.angle())
	for i in vehicle.get_slide_collision_count():
		var other := vehicle.get_slide_collision(i).get_collider()
		if other is CharacterBody2D and other != vehicle and other.has_method("apply_effect"):
			var slow := StatusEffectSpec.new()
			slow.kind = &"slow"
			slow.duration = DASH_SLOW_T
			slow.magnitude = DASH_SLOW
			other.apply_effect(slow)
			var invuln := StatusEffectSpec.new()
			invuln.kind = &"invuln"
			invuln.duration = DASH_INVULN_T
			if vehicle.has_method("apply_effect"):
				vehicle.apply_effect(invuln)
			_end_dash(vehicle)
			return
	_dash_t -= delta
	if _dash_t <= 0.0:
		_end_dash(vehicle)

func _end_dash(vehicle: CharacterBody2D) -> void:
	_dash_t = 0.0
	_dash_target = null
	# Restore the mask to match the car's air state (grounded 7 / airborne 2),
	# same split as Vehicle._set_airborne.
	var airborne: bool = vehicle.get("height") != null and vehicle.get("height") > 0.0
	vehicle.set_deferred("collision_mask", 2 if airborne else 7)

## Blunt Blaze: a column of flame off the nose for FLAME_DURATION per ammo —
## holding fire chains bursts into a sustained torch (recharge-fed). Damage is
## authored as dps; anything Health-bearing inside the column cooks, vehicles
## also pick up the def's burn effect (refreshed every tick while bathed).
func _flame(pressed: bool) -> bool:
	if not pressed or _flame_t > 0.0:
		return false
	_flame_t = FLAME_DURATION
	var vehicle := get_parent() as Node2D
	var visual := vehicle.get_node_or_null("Visual") if vehicle else null
	if visual:
		_flame_vis = Polygon2D.new()
		visual.add_child(_flame_vis)  # rides the rotating visual — tracks the nose
	return true

func _flame_tick(delta: float) -> void:
	var vehicle := get_parent() as CollisionObject2D
	if vehicle == null:
		_end_flame()
		return
	if _flame_vis:
		_flame_vis.polygon = _flame_shape()
		_flame_vis.color = Color(1.0, lerpf(0.35, 0.6, randf()), 0.08, 0.8)
	# Damage everything Health-bearing inside the column (cars, crates, dummies).
	var shape := RectangleShape2D.new()
	shape.size = Vector2(FLAME_LENGTH, FLAME_WIDTH)
	var heading: float = vehicle.get("heading")
	var forward := Vector2.RIGHT.rotated(heading)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(heading, vehicle.global_position + forward * (FLAME_LENGTH * 0.5 + 30.0))
	params.collision_mask = 5  # ground | obstacle
	params.exclude = [vehicle.get_rid()]
	for hit in vehicle.get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		for child in body.get_children():
			if child is Health:
				child.take_damage(_def.damage * delta * Combat.scale(vehicle, body))
				if "last_attacker" in body:
					body.last_attacker = vehicle
				break
		if body.has_method("apply_effect"):
			for spec in _def.on_hit_effects:
				body.apply_effect(spec)
	_flame_t -= delta
	if _flame_t <= 0.0:
		_end_flame()

## A jagged, flickering column in the visual's local space (nose at +X).
func _flame_shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := FLAME_WIDTH * 0.5
	pts.append(Vector2(26.0, -6.0))
	for i in 4:  # ragged top edge, widening with distance
		var x := lerpf(80.0, 30.0 + FLAME_LENGTH, float(i) / 3.0)
		pts.append(Vector2(x + randf_range(-12.0, 12.0), lerpf(-14.0, -half, float(i) / 3.0) + randf_range(-6.0, 6.0)))
	pts.append(Vector2(30.0 + FLAME_LENGTH + randf_range(-8.0, 16.0), randf_range(-10.0, 10.0)))
	for i in 4:  # ragged bottom edge back toward the nose
		var x := lerpf(30.0 + FLAME_LENGTH, 80.0, float(i) / 3.0)
		pts.append(Vector2(x + randf_range(-12.0, 12.0), lerpf(half, 14.0, float(i) / 3.0) + randf_range(-6.0, 6.0)))
	pts.append(Vector2(26.0, 6.0))
	return pts

func _end_flame() -> void:
	_flame_t = 0.0
	if _flame_vis:
		_flame_vis.queue_free()
		_flame_vis = null

## Toe Jam: arm a charge that replaces the next landed ram's speed-scaled
## damage with one heavy flat hit (def.damage). Held until it connects; the
## front bumper glows while armed.
func _trigger(pressed: bool, _origin: Vector2, _direction: Vector2, _shooter: Node) -> bool:
	if not pressed or _armed:
		return false
	_armed = true
	_set_bumper_glow(true)
	return true

## Called by Vehicle._update_ram on a landed ram. Pays out the charged damage
## exactly once (0.0 when unarmed).
func take_armed_hit() -> float:
	if not _armed:
		return 0.0
	_armed = false
	_set_bumper_glow(false)
	return _def.damage if _def else 0.0

func _set_bumper_glow(on: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bumper := parent.get_node_or_null("Visual/FrontBumper") as CanvasItem
	if bumper:
		bumper.modulate = Color(2.2, 1.6, 0.6) if on else Color.WHITE
