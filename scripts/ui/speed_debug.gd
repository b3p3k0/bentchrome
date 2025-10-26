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
		text = "Speed: %.0f" % speed