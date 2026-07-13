class_name SpecialController
extends Node
## Routes a vehicle's "fire special" to the right behavior based on its
## WeaponDef.kind. PROJECTILE reuses the sibling SecondaryMount (WeaponMount);
## BEAM / DASH / TRIGGER are handler slots, filled when those specials are wired.
##
## This is the durable extension point: a new unusual special is a new kind +
## its handler here, while ordinary specials stay pure data on a projectile kind.

const Combat := preload("res://game/combat.gd")  # dependency-free damage rules
const Floors := preload("res://game/floors.gd")  # terraced-floor gates (same rules)
const NetEvents := preload("res://game/net/net_events.gd")  # host-armed FX tap (leaf)
const TornadoSwirl := preload("res://vehicles/tornado_swirl.gd")  # AoE-honest wind ring
const PulseRing := preload("res://vehicles/pulse_ring.gd")  # damage-front-honest blast ring
const ElectricArcScene := preload("res://environment/electric_arc_fx.tscn")

const BEAM_DURATION := 4.0        # legacy fallback; current defs author active_duration
const BEAM_SLOW := 0.5            # handling cripple while zapped
const BEAM_HOLD_FACTOR := 2.0     # latch breaks beyond acquisition * this

const DASH_SPEED := 1400.0        # body-check velocity (well past any top speed)
const DASH_DURATION := 0.4        # ~560px of travel
const DASH_LOCK_RANGE := 700.0    # lock the nearest vehicle inside this
const DASH_INVULN_T := 2.0        # invulnerability after connecting
const DASH_SLOW := 0.5            # victim speed drain
const DASH_SLOW_T := 2.0

const FLAME_DURATION := 3.0       # legacy fallback; current defs author active_duration
								  # July 2026 balance: 5s + 30 dps read OP in playtest
const FLAME_LENGTH := 300.0       # nose-forward reach
const FLAME_WIDTH := 70.0         # column thickness

const DROP_COOLDOWN := 0.5        # held button lays a trail, not a carpet

# Tornado Alley (Cyclone): rear wheels up, violent spin, mobile AoE.
static var TORNADO_SPIN_DEG := 900.0   # visual whirl rate (quantizer bypassed)
static var TORNADO_STEER := 0.3        # steer authority left while spinning
static var TORNADO_RADIUS_MULT := 2.2  # AoE radius = this x the visual footprint
                                       # (the swirl ring draws exactly here)
static var TORNADO_SHOVE := 220.0      # outward shove on a caught car (once each)
static var TORNADO_DEV_MIN := 5.0      # course-deviation band (deg) — the land-mine
static var TORNADO_DEV_MAX := 45.0     # spin-out idiom, momentum preserved

# Pulse Wave (Hubcap): expanding radial blast, center-out falloff + shove.
# Range = def.projectile_speed x def.projectile_lifetime (wave speed x time).
static var PULSE_EDGE_FRAC := 0.25     # damage/shove remaining at the rim
static var PULSE_SHOVE := 380.0        # radial shove at point-blank (px/s, additive)
static var PULSE_HOP_VZ := 200.0       # the caster's little launch kick

const TRIGGER_WINDOW := 5.0       # armed Toe Jam expires unspent after this

var _def: WeaponDef = null
var _twin: WeaponDef = null       # second barrel sharing the SPECIAL ammo pool
var _beam_def: WeaponDef = null   # running effects keep the def they latched
var _flame_def: WeaponDef = null  # with — selection/twin swaps can't corrupt them
var _armed_damage := 0.0
var _beam_target: Node2D = null
var _beam_t := 0.0
var _beam_fx: Node2D = null
var _dash_t := 0.0
var _dash_target: Node2D = null
var _dash_dir := Vector2.RIGHT
var _dash_damage_mult := 1.0  # terrain snapshot; consumed by first landed ram
var _armed := false
var _armed_t := 0.0               # Toe Jam use-it-or-lose-it countdown
var _armed_fx: CPUParticles2D = null
var _flame_t := 0.0
var _flame_vis: Polygon2D = null
var _drop_cd := 0.0
var _sustained_cooldown_t := 0.0  # BEAM/FLAME: starts only after the effect ends
var _tornado_t := 0.0
var _tornado_def: WeaponDef = null
var _tornado_spin := 0.0          # accumulated visual whirl angle
var _tornado_hit := {}            # instance id -> true: one spin-out per victim
var _tornado_fx: CPUParticles2D = null
var _tornado_swirl: Node2D = null # the wind ring drawn at the AoE boundary
var _pulse_t := 0.0               # elapsed expansion time
var _pulse_def: WeaponDef = null
var _pulse_origin := Vector2.ZERO # the wave detaches — anchored at cast position
var _pulse_hit := {}              # instance id -> true: the front crosses each body once
var _pulse_ring: Node2D = null

