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
			_health.take_damage(e.magnitude * delta)
		e.remaining -= delta
		if e.remaining <= 0.0:
			_active.remove_at(i)
		i -= 1
	if _health:
		_health.invulnerable = _has(&"invuln")

func speed_scale() -> float:
	var s := 1.0
	for e in _active:
		if e.kind == &"slow":
			s *= e.magnitude
	return s

func _has(kind: StringName) -> bool:
	for e in _active:
		if e.kind == kind:
			return true
	return false

func clear() -> void:
	_active.clear()
	if _health:
		_health.invulnerable = false
