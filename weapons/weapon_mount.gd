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
@export var bursts := 1           # sequential waves per shot (rocket volleys)
@export var burst_interval := 0.12
@export var projectile_scene: PackedScene
@export var projectile_tint := Color.WHITE  # modulates spawned shots (color-coded missiles)
@export var pierces_cover := false      # spawned shots ignore the obstacle layer
@export var cooldown_scale := 1.0       # >1 slows fire; AI mounts run at 3x

@export_group("Heat")
@export var heat_per_shot := 0.0   # 0 = no heat mechanic (secondaries)
@export var heat_max := 100.0
@export var cool_per_sec := 28.0
@export var resume_frac := 0.35    # locked until heat cools below this fraction

var heat := 0.0
var _locked := false
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
	bursts = maxi(w.bursts, 1)
	burst_interval = w.burst_interval
	if w.projectile_scene:
		projectile_scene = w.projectile_scene
	projectile_tint = w.projectile_tint
	pierces_cover = w.pierces_cover
	_stub = w.stub
	on_hit_effects = w.on_hit_effects

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if heat > 0.0:
		heat = maxf(heat - cool_per_sec * delta, 0.0)
		if _locked and heat <= heat_max * resume_frac:
			_locked = false

func heat_fraction() -> float:
	return heat / heat_max if heat_max > 0.0 else 0.0

func is_locked() -> bool:
	return _locked

## Returns true when a shot actually left the mount (ammo is consumed on true).
## Multi-burst weapons fire wave 1 now and schedule the rest — still ONE press,
## ONE consume, ONE cooldown; the follow-up waves are part of the same shot.
func try_fire(origin: Vector2, direction: Vector2, shooter: Node) -> bool:
	if _stub or _locked or _cooldown > 0.0 or projectile_scene == null:
		return false
	_cooldown = cooldown_scale / fire_rate
	if heat_per_shot > 0.0:
		heat = minf(heat + heat_per_shot, heat_max)
		if heat >= heat_max:
			_locked = true
	_fire_wave(origin, direction, shooter)
	for n in range(1, bursts):
		get_tree().create_timer(burst_interval * n).timeout.connect(
			_burst_wave.bind(origin, direction, shooter), CONNECT_ONE_SHOT)
	if shooter is Node and shooter.is_in_group(&"player"):
		var audio := get_node_or_null(^"/root/AudioDirector")
		if audio:
			audio.play(&"mg_fire" if heat_per_shot > 0.0 else &"missile_fire")
	return true

## Follow-up wave: launched off the shooter's CURRENT muzzle/heading (the car
## kept moving), falling back to the launch snapshot. A dead shooter takes the
## rest of the volley with them — no ghost rockets. Shooter is UNTYPED: the
## bound argument may be a freed instance by the time the timer fires, and a
## typed Node parameter errors on the conversion before the body can guard.
func _burst_wave(origin: Vector2, direction: Vector2, shooter) -> void:
	if not is_inside_tree() or shooter == null or not is_instance_valid(shooter):
		return
	if shooter is Node2D:
		var muzzle := (shooter as Node2D).get_node_or_null(^"Visual/Muzzle")
		var h: Variant = shooter.get("heading")
		if muzzle is Node2D and h is float:
			origin = (muzzle as Node2D).global_position
			direction = Vector2.RIGHT.rotated(h)
	_fire_wave(origin, direction, shooter)

func _fire_wave(origin: Vector2, direction: Vector2, shooter: Node) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
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
		p.modulate = projectile_tint
		p.hit_sfx = &"hit_mg" if heat_per_shot > 0.0 else &"hit_weapon"
		if pierces_cover:
			p.collision_mask &= ~4  # drop the obstacle bit — flies through cover
		scene.add_child(p)
		p.setup(origin, dir, projectile_speed, damage, projectile_lifetime, shooter, deg_to_rad(turn_rate_deg), tgt)
		p.on_hit_effects = on_hit_effects
