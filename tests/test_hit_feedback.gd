extends RefCounted
## Meaningful vehicle hits expose the trigger synchronously. Projectile-side
## code stays duck-typed but must stamp attribution before Health emits damaged.

const VehicleScene := preload("res://vehicles/enemy_vehicle.tscn")
const ProjectileScene := preload("res://weapons/projectile.tscn")
const NetEvents := preload("res://game/net/net_events.gd")

var t

func _init(runner) -> void:
	t = runner

func _vehicle() -> Vehicle:
	var v: Vehicle = VehicleScene.instantiate()
	t.root.add_child(v)
	return v

func _done(v: Vehicle) -> void:
	t.root.remove_child(v)
	v.free()

func test_meaningful_threshold_and_ram_attribution() -> void:
	NetEvents.reset()
	var victim := _vehicle()
	var attacker := Node2D.new()
	t.root.add_child(attacker)
	var hits: Array = []
	victim.combat_hit.connect(func(source: Node2D) -> void: hits.append(source))
	victim.take_ram_damage(0.5, attacker)
	t.check(hits.is_empty(), "hit feedback: sub-1 damage stays quiet")
	victim.take_ram_damage(2.0, attacker)
	t.check(hits == [attacker], "hit feedback: meaningful ram carries attacker")
	t.root.remove_child(attacker)
	attacker.free()
	_done(victim)

func test_projectile_stamps_before_damage_signal() -> void:
	NetEvents.reset()
	var victim := _vehicle()
	var attacker := Node2D.new()
	attacker.add_to_group(&"player")
	t.root.add_child(attacker)
	var seen: Array = []
	victim.combat_hit.connect(func(source: Node2D) -> void: seen.append(source))
	var shot = ProjectileScene.instantiate()
	t.root.add_child(shot)
	shot.setup(victim.global_position, Vector2.RIGHT, 100.0, 2.0, 1.0, attacker)
	shot._on_body_entered(victim)
	t.check(seen == [attacker], "hit feedback: projectile trigger is visible inside damaged signal")
	t.check(victim.last_attacker == attacker, "hit feedback: projectile stamps the victim")
	if is_instance_valid(shot):
		t.root.remove_child(shot)
		shot.free()
	t.root.remove_child(attacker)
	attacker.free()
	_done(victim)

func test_host_event_tap_is_dormant_then_queues_pair() -> void:
	NetEvents.reset()
	var victim := _vehicle()
	var attacker := Node2D.new()
	t.root.add_child(attacker)
	victim.take_ram_damage(2.0, attacker)
	t.check(NetEvents.queue.is_empty(), "hit feedback: SP leaves network tap dormant")
	NetEvents.armed = true
	victim.take_ram_damage(2.0, attacker)
	t.check(NetEvents.queue.size() == 1 and NetEvents.queue[0].attacker == attacker
		and NetEvents.queue[0].victim == victim, "hit feedback: host queues attacker/victim refs")
	NetEvents.reset()
	t.root.remove_child(attacker)
	attacker.free()
	_done(victim)
