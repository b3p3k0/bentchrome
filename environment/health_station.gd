extends Area2D
## Player-only repair bay: a damaged driver is held for a visible refill.
## Limited uses per round with a cooldown between them — dims while cooling,
## goes dark when spent. Enemies roll right over it; no free heals for the mob.
## Overlap is polled (not entry-triggered) so parking on the pad heals as soon
## as the cooldown clears. Any heal puts EVERY station on the level on
## cooldown — no pad-hopping between top-ups.

const READY_TINT := Color.WHITE
const COOLING_TINT := Color(0.45, 0.45, 0.52)
const SPENT_TINT := Color(0.22, 0.22, 0.28)
const TREATMENT_SECONDS := 2.0

@export var uses := 2
@export var cooldown_seconds := 45.0

var _cd := 0.0
var _patient: CharacterBody2D = null
var _patient_health: Health = null
var _start_hp := 0.0
var _treatment_t := 0.0

func _ready() -> void:
	add_to_group(&"health_stations")

## Level-wide lockout: called on every station when any one of them heals.
func start_cooldown() -> void:
	_cd = cooldown_seconds
	if uses > 0:
		modulate = COOLING_TINT

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if _patient != null:
		_tick_treatment(delta)
	if _cd > 0.0:
		_cd -= delta
		if _cd <= 0.0 and uses > 0:
			modulate = READY_TINT
	if _patient != null or _cd > 0.0 or uses <= 0:
		return
	for body in get_overlapping_bodies():
		if try_begin_treatment(body):
			return

## Public for deterministic fixtures and future scripted activations; the same
## eligibility gate remains authoritative for overlap-driven play.
func try_begin_treatment(body: Node) -> bool:
	if _patient != null or _cd > 0.0 or uses <= 0 or body == null \
			or not body.is_in_group(&"player") or not body is CharacterBody2D:
		return false
	var health := body.get_node_or_null(^"Health") as Health
	if health == null or health.hp >= health.max_hp or health.hp <= 0.0:
		return false
	if not body.has_method(&"begin_repair_hold") \
			or not bool(body.call(&"begin_repair_hold", global_position)):
		return false
	_patient = body as CharacterBody2D
	_patient_health = health
	_start_hp = health.hp
	_treatment_t = 0.0
	uses -= 1
	get_tree().call_group(&"health_stations", "start_cooldown")  # reserve every bay now
	modulate = SPENT_TINT if uses <= 0 else COOLING_TINT
	return true

func _tick_treatment(delta: float) -> void:
	if not is_instance_valid(_patient) or not is_instance_valid(_patient_health) \
			or _patient_health.hp <= 0.0:
		_cancel_treatment(false)
		return
	_treatment_t = minf(_treatment_t + delta, TREATMENT_SECONDS)
	var target := lerpf(_start_hp, _patient_health.max_hp,
		_treatment_t / TREATMENT_SECONDS)
	_patient_health.heal(target - _patient_health.hp)
	if _treatment_t >= TREATMENT_SECONDS:
		_patient_health.heal(_patient_health.max_hp - _patient_health.hp)
		_cancel_treatment(true)

func _cancel_treatment(restore_momentum: bool) -> void:
	if is_instance_valid(_patient) and _patient.has_method(&"end_repair_hold"):
		_patient.call(&"end_repair_hold", restore_momentum)
	_patient = null
	_patient_health = null
	_start_hp = 0.0
	_treatment_t = 0.0

func _exit_tree() -> void:
	_cancel_treatment(false)
