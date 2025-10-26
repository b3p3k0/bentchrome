extends Control

## PlayerSelect - Character selection screen with portrait display and navigation

const REQUIRED_ACTIONS = ["select_prev_car", "select_next_car", "select_more_info", "select_confirm"]

const ACTION_DEFINITIONS := {
	"select_prev_car": [
		{"type": "key", "code": Key.KEY_A},
		{"type": "key", "code": Key.KEY_LEFT}
	],
	"select_next_car": [
		{"type": "key", "code": Key.KEY_D},
		{"type": "key", "code": Key.KEY_RIGHT}
	],
	"select_more_info": [
		{"type": "key", "code": Key.KEY_W}
	],
	"select_confirm": [
		{"type": "key", "code": Key.KEY_ENTER},
		{"type": "key", "code": Key.KEY_KP_ENTER},
		{"type": "key", "code": Key.KEY_SPACE}
	]
}

var roster := []
var current_index := 0
var is_dialog_open := false
var portrait_cache := {}

@onready var portrait := $PortraitContainer/Portrait
@onready var car_name_label := $PortraitContainer/InfoOverlay/VBoxContainer/CarName
@onready var driver_name_label := $PortraitContainer/InfoOverlay/VBoxContainer/DriverName
@onready var accel_value := $PortraitContainer/InfoOverlay/VBoxContainer/StatsContainer/AccelValue
@onready var speed_value := $PortraitContainer/InfoOverlay/VBoxContainer/StatsContainer/SpeedValue
@onready var handling_value := $PortraitContainer/InfoOverlay/VBoxContainer/StatsContainer/HandlingValue
@onready var armor_value := $PortraitContainer/InfoOverlay/VBoxContainer/StatsContainer/ArmorValue
@onready var special_value := $PortraitContainer/InfoOverlay/VBoxContainer/StatsContainer/SpecialValue

@onready var dialog := $MoreInfoDialog
@onready var dialog_title := $MoreInfoDialog/DialogContent/VBoxContainer/Title
@onready var dialog_flavor := $MoreInfoDialog/DialogContent/VBoxContainer/FlavorText
@onready var dialog_accel := $MoreInfoDialog/DialogContent/VBoxContainer/DetailedStats/AccelValue2
@onready var dialog_speed := $MoreInfoDialog/DialogContent/VBoxContainer/DetailedStats/SpeedValue2
@onready var dialog_handling := $MoreInfoDialog/DialogContent/VBoxContainer/DetailedStats/HandlingValue2
@onready var dialog_armor := $MoreInfoDialog/DialogContent/VBoxContainer/DetailedStats/ArmorValue2
@onready var dialog_special := $MoreInfoDialog/DialogContent/VBoxContainer/DetailedStats/SpecialValue2

func _ready():
	_ensure_required_actions()

	if not SelectionState.load_roster("res://assets/data/roster.json"):
		push_error("Failed to load character roster")
		return

	roster = SelectionState.get_roster()
	if roster.size() == 0:
		push_error("No characters found in roster")
		return

	# Connect dialog close signal to sync is_dialog_open flag
	dialog.popup_hide.connect(_on_dialog_hidden)

	current_index = 0
	update_display()
	print("Player Selection initialized with ", roster.size(), " characters")

func _unhandled_input(event):
	# Use discrete navigation only (no continuous hold-to-scroll)
	if is_dialog_open:
		if Input.is_action_just_pressed("select_more_info"):
			toggle_more_info_dialog()
			accept_event()
		return

	if Input.is_action_just_pressed("select_prev_car"):
		navigate_previous()
		accept_event()
	elif Input.is_action_just_pressed("select_next_car"):
		navigate_next()
		accept_event()
	elif Input.is_action_just_pressed("select_more_info"):
		toggle_more_info_dialog()
		accept_event()
	elif Input.is_action_just_pressed("select_confirm"):
		confirm_selection()
		accept_event()

func _ensure_required_actions():
	var missing_actions: Array[String] = []
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			_register_action(action)
			missing_actions.append(action)

	if missing_actions.size() > 0:
		print("Registered missing input actions at runtime: ", missing_actions)

func _register_action(action_name: String) -> void:
	if not ACTION_DEFINITIONS.has(action_name):
		return

	InputMap.add_action(action_name, 0.5)
	for definition in ACTION_DEFINITIONS[action_name]:
		var event: InputEvent = null
		if definition.type == "key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = definition.code
			event = key_event

		if event != null:
			InputMap.action_add_event(action_name, event)

func navigate_previous():
	if roster.is_empty():
		return
	current_index = (current_index - 1) % roster.size()
	if current_index < 0:
		current_index = roster.size() - 1
	update_display()

func navigate_next():
	if roster.is_empty():
		return
	current_index = (current_index + 1) % roster.size()
	update_display()

func _on_dialog_hidden():
	is_dialog_open = false

func toggle_more_info_dialog():
	if is_dialog_open:
		dialog.hide()
		is_dialog_open = false
	else:
		update_dialog_content()
		dialog.popup_centered()
		is_dialog_open = true

func update_display():
	if roster.size() == 0 or current_index >= roster.size():
		return

	var entry = roster[current_index]

	# Update portrait with caching
	var portrait_path = entry.get("portrait", "")
	if portrait_path != "":
		var texture: Texture2D

		# Check cache first
		if portrait_cache.has(portrait_path):
			texture = portrait_cache[portrait_path]
		else:
			# Load texture directly
			texture = load(portrait_path)
			# Cache only successful loads
			if texture:
				portrait_cache[portrait_path] = texture
			else:
				push_warning("Portrait failed for " + entry.get("id", "unknown") + ": " + portrait_path)

		portrait.texture = texture
	else:
		# Clear texture for entries without portrait path
		portrait.texture = null

	# Update text labels
	car_name_label.text = entry.get("car_name", "Unknown")
	driver_name_label.text = entry.get("driver_name", "Unknown Driver")

	# Update stats
	var stats = entry.get("stats", {})
	accel_value.text = str(stats.get("acceleration", 1))
	speed_value.text = str(stats.get("top_speed", 1))
	handling_value.text = str(stats.get("handling", 1))
	armor_value.text = str(stats.get("armor", 1))
	special_value.text = str(stats.get("special_power", 1))

func update_dialog_content():
	if roster.size() == 0 or current_index >= roster.size():
		return

	var entry = roster[current_index]
	var car_name = entry.get("car_name", "Unknown")
	var driver_name = entry.get("driver_name", "Unknown Driver")
	var flavor = entry.get("flavor", "No description available.")
	var stats = entry.get("stats", {})

	dialog_title.text = car_name + " - " + driver_name
	dialog_flavor.text = flavor

	# Update detailed stats with x/5 format
	dialog_accel.text = str(stats.get("acceleration", 1)) + "/5"
	dialog_speed.text = str(stats.get("top_speed", 1)) + "/5"
	dialog_handling.text = str(stats.get("handling", 1)) + "/5"
	dialog_armor.text = str(stats.get("armor", 1)) + "/5"
	dialog_special.text = str(stats.get("special_power", 1)) + "/5"

func confirm_selection():
	if roster.size() == 0 or current_index >= roster.size():
		push_error("Invalid selection state")
		return

	var selected_entry = roster[current_index]
	SelectionState.set_selection(selected_entry)

	print("Selected: ", selected_entry.get("car_name", "Unknown"), " (", selected_entry.get("driver_name", "Unknown"), ")")

	# Transition to main game scene
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