@onready var _mount: WeaponMount = get_parent().get_node_or_null("SecondaryMount") if get_parent() else null

func set_weapon(def: WeaponDef) -> void:
	_def = def
	if _mount:
		_mount.set_weapon(def)   # projectile-kind firing lives in the mount

## Twin special: a second barrel on the same ammo pool (non-PROJECTILE kinds
## only — the mount owns projectile defs). Chosen per activation.
func set_twin(def: WeaponDef) -> void:
	_twin = def

## Pick the barrel that fits the moment: the BEAM (latch weapon) when a target
## sits inside its acquisition with clear LoS, otherwise the partner (the
## close-quarters barrel). Running effects keep the def they latched with.
func _active_def(origin: Vector2, shooter: Node) -> WeaponDef:
	if _twin == null or _def == null:
		return _def
	var beam_def: WeaponDef = null
	if _twin.kind == WeaponDef.Kind.BEAM:
		beam_def = _twin
	elif _def.kind == WeaponDef.Kind.BEAM:
		beam_def = _def
	if beam_def == null:
		return _def
	var other: WeaponDef = _def if beam_def == _twin else _twin
	var tgt := Targeting.nearest_other(origin, shooter, beam_def.acquisition_radius, shooter)
	if tgt and _los_clear(origin, tgt, shooter):
		return beam_def
	return other

## Returns true when the weapon actually fired (ammo is consumed on true).
func activate(pressed: bool, origin: Vector2, direction: Vector2, shooter: Node) -> bool:
	if _def == null:
		return false
	var def := _active_def(origin, shooter) if pressed else _def
	if def == null:
		return false
	if def.kind in [WeaponDef.Kind.BEAM, WeaponDef.Kind.FLAME] \
			and (_beam_t > 0.0 or _flame_t > 0.0 or _sustained_cooldown_t > 0.0):
		return false  # twin barrels share one active/post-fire gate
	match def.kind:
		WeaponDef.Kind.PROJECTILE:
			if pressed and _mount:
				return _mount.try_fire(origin, direction, shooter)
		WeaponDef.Kind.BEAM:
			return _beam(pressed, origin, direction, shooter, def)
		WeaponDef.Kind.DASH:
			return _dash(pressed, origin, direction, shooter)
		WeaponDef.Kind.TRIGGER:
			return _trigger(pressed, def)
		WeaponDef.Kind.FLAME:
			return _flame(pressed, def)
		WeaponDef.Kind.DROP:
			return _drop(pressed, shooter, def)
		WeaponDef.Kind.TORNADO:
			return _tornado(pressed, def)
		WeaponDef.Kind.PULSE:
			return _pulse(pressed, def, shooter)
	return false

## Mines: deploy off the REAR bumper. Internal cooldown so a held button lays
## a trail, not a carpet. Ammo is consumed by the caller on true, as always.
func _drop(pressed: bool, shooter: Node, def: WeaponDef) -> bool:
	if not pressed or _drop_cd > 0.0 or def.projectile_scene == null:
		return false
	var vehicle := shooter as Node2D
	var scene := get_tree().current_scene
	if vehicle == null or scene == null:
		return false
	_drop_cd = DROP_COOLDOWN
	var mine := def.projectile_scene.instantiate()
	var heading: float = vehicle.get("heading")
	mine.global_position = vehicle.global_position - Vector2.RIGHT.rotated(heading) * 48.0
	mine.damage = def.damage
	mine.dropper = shooter
	if "floor_index" in mine:
		mine.floor_index = Floors.floor_of(shooter)  # armed for the dropper's terrace
		if mine is CanvasItem and int(mine.floor_index) >= 3:
			mine.z_index = 2  # sit ON the terrace deck paint, not under it
	scene.add_child(mine)
	if "net_id" in mine:
		# Reliable plane: clients grow a cosmetic twin they can actually SEE.
		mine.net_id = NetEvents.next_mine_id()
		NetEvents.mine_drop(int(mine.net_id), def.projectile_scene.resource_path,
			mine.global_position, int(mine.get("floor_index")), bool(mine.get("jump")))
	return true

