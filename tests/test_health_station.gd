extends RefCounted
## Health station: player-only full restore, cooldown between uses, hard use
## cap, no resurrection. Overlap needs real physics frames (the runner awaits
## test methods); the cooldown is fast-forwarded via tick() like the rack tests.

const StationScene := preload("res://environment/health_station.tscn")
const HealthScript := preload("res://vehicles/health.gd")

var t

func _init(runner) -> void:
	t = runner

## A minimal ground-layer body the station can see; faction picks the group.
func _car(container: Node, group: StringName, hp: float) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = 1
	var col := CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = 22.0
	body.add_child(col)
	var health = HealthScript.new()
	health.name = "Health"
	health.max_hp = 100.0
	body.add_child(health)
	body.add_to_group(group)
	container.add_child(body)
	health.hp = hp
	return body

func test_station_lifecycle() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var station = StationScene.instantiate()
	container.add_child(station)
	var enemy := _car(container, &"enemies", 30.0)  # parked on the pad first
	var player := _car(container, &"player", 40.0)
	await t.physics_frame
	await t.physics_frame  # overlap registers on the next physics pass

	var p_health = player.get_node("Health")
	var e_health = enemy.get_node("Health")
	t.check(p_health.hp == 100.0, "station: injured player fully restored")
	t.check(e_health.hp == 30.0, "station: enemies get nothing")
	t.check(station.uses == 1, "station: one use burned")

	p_health.hp = 10.0
	await t.physics_frame
	t.check(p_health.hp == 10.0, "station: cooldown blocks a second heal")

	station.tick(station.cooldown_seconds)  # fast-forward the cooldown
	await t.physics_frame
	await t.physics_frame
	t.check(p_health.hp == 100.0, "station: heals again after cooldown")
	t.check(station.uses == 0, "station: both uses spent")

	station.tick(station.cooldown_seconds)
	p_health.hp = 10.0
	await t.physics_frame
	await t.physics_frame
	t.check(p_health.hp == 10.0, "station: spent pad never heals again")

	p_health.hp = 0.0
	station.uses = 1
	station.tick(station.cooldown_seconds)
	await t.physics_frame
	t.check(p_health.hp == 0.0, "station: no resurrections")

	t.root.remove_child(container)
	container.free()
