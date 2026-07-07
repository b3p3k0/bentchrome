extends Control
## Car-select carousel: browse the 9 cars (portrait + stats + special), confirm
## to set the player's car (GameState) and enter the arena.

var _cars: Array = []
var _index := 0
var _done := false

@onready var _portrait: TextureRect = $Portrait
@onready var _name: Label = $Footer/Margin/VBox/Name
@onready var _driver: Label = $Footer/Margin/VBox/Driver
@onready var _stats: Label = $Footer/Margin/VBox/Stats
@onready var _special: Label = $Footer/Margin/VBox/Special

func _ready() -> void:
	_load_cars()
	if _cars.is_empty():
		push_warning("car_select: no cars loaded")
		return
	for i in _cars.size():
		if _cars[i].id == GameState.selected_vehicle_id:
			_index = i
	_show()

func _load_cars() -> void:
	var f := FileAccess.open("res://assets/data/roster.json", FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for c in data.get("characters", []):
		var vs: Variant = load("res://data/vehicles/%s.tres" % c.get("id", ""))
		if vs:
			_cars.append(vs)

func _unhandled_input(event: InputEvent) -> void:
	if _done or _cars.is_empty():
		return
	if event.is_action_pressed(&"select_next"):
		_index = (_index + 1) % _cars.size()
		_show()
	elif event.is_action_pressed(&"select_prev"):
		_index = (_index - 1 + _cars.size()) % _cars.size()
		_show()
	elif event.is_action_pressed(&"select_confirm"):
		_done = true
		GameState.selected_vehicle_id = _cars[_index].id
		GameState.reset_campaign()
		SceneFlow.to_level(0)

func _show() -> void:
	var car: Variant = _cars[_index]
	_portrait.texture = TextureLoader.load_texture("res://assets/img/bios/%s.png" % car.id)
	_name.text = car.car_name
	_driver.text = car.driver_name
	_stats.text = "ACCEL %d    TOP %d    HANDLING %d    ARMOR %d    SPECIAL %d" % [
		car.acceleration, car.top_speed, car.handling, car.armor, car.special_power]
	_special.text = "%s — %s" % [car.special_name, car.special_desc]
