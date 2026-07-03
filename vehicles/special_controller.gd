class_name SpecialController
extends Node
## Routes a vehicle's "fire special" to the right behavior based on its
## WeaponDef.kind. PROJECTILE reuses the sibling SecondaryMount (WeaponMount);
## BEAM / DASH / TRIGGER are handler slots, filled when those specials are wired.
##
## This is the durable extension point: a new unusual special is a new kind +
## its handler here, while ordinary specials stay pure data on a projectile kind.

const BEAM_DURATION := 4.0        # seconds a zap stays latched
const BEAM_SLOW := 0.5            # handling cripple while zapped
const BEAM_HOLD_FACTOR := 2.0     # latch breaks beyond acquisition * this

var _def: WeaponDef = null
var _beam_target: Node2D = null
var _beam_t := 0.0
var _beam_line: Line2D = null

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
		_beam_target.take_ram_damage(_def.damage * delta)  # damage authored as dps
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
	_end_beam()  # don't leave an orphaned beam line if the car dies mid-zap

func _dash(_pressed: bool, _origin: Vector2, _direction: Vector2, _shooter: Node) -> bool:
	return false  # TODO (Leap): dash the caster toward the nearest target + brief invuln

func _trigger(_pressed: bool, _origin: Vector2, _direction: Vector2, _shooter: Node) -> bool:
	return false  # TODO (Toe Jam): arm a charged collision hit until the next ram
