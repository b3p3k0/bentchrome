extends "res://levels/combat_level.gd"
## The Coliseum's shell: stock combat_level plus THE ENDING — when the king
## falls, the world does not freeze. The end screen shows its card unpaused
## (win_keeps_rolling), the player's car is handed to the victory-lap driver
## and parades the ring god-moded, and fireworks pop over the stands until
## a button is pressed. The lose path is untouched.

const VictoryDriver := preload("res://vehicles/goliath/victory_lap_driver.gd")
const Deco := preload("res://levels/stadium/stadium_deco.gd")  # _make_light

static var NIGHT_TINT := Color(0.5, 0.56, 0.82)  # the dusk over the bowl —
	# mild by design: combat readability first, the lights do the drama
static var HEADLIGHT_SPREAD := 56.0     # beam cone angle (degrees, total)
static var PLAYER_BEAM_LENGTH := 480.0  # Visual-local throw past the nose
static var PLAYER_BEAM_ENERGY := 0.7
static var PLAYER_NOSE := 38.0          # lamp line, Visual-local px
static var GOLIATH_BEAM_LENGTH := 420.0 # rides his 1.6 Visual scale — the
static var GOLIATH_BEAM_ENERGY := 0.75  # king's throw reads BIG: you see
static var GOLIATH_NOSE := 44.0         # him coming before you hear him
static var FIREWORK_GAP := 0.9      # seconds between bursts
static var FIREWORK_DOUBLE := 0.3   # chance a burst brings a friend
static var FIREWORK_LIGHT := 1.1    # each shell blooms in the dark
static var FIREWORK_COLORS := [Color(1.0, 0.75, 0.2), Color(0.9, 0.3, 0.25),
	Color(0.4, 0.75, 0.95), Color(0.7, 0.95, 0.5), Color(0.95, 0.9, 0.85)]

var _lap_started := false
var _saw_enemies := false
var _fw_timer := 0.0
var _fw_rng := RandomNumberGenerator.new()

func _ready() -> void:
	super()
	_fw_rng.randomize()
	for child in get_children():  # the end screen combat_level just added
		if child.get("win_keeps_rolling") != null:
			child.win_keeps_rolling = true
	# Night game: the authored CanvasModulate gets its tint (code = the knob)
	# and the group marker other systems duck-check (explosion blooms).
	var night := get_node_or_null(^"NightTint")
	if night:
		night.color = NIGHT_TINT
		night.add_to_group(&"night_arena")
	# Headlights: true beam cones (truncated at the lamp line — light never
	# radiates BEHIND the nose), riding each car's Visual so they turn with
	# the 16-step facing. The player's keeps the bowl playable at zero
	# towers; Goliath's warm throw telegraphs his approach.
	_attach_headlights(_player, PLAYER_NOSE, PLAYER_BEAM_LENGTH,
		PLAYER_BEAM_ENERGY, Color(0.85, 0.9, 1.0))
	_attach_headlights(get_node_or_null(^"Enemy1"), GOLIATH_NOSE,
		GOLIATH_BEAM_LENGTH, GOLIATH_BEAM_ENERGY, Color(1.0, 0.9, 0.7))

func _attach_headlights(car: Node, nose: float, length: float,
		energy: float, color: Color) -> void:
	if car == null or not is_instance_valid(car):
		return
	var beam := Deco._make_beam(length, HEADLIGHT_SPREAD, energy, color)
	var visual: Node = car.get_node_or_null(^"Visual")
	if visual:
		# pin the beam's lamp line to the nose (the texture center sits
		# center_ahead px past it)
		beam.position = Vector2(nose + float(beam.get_meta(&"center_ahead")), 0.0)
		visual.add_child(beam)
	else:
		car.add_child(beam)  # bare fixtures: a beam somewhere beats none

func _process(delta: float) -> void:
	super(delta)
	if _lap_started:
		_fw_timer -= delta
		if _fw_timer <= 0.0:
			_fw_timer = FIREWORK_GAP
			_firework()
			if _fw_rng.randf() < FIREWORK_DOUBLE:
				_firework()
		return
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	if not enemies.is_empty():
		_saw_enemies = true
	elif _saw_enemies:
		_start_victory_lap()

func _start_victory_lap() -> void:
	_lap_started = true
	if _player == null or not is_instance_valid(_player) or _player.get_hp() <= 0.0:
		return  # died with the last hit — the lose flow owns the moment
	if _player.has_method(&"set_driver"):
		_player.set_driver(VictoryDriver.new())
	var health := _player.get_node_or_null(^"Health") as Health
	if health:
		health.god = true  # nothing interrupts a victory lap

## One firework over the stands: a launch flash and a colored shellburst at a
## random point on the seating ring.
func _firework() -> void:
	var side := _fw_rng.randi() % 4
	var at := Vector2.ZERO
	match side:
		0:
			at = Vector2(_fw_rng.randf_range(-2000.0, 2000.0), _fw_rng.randf_range(-1750.0, -1250.0))
		1:
			at = Vector2(_fw_rng.randf_range(-2000.0, 2000.0), _fw_rng.randf_range(1250.0, 1750.0))
		2:
			at = Vector2(_fw_rng.randf_range(-2250.0, -1750.0), _fw_rng.randf_range(-1100.0, 1100.0))
		_:
			at = Vector2(_fw_rng.randf_range(1750.0, 2250.0), _fw_rng.randf_range(-1100.0, 1100.0))
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 30
	burst.lifetime = 1.0
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 160.0
	burst.initial_velocity_max = 340.0
	burst.damping_min = 120.0
	burst.damping_max = 220.0
	burst.gravity = Vector2(0, 70)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 3.6
	burst.color = FIREWORK_COLORS[_fw_rng.randi() % FIREWORK_COLORS.size()]
	burst.finished.connect(burst.queue_free)
	add_child(burst)
	burst.global_position = at
	var flash := Deco._make_light(360.0, FIREWORK_LIGHT, burst.color)
	burst.add_child(flash)  # rides the shell, dies with it
	var tw := flash.create_tween()
	tw.tween_property(flash, "energy", 0.0, 0.9)
