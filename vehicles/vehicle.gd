class_name Vehicle
extends CharacterBody2D
## The one vehicle. A Driver supplies intent; a DrivingController turns it into
## motion. Player and AI both instance this scene — only the Driver differs.
## The body stays axis-aligned (so a child Camera2D never spins); only the
## Visual node rotates to the heading.

var heading: float = 0.0  # radians; the direction the nose points
var current_terrain: StringName = &"road"

@onready var _controller: DrivingController = $DrivingController
@onready var _driver: Driver = $Driver
@onready var _visual: Node2D = $Visual
@onready var _terrain_sensor: TerrainSensor = $TerrainSensor

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

func get_speed() -> float:
	return velocity.length()
