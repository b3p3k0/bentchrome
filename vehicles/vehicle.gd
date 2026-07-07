class_name Vehicle
extends CharacterBody2D
## The one vehicle. A Driver supplies intent; a DrivingController turns it into
## motion. Player and AI both instance this scene — only the Driver, faction, and
## stats differ. If a VehicleStats resource is assigned, StatCurves configures the
## controller + health from its 1-10 design stats, then per-car handling_overrides
## (from the dev dashboard) win. The body stays axis-aligned (so a child Camera2D
## never spins); only the Visual rotates. Combat is free-for-all: faction is
## identity only, not damage immunity.
##
## Collision layers: 1 = ground (vehicles, dummies), 2 = walls/barriers,
## 4 = obstacles (blocks/cover). While airborne the car keeps only the wall bit,
## so ramp jumps clear obstacles but can't leave the arena.

const LAYER_GROUND := 1
const LAYER_WALL := 2
const LAYER_OBSTACLE := 4
const Combat := preload("res://game/combat.gd")  # AI-vs-AI governor/mercy rules
const ExplosionScene := preload("res://environment/explosion.tscn")

@export_group("Identity")
@export var stats: VehicleStats
@export var faction: StringName = &"player"
@export var body_color := Color(0.85, 0.2, 0.3)
@export var ai_cooldown_scale := 3.0  # AI mounts fire at 1/3 player rate

@export_group("Depth")
@export var gravity_z := 1300.0
@export var ramp_launch := 760.0
@export var min_launch_speed := 120.0

@export_group("Ram")
@export var ram_damage_scale := 0.06
@export var ram_min_speed := 220.0
@export var ram_cooldown := 0.3

@export_group("Bounce")
@export var bounce_factor := 0.35     # fraction of the into-surface speed reflected
@export var bounce_min_speed := 100.0  # below this, grinding along walls stays smooth

var heading: float = 0.0  # radians; the direction the nose points
var current_terrain: StringName = &"road"
var height: float = 0.0   # fake vertical offset (px); 0 = on the ground
var vz: float = 0.0       # vertical velocity (px/s)
var _ram_cd := 0.0        # cooldown between ram hits
var _shake := 0.0         # camera shake energy (player only)
var _falling := false     # mid pit-fall (shrinking); suppresses the explosion
var last_attacker: Node2D = null  # whoever hurt us last — AI holds a grudge

@onready var _controller: DrivingController = $DrivingController
@onready var _driver: Driver = $Driver
@onready var _visual: Node2D = $Visual
@onready var _shadow: Node2D = $Shadow
@onready var _terrain_sensor: TerrainSensor = $TerrainSensor
@onready var _mg_mount: WeaponMount = $MachineGunMount
@onready var _special: SpecialController = $SpecialController
@onready var _muzzle: Marker2D = $Visual/Muzzle
@onready var _health: Health = $Health
@onready var _status: StatusReceiver = $Status
@onready var _rack: WeaponRack = $WeaponRack

func _ready() -> void:
	if stats == null and faction == &"player":
		# Player car comes from the picker (GameState); fall back to Ghost so a
		# direct/dev arena launch still works. Autoload fetched by path so this
		# script compiles in headless -s test runs (no autoloads there).
		var gs := get_node_or_null(^"/root/GameState")
		var id: StringName = gs.selected_vehicle_id if gs else &""
		var path := "res://data/vehicles/ghost.tres"
		if id != &"":
			path = "res://data/vehicles/%s.tres" % id
		stats = load(path)
	if stats:
		_apply_stats()
	else:
		($Visual/Body as Polygon2D).color = body_color
	add_to_group(faction)        # "player" or "enemies" — identity
	add_to_group(&"vehicles")    # every combatant, for free-for-all targeting
	if faction != &"player":
		# Same loadout as the player, a third of the trigger speed.
		if _mg_mount:
			_mg_mount.cooldown_scale = ai_cooldown_scale
		var secondary := get_node_or_null(^"SecondaryMount") as WeaponMount
		if secondary:
			secondary.cooldown_scale = ai_cooldown_scale
	if _rack and _special:
		# Selection drives what the special/secondary path fires next.
		_rack.selection_changed.connect(func(_i: int) -> void: _special.set_weapon(_rack.selected_def()))
	if _health:
		_health.died.connect(_on_died)
		_health.damaged.connect(_on_damaged)
	heading = rotation
	rotation = 0.0

## Hit feedback: brief white pulse (skipped for sub-1 DoT ticks, which would
## strobe), plus camera shake when it's the player taking it.
func _on_damaged(amount: float, _hp: float) -> void:
	if amount < 1.0:
		return
	if _visual:
		_visual.modulate = Color(2.2, 2.2, 2.2)
		var tween := create_tween()
		tween.tween_property(_visual, "modulate", Color.WHITE, 0.12)
	if is_in_group(&"player"):
		add_shake(minf(amount * 0.4, 8.0))

