extends "res://levels/combat_level.gd"
## The Coliseum's shell: stock combat_level plus THE ENDING — when the king
## falls, the world does not freeze. The end screen shows its card unpaused
## (win_keeps_rolling), the player's car is handed to the victory-lap driver
## and parades the ring god-moded, and fireworks pop over the stands until
## a button is pressed. The lose path is untouched.

const VictoryDriver := preload("res://vehicles/goliath/victory_lap_driver.gd")

static var FIREWORK_GAP := 0.9      # seconds between bursts
static var FIREWORK_DOUBLE := 0.3   # chance a burst brings a friend
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
