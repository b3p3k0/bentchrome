extends CanvasLayer

@onready var player_name_label := $HUDRoot/HUDColumn/VBoxContainer/PlayerName
@onready var player_health_bar := $HUDRoot/HUDColumn/VBoxContainer/PlayerHealthBar
@onready var radar_placeholder := $HUDRoot/HUDColumn/VBoxContainer/RadarContainer/RadarPlaceholder
@onready var opponents_container := $HUDRoot/HUDColumn/VBoxContainer/OpponentsContainer

var player_car: CharacterBody2D
var player_vehicle_health
var opponent_health_refs: Array[Dictionary] = []
var player_health_background_style: StyleBoxFlat
var player_health_fill_style: StyleBoxFlat
var opponent_health_background_style: StyleBoxFlat
var opponent_health_fill_style: StyleBoxFlat
const OPPONENT_BAR_HEIGHT_RATIO := 0.2
var _game_manager_connected := false
var _spawn_signal_callable := Callable()
var _destroy_signal_callable := Callable()

var missile_label: Label = null
var _debug_accum: float = 0.0
const _DEBUG_INTERVAL: float = 2.0
const DEV_MISSILE_SCENE: PackedScene = preload("res://scenes/weapons/Missile.tscn")
var _prev_k_pressed: bool = false

func _ready():
	_configure_health_bar_styles()
	_initialize_player_info()
	_initialize_health_connection()
	_setup_opponent_tracking()

	# Resolve missile label defensively (scene file may define nodes in different order)
	missile_label = get_node_or_null("HUDRoot/HUDColumn/VBoxContainer/MissileLabel")
	if missile_label == null:
		# CanvasLayer doesn't expose find_node in this context; use find_child instead
		if has_method("find_child"):
			missile_label = find_child("MissileLabel", true, false)
		else:
			# Fallback: search the whole tree for a node named MissileLabel
			for n in get_tree().get_nodes_in_group(""):
				if n and n.name == "MissileLabel":
					missile_label = n
					break

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
	if not player_car or not player_car.has_method("get_current_hp") or not player_car.has_method("get_max_hp"):
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
		var health_component = ref.get("vehicle_health")
		if health_component:
			var took_damage_callable = ref.get("took_damage_callable")
			if took_damage_callable and health_component.took_damage.is_connected(took_damage_callable):
				health_component.took_damage.disconnect(took_damage_callable)

			var healed_callable = ref.get("healed_callable")
			if healed_callable and health_component.healed.is_connected(healed_callable):
				health_component.healed.disconnect(healed_callable)

			var died_callable = ref.get("died_callable")
			if died_callable and health_component.died.is_connected(died_callable):
				health_component.died.disconnect(died_callable)

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

	var health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(0, max(player_health_bar.custom_minimum_size.y * OPPONENT_BAR_HEIGHT_RATIO, 6))
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_bar.add_theme_stylebox_override("background", opponent_health_background_style.duplicate())
	health_bar.add_theme_stylebox_override("fill", opponent_health_fill_style.duplicate())

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
		var took_damage_callable = Callable(self, "_on_opponent_took_damage_internal").bind(ref_data)
		var healed_callable = Callable(self, "_on_opponent_healed_internal").bind(ref_data)
		var died_callable = Callable(self, "_on_opponent_died_internal").bind(ref_data)

		ref_data["took_damage_callable"] = took_damage_callable
		ref_data["healed_callable"] = healed_callable
		ref_data["died_callable"] = died_callable

		health_component.took_damage.connect(took_damage_callable)
		health_component.healed.connect(healed_callable)
		health_component.died.connect(died_callable)

	opponent_health_refs.append(ref_data)

func _on_opponent_took_damage_internal(amount: float, source, ref_data: Dictionary):
	_update_opponent_health_bar(ref_data)

func _on_opponent_healed_internal(amount: float, ref_data: Dictionary):
	_update_opponent_health_bar(ref_data)

func _on_opponent_died_internal(ref_data: Dictionary):
	_update_opponent_health_bar(ref_data)

func _update_opponent_health_bar(ref_data: Dictionary):
	var vehicle_health = ref_data.get("vehicle_health")
	var health_bar = ref_data.get("health_bar")

	if vehicle_health and health_bar:
		health_bar.value = vehicle_health.current_hp

func _exit_tree():
	_disconnect_game_manager()
	_clear_opponent_rows()