func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 12.0)

func _process(delta: float) -> void:
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera == null or not camera.enabled:
		return
	if _shake > 0.05:
		_shake = maxf(_shake - 30.0 * delta, 0.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

## Applies the current stats to the controller/health/visuals. Re-callable live
## (the dev dashboard's car switcher uses set_stats()).
func _apply_stats() -> void:
	StatCurves.apply(stats, _controller, _health)
	for k in stats.handling_overrides:
		_controller.set(k, stats.handling_overrides[k])
	body_color = stats.primary_color
	($Visual/Body as Polygon2D).color = body_color
	($Visual/FrontBumper as Polygon2D).color = stats.accent_color
	if _rack:
		_rack.configure(stats.special, stats.special_ammo_cap, stats.special_recharge_seconds)
	if stats.special and _special:
		_special.set_weapon(_rack.selected_def() if _rack else stats.special)

func set_stats(new_stats: VehicleStats) -> void:
	if new_stats == null:
		return
	stats = new_stats
	_apply_stats()

func get_controller() -> DrivingController:
	return _controller

func _physics_process(delta: float) -> void:
	if _terrain_sensor:
		current_terrain = _terrain_sensor.current_terrain
	var intent: Dictionary = _driver.get_intent(self, delta) if _driver else {}
	if _controller and not (_special and _special.is_dashing()):
		# Normal driving; skipped mid-Leap so the controller's top-speed clamp
		# doesn't eat the dash velocity.
		_controller.apply(self, intent, delta)
	# Captured before move_and_slide: a head-on hit on a static body zeroes
	# velocity during the slide, so post-slide speed under-reads the impact.
	var pre_slide_vel := velocity
	move_and_slide()
	_apply_bounce(pre_slide_vel)
	_update_ram(delta, pre_slide_vel.length())
	_visual.rotation = heading
	_update_depth(delta)
	var aim := Vector2.RIGHT.rotated(heading)
	if _mg_mount and _muzzle and intent.get("fire_mg", false):
		_mg_mount.try_fire(_muzzle.global_position, aim, self)
	if _rack:
		if intent.get("weapon_prev", false):
			_rack.select_prev()
		if intent.get("weapon_next", false):
			_rack.select_next()
	if _special and _muzzle:
		var wants_fire: bool = intent.get("fire_selected", false)
		if _rack:
			wants_fire = wants_fire and _rack.can_consume()
		if _special.activate(wants_fire, _muzzle.global_position, aim, self) and _rack:
			_rack.consume()

func _update_depth(delta: float) -> void:
	if height > 0.0 or vz != 0.0:
		vz -= gravity_z * delta
		height += vz * delta
		if height <= 0.0:
			height = 0.0
			vz = 0.0
			_set_airborne(false)
	_visual.position.y = -height
	if _shadow:
		var s := clampf(1.0 - height * 0.0012, 0.5, 1.0)
		_shadow.scale = Vector2(s, s)
		_shadow.modulate.a = clampf(1.0 - height * 0.0016, 0.4, 1.0)

func _set_airborne(on: bool) -> void:
	# Airborne: keep the wall bit (stay in the arena), drop ground + obstacles
	# (clear other cars and blocks — ramp jumps sail over cover).
	set_deferred("collision_mask", LAYER_WALL if on else (LAYER_GROUND | LAYER_WALL | LAYER_OBSTACLE))

func launch_from_ramp() -> void:
	if height > 0.0 or velocity.length() < min_launch_speed:
		return
	vz = ramp_launch
	_set_airborne(true)

## Over the edge: kill physics and collisions, shrink into the void, then die
## for real. The fall suppresses the explosion — you fell, you didn't pop.
func fall_into_pit() -> void:
	if _falling or height > 0.0 or (_health and _health.hp <= 0.0):
		return
	_falling = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var tween := create_tween()
	if _visual:
		tween.tween_property(_visual, "scale", Vector2(0.05, 0.05), 0.7)
	if _shadow:
		tween.parallel().tween_property(_shadow, "scale", Vector2(0.05, 0.05), 0.7)
	tween.tween_callback(func() -> void:
		if _health:
			_health.kill()
		_falling = false)

func _on_died() -> void:
	if not _falling:
		_spawn_explosion()
	if is_in_group(&"player"):
		set_physics_process(false)
		print("[player] destroyed")
	else:
		queue_free()

func _spawn_explosion() -> void:
	var scene := get_tree().current_scene
	if scene == null:  # headless fixtures may not set one
		return
	var boom := ExplosionScene.instantiate()
	boom.global_position = global_position
	boom.tint = body_color
	scene.add_child(boom)

func get_speed() -> float:
	return velocity.length()

func get_hp() -> float:
	return _health.hp if _health else 0.0

func get_max_hp() -> float:
	return _health.max_hp if _health else 0.0

func get_hp_fraction() -> float:
	return _health.hp / _health.max_hp if _health and _health.max_hp > 0.0 else 1.0

func get_rack() -> WeaponRack:
	return _rack

func get_mg_mount() -> WeaponMount:
	return _mg_mount

func get_speed_scale() -> float:
	return _status.speed_scale() if _status else 1.0

func apply_effect(spec: StatusEffectSpec) -> void:
	if _status:
		_status.apply(spec)

## Campaign respawn: back to a spawn point, full tank, physics on, and a brief
## invuln blink-shield so spawn-camping hunters can't chain-kill.
func respawn(at: Vector2, new_heading: float, shield_seconds := 2.0) -> void:
	global_position = at
	heading = new_heading
	velocity = Vector2.ZERO
	height = 0.0
	vz = 0.0
	_falling = false
	set_deferred("collision_layer", LAYER_GROUND)
	set_deferred("collision_mask", LAYER_GROUND | LAYER_WALL | LAYER_OBSTACLE)
	if _health:
		_health.hp = _health.max_hp
	set_physics_process(true)
	if _visual:
		_visual.scale = Vector2.ONE  # pit falls shrink it
		_visual.modulate = Color.WHITE
	if _shadow:
		_shadow.scale = Vector2.ONE
	if shield_seconds > 0.0 and _status:
		var shield := StatusEffectSpec.new()
		shield.kind = &"invuln"
		shield.duration = shield_seconds
		apply_effect(shield)
		if _visual:
			var tween := create_tween()
			tween.set_loops(int(shield_seconds / 0.2))
			tween.tween_property(_visual, "modulate:a", 0.35, 0.1)
			tween.tween_property(_visual, "modulate:a", 1.0, 0.1)

func take_ram_damage(amount: float, source: Node2D = null) -> void:
	if source:
		last_attacker = source
	if _health:
		_health.take_damage(amount)

## Speed-based collision damage after move_and_slide: other vehicles, plus any
## Health-bearing body (destructible blocks, dummies). The rammer takes nothing
## from static targets; Toe Jam's armed charge is saved for vehicles.
func _update_ram(delta: float, impact_speed: float) -> void:
	if _ram_cd > 0.0:
		_ram_cd -= delta
		return
	for i in get_slide_collision_count():
		var other = get_slide_collision(i).get_collider()
		if other == self:
			continue
		if other is Vehicle:
			var rel: float = (velocity - other.velocity).length()
			if rel > ram_min_speed:
				# An armed Toe Jam charge replaces the speed-scaled hit.
				var charged: float = _special.take_armed_hit() if _special else 0.0
				var hit: float = charged if charged > 0.0 else (rel - ram_min_speed) * ram_damage_scale
				hit = ram_clamp(hit * Combat.scale(self, other), self, other)
				other.take_ram_damage(hit, self)
				_ram_cd = ram_cooldown
				break
		else:
			var health := _find_health_child(other)
			if health and impact_speed > ram_min_speed:
				health.take_damage((impact_speed - ram_min_speed) * ram_damage_scale)
				_ram_cd = ram_cooldown
				break

## Deflection: reflect the pre-slide velocity component that went INTO the
## surface, scaled by bounce_factor — angled hits carom, dead-on stays a thud.
## Sub-threshold contact (grinding along a wall) is left smooth. Hitting
## another car shoves it along the same normal at half strength.
func _apply_bounce(pre_vel: Vector2) -> void:
	if get_slide_collision_count() == 0:
		return
	var col := get_slide_collision(0)
	var n := col.get_normal()
	var into := -pre_vel.dot(n)  # positive = moving into the surface
	if into < bounce_min_speed:
		return
	velocity += n * into * bounce_factor
	var other = col.get_collider()
	if other is Vehicle and other != self:
		other.velocity -= n * into * bounce_factor * 0.5

## Rams involving the player are lethal BOTH ways (your bumper finishes NPCs,
## theirs finishes you). AI-on-AI rams never land the killing blow (>=1% HP
## floor) — the mercy governor checks HP before the hit, so rams just above
## its line were still finishing cars. Obstacle crashes damage nobody anyway.
static func ram_clamp(hit: float, attacker: Node, victim: Node) -> float:
	if attacker.is_in_group(&"player") or victim.is_in_group(&"player"):
		return hit
	if victim.has_method(&"get_hp"):
		return minf(hit, maxf(victim.get_hp() - 0.01 * victim.get_max_hp(), 0.0))
	return hit

func _find_health_child(body: Node) -> Health:
	for child in body.get_children():
		if child is Health:
			return child
	return null