## Taser: burst zap — latch the nearest vehicle in close range and shock it for
## BEAM_DURATION (light dps + slow), holding through turns. The latch breaks
## only when line of sight is blocked (wall/block/another car), the target
## strays far beyond range, or the target dies.
func _beam(pressed: bool, origin: Vector2, _direction: Vector2, shooter: Node, def: WeaponDef) -> bool:
	if not pressed or _beam_t > 0.0 or def == null:
		return false
	var tgt := Targeting.nearest_other(origin, shooter, def.acquisition_radius, shooter)
	if tgt == null or not _los_clear(origin, tgt, shooter):
		return false
	var fx_scene := get_tree().current_scene
	if fx_scene == null:
		return false  # headless fixtures may not set one — same guard as the mount
	_beam_def = def
	_beam_target = tgt
	_beam_t = _duration(def, BEAM_DURATION)
	_beam_fx = ElectricArcScene.instantiate() as Node2D
	if shooter is CanvasItem:
		_beam_fx.z_index = (shooter as CanvasItem).z_index  # arcs above fl-3 decks
	fx_scene.add_child(_beam_fx)
	NetEvents.beam_on(shooter as Node2D, tgt)  # clients mirror the latch
	return true

func _physics_process(delta: float) -> void:
	# Tick before active effects: when one ends below and arms the cooldown, its
	# first full frame is the NEXT frame — firing time never pays the lockout.
	if _sustained_cooldown_t > 0.0 and _beam_t <= 0.0 and _flame_t <= 0.0:
		_sustained_cooldown_t = maxf(_sustained_cooldown_t - delta, 0.0)
		if _sustained_cooldown_t < 0.0001:
			_sustained_cooldown_t = 0.0  # float grain must not steal an extra frame
	if _beam_t > 0.0:
		_beam_tick(delta)
	if _dash_t > 0.0:
		_dash_tick(delta)
	if _flame_t > 0.0:
		_flame_tick(delta)
	if _tornado_t > 0.0:
		_tornado_tick(delta)
	if _pulse_def != null:
		_pulse_tick(delta)
	if _drop_cd > 0.0:
		_drop_cd -= delta
	if _armed and _armed_t > 0.0:
		_armed_t -= delta
		if _armed_t <= 0.0:
			_disarm_expired()

func _beam_tick(delta: float) -> void:
	var vehicle := get_parent() as Node2D
	if vehicle == null or _beam_target == null or not is_instance_valid(_beam_target):
		_end_beam()
		return
	var muzzle := vehicle.get_node_or_null("Visual/Muzzle") as Node2D
	var origin: Vector2 = muzzle.global_position if muzzle else vehicle.global_position
	var dist := origin.distance_to(_beam_target.global_position)
	if _beam_def == null \
			or dist > _beam_def.acquisition_radius * BEAM_HOLD_FACTOR \
			or not Floors.same_floor(vehicle, _beam_target) \
			or not _los_clear(origin, _beam_target, vehicle):
		_end_beam()  # a roof-drop snaps the taser, same as breaking LoS
		return
	if _beam_target.has_method("take_ram_damage"):
		# Damage authored as dps; AI-on-AI runs through the governor.
		_beam_target.take_ram_damage(_beam_def.damage * delta * Combat.scale(vehicle, _beam_target), vehicle)
	if _beam_target.has_method("apply_effect"):
		var slow := StatusEffectSpec.new()
		slow.kind = &"slow"
		slow.duration = 0.4  # refreshed every tick while latched
		slow.magnitude = BEAM_SLOW
		_beam_target.apply_effect(slow)
	if _beam_fx:
		_beam_fx.set_arc(origin, _beam_target.global_position)
	_beam_t -= delta
	if _beam_t <= 0.0:
		_end_beam()

