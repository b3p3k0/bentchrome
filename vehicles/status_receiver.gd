class_name StatusReceiver
extends Node
## Holds the active status effects on a vehicle. Ticks burn (DoT via the sibling
## Health), aggregates slow into a speed scale, and toggles Health.invulnerable.
## New effect kinds are handled here — one place, not per-special.

@onready var _health: Health = get_parent().get_node_or_null("Health") if get_parent() else null

var _active: Array = []  # each: {kind: StringName, remaining: float, magnitude: float}

func apply(spec: StatusEffectSpec) -> void:
	if spec == null:
		return
	# Bosses keep their trigger fingers: fixed_loadout rigs refuse the disarm.
	if spec.kind == &"disarm" and get_parent() and bool(get_parent().get("fixed_loadout")):
		return
	for e in _active:  # same kind refreshes (longest remaining wins)
		if e.kind == spec.kind:
			e.remaining = maxf(e.remaining, spec.duration)
			e.magnitude = spec.magnitude
			return
	_active.append({"kind": spec.kind, "remaining": spec.duration, "magnitude": spec.magnitude})

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if _active.is_empty():
		return
	var i := _active.size() - 1
	while i >= 0:
		var e = _active[i]
		if e.kind == &"burn" and _health:
			_health.take_damage(e.magnitude * delta * _burn_taken())
		e.remaining -= delta
		if e.remaining <= 0.0:
			_active.remove_at(i)
		i -= 1
	if _health:
		_health.invulnerable = has_effect(&"invuln")

## Control cut (Goliath's jackknife tail / a whiffed ram charge): the Vehicle
## zeroes its driver intent while this holds — physics keeps carrying the car.
func is_stunned() -> bool:
	return has_effect(&"stun")

## Per-car burn vulnerability (VehicleStats.burn_taken — Lovebug's air-cooled
## engine runs hot). Read lazily: stats can land after this node's _ready.
func _burn_taken() -> float:
	var stats: Variant = get_parent().get("stats") if get_parent() else null
	return float(stats.burn_taken) if stats is VehicleStats else 1.0

func speed_scale() -> float:
	var s := 1.0
	for e in _active:
		if e.kind == &"slow":
			s *= e.magnitude
	return s

func has_effect(kind: StringName) -> bool:
	for e in _active:
		if e.kind == kind:
			return true
	return false

## Network-puppet FX injection: a physics-off mirror still shows burn licks.
## Long-duration marker, cleared explicitly by the next snapshot — never ticks
## DoT (puppet StatusReceivers have _physics_process disabled).
func set_cosmetic(kind: StringName, on: bool) -> void:
	if on:
		if not has_effect(kind):
			_active.append({"kind": kind, "remaining": 3600.0, "magnitude": 0.0})
	else:
		clear_kind(kind)

## Removes every effect of one kind (boost blows out a burn, etc.).
func clear_kind(kind: StringName) -> void:
	var i := _active.size() - 1
	while i >= 0:
		if _active[i].kind == kind:
			_active.remove_at(i)
		i -= 1
	if _health:
		_health.invulnerable = has_effect(&"invuln")

func clear() -> void:
	_active.clear()
	if _health:
		_health.invulnerable = false
