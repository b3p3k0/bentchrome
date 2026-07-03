class_name WeaponMount
extends Node
## Fires projectiles at a fixed rate. Straight by default; turn_rate_deg +
## acquisition_radius make it home; spread_deg + pellets make a salvo. Configured
## either by the inspector fields (the machine gun) or by a WeaponDef assigned
## from a car's VehicleStats (secondaries/specials). A stub weapon fires nothing.
## on_hit_effects (from the WeaponDef) ride along on each projectile.

@export var weapon: WeaponDef           # if set, overrides the fields below
@export var fire_rate := 12.0
@export var damage := 2.0
@export var projectile_speed := 1100.0
@export var projectile_lifetime := 1.2
@export var turn_rate_deg := 0.0
@export var acquisition_radius := 0.0
@export var spread_deg := 0.0
@export var pellets := 1
@export var projectile_scene: PackedScene

var _cooldown := 0.0
var _stub := false
var on_hit_effects: Array = []

func _ready() -> void:
	if weapon:
		set_weapon(weapon)

func set_weapon(w: WeaponDef) -> void:
	weapon = w
	if w == null:
		return
	fire_rate = 1.0 / maxf(w.cooldown, 0.01)
	damage = w.damage
	projectile_speed = w.projectile_speed
	projectile_lifetime = w.projectile_lifetime
	turn_rate_deg = w.turn_rate_deg
	acquisition_radius = w.acquisition_radius
	spread_deg = w.spread_deg
	pellets = maxi(w.pellets, 1)
	if w.projectile_scene:
		projectile_scene = w.projectile_scene
	_stub = w.stub
	on_hit_effects = w.on_hit_effects

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

## Returns true when a shot actually left the mount (ammo is consumed on true).
func try_fire(origin: Vector2, direction: Vector2, shooter: Node) -> bool:
	if _stub or _cooldown > 0.0 or projectile_scene == null:
		return false
	_cooldown = 1.0 / fire_rate
	var tgt: Node2D = null
	if turn_rate_deg > 0.0 and acquisition_radius > 0.0:
		tgt = Targeting.nearest_other(origin, shooter, acquisition_radius)
	for i in pellets:
		var dir := direction
		if pellets > 1:
			var t := float(i) / float(pellets - 1)
			dir = direction.rotated(deg_to_rad(lerpf(-spread_deg * 0.5, spread_deg * 0.5, t)))
		elif spread_deg > 0.0:
			dir = direction.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))
		var p := projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(p)
		p.setup(origin, dir, projectile_speed, damage, projectile_lifetime, shooter, deg_to_rad(turn_rate_deg), tgt)
		p.on_hit_effects = on_hit_effects
	return true