func _end_beam(arm_cooldown := true) -> void:
	var cooldown := _beam_def.cooldown if _beam_def else 0.0
	var was_active := _beam_def != null
	_beam_target = null
	_beam_def = null
	_beam_t = 0.0
	if arm_cooldown and was_active:
		_sustained_cooldown_t = maxf(cooldown, 0.0)
	if _beam_fx:
		_beam_fx.queue_free()
		_beam_fx = null
	if was_active:
		NetEvents.beam_off(get_parent() as Node2D)  # early breaks included

func _los_clear(from: Vector2, target: Node2D, shooter: Node) -> bool:
	var body := shooter as CollisionObject2D
	var target_body := target as CollisionObject2D
	if body == null or target_body == null:
		return false
	# Legacy = ground|wall|obstacle (7); floor mode = walls + own-floor statics.
	var query := PhysicsRayQueryParameters2D.create(
		from, target.global_position, Floors.los_mask(Floors.floor_of(shooter)))
	query.exclude = [body.get_rid(), target_body.get_rid()]
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _exit_tree() -> void:
	_end_beam(false)   # don't leave an orphaned beam line if the car dies mid-zap
	_end_flame(false)  # same etiquette for the torch
	_end_tornado(false)
	_end_pulse()
	_dash_t = 0.0
	_dash_target = null
	_dash_damage_mult = 1.0

## Leap: lock the nearest vehicle in range and full-throttle body-check it
## (straight ahead when nothing is in range). The dash overrides normal driving,
## sails over obstacles, and on connecting drains the victim's speed and grants
## the caster brief invulnerability. Ram damage itself comes from the existing
## ram loop — at dash speed that's already a massive hit.
func _dash(pressed: bool, _origin: Vector2, direction: Vector2, shooter: Node) -> bool:
	if not pressed or _dash_t > 0.0:
		return false
	_dash_target = Targeting.nearest_other((shooter as Node2D).global_position, shooter, DASH_LOCK_RANGE, shooter)
	_dash_dir = direction
	_dash_t = DASH_DURATION
	_dash_damage_mult = 1.0
	if shooter.has_method(&"terrain_factor"):
		_dash_damage_mult = float(shooter.terrain_factor(&"dash_damage"))
	if shooter is CollisionObject2D:
		shooter.collision_mask &= ~4  # ignore obstacles mid-leap
	return true

func is_dashing() -> bool:
	return _dash_t > 0.0

func dash_damage_multiplier() -> float:
	return _dash_damage_mult if _dash_t > 0.0 else 1.0

## Vehicle's ram authority calls this only on a real vehicle impact. Consuming
## prevents one dash from pricing multiple cars in the same physics frame.
func take_dash_ram_multiplier() -> float:
	if _dash_t <= 0.0:
		return 1.0
	var value := _dash_damage_mult
	_dash_damage_mult = 1.0
	return value

func cancel_dash() -> void:
	var vehicle := get_parent() as CharacterBody2D
	if _dash_t > 0.0 and vehicle:
		_end_dash(vehicle)
	else:
		_dash_t = 0.0
		_dash_target = null
		_dash_damage_mult = 1.0

## A world interaction has taken the wheel. Running sustained effects end as a
## real early finish (and therefore arm their authored post-fire cooldown);
## a live dash gives up its movement override and ram premium.
func cancel_for_interaction() -> void:
	_end_beam()
	_end_flame()
	_end_tornado(false)  # interaction owns the pose — no random exit heading
	_end_pulse()
	cancel_dash()

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
	_dash_damage_mult = 1.0
	# Restore the mask to match the car's air state, same split as
	# Vehicle._set_airborne. Grounded values come from the car's own mask
	# authority (floor-aware); duck-typed — never name Vehicle here.
	var airborne: bool = vehicle.get("height") != null and vehicle.get("height") > 0.0
	if airborne:
		vehicle.set_deferred("collision_mask", 2)
	elif vehicle.has_method(&"current_ground_mask"):
		vehicle.set_deferred("collision_mask", vehicle.current_ground_mask())
	else:
		vehicle.set_deferred("collision_mask", 7)

