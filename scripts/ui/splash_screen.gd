extends Control

@onready var start_button := $UIGrid/Cell7/MenuBox/StartButton
var is_transitioning := false

func _ready():
	# Connect button signal
	start_button.pressed.connect(start_game)

	# Defer focus to avoid Godot settling issues
	call_deferred("_set_initial_focus")

	print("Splash screen initialized")

func _set_initial_focus():
	start_button.grab_focus()

func _unhandled_input(event):
	# Handle ui_accept events specifically (not polling)
	if event.is_action_pressed("ui_accept") and not is_transitioning:
		start_game()
		accept_event()

func start_game():
	if is_transitioning:
		return # Prevent double-fire

	is_transitioning = true
	print("Starting game - transitioning to PlayerSelect")

	var err = get_tree().change_scene_to_file("res://scenes/ui/PlayerSelect.tscn")
	if err != OK:
		push_error("Failed to load PlayerSelect scene: " + str(err))
		is_transitioning = false