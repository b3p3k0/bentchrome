class_name WeaponMount
extends Node
## Fires projectiles at a fixed rate. Straight by default; turn_rate_deg +
## acquisition_radius make it home; spread_deg + pellets make a salvo. Configured
## either by the inspector fields (the machine gun) or by a WeaponDef assigned
## from a car's VehicleStats (secondaries/specials). A stub weapon fires nothing.
## on_hit_effects (from the WeaponDef) ride along on each projectile.

const Floors := preload("res://game/floors.gd")  # floor-mask stamping (dependency-free)
const FlashScene := preload("res://weapons/muzzle_flash.tscn")

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

## Puppet HUD state: the host's heat/lock, verbatim (a network mirror's own
## _physics_process is disabled, so nothing here cools or unlocks).
func net_mirror_heat(frac: float, locked: bool) -> void:
	heat = clampf(frac, 0.0, 1.0) * heat_max
	_locked = locked

## Special-slot voice: when set (sp_<def id>, from SpecialController) the wave
## audio plays this instead of the generic missile_fire — if its asset exists.
var sfx_override: StringName = &""

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
			if shooter is Node and shooter.is_in_group(&"player"):
				var audio_h := get_node_or_null(^"/root/AudioDirector")
				if audio_h:
					audio_h.play(&"overheat")  # the lockout tell — once per lock
	# Snapshot the weapon NOW so a mid-volley set_weapon can't bleed a different
	# weapon into this volley's follow-up waves: firing the last special makes
	# consume() auto-cycle the rack, which re-wires SecondaryMount.set_weapon —
	# without this snapshot Red Glare's waves 2-3 would launch fire missiles.
	# One press, one weapon.
	var wp := _wave_params()
	_fire_wave(origin, direction, shooter, wp)
	for n in range(1, bursts):
		get_tree().create_timer(burst_interval * n).timeout.connect(
			_burst_wave.bind(origin, direction, shooter, wp), CONNECT_ONE_SHOT)
	return true

## Frozen copy of every per-wave weapon field — the whole volley fires from this,
## never from the live instance vars (which set_weapon can change mid-volley).
func _wave_params() -> Dictionary:
	return {
		"scene": projectile_scene,
		"tint": projectile_tint,
		"hot": heat_per_shot > 0.0,
		"sfx_override": sfx_override,
		"turn_rate_deg": turn_rate_deg,
		"acquisition_radius": acquisition_radius,
		"spread_deg": spread_deg,
		"pellets": pellets,
		"speed": projectile_speed,
		"damage": damage,
		"lifetime": projectile_lifetime,
		"pierces_cover": pierces_cover,
		"on_hit_effects": on_hit_effects,
	}

## Follow-up wave: launched off the shooter's CURRENT muzzle/heading (the car
## kept moving), falling back to the launch snapshot. A dead shooter takes the
## rest of the volley with them — no ghost rockets. Shooter is UNTYPED: the
## bound argument may be a freed instance by the time the timer fires, and a
## typed Node parameter errors on the conversion before the body can guard.
func _burst_wave(origin: Vector2, direction: Vector2, shooter, wp: Dictionary) -> void:
	if not is_inside_tree() or shooter == null or not is_instance_valid(shooter):
		return
	if shooter is Node2D:
		var muzzle := (shooter as Node2D).get_node_or_null(^"Visual/Muzzle")
		var h: Variant = shooter.get("heading")
		if muzzle is Node2D and h is float:
			origin = (muzzle as Node2D).global_position
			direction = Vector2.RIGHT.rotated(h)
	_fire_wave(origin, direction, shooter, wp)

func _fire_wave(origin: Vector2, direction: Vector2, shooter: Node, wp: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var hot: bool = wp["hot"]
	var proj_scene: PackedScene = wp["scene"]
	if proj_scene == null:
		return
	# Audio rides the WAVE, not the press — multi-burst volleys (red_glare x3)
	# repeat their launch sound per rocket. sfx_override = the special's own
	# voice (sp_<def>, set by SpecialController); missing asset falls back.
	if shooter is Node and shooter.is_in_group(&"player"):
		var audio := get_node_or_null(^"/root/AudioDirector")
		if audio:
			var event: StringName = &"mg_fire" if hot else &"missile_fire"
			var ov: StringName = wp["sfx_override"]
			if ov != &"":
				if audio.has_asset(ov):
					event = ov
				elif audio.has_asset(&"sp_placeholder"):
					event = &"sp_placeholder"  # where's the beef?
			audio.play(event)
	var spawner := get_node_or_null(^"/root/Spawner")  # may be absent in bare fixtures
	# One flash per wave (not per pellet) — pooled; the MG asks 12 times a second.
	var flash := (spawner.acquire(FlashScene) if spawner else FlashScene.instantiate()) as Node2D
	scene.add_child(flash)
	flash.setup(origin, direction, not hot)
	var pellet_count: int = wp["pellets"]
	var spread: float = wp["spread_deg"]
	var turn: float = wp["turn_rate_deg"]
	var acq: float = wp["acquisition_radius"]
	var tracking := turn > 0.0 and acq > 0.0
	var shooter_floor := Floors.floor_of(shooter)
	var tgt: Node2D = null
	if tracking:
		tgt = Targeting.nearest_other(origin, shooter, acq)
	var target_floor := Floors.floor_of(tgt)
	var pierces: bool = wp["pierces_cover"]
	for i in pellet_count:
		var dir := direction
		if pellet_count > 1:
			var t := float(i) / float(pellet_count - 1)
			dir = direction.rotated(deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, t)))
		elif spread > 0.0:
			dir = direction.rotated(deg_to_rad(randf_range(-spread * 0.5, spread * 0.5)))
		var p := (spawner.acquire(proj_scene) if spawner
			else proj_scene.instantiate()) as Projectile
		p.modulate = wp["tint"]
		p.hit_sfx = &"hit_mg" if hot else &"hit_weapon"
		# One shared mask path keeps legacy, straight, tracking, and explicit
		# cover-piercing semantics aligned. Tracking shots arc over intermediate
		# terraces while cover on the launch and locked-target floors can stop them.
		p.collision_mask = Floors.projectile_mask(shooter_floor, tracking,
			target_floor, pierces)
		scene.add_child(p)
		p.setup(origin, dir, wp["speed"], wp["damage"], wp["lifetime"], shooter, deg_to_rad(turn), tgt)
		p.on_hit_effects = wp["on_hit_effects"]