## Blunt Blaze: a column of flame off the nose for FLAME_DURATION per ammo —
## holding fire chains bursts into a sustained torch (recharge-fed). Damage is
## authored as dps; anything Health-bearing inside the column cooks, vehicles
## also pick up the def's burn effect (refreshed every tick while bathed).
func _flame(pressed: bool, def: WeaponDef) -> bool:
	if not pressed or _flame_t > 0.0:
		return false
	_flame_def = def
	_flame_t = _duration(def, FLAME_DURATION)
	_build_flame_vis()
	return true

## Shared by the live cast and the network mirror.
func _build_flame_vis() -> void:
	var vehicle := get_parent() as Node2D
	var visual := vehicle.get_node_or_null("Visual") if vehicle else null
	if visual and _flame_vis == null:
		_flame_vis = Polygon2D.new()
		visual.add_child(_flame_vis)  # rides the rotating visual — tracks the nose

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
	params.transform = Transform2D(heading, vehicle.global_position + forward * (FLAME_LENGTH * 0.5 + _nose() + 4.0))
	params.collision_mask = 5 | (1 << 9)  # ground | obstacle | soft target
	params.collide_with_areas = true
	params.exclude = [vehicle.get_rid()]
	if _flame_def == null:
		_end_flame()
		return
	for hit in vehicle.get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if not Floors.same_floor(vehicle, body):
			continue  # the torch doesn't reach up to roofs or down to the shore
		for child in body.get_children():
			if child is Health:
				if "last_attacker" in body:
					body.last_attacker = vehicle
				child.take_damage(_flame_def.damage * delta * Combat.scale(vehicle, body))
				break
		if body.has_method("apply_effect"):
			for spec in _flame_def.on_hit_effects:
				body.apply_effect(spec)
	_flame_t -= delta
	if _flame_t <= 0.0:
		_end_flame()

## The shooter's body half-length — the flame roots at the real nose, whatever
## the car's paint style says it is (fallback = the classic 26px square).
func _nose() -> float:
	var vehicle := get_parent()
	if vehicle and vehicle.has_method("body_metrics"):
		var m: Dictionary = vehicle.body_metrics()
		return float(m.get("half_len", 26.0))
	return 26.0

## A jagged, flickering column in the visual's local space (nose at +X).
func _flame_shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := FLAME_WIDTH * 0.5
	var nose := _nose()
	var root := nose + 4.0
	pts.append(Vector2(nose, -6.0))
	for i in 4:  # ragged top edge, widening with distance
		var x := lerpf(root + 50.0, root + FLAME_LENGTH, float(i) / 3.0)
		pts.append(Vector2(x + randf_range(-12.0, 12.0), lerpf(-14.0, -half, float(i) / 3.0) + randf_range(-6.0, 6.0)))
	pts.append(Vector2(root + FLAME_LENGTH + randf_range(-8.0, 16.0), randf_range(-10.0, 10.0)))
	for i in 4:  # ragged bottom edge back toward the nose
		var x := lerpf(root + FLAME_LENGTH, root + 50.0, float(i) / 3.0)
		pts.append(Vector2(x + randf_range(-12.0, 12.0), lerpf(half, 14.0, float(i) / 3.0) + randf_range(-6.0, 6.0)))
	pts.append(Vector2(nose, 6.0))
	return pts

func _end_flame(arm_cooldown := true) -> void:
	var cooldown := _flame_def.cooldown if _flame_def else 0.0
	var was_active := _flame_def != null
	_flame_t = 0.0
	_flame_def = null
	if arm_cooldown and was_active:
		_sustained_cooldown_t = maxf(cooldown, 0.0)
	if _flame_vis:
		_flame_vis.queue_free()
		_flame_vis = null

## Tornado Alley: the rear wheels lift and the car whips into a violent spin
## for active_duration — a mobile AoE that cooks anything Health-bearing in a
## ring ~TORNADO_RADIUS_MULT x the visual footprint (damage authored as dps).
## A caught car gets the land-mine spin-out (course deviation, momentum kept)
## plus an outward shove, once per activation. The Vehicle reads is_spinning()
## to whirl the visual past the 16-step quantizer and cut steer authority;
## when it stops, the nose points wherever the spin left it.
func _tornado(pressed: bool, def: WeaponDef) -> bool:
	if not pressed or _tornado_t > 0.0:
		return false
	_tornado_def = def
	_tornado_t = _duration(def, 3.0)
	_tornado_hit = {}
	var vehicle := get_parent() as Node2D
	_tornado_spin = float(vehicle.get("heading")) if vehicle else 0.0
	_build_tornado_fx()
	return true

