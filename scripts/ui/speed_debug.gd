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

		text = "Speed: %.0f / %.0f" % [speed, cap]
