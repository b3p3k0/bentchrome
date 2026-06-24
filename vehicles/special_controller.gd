class_name SpecialController
extends Node
## Routes a vehicle's "fire special" to the right behavior based on its
## WeaponDef.kind. PROJECTILE reuses the sibling SecondaryMount (WeaponMount);
## BEAM / DASH / TRIGGER are handler slots, filled when those specials are wired.
##
## This is the durable extension point: a new unusual special is a new kind +
## its handler here, while ordinary specials stay pure data on a projectile kind.

var _def: WeaponDef = null

@onready var _mount: WeaponMount = get_parent().get_node_or_null("SecondaryMount") if get_parent() else null

func set_weapon(def: WeaponDef) -> void:
	_def = def
	if _mount:
		_mount.set_weapon(def)   # projectile-kind firing lives in the mount

func activate(pressed: bool, origin: Vector2, direction: Vector2, shooter: Node) -> void:
	if _def == null:
		return
	match _def.kind:
		WeaponDef.Kind.PROJECTILE:
			if pressed and _mount:
				_mount.try_fire(origin, direction, shooter)
		WeaponDef.Kind.BEAM:
			_beam(pressed, origin, direction, shooter)
		WeaponDef.Kind.DASH:
			_dash(pressed, origin, direction, shooter)
		WeaponDef.Kind.TRIGGER:
			_trigger(pressed, origin, direction, shooter)

func _beam(_pressed: bool, _origin: Vector2, _direction: Vector2, _shooter: Node) -> void:
	pass  # TODO (Taser): close-range channeled beam + slow status while held

func _dash(_pressed: bool, _origin: Vector2, _direction: Vector2, _shooter: Node) -> void:
	pass  # TODO (Leap): dash the caster toward the nearest target + brief invuln

func _trigger(_pressed: bool, _origin: Vector2, _direction: Vector2, _shooter: Node) -> void:
	pass  # TODO (Toe Jam): arm a charged collision hit until the next ram
