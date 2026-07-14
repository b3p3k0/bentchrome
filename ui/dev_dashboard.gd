extends CanvasLayer
## Dev-only tuning dashboard (toggle with F1). Live-edits the player car's raw
## handling knobs and exports them as per-car overrides into the car's .tres.
## Added to the arena only when Dev.enabled. UI is built in code (dynamic slider
## list), so the scene is just this script on a CanvasLayer.

const TUNABLE := [
	"max_speed", "acceleration", "turn_rate_deg", "lateral_grip",
	"brake_deceleration", "reverse_max_speed", "coast_deceleration",
	"turn_authority_speed", "min_turn_authority",
	"mass", "accel_taper", "launch_boost", "launch_factor",
	"handbrake_deceleration", "handbrake_grip_factor",
]
const RANGES := {
	"max_speed": [100.0, 900.0, 5.0],
	"acceleration": [60.0, 900.0, 5.0],
	"turn_rate_deg": [60.0, 360.0, 2.0],
	"lateral_grip": [1.0, 15.0, 0.1],
	"brake_deceleration": [200.0, 2000.0, 10.0],
	"reverse_max_speed": [40.0, 400.0, 5.0],
	"coast_deceleration": [100.0, 900.0, 5.0],
	"turn_authority_speed": [40.0, 400.0, 5.0],
	"min_turn_authority": [0.0, 1.0, 0.01],
	"mass": [1.0, 10.0, 0.5],
	"accel_taper": [0.0, 0.95, 0.01],
	"launch_boost": [1.0, 3.0, 0.05],
	"launch_factor": [0.0, 2.0, 0.05],
	"handbrake_deceleration": [100.0, 1200.0, 10.0],
	"handbrake_grip_factor": [0.0, 1.0, 0.01],
}

const MPH_PER_PXS := 0.15       # ui/hud.gd display anchor (US units)
const SIXTY_MPH_PXS := 400.0    # 60 mph

var _player: Node = null
var _cars: Array = []
var _panel: PanelContainer
var _car_picker: OptionButton
var _status: Label
var _terrain_status: Label
var _feel_status: Label
var _sliders := {}
var _value_labels := {}

## Minimal ride for the 0-60 sim: apply() only touches these members.
class FeelStub:
	var heading := 0.0
	var velocity := Vector2.ZERO
	var current_terrain: StringName = &"road"
	var stats = null
	func get_speed_scale() -> float:
		return 1.0

func _ready() -> void:
	layer = 50
	_build_ui()
	_load_cars()
	_panel.visible = false
	call_deferred("_bind_player")

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
			_car_picker.add_item(vs.car_name)

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player")
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible
		if _panel.visible:
			if _player == null or not is_instance_valid(_player):
				_bind_player()
			else:
					_refresh()

func _process(_delta: float) -> void:
	if _panel and _panel.visible:
		_refresh_terrain_status()

func _refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var c = _player.get_controller()
	if c == null:
		return
	for knob in TUNABLE:
		var v: float = c.get(knob)
		_sliders[knob].set_value_no_signal(v)
		_value_labels[knob].text = _fmt_value(knob, v)
	var sid: StringName = _player.stats.id if _player.stats else &""
	for i in _cars.size():
		if _cars[i].id == sid:
			_car_picker.select(i)
	_refresh_terrain_status()
	_refresh_feel_status()

func _refresh_terrain_status() -> void:
	if _terrain_status and _player and is_instance_valid(_player):
		_terrain_status.text = terrain_readout(_player)

static func terrain_readout(vehicle) -> String:
	if vehicle == null:
		return "surface —"
	var surface_v: Variant = vehicle.get("current_terrain")
	var surface := StringName(surface_v)
	var effective: Dictionary = DrivingController.effective_terrain(vehicle, surface)
	return "surface %-5s  accel %.2f  top %.2f  grip %.2f  steer %.2f" % [
		String(surface), effective.accel, effective.top, effective.grip, effective.steer]

func _on_knob_changed(value: float, knob: String) -> void:
	if _player and is_instance_valid(_player):
		_player.get_controller().set(knob, value)
	_value_labels[knob].text = _fmt_value(knob, value)
	_refresh_feel_status()

