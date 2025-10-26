extends Control

@onready var text_label := $TextPanel/TextLabel
var is_returning := false

func _ready():
	print("Story screen initialized")
	load_story_data()
	calculate_text_capacity()

func load_story_data():
	var file = FileAccess.open("res://assets/data/story.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load story.json file")
		text_label.text = "Story data unavailable. Return to continue."
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse story.json: " + json.get_error_message())
		text_label.text = "Story data unavailable. Return to continue."
		return

	var story_data = json.data
	if story_data.has("body"):
		text_label.text = story_data.body
	else:
		text_label.text = "Story data unavailable. Return to continue."

func calculate_text_capacity():
	var font = text_label.get_theme_font("font", "Label")
	if font == null:
		font = text_label.get_theme_default_font()

	var char_width = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var panel_width = $TextPanel.size.x - 40  # Account for margins
	var panel_height = $TextPanel.size.y - 64  # Account for top/bottom margins
	var line_height = font.get_height(20)

	var chars_per_line = int(panel_width / char_width)
	var estimated_lines = int(panel_height / line_height)
	var estimated_chars = chars_per_line * estimated_lines

	print("Story text panel holds approx ", estimated_chars, " characters.")

func _unhandled_input(event):
	if is_returning:
		return

	var should_return = false

	# Handle keyboard, mouse, and controller input
	if event is InputEventKey and event.pressed:
		should_return = true
	elif event is InputEventMouseButton and event.pressed:
		should_return = true
	elif event is InputEventJoypadButton and event.pressed:
		should_return = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		should_return = true

	if should_return:
		return_to_splash()
		accept_event()

func return_to_splash():
	if is_returning:
		return  # Prevent double-fire

	is_returning = true
	print("Returning to splash screen")

	var err = get_tree().change_scene_to_file("res://scenes/ui/SplashScreen.tscn")
	if err != OK:
		push_error("Failed to load SplashScreen scene: " + str(err))
		is_returning = false