extends Control

## MatchInterstitial - Displays matchup splash before combat begins.

const SPLASH_DIR := "res://assets/img/splash"
const SPLASH_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const SPLASH_TYPE_HINT := "Texture2D"
const MAX_FALLBACK_SPLASH_VARIANTS := 16
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

@export var opponent_count: int = 3

@onready var splash_rect: TextureRect = $Splash
@onready var player_name_label: Label = $DialogPanel/MarginContainer/VBoxContainer/PlayerName
@onready var vs_label: Label = $DialogPanel/MarginContainer/VBoxContainer/VsBreak
@onready var opponents_label: Label = $DialogPanel/MarginContainer/VBoxContainer/Opponents
@onready var prompt_label: Label = $DialogPanel/MarginContainer/VBoxContainer/Prompt

var _transition_started := false
var _active_opponent_ids: Array = []

func _ready():
	_apply_random_splash()
	_populate_dialog()
	vs_label.text = "      -- vs --"

func _apply_random_splash():
	var splash_paths := _gather_splash_paths()
	if splash_paths.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var path := String(splash_paths[rng.randi_range(0, splash_paths.size() - 1)])
	var texture := _load_splash_texture(path)
	if texture:
		splash_rect.texture = texture
	else:
		push_warning("MatchInterstitial: Failed to load splash texture at " + path)

func _load_splash_texture(path: String) -> Texture2D:
	var loaded = ResourceLoader.load(path, SPLASH_TYPE_HINT)
	if loaded and loaded is Texture2D:
		return loaded

	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		var absolute_path := ProjectSettings.globalize_path(path)
		err = image.load(absolute_path)
	if err != OK:
		return null

	return ImageTexture.create_from_image(image)

func _gather_splash_paths() -> Array:
	var paths: Array = []
	var dir := DirAccess.open(SPLASH_DIR)
	if dir == null:
		return _fallback_splash_paths()

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue

		if file_name.begins_with("."):
			continue

		var extension := file_name.get_extension().to_lower()
		if extension in SPLASH_EXTENSIONS:
			paths.append(SPLASH_DIR + "/" + file_name)
	dir.list_dir_end()

	if paths.is_empty():
		return _fallback_splash_paths()

	paths.sort()
	return paths

func _fallback_splash_paths() -> Array:
	var paths: Array = []
	for i in range(MAX_FALLBACK_SPLASH_VARIANTS):
		var candidate := "%s/splash_%d.png" % [SPLASH_DIR, i]
		if FileAccess.file_exists(candidate):
			paths.append(candidate)
	return paths

func _populate_dialog():
	var player_name := _resolve_player_car_name()
	player_name_label.text = player_name

	if SelectionState:
		if SelectionState.has_match_opponents():
			_active_opponent_ids = SelectionState.get_match_opponents()
		else:
			_active_opponent_ids = SelectionState.prepare_match_opponents(opponent_count)
	else:
		_active_opponent_ids = []

	if _active_opponent_ids.size() < opponent_count and SelectionState:
		_active_opponent_ids = SelectionState.prepare_match_opponents(opponent_count)

	var opponent_names := _resolve_opponent_names(_active_opponent_ids)
	if opponent_names.is_empty():
		opponents_label.text = "(no opponents found)"
	else:
		opponents_label.text = "\n".join(opponent_names)

	prompt_label.text = "Press any key to start"

func _resolve_player_car_name() -> String:
	if SelectionState and SelectionState.has_selection():
		var selection := SelectionState.get_selection()
		return selection.get("car_name", "Player")
	return "Player"

func _resolve_opponent_names(ids: Array) -> Array:
	if ids.is_empty():
		return []

	var roster_map := {}
	if SelectionState:
		for entry in SelectionState.get_roster():
			if entry is Dictionary and entry.has("id"):
				roster_map[entry.get("id")] = entry
	var display_names: Array = []
	for id in ids:
		var entry = roster_map.get(id, null)
		if entry:
			var car_name = entry.get("car_name", String(id))
			if not car_name is String:
				car_name = str(car_name)
			display_names.append(car_name)
		else:
			display_names.append(String(id))

	return display_names

func _unhandled_input(event):
	if _transition_started:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		_start_gameplay_transition()
	elif event is InputEventJoypadButton and event.pressed:
		_start_gameplay_transition()
	elif event is InputEventMouseButton and event.pressed:
		_start_gameplay_transition()

func _start_gameplay_transition():
	_transition_started = true
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