func _process(_delta):
	# Update missile count display defensively
	var count_text = "-"
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		if player_node.has_method("get_missile_count"):
			count_text = str(player_node.get_missile_count())
		else:
			var mc = player_node.get("missile_count")
			if mc != null:
				count_text = str(mc)
	else:
		# Try SelectionState to resolve selection to a node by roster id
		if Engine.has_singleton("SelectionState") and SelectionState.has_selection():
			var sel = SelectionState.get_selection()
			var roster_id = sel.get("id", "")
			if roster_id != "":
				for n in get_tree().get_nodes_in_group("player"):
					if not n:
						continue
					var nid = n.get("roster_id")
					if nid == roster_id:
						if n.has_method("get_missile_count"):
							count_text = str(n.get_missile_count())
						else:
							var mc2 = n.get("missile_count")
							if mc2 != null:
								count_text = str(mc2)
						break

	if missile_label:
		missile_label.text = "Missiles: " + count_text

	# Debug/testing helpers: allow keyboard fallback to fire missile (press 'M') and periodic diagnostics
	_debug_accum += _delta
	# Edge-detect 'M' for invoking player's fire_missile() if available
	if Input.is_key_pressed(Key.KEY_M):
		var p = get_tree().get_first_node_in_group("player")
		if p and p.has_method("fire_missile"):
			print("[HUD] Debug: invoking fire_missile() on player via 'M' key")
			p.fire_missile()
		else:
			print("[HUD] Debug: player node or fire_missile() not available")

	# Developer spawn key: press 'K' to spawn a debug missile at the player's muzzle (bypasses ammo/cooldown)
	var k_pressed = Input.is_key_pressed(Key.KEY_K)
	if k_pressed and not _prev_k_pressed:
		var p2 = get_tree().get_first_node_in_group("player")
		if p2 and p2.has_method("fire_missile"):
			p2.fire_missile()
		else:
			print("[HUD] Dev spawn: player or fire_missile() not available")
	_prev_k_pressed = k_pressed

	# Right-click dev-spawn: make right mouse behave like K (edge-detected)
	if Input.is_action_just_pressed("fire_special"):
		var p2 = get_tree().get_first_node_in_group("player")
		if p2 and p2.has_method("fire_missile"):
			p2.fire_missile()
		else:
			print("[HUD] Right-click dev spawn: player or fire_missile() not available")

	if _debug_accum >= _DEBUG_INTERVAL:
		_debug_accum = 0.0
		var pnode = get_tree().get_first_node_in_group("player")
		if pnode:
			var mc = "<no-missile-count>"
			if pnode.has_method("get_missile_count"):
				mc = str(pnode.get_missile_count())
			else:
				var tmpmc = pnode.get("missile_count")
				if tmpmc != null:
					mc = str(tmpmc)
			print("[HUD] Debug: player found; missile_count=", mc, ", missile_label_resolved=", missile_label != null)
		else:
			print("[HUD] Debug: player not found in group 'player'; missile_label_resolved=", missile_label != null)

func _configure_health_bar_styles():
	player_health_background_style = _make_style_box(Color(0.12, 0.12, 0.16), 6)
	player_health_fill_style = _make_style_box(Color(0.8, 0.22, 0.24), 6)
	opponent_health_background_style = _make_style_box(Color(0.12, 0.12, 0.14), 4)
	opponent_health_fill_style = _make_style_box(Color(0.72, 0.58, 0.22), 4)

	player_health_bar.add_theme_stylebox_override("background", player_health_background_style.duplicate())
	player_health_bar.add_theme_stylebox_override("fill", player_health_fill_style.duplicate())
	player_health_bar.show_percentage = false

func _make_style_box(color: Color, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.border_color = Color(
		clamp(color.r + 0.1, 0.0, 1.0),
		clamp(color.g + 0.1, 0.0, 1.0),
		clamp(color.b + 0.1, 0.0, 1.0),
		1.0
	)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style

func _setup_opponent_tracking():
	_connect_game_manager()
	_refresh_opponent_list()

func _connect_game_manager():
	if _game_manager_connected:
		return

	if GameManager == null:
		return

	_spawn_signal_callable = Callable(self, "_on_game_manager_object_spawned")
	_destroy_signal_callable = Callable(self, "_on_game_manager_object_destroyed")

	if not GameManager.object_spawned.is_connected(_spawn_signal_callable):
		GameManager.object_spawned.connect(_spawn_signal_callable)

	if not GameManager.object_destroyed.is_connected(_destroy_signal_callable):
		GameManager.object_destroyed.connect(_destroy_signal_callable)

	_game_manager_connected = true

func _disconnect_game_manager():
	if not _game_manager_connected:
		return

	if GameManager != null:
		if GameManager.object_spawned.is_connected(_spawn_signal_callable):
			GameManager.object_spawned.disconnect(_spawn_signal_callable)
		if GameManager.object_destroyed.is_connected(_destroy_signal_callable):
			GameManager.object_destroyed.disconnect(_destroy_signal_callable)

	_game_manager_connected = false

func _on_game_manager_object_spawned(object: Node, object_type: String):
	if object_type == "enemy":
		call_deferred("_refresh_opponent_list")

func _on_game_manager_object_destroyed(object: Node, object_type: String):
	if object_type == "enemy":
		call_deferred("_refresh_opponent_list")

func _refresh_opponent_list():
	var opponent_data: Array = []
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_inside_tree():
			continue

		var entry = _build_opponent_entry(enemy)
		if entry.size() > 0:
			opponent_data.append(entry)

	set_opponents(opponent_data)

func _build_opponent_entry(enemy: Node) -> Dictionary:
	var entry: Dictionary = {}
	var display_name := ""

	if enemy.has_method("get_display_name"):
		display_name = enemy.get_display_name()
	else:
		display_name = enemy.name

	var health_component = null
	if enemy.has_method("get_vehicle_health"):
		health_component = enemy.get_vehicle_health()
	elif enemy.has_method("get_vehicle_health_component"):
		health_component = enemy.get_vehicle_health_component()

	entry["name"] = display_name

	if health_component:
		entry["health_component"] = health_component
		entry["current_hp"] = health_component.current_hp
		entry["max_hp"] = max(health_component.max_hp, 1.0)
	else:
		entry["current_hp"] = 0.0
		entry["max_hp"] = 100.0

	return entry
