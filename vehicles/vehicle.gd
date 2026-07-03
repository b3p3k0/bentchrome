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

@export_group("Identity")
@export var stats: VehicleStats
@export var faction: StringName = &"player"
@export var body_color := Color(0.85, 0.2, 0.3)

@export_group("Depth")
@export var gravity_z := 1300.0
@export var ramp_launch := 760.0
@export var min_launch_speed := 120.0

@export_group("Ram")
@export var ram_damage_scale := 0.06
@export var ram_min_speed := 220.0
@export var ram_cooldown := 0.3

var heading: float = 0.0  # radians; the direction the nose points
var current_terrain: StringName = &"road"
var height: float = 0.0   # fake vertical offset (px); 0 = on the ground
var vz: float = 0.0       # vertical velocity (px/s)
var _ram_cd := 0.0        # cooldown between ram hits

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
		# direct/dev arena launch still works.
		var id: StringName = GameState.selected_vehicle_id
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
	if _rack and _special:
		# Selection drives what the special/secondary path fires next.
		_rack.selection_changed.connect(func(_i: int) -> void: _special.set_weapon(_rack.selected_def()))
	if _health:
		_health.died.connect(_on_died)
	heading = rotation
	rotation = 0.0

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
	if _controller:
		_controller.apply(self, intent, delta)
	move_and_slide()
	_update_ram(delta)
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

func _on_died() -> void:
	if is_in_group(&"player"):
		set_physics_process(false)
		print("[player] destroyed")
	else:
		queue_free()

func get_speed() -> float:
	return velocity.length()

func get_hp() -> float:
	return _health.hp if _health else 0.0

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

func take_ram_damage(amount: float) -> void:
	if _health:
		_health.take_damage(amount)

## Speed-based collision damage to other vehicles after move_and_slide.
func _update_ram(delta: float) -> void:
	if _ram_cd > 0.0:
		_ram_cd -= delta
		return
	for i in get_slide_collision_count():
		var other = get_slide_collision(i).get_collider()
		if other is Vehicle and other != self:
			var rel: float = (velocity - other.velocity).length()
			if rel > ram_min_speed:
				other.take_ram_damage((rel - ram_min_speed) * ram_damage_scale)
				_ram_cd = ram_cooldown
				break
