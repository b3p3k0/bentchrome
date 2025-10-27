extends CanvasLayer

@onready var player_name_label := $HUDRoot/HUDColumn/VBoxContainer/PlayerName
@onready var player_health_bar := $HUDRoot/HUDColumn/VBoxContainer/PlayerHealthBar
@onready var radar_placeholder := $HUDRoot/HUDColumn/VBoxContainer/RadarContainer/RadarPlaceholder
@onready var opponents_container := $HUDRoot/HUDColumn/VBoxContainer/OpponentsContainer

var player_car: CharacterBody2D
var player_vehicle_health
var opponent_health_refs: Array[Dictionary] = []

func _ready():
	_initialize_player_info()
	_initialize_health_connection()
	set_opponents([])

func _initialize_player_info():
	var player_name = "Player"

	if SelectionState.has_selection():
		var selection = SelectionState.get_selection()
		var car_name = selection.get("car_name", "")
		var driver_name = selection.get("driver_name", "")

		if not car_name.is_empty() and not driver_name.is_empty():
			player_name = car_name
		elif not driver_name.is_empty():
			player_name = driver_name
		elif not car_name.is_empty():
			player_name = car_name

	player_name_label.text = player_name

func _initialize_health_connection():
	player_car = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if not player_car:
		print("Warning: PlayerCar not found in 'player' group for HUD")
		return

	if player_car.has_method("get_current_hp") and player_car.has_method("get_max_hp"):
		player_vehicle_health = player_car.get("vehicle_health")

		if player_vehicle_health and player_vehicle_health.has_signal("took_damage"):
			player_vehicle_health.took_damage.connect(_on_player_took_damage)
			player_vehicle_health.healed.connect(_on_player_healed)
			player_vehicle_health.died.connect(_on_player_died)

			_update_player_health_bar()
		else:
			print("Warning: PlayerCar vehicle_health not ready for HUD connection")
	else:
		print("Warning: PlayerCar missing health interface for HUD")

func _update_player_health_bar():
	if not player_car:
		return

	var current_hp = player_car.get_current_hp()
	var max_hp = player_car.get_max_hp()

	if max_hp > 0:
		player_health_bar.max_value = max_hp
		player_health_bar.value = current_hp
	else:
		player_health_bar.value = 0

func _on_player_took_damage(amount: float, source):
	_update_player_health_bar()

func _on_player_healed(amount: float):
	_update_player_health_bar()

func _on_player_died():
	_update_player_health_bar()

func set_opponents(opponents: Array):
	_clear_opponent_rows()

	for opponent_data in opponents:
		_add_opponent_row(opponent_data)

func _clear_opponent_rows():
	for ref in opponent_health_refs:
		if ref.has("vehicle_health") and ref.vehicle_health and ref.vehicle_health.has_signal("took_damage"):
			if ref.vehicle_health.took_damage.is_connected(_on_opponent_took_damage):
				ref.vehicle_health.took_damage.disconnect(_on_opponent_took_damage)
			if ref.vehicle_health.healed.is_connected(_on_opponent_healed):
				ref.vehicle_health.healed.disconnect(_on_opponent_healed)
			if ref.vehicle_health.died.is_connected(_on_opponent_died):
				ref.vehicle_health.died.disconnect(_on_opponent_died)

	opponent_health_refs.clear()

	var children = opponents_container.get_children()
	for child in children:
		if child.name != "OpponentsSpacer":
			child.queue_free()

func _add_opponent_row(opponent_data: Dictionary):
	var name = opponent_data.get("name", "Unknown")
	var health_component = opponent_data.get("health_component")
	var current_hp = opponent_data.get("current_hp", 0.0)
	var max_hp = opponent_data.get("max_hp", 100.0)

	var row_container = VBoxContainer.new()
	row_container.name = "Opponent_" + name

	var name_label = Label.new()
	name_label.text = name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var health_bar = TextureProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 16)
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_bar.nine_patch_stretch = true
	health_bar.stretch_margin_left = 2
	health_bar.stretch_margin_top = 2
	health_bar.stretch_margin_right = 2
	health_bar.stretch_margin_bottom = 2

	row_container.add_child(name_label)
	row_container.add_child(health_bar)
	opponents_container.add_child(row_container)

	var ref_data = {
		"name": name,
		"row": row_container,
		"health_bar": health_bar,
		"vehicle_health": health_component
	}

	if health_component and health_component.has_signal("took_damage"):
		health_component.took_damage.connect(_on_opponent_took_damage.bind(ref_data))
		health_component.healed.connect(_on_opponent_healed.bind(ref_data))
		health_component.died.connect(_on_opponent_died.bind(ref_data))

	opponent_health_refs.append(ref_data)

func _on_opponent_took_damage(ref_data: Dictionary, amount: float, source):
	_update_opponent_health_bar(ref_data)

func _on_opponent_healed(ref_data: Dictionary, amount: float):
	_update_opponent_health_bar(ref_data)

func _on_opponent_died(ref_data: Dictionary):
	_update_opponent_health_bar(ref_data)

func _update_opponent_health_bar(ref_data: Dictionary):
	var vehicle_health = ref_data.get("vehicle_health")
	var health_bar = ref_data.get("health_bar")

	if vehicle_health and health_bar:
		health_bar.value = vehicle_health.current_hp

func _exit_tree():
	_clear_opponent_rows()