static func _fmt_value(knob: String, v: float) -> String:
	if knob == "max_speed":
		return "%.0f (%.0fmph)" % [v, v * MPH_PER_PXS]
	return "%.2f" % v

## Measured 0-60 mph (time to 400 px/s on the current knobs + the car's road
## terrain factors) — simulated on a scratch controller, so tuning against the
## baselines table is a number, not vibes. Recomputed on car pick/knob drag
## only; too heavy for _process.
func _refresh_feel_status() -> void:
	if _feel_status == null or _player == null or not is_instance_valid(_player):
		return
	var c = _player.get_controller()
	if c == null:
		return
	var sim := DrivingController.new()
	for knob in TUNABLE:
		sim.set(knob, c.get(knob))
	var stub := FeelStub.new()
	stub.stats = _player.get("stats")
	var intent := {"throttle": 1.0, "steer": 0.0}
	var elapsed := 0.0
	while stub.velocity.dot(Vector2.RIGHT.rotated(stub.heading)) < SIXTY_MPH_PXS \
			and elapsed < 30.0:
		sim.apply(stub, intent, 1.0 / 60.0)
		elapsed += 1.0 / 60.0
	sim.free()
	_feel_status.text = "0-60 mph: %s" % ("%.2fs" % elapsed if elapsed < 30.0 else "never (top < 60)")

func _on_car_picked(index: int) -> void:
	if _player and is_instance_valid(_player) and index < _cars.size():
		_player.set_stats(_cars[index])
		_refresh()

func _on_export() -> void:
	if _player == null or _player.stats == null:
		return
	var c = _player.get_controller()
	var overrides := {}
	for knob in TUNABLE:
		overrides[knob] = c.get(knob)
	_player.stats.handling_overrides = overrides
	var path := "res://data/vehicles/%s.tres" % _player.stats.id
	var err := ResourceSaver.save(_player.stats, path)
	_status.text = "exported %s (err %d)" % [_player.stats.id, err]

func _on_reset() -> void:
	if _player == null or _player.stats == null:
		return
	_player.stats.handling_overrides = {}
	_player.set_stats(_player.stats)
	_refresh()
	_status.text = "reset %s to curves" % _player.stats.id

func _on_test_effect(kind: String) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var spec := StatusEffectSpec.new()
	spec.kind = StringName(kind)
	spec.duration = 4.0
	spec.magnitude = 20.0 if kind == "burn" else (0.4 if kind == "slow" else 1.0)
	_player.apply_effect(spec)
	_status.text = "applied %s to player (4s)" % kind

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.custom_minimum_size = Vector2(390, 0)
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DEV — car tuning (F1 to toggle)"
	vbox.add_child(title)

	_car_picker = OptionButton.new()
	_car_picker.item_selected.connect(_on_car_picked)
	vbox.add_child(_car_picker)

	_terrain_status = Label.new()
	_terrain_status.modulate = Color(0.65, 0.82, 0.95)
	vbox.add_child(_terrain_status)

	_feel_status = Label.new()
	_feel_status.modulate = Color(0.95, 0.85, 0.6)
	vbox.add_child(_feel_status)

	for knob in TUNABLE:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = knob
		lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		var r: Array = RANGES[knob]
		slider.min_value = r[0]
		slider.max_value = r[1]
		slider.step = r[2]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(120, 0)
		slider.value_changed.connect(_on_knob_changed.bind(knob))
		row.add_child(slider)
		var val := Label.new()
		val.custom_minimum_size = Vector2(56, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		_sliders[knob] = slider
		_value_labels[knob] = val
		vbox.add_child(row)

	var btns := HBoxContainer.new()
	var export_btn := Button.new()
	export_btn.text = "Export overrides"
	export_btn.pressed.connect(_on_export)
	btns.add_child(export_btn)
	var reset_btn := Button.new()
	reset_btn.text = "Reset to curves"
	reset_btn.pressed.connect(_on_reset)
	btns.add_child(reset_btn)
	vbox.add_child(btns)

	var fx := HBoxContainer.new()
	for kind in ["burn", "slow", "invuln"]:
		var b := Button.new()
		b.text = "test " + kind
		b.pressed.connect(_on_test_effect.bind(kind))
		fx.add_child(b)
	vbox.add_child(fx)

	_status = Label.new()
	vbox.add_child(_status)
