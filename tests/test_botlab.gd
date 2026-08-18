extends RefCounted
## Botlab harness guarantees: the combat governor's shipping defaults survive
## the const->static-var conversion byte-for-byte, the lethal override round-
## trips cleanly (playerless matches CAN end, and only when asked), ram_clamp
## keeps its AI-vs-AI floor at defaults, and the match recorder classifies
## damage kinds / kill attribution off the bc_hit_kind breadcrumbs. Every test
## restores the Combat statics — script statics leak across suites.

const Combat := preload("res://game/combat.gd")
const RecorderScript := preload("res://tools/botlab/match_recorder.gd")

class Stub extends Node:
	var hp_frac := 1.0
	var hp := 100.0
	var max_hp := 100.0
	func get_hp_fraction() -> float:
		return hp_frac
	func get_hp() -> float:
		return hp
	func get_max_hp() -> float:
		return max_hp

## A recorder-facing car: Node2D + Health child + the last_attacker contract.
class StubCar extends Node2D:
	var last_attacker: Node2D = null
	func get_speed() -> float:
		return 0.0

var t

func _init(runner) -> void:
	t = runner

func _combatant(group: StringName) -> Stub:
	var n := Stub.new()
	n.add_to_group(&"vehicles")
	n.add_to_group(group)
	return n

func _car(hp: float) -> StubCar:
	var car := StubCar.new()
	var health := Health.new()
	health.name = "Health"
	health.max_hp = hp
	health.hp = hp
	car.add_child(health)
	return car

func test_governor_defaults_intact() -> void:
	t.check(is_equal_approx(Combat.AI_VS_AI_DAMAGE, 0.35),
		"botlab: shipping AI-vs-AI governor is 0.35")
	t.check(is_equal_approx(Combat.AI_MERCY_HP, 0.10),
		"botlab: shipping mercy floor is 10%")
	var a := _combatant(&"enemies")
	var b := _combatant(&"enemies")
	t.check(is_equal_approx(Combat.scale(a, b), 0.35),
		"botlab: AI-on-AI damage runs the 0.35 theater scale by default")
	b.hp_frac = 0.09
	t.check(Combat.scale(a, b) == 0.0,
		"botlab: a near-dead AI is immune to fellow AI by default")
	a.free()
	b.free()

func test_lethal_override_round_trip() -> void:
	var saved_dmg: float = Combat.AI_VS_AI_DAMAGE
	var saved_mercy: float = Combat.AI_MERCY_HP
	Combat.AI_VS_AI_DAMAGE = 1.0
	Combat.AI_MERCY_HP = 0.0
	var a := _combatant(&"enemies")
	var b := _combatant(&"enemies")
	b.hp_frac = 0.05
	t.check(is_equal_approx(Combat.scale(a, b), 1.0),
		"botlab: lethal mode — full damage even on a near-dead AI")
	t.check(Vehicle.ram_clamp(500.0, a, b) == 500.0,
		"botlab: lethal mode — ram_clamp passes the full hit through")
	Combat.AI_VS_AI_DAMAGE = saved_dmg
	Combat.AI_MERCY_HP = saved_mercy
	t.check(is_equal_approx(Combat.scale(a, b), 0.0),
		"botlab: restore — mercy floor is back after the round trip")
	b.hp_frac = 1.0
	t.check(is_equal_approx(Combat.scale(a, b), 0.35),
		"botlab: restore — theater scale is back after the round trip")
	a.free()
	b.free()

func test_ram_clamp_default_floor() -> void:
	var a := _combatant(&"enemies")
	var b := _combatant(&"enemies")
	b.hp = 50.0
	b.max_hp = 100.0
	var clamped: float = Vehicle.ram_clamp(500.0, a, b)
	t.check(is_equal_approx(clamped, 50.0 - 1.0),
		"botlab: default ram_clamp still floors an AI-vs-AI ram at 1% HP")
	var p := _combatant(&"player")
	t.check(Vehicle.ram_clamp(500.0, p, b) == 500.0,
		"botlab: default ram_clamp never blunts a player-involved ram")
	a.free()
	b.free()
	p.free()

func test_recorder_kind_classification_and_attribution() -> void:
	var rec: Node = RecorderScript.new()
	var victim := _car(100.0)
	var attacker := _car(100.0)
	rec.register_car(victim, "victim", "hornet", "stock")
	rec.register_car(attacker, "attacker", "warpig", "stock")
	var health: Health = victim.get_node("Health")
	# MG hit: breadcrumb + attacker stamp, exactly like projectile.gd does it.
	victim.last_attacker = attacker
	victim.set_meta(&"bc_hit_kind", &"hit_mg")
	health.take_damage(10.0)
	# Ram hit.
	victim.set_meta(&"bc_hit_kind", &"ram")
	health.take_damage(5.0)
	# Unstamped remainder with a live attacker but no burn status -> environment.
	health.take_damage(2.0)
	var d: Dictionary = rec.to_dict()
	var vrow: Dictionary
	var arow: Dictionary
	for row in d.cars:
		if row.label == "victim":
			vrow = row
		else:
			arow = row
	t.check(is_equal_approx(vrow.damage_taken.get("mg", 0.0), 10.0),
		"botlab: recorder buckets the MG breadcrumb")
	t.check(is_equal_approx(vrow.damage_taken.get("ram", 0.0), 5.0),
		"botlab: recorder buckets the ram breadcrumb")
	t.check(is_equal_approx(vrow.damage_taken.get("environment", 0.0), 2.0),
		"botlab: unstamped damage without burn lands as environment")
	t.check(is_equal_approx(arow.damage_dealt.get("mg", 0.0), 10.0),
		"botlab: the attacker is credited with the dealt mirror")
	t.check(arow.vehicle_hits == 1,
		"botlab: only mg/weapon kinds count as accuracy hits")
	t.check(not victim.has_meta(&"bc_hit_kind"),
		"botlab: the breadcrumb is consumed per event")
	# Finishing blow: stamped weapon hit drops hp to 0 -> attributed kill.
	victim.set_meta(&"bc_hit_kind", &"hit_weapon")
	health.take_damage(1000.0)
	d = rec.to_dict()
	for row in d.cars:
		if row.label == "victim":
			vrow = row
		else:
			arow = row
	t.check(vrow.killed_by == "attacker" and vrow.death_cause == "weapon",
		"botlab: kill credit + cause ride the final stamped hit")
	t.check(arow.kills == 1, "botlab: the killer is billed the kill")
	t.check(String(d.first_blood) == "victim", "botlab: first blood recorded")
	victim.free()
	attacker.free()
	rec.free()

func test_recorder_wasteland_and_environment_kill() -> void:
	var rec: Node = RecorderScript.new()
	var victim := _car(100.0)
	rec.register_car(victim, "loner", "ghost", "stock")
	# kill() (pit / deep water): no damaged event, no attacker, no breadcrumb.
	(victim.get_node("Health") as Health).kill()
	var d: Dictionary = rec.to_dict()
	var row: Dictionary = d.cars[0]
	t.check(row.killed_by == "wasteland",
		"botlab: an unattributed death goes to the wasteland")
	t.check(row.death_cause == "environment",
		"botlab: a kill() death is environmental — damaged never fired")
	victim.free()
	rec.free()