## Shared by the live cast and the network mirror.
func _build_tornado_fx() -> void:
	var vehicle := get_parent() as Node2D
	if vehicle == null or _tornado_fx != null:
		return
	_tornado_fx = CPUParticles2D.new()
	_tornado_fx.amount = 30
	_tornado_fx.lifetime = 0.5
	_tornado_fx.local_coords = false
	_tornado_fx.spread = 180.0
	_tornado_fx.gravity = Vector2.ZERO
	_tornado_fx.initial_velocity_min = 30.0
	_tornado_fx.initial_velocity_max = 80.0
	_tornado_fx.tangential_accel_min = 140.0  # the vortex read
	_tornado_fx.tangential_accel_max = 220.0
	_tornado_fx.scale_amount_min = 2.0
	_tornado_fx.scale_amount_max = 4.0
	_tornado_fx.color = Color(0.62, 0.56, 0.46, 0.55)  # the swirl carries the read
	vehicle.add_child(_tornado_fx)
	_tornado_swirl = TornadoSwirl.new()
	_tornado_swirl.radius = _tornado_radius()
	_tornado_swirl.z_index = 2  # over the car, under explosions
	vehicle.add_child(_tornado_swirl)

func _tornado_tick(delta: float) -> void:
	var vehicle := get_parent() as CollisionObject2D
	if vehicle == null or _tornado_def == null:
		_end_tornado(false)
		return
	_tornado_spin += deg_to_rad(TORNADO_SPIN_DEG) * delta
	var shape := CircleShape2D.new()
	shape.radius = _tornado_radius()
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, vehicle.global_position)
	params.collision_mask = 5 | (1 << 9)  # ground | obstacle | soft target
	params.collide_with_areas = true
	params.exclude = [vehicle.get_rid()]
	for hit in vehicle.get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if not Floors.same_floor(vehicle, body):
			continue  # the funnel stays on its own terrace
		for child in body.get_children():
			if child is Health:
				if "last_attacker" in body:
					body.last_attacker = vehicle
				child.take_damage(_tornado_def.damage * delta * Combat.scale(vehicle, body))
				break
		if body is CharacterBody2D and body.has_method("apply_effect") \
				and not _tornado_hit.has(body.get_instance_id()) \
				and not bool(body.get("launch_immune")):
			_tornado_hit[body.get_instance_id()] = true
			var dev := deg_to_rad(randf_range(TORNADO_DEV_MIN, TORNADO_DEV_MAX))
			if randf() < 0.5:
				dev = -dev
			body.velocity = body.velocity.rotated(dev)
			if "heading" in body:
				body.heading += dev
			var away: Vector2 = ((body as Node2D).global_position - vehicle.global_position).normalized()
			body.velocity += away * TORNADO_SHOVE
	_tornado_t -= delta
	if _tornado_t <= 0.0:
		_end_tornado()

## AoE reach: the fleet-scaled visual footprint, not the collision radius —
## the funnel should look like it touches what it touches.
func _tornado_radius() -> float:
	var vehicle := get_parent()
	if vehicle and vehicle.has_method("body_metrics"):
		var m: Dictionary = vehicle.body_metrics()
		return maxf(float(m.get("half_len", 26.0)), float(m.get("half_wid", 13.0))) * TORNADO_RADIUS_MULT
	return 26.0 * TORNADO_RADIUS_MULT

func _end_tornado(random_heading := true) -> void:
	var was_active := _tornado_def != null
	_tornado_t = 0.0
	_tornado_def = null
	_tornado_hit = {}
	if _tornado_fx:
		_tornado_fx.queue_free()
		_tornado_fx = null
	if _tornado_swirl:
		_tornado_swirl.queue_free()
		_tornado_swirl = null
	if was_active and random_heading:
		var vehicle := get_parent()
		if vehicle:
			vehicle.set("heading", randf_range(0.0, TAU))  # as if it suddenly stopped

func is_spinning() -> bool:
	return _tornado_t > 0.0

