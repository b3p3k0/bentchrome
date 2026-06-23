class_name Vehicle
extends CharacterBody2D
## The one vehicle. A Driver supplies intent; a DrivingController turns it into
## motion. Player and AI both instance this scene — only the Driver differs.
## The body stays axis-aligned (so a child Camera2D never spins); only the
## Visual rotates. Fake depth: a height/vz pair lifts the Visual and shrinks the
## Shadow; ramps launch the car, which clears obstacles while airborne.

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
@onready var _body_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
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
	if _body_shape:
		_body_shape.set_deferred("disabled", on)

func launch_from_ramp() -> void:
	if height > 0.0 or velocity.length() < min_launch_speed:
		return
	vz = ramp_launch
	_set_airborne(true)

func get_speed() -> float:
	return velocity.length()
