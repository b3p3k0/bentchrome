extends Area2D
## Player-only repair pad: drive over it while damaged for a full HP restore.
## Limited uses per round with a cooldown between them — dims while cooling,
## goes dark when spent. Enemies roll right over it; no free heals for the mob.
## Overlap is polled (not entry-triggered) so parking on the pad heals as soon
## as the cooldown clears. Any heal puts EVERY station on the level on
## cooldown — no pad-hopping between top-ups.

const READY_TINT := Color.WHITE
const COOLING_TINT := Color(0.45, 0.45, 0.52)
const SPENT_TINT := Color(0.22, 0.22, 0.28)

@export var uses := 2
@export var cooldown_seconds := 45.0

var _cd := 0.0

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
	if _cd > 0.0:
		_cd -= delta
		if _cd <= 0.0 and uses > 0:
			modulate = READY_TINT
	if _cd > 0.0 or uses <= 0:
		return
	for body in get_overlapping_bodies():
		if not body.is_in_group(&"player"):
			continue
		var health = body.get_node_or_null(^"Health")
		if health == null or health.hp >= health.max_hp or health.hp <= 0.0:
			continue  # full tank or already dead — don't burn a use
		health.hp = health.max_hp
		uses -= 1
		get_tree().call_group(&"health_stations", "start_cooldown")  # all pads offline
		modulate = SPENT_TINT if uses <= 0 else COOLING_TINT
		return