## The accumulated whirl angle — the Vehicle paints this instead of the
## quantized heading while the tornado runs.
func tornado_visual_angle() -> float:
	return _tornado_spin

# ------------------------------------------------------------ network mirrors
# Puppet-side cosmetics. This controller's _physics_process is OFF on network
# mirrors, so nothing here can tick damage or timers — the snapshot flag IS
# the lifecycle. The tornado mirror reuses the real activation fields (a
# sentinel _tornado_t with no def), so the Vehicle's is_spinning()/
# tornado_visual_angle() paint seam works unchanged on both ends.

## Host row getters — what the shell broadcasts each snapshot.
func flame_active() -> bool:
	return _flame_t > 0.0

func tornado_active() -> bool:
	return _tornado_t > 0.0

func trigger_armed() -> bool:
	return _armed

func mirror_flame(on: bool) -> void:
	if on == (_flame_vis != null):
		return
	if on:
		_build_flame_vis()
	else:
		_end_flame(false)  # def is null on a mirror: frees the vis, arms nothing

func mirror_tornado(on: bool) -> void:
	if on == (_tornado_t > 0.0):
		return
	if not on:
		_end_tornado(false)  # mirrors never randomize the heading — it streams
		return
	_tornado_t = 1.0  # sentinel: is_spinning() true, nothing ever ticks it down
	_tornado_hit = {}
	var vehicle := get_parent() as Node2D
	_tornado_spin = float(vehicle.get("heading")) if vehicle else 0.0
	_build_tornado_fx()

func mirror_armed(on: bool) -> void:
	_set_armed_fx(on)

## Per-frame animation for mirrored sustained FX, called from the puppet tick.
## The def-null / timer-sentinel guards keep this inert on the host's live
## effects (which animate themselves in their own ticks).
func mirror_tick(delta: float) -> void:
	if _flame_vis and _flame_t <= 0.0:
		_flame_vis.polygon = _flame_shape()
		_flame_vis.color = Color(1.0, lerpf(0.35, 0.6, randf()), 0.08, 0.8)
	if _tornado_t > 0.0 and _tornado_def == null:
		_tornado_spin += deg_to_rad(TORNADO_SPIN_DEG) * delta

## Pulse Wave: a neon shockwave radiating from the CAST POSITION (the wave
## detaches — the caster hops away mid-blast) out to projectile_speed x
## projectile_lifetime px over that lifetime. Damage and shove fall off
## center-to-rim (PULSE_EDGE_FRAC floor); the front crosses each body exactly
## once; launch_immune rigs take the damage but hold course. The ring visual
## draws exactly at the damage front.
func _pulse(pressed: bool, def: WeaponDef, shooter: Node) -> bool:
	if not pressed or _pulse_def != null:
		return false
	var vehicle := shooter as Node2D
	if vehicle == null:
		return false
	_pulse_def = def
	_pulse_t = 0.0
	_pulse_hit = {}
	_pulse_origin = vehicle.global_position
	if shooter.has_method(&"pop_airborne"):
		shooter.pop_airborne(PULSE_HOP_VZ)  # showmanship, not flight
	var host := vehicle.get_parent()
	if host:
		_pulse_ring = PulseRing.new()
		_pulse_ring.global_position = _pulse_origin
		_pulse_ring.range_px = _pulse_range(def)
		_pulse_ring.z_index = 2
		host.add_child(_pulse_ring)
	NetEvents.pulse(_pulse_origin, _pulse_range(def),
		maxf(def.projectile_lifetime, 0.05))  # the wave is deterministic from these
	return true

func _pulse_range(def: WeaponDef) -> float:
	return maxf(def.projectile_speed * def.projectile_lifetime, 1.0)

