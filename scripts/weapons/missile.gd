extends Area2D

## Enhanced missile system with pluggable guidance algorithms
## Supports three missile types: Power (no tracking), Fire (moderate), Homing (aggressive)

# Safe missile type constants (no class_name dependencies)
const TYPE_POWER = 0
const TYPE_FIRE = 1
const TYPE_HOMING = 2

# Core properties
@export var missile_type: int = TYPE_FIRE
@export var speed: float = 1400.0
@export var lifetime: float = 3.0  # Short lifetime simulates "fuel depletion"
@export var acquisition_radius: float = 600.0

# Type-specific properties (will be set based on missile_type)
var damage: int = 80
var guidance_system = null
var color: Color = Color.ORANGE

# Physics and targeting
var velocity: Vector2 = Vector2.ZERO
var owner_node = null
var target = null
var life_timer: float = 0.0
var _handled_hit: bool = false

# Safe missile type configurations (no external dependencies)
## Debug logging helper for missile system
func _missile_debug_log(message: String):
	var timestamp = Time.get_ticks_msec() / 1000.0
	var log_entry = "[%.3f] %s\n" % [timestamp, message]
	var file = FileAccess.open("/tmp/missile_debug.log", FileAccess.WRITE_READ)
	if file:
		file.seek_end()  # Append to end of file
		file.store_string(log_entry)
		file.close()
	print("[%.3f] %s" % [timestamp, message])  # Fixed: removed strip() call

const MISSILE_CONFIG = {
	TYPE_POWER: {
		"damage": 120,
		"color": Color.RED,
		"guidance_class": "PowerGuidance",
		"acquisition_radius": 0.0,  # No targeting
		"description": "High damage, no tracking"
	},
	TYPE_FIRE: {
		"damage": 80,
		"color": Color.ORANGE,
		"guidance_class": "SteeringGuidance",
		"acquisition_radius": 600.0,
		"description": "Moderate damage, basic tracking"
	},
	TYPE_HOMING: {
		"damage": 40,
		"color": Color.PURPLE,
		"guidance_class": "ProportionalNavigation",
		"acquisition_radius": 800.0,
		"description": "Low damage, aggressive tracking"
	}
}

func _ready():
	# Configure missile based on type
	_configure_missile_type()

	# Initialize guidance system
	_initialize_guidance()

	# Set up collision detection
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Initialize velocity if not set by spawner
	if velocity == Vector2.ZERO:
		velocity = Vector2.UP.rotated(rotation) * speed

	# Update visual appearance based on missile type
	_update_visual()

	# Ensure missile is visible
	visible = true

	life_timer = 0.0
	var type_names = ["POWER", "FIRE", "HOMING"]
	var type_name = type_names[missile_type] if missile_type < type_names.size() else "UNKNOWN"


func _configure_missile_type():
	var config = MISSILE_CONFIG[missile_type]
	damage = config.damage
	color = config.color
	acquisition_radius = config.acquisition_radius

func _initialize_guidance():
	var config = MISSILE_CONFIG[missile_type]
	var guidance_class_name = config.guidance_class

	match guidance_class_name:
		"PowerGuidance":
			guidance_system = PowerGuidance.new()
		"SteeringGuidance":
			guidance_system = SteeringGuidance.new()
		"ProportionalNavigation":
			guidance_system = ProportionalNavigation.new()
		_:
			push_error("Unknown guidance class: " + guidance_class_name)
			guidance_system = PowerGuidance.new()  # Fallback

	guidance_system.missile = self

func _physics_process(delta):
	life_timer += delta

	# Remove missile after lifetime expires (fuel depletion)
	if life_timer > lifetime:
		queue_free()
		return

	# Target acquisition (only for tracking missiles)
	if acquisition_radius > 0 and (not target or not is_instance_valid(target)):
		_acquire_target()

	# Apply guidance system
	if guidance_system:
		guidance_system.update(delta)

	# Update position and rotation
	global_position += velocity * delta
	rotation = velocity.angle()

func _acquire_target():
	var groups = ["player", "enemies"]
	var best_target = null
	var best_distance = acquisition_radius

	for group_name in groups:
		for candidate in get_tree().get_nodes_in_group(group_name):
			# Skip self-targeting
			if candidate == owner_node:
				continue

			# Validate target
			if not is_instance_valid(candidate) or not candidate.is_inside_tree():
				continue

			if not (candidate is Node2D):
				continue

			# Check distance
			var distance = global_position.distance_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best_target = candidate

	if best_target:
		target = best_target

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func _handle_hit(obj):
	if _handled_hit or obj == owner_node:
		return

	_handled_hit = true
	_apply_damage(obj)
	queue_free()

func _apply_damage(target_obj):
	if not is_instance_valid(target_obj):
		return

	# Try different damage application methods
	if target_obj.has_method("apply_damage"):
		target_obj.apply_damage(damage, owner_node)
	elif target_obj.has_meta("health"):
		var current_health = target_obj.get_meta("health")
		target_obj.set_meta("health", current_health - damage)
	elif target_obj.has_method("get") and target_obj.get("health") != null:
		var current_health = target_obj.get("health")
		if target_obj.has_method("set"):
			target_obj.set("health", max(0, current_health - damage))

func _update_visual():
	# Update the ColorRect visual child (like bullets do)
	var visual = get_node_or_null("Visual")
	if visual and visual is ColorRect:
		# Change color based on missile type for testing
		match missile_type:
			TYPE_POWER:
				visual.color = Color.RED
			TYPE_FIRE:
				visual.color = Color.ORANGE
			TYPE_HOMING:
				visual.color = Color.MAGENTA
			_:
				visual.color = Color.WHITE

# ============================================================================
# GUIDANCE SYSTEM CLASSES
# ============================================================================

class PowerGuidance:
	var missile = null

	func update(delta):
		# No guidance - maintain straight trajectory
		pass

class SteeringGuidance:
	var missile = null
	var steer_force: float = 50.0

	func update(delta):
		if not missile.target or not is_instance_valid(missile.target):
			return

		# Calculate steering force toward target
		var desired_velocity = (missile.target.global_position - missile.global_position).normalized() * missile.speed
		var steering_force = (desired_velocity - missile.velocity).normalized() * steer_force

		# Apply steering with velocity clamping
		missile.velocity += steering_force * delta
		missile.velocity = missile.velocity.limit_length(missile.speed)

class ProportionalNavigation:
	var missile = null
	var navigation_constant: float = 3.0
	var previous_los_angle: float = 0.0
	var previous_time: float = 0.0

	func update(delta):
		if not missile.target or not is_instance_valid(missile.target):
			return

		var current_time = Time.get_ticks_msec() / 1000.0
		if previous_time == 0.0:
			previous_time = current_time
			var los_vector = missile.target.global_position - missile.global_position
			previous_los_angle = los_vector.angle()
			return

		# Calculate Line of Sight (LOS) rate
		var los_vector = missile.target.global_position - missile.global_position
		var current_los_angle = los_vector.angle()
		var dt = current_time - previous_time

		if dt > 0.0:
			var los_rate = (current_los_angle - previous_los_angle) / dt

			# Proportional Navigation: acceleration perpendicular to LOS
			var los_normal = Vector2(-los_vector.y, los_vector.x).normalized()
			var acceleration = los_normal * los_rate * navigation_constant * missile.speed

			# Apply acceleration
			missile.velocity += acceleration * delta
			missile.velocity = missile.velocity.limit_length(missile.speed)

		# Store for next frame
		previous_los_angle = current_los_angle
		previous_time = current_time