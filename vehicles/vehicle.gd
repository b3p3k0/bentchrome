class_name Vehicle
extends CharacterBody2D
## The one vehicle. A Driver supplies intent; a DrivingController turns it into
## motion. Player and AI both instance this scene — only the Driver, faction, and
## stats differ. If a VehicleStats resource is assigned, StatCurves configures the
## controller + health from its 1-10 design stats (data-driven feel); otherwise
## the controller's hand-tuned defaults apply. The body stays axis-aligned (so a
## child Camera2D never spins); only the Visual rotates. Combat is free-for-all:
## faction is identity only, not damage immunity.
##
## Collision layers: 1 = ground (vehicles, blocks, dummies), 2 = walls/barriers.
## While airborne the car drops the ground bit (clears blocks) but keeps the wall
## bit, so ramp jumps can't leave the arena.

const LAYER_GROUND := 1
const LAYER_WALL := 2

@export_group("Identity")
@export var stats: VehicleStats
@export var faction: StringName = &"player"
@export var body_color := Color(0.85, 0.2, 0.3)

@export_group("Depth")
@export var gravity_z := 1300.0
@export var ramp_launch := 760.0
@export var min_launch_speed := 120.0

var heading: float = 0.0  # radians; the direction the nose points
var current_terrain: StringName = &"road"
var height: float = 0.0   # fake vertical offset (px); 0 = on the ground
var vz: float = 0.0       # vertical velocity (px/s)

@onready var _controller: DrivingController = $DrivingController
@onready var _driver: Driver = $Driver
@onready var _visual: Node2D = $Visual
@onready var _shadow: Node2D = $Shadow
@onready var _terrain_sensor: TerrainSensor = $TerrainSensor
@onready var _mg_mount: WeaponMount = $MachineGunMount
@onready var _secondary_mount: WeaponMount = $SecondaryMount
@onready var _muzzle: Marker2D = $Visual/Muzzle
@onready var _health: Health = $Health

func _ready() -> void:
	if stats:
		StatCurves.apply(stats, _controller, _health)
		body_color = stats.primary_color
	add_to_group(faction)        # "player" or "enemies" — identity
	add_to_group(&"vehicles")    # every combatant, for free-for-all targeting
	($Visual/Body as Polygon2D).color = body_color
	if _health:
		_health.died.connect(_on_died)
	heading = rotation
	rotation = 0.0

func _physics_process(delta: float) -> void:
	if _terrain_sensor:
		current_terrain = _terrain_sensor.current_terrain
	var intent: Dictionary = _driver.get_intent(self, delta) if _driver else {}
	if _controller:
		_controller.apply(self, intent, delta)
	move_and_slide()
	_visual.rotation = heading
	_update_depth(delta)
	var aim := Vector2.RIGHT.rotated(heading)
	if _mg_mount and _muzzle and intent.get("fire_mg", false):
		_mg_mount.try_fire(_muzzle.global_position, aim, self)
	if _secondary_mount and _muzzle and intent.get("fire_special", false):
		_secondary_mount.try_fire(_muzzle.global_position, aim, self)

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
	# Airborne: keep the wall bit (stay in the arena), drop ground (clear blocks).
	set_deferred("collision_mask", LAYER_WALL if on else (LAYER_GROUND | LAYER_WALL))

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