func _pulse_tick(delta: float) -> void:
	var vehicle := get_parent() as CollisionObject2D
	if vehicle == null or _pulse_def == null:
		_end_pulse()
		return
	_pulse_t += delta
	var range_px := _pulse_range(_pulse_def)
	var lifetime: float = maxf(_pulse_def.projectile_lifetime, 0.05)
	var front := range_px * clampf(_pulse_t / lifetime, 0.0, 1.0)
	if _pulse_ring:
		_pulse_ring.radius = front
	var shape := CircleShape2D.new()
	shape.radius = front
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, _pulse_origin)
	params.collision_mask = 5 | (1 << 9)  # ground | obstacle | soft target
	params.collide_with_areas = true
	params.exclude = [vehicle.get_rid()]
	for hit in vehicle.get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if _pulse_hit.has(body.get_instance_id()) or not Floors.same_floor(vehicle, body):
			continue
		_pulse_hit[body.get_instance_id()] = true
		var dist: float = minf(((body as Node2D).global_position - _pulse_origin).length(), range_px)
		var falloff := lerpf(1.0, PULSE_EDGE_FRAC, dist / range_px)
		for child in body.get_children():
			if child is Health:
				if "last_attacker" in body:
					body.last_attacker = vehicle
				child.take_damage(_pulse_def.damage * falloff * Combat.scale(vehicle, body))
				break
		if body is CharacterBody2D and not bool(body.get("launch_immune")):
			var away: Vector2 = ((body as Node2D).global_position - _pulse_origin).normalized()
			if away == Vector2.ZERO:
				away = Vector2.RIGHT
			body.velocity += away * PULSE_SHOVE * falloff
	if _pulse_t >= lifetime:
		_end_pulse()

func _end_pulse() -> void:
	_pulse_t = 0.0
	_pulse_def = null
	_pulse_hit = {}
	if is_instance_valid(_pulse_ring):
		_pulse_ring.queue_free()
	_pulse_ring = null

func sustained_cooldown_remaining() -> float:
	return _sustained_cooldown_t

func _duration(def: WeaponDef, fallback: float) -> float:
	return def.active_duration if def and def.active_duration > 0.0 else fallback

## Toe Jam: arm a charge that replaces the next landed ram's speed-scaled
## damage with one heavy flat hit (def.damage). Smash something within
## TRIGGER_WINDOW or the charge is lost — missed opportunity, too bad, so sad.
## The exhaust stacks belch smoke while armed.
func _trigger(pressed: bool, def: WeaponDef) -> bool:
	if not pressed or _armed:
		return false
	_armed = true
	_armed_t = TRIGGER_WINDOW
	_armed_damage = def.damage if def else 0.0  # captured: swaps can't re-price it
	_set_armed_fx(true)
	return true

## Called by Vehicle._update_ram on a landed ram. Pays out the charged damage
## exactly once (0.0 when unarmed).
func take_armed_hit() -> float:
	if not _armed:
		return 0.0
	_armed = false
	_armed_t = 0.0
	_set_armed_fx(false)
	return _armed_damage

func _disarm_expired() -> void:
	_armed = false
	_set_armed_fx(false)  # the charge stays spent — window's closed

## Armed indicator: dark exhaust smoke off the stacks. Positions match
## hammertoe's painted stacks (his signature special); on any other hull it
## still reads as "engine's angry".
func _set_armed_fx(on: bool) -> void:
	if not on:
		if _armed_fx:
			_armed_fx.queue_free()
			_armed_fx = null
		return
	var parent := get_parent()
	var visual := parent.get_node_or_null("Visual") if parent else null
	if visual == null:
		return
	_armed_fx = CPUParticles2D.new()
	_armed_fx.amount = 22
	_armed_fx.lifetime = 0.7
	_armed_fx.local_coords = false  # smoke hangs in the world as the truck moves
	_armed_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	# Hammertoe's painted stacks, at the fleet's visual scale (paint self-scales;
	# these are Visual-local coords, so the scale is applied here by hand).
	var fleet: float = preload("res://vehicles/car_paint.gd").FLEET_SCALE
	_armed_fx.emission_points = PackedVector2Array([
		Vector2(-7, -9) * fleet, Vector2(-7, 9) * fleet,
	])
	_armed_fx.direction = Vector2(-1, 0)
	_armed_fx.spread = 25.0
	_armed_fx.initial_velocity_min = 30.0
	_armed_fx.initial_velocity_max = 70.0
	_armed_fx.scale_amount_min = 2.0
	_armed_fx.scale_amount_max = 4.5
	_armed_fx.gravity = Vector2.ZERO
	_armed_fx.color = Color(0.18, 0.17, 0.16, 0.8)
	visual.add_child(_armed_fx)
