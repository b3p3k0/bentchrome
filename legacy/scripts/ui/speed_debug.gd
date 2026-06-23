extends Label

@export var player_car_path: NodePath = NodePath()

var player_car: CharacterBody2D

func _ready():
	if player_car_path.is_empty():
		player_car = get_tree().get_first_node_in_group("player") as CharacterBody2D
	else:
		player_car = get_node(player_car_path) as CharacterBody2D

	if not player_car:
		print("Warning: PlayerCar not found. Ensure PlayerCar is in 'player' group or set player_car_path manually.")

func _process(_delta):
	if player_car:
		var speed = player_car.velocity.length()
		var cap = speed
		if player_car.has_method("get_effective_max_speed"):
			cap = player_car.get_effective_max_speed()
		elif player_car.has_method("get_max_speed"):
			cap = player_car.get("max_speed")

		# Enhanced debug info (wrapped in DEBUG_VEHICLE_TUNING check)
		var debug_tuning = player_car.get("DEBUG_VEHICLE_TUNING") if player_car.has_method("get") else false
		if debug_tuning:
			var mass_scalar = 1.0
			var accel = 0.0
			var brake = 0.0
			var base_accel = 0.0

			if player_car.has_method("get_mass_scalar"):
				mass_scalar = player_car.get_mass_scalar()
			elif player_car.get("vehicle_health") and player_car.vehicle_health.has_method("get_mass_scalar"):
				mass_scalar = player_car.vehicle_health.get_mass_scalar()

			if player_car.has_method("get"):
				accel = player_car.get("acceleration")
				brake = player_car.get("brake_force")
				var base_stats = player_car.get("_base_stats")
				if base_stats and base_stats.has("acceleration"):
					base_accel = base_stats.acceleration

			text = "Speed: %.0f / %.0f\nAccel: %.0f (base: %.0f)\nBrake: %.0f | Mass: %.2f" % [
				speed, cap, accel, base_accel, brake, mass_scalar
			]
		else:
			text = "Speed: %.0f / %.0f" % [speed, cap]
