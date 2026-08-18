extends Node2D
## Capital thunderstorm choreographer — pure presentation, zero wire state.
## Builds its own StormTint CanvasModulate in _ready (joined to &"night_arena"
## so explosion blooms and headlight beams read against the gloom) and runs
## the strike cycle Kevin ordered: rolling thunder BOOM first (AudioDirector
## &"thunder" — silent no-op until the asset ships), a beat later the
## blinding FLASH, then a DIP below the storm base (eyes readjusting), then
## an eased RECOVER. Distant strikes are sound-only so the storm breathes.
## Cosmetic-local in LAN: each client rolls its own seeded storm — ambience
## may never touch collision, damage, targeting, score, or objectives.
## Pair with a RainSquall node for the slashing rain. Knobs: static vars.

enum Phase { IDLE, LEAD, FLASH, DIP, RECOVER }

static var CADENCE_MIN := 8.0    # seconds between strikes
static var CADENCE_MAX := 20.0
static var THUNDER_LEAD := 0.45  # the boom rolls in, THEN the sky tears open
static var FLASH_SECONDS := 0.12
static var DIP_SECONDS := 0.35
static var RECOVER_SECONDS := 0.9
static var DISTANT_CHANCE := 0.35  # thunder with no flash

static var BASE_TINT := Color(0.56, 0.58, 0.72)   # storm-dark; brighter than stadium night
static var FLASH_TINT := Color(1.55, 1.55, 1.65)  # >1.0 canvas modulate = blinding
static var DIP_TINT := Color(0.3, 0.3, 0.4)       # below base — the readjustment plunge

var phase := Phase.IDLE
var phase_timer := 0.0
var _tint: CanvasModulate
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + 4242
	_tint = CanvasModulate.new()
	_tint.name = "StormTint"
	_tint.color = BASE_TINT
	_tint.add_to_group(&"night_arena")
	add_child(_tint)
	# First strike lands inside half a cadence — the storm announces itself.
	phase_timer = _rng.randf_range(CADENCE_MIN, CADENCE_MAX) * 0.5

func _physics_process(delta: float) -> void:
	tick(delta)

## Public and delta-driven so tests drive the cycle directly (generator idiom).
func tick(delta: float) -> void:
	phase_timer -= delta
	match phase:
		Phase.IDLE:
			if phase_timer <= 0.0:
				_begin_strike()
		Phase.LEAD:
			if phase_timer <= 0.0:
				_set_phase(Phase.FLASH)
		Phase.FLASH:
			if phase_timer <= 0.0:
				_set_phase(Phase.DIP)
		Phase.DIP:
			if phase_timer <= 0.0:
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			if _tint:
				_tint.color = DIP_TINT.lerp(BASE_TINT,
					clampf(1.0 - phase_timer / RECOVER_SECONDS, 0.0, 1.0))
			if phase_timer <= 0.0:
				_set_phase(Phase.IDLE)

func _begin_strike() -> void:
	_boom()
	if _rng.randf() < DISTANT_CHANCE:
		_set_phase(Phase.IDLE)  # a rumble beyond the river — no flash
	else:
		_set_phase(Phase.LEAD)

func _set_phase(p: Phase) -> void:
	phase = p
	match p:
		Phase.IDLE:
			phase_timer = _rng.randf_range(CADENCE_MIN, CADENCE_MAX)
			if _tint:
				_tint.color = BASE_TINT
		Phase.LEAD:
			phase_timer = THUNDER_LEAD
		Phase.FLASH:
			phase_timer = FLASH_SECONDS
			if _tint:
				_tint.color = FLASH_TINT
		Phase.DIP:
			phase_timer = DIP_SECONDS
			if _tint:
				_tint.color = DIP_TINT
		Phase.RECOVER:
			phase_timer = RECOVER_SECONDS

func _boom() -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio and audio.has_method(&"play"):
		audio.play(&"thunder")
