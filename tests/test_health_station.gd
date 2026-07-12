extends RefCounted
## Health station: two-second repair hold, composable immunity, exact momentum
## return, level-wide cooldown, and unchanged eligibility rules.

const StationScene := preload("res://environment/health_station.tscn")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func _car(container: Node, faction: StringName, hp: float) -> Vehicle:
	var body := VehicleScene.instantiate() as Vehicle
	body.faction = faction
	container.add_child(body)
	var health := body.get_node(^"Health") as Health
	health.max_hp = 100.0
	health.hp = hp
	return body

func test_station_lifecycle() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var station := StationScene.instantiate()
	container.add_child(station)
	var player := _car(container, &"player", 40.0)
	var p_health := player.get_node(^"Health") as Health
	player.global_position = Vector2(90, 40)
	player.velocity = Vector2(-180, 75)
	player.heading = 1.2
	var layer := player.collision_layer
	var mask := player.collision_mask
	t.check(station.try_begin_treatment(player), "station: damaged player starts treatment")
	t.check(player.global_position == station.global_position and player.velocity == Vector2.ZERO,
		"station: player snaps to center and pins")
	t.check(player.is_repairing() and player.collision_layer == layer and player.collision_mask == mask,
		"station: pinned player stays solid")
	p_health.take_damage(50.0)
	t.check(p_health.hp == 40.0, "station: repair hold is damage immune")
	player.apply_impact(Vector2.LEFT * 20.0, 20.0, 900.0, 1.0, 1.0)
	t.check(player.velocity == Vector2.ZERO and is_equal_approx(player.heading, 1.2),
		"station: heavyweight impacts cannot move or spin the pin")

	station.tick(1.0)
	t.check(is_equal_approx(p_health.hp, 70.0) and player.is_repairing(),
		"station: health sweeps linearly at the halfway point")
	station.tick(0.99)
	t.check(p_health.hp < 100.0 and player.is_repairing(),
		"station: repair is never instant or early")
	station.tick(0.01)
	t.check(is_equal_approx(p_health.hp, 100.0) and not player.is_repairing(),
		"station: two seconds lands exactly on full health")
	t.check(player.velocity == Vector2(-180, 75) and is_equal_approx(player.heading, 1.2),
		"station: complete world velocity and facing resume")
	t.check(station.uses == 1, "station: one use burned")

	p_health.hp = 10.0
	t.check(not station.try_begin_treatment(player), "station: cooldown blocks a second heal")

	station.tick(station.cooldown_seconds)  # fast-forward the cooldown
	t.check(station.try_begin_treatment(player), "station: ready again after cooldown")
	station.tick(2.0)
	t.check(p_health.hp == 100.0, "station: second treatment completes")
	t.check(station.uses == 0, "station: both uses spent")

	station.tick(station.cooldown_seconds)
	p_health.hp = 10.0
	t.check(not station.try_begin_treatment(player) and p_health.hp == 10.0,
		"station: spent pad never heals again")

	p_health.hp = 0.0
	station.uses = 1
	station.tick(station.cooldown_seconds)
	t.check(not station.try_begin_treatment(player) and p_health.hp == 0.0,
		"station: no resurrections")

	t.root.remove_child(container)
	container.free()

## One heal locks out EVERY station on the level for the full cooldown.
func test_any_heal_locks_all_stations() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var near = StationScene.instantiate()
	container.add_child(near)
	var far = StationScene.instantiate()
	far.position = Vector2(2000, 0)  # nowhere near the player
	container.add_child(far)
	var player := _car(container, &"player", 40.0)
	t.check(near.try_begin_treatment(player), "lockout: near station reserves the player")
	t.check(near.uses == 1 and far.uses == 2, "lockout: only the healer burned a use")
	t.check(not far.try_begin_treatment(player), "lockout: every other station goes offline immediately")
	near.tick(2.0)
	var health := player.get_node(^"Health") as Health
	health.hp = 10.0
	far.tick(far.cooldown_seconds)  # fast-forward its cooldown
	t.check(far.try_begin_treatment(player), "lockout: far station recovers after cooldown")
	far.tick(2.0)
	t.check(health.hp == 100.0, "lockout: recovered station completes treatment")

	t.root.remove_child(container)
	container.free()

func test_eligibility_immunity_and_cleanup() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var station := StationScene.instantiate()
	container.add_child(station)
	var enemy := _car(container, &"enemies", 30.0)
	var player := _car(container, &"player", 100.0)
	t.check(not station.try_begin_treatment(enemy), "station: enemies receive no repair")
	t.check(not station.try_begin_treatment(player), "station: full health does not burn a use")
	player.get_node(^"Health").hp = 50.0
	player.height = 10.0
	t.check(not station.try_begin_treatment(player), "station: airborne cars cannot dock")
	player.height = 0.0
	var health := player.get_node(^"Health") as Health
	health.invulnerable = true
	t.check(station.try_begin_treatment(player), "station: status-shielded car can still repair")
	station.tick(2.0)
	health.take_damage(10.0)
	t.check(health.hp == 100.0, "station: releasing its hold preserves status immunity")
	health.invulnerable = false
	health.take_damage(10.0)
	t.check(health.hp == 90.0, "station: repair immunity clears after release")

	# Removal is a cancellation: no stale immunity and no stored launch velocity.
	health.hp = 50.0
	player.velocity = Vector2(250, 0)
	station.tick(station.cooldown_seconds)
	t.check(station.try_begin_treatment(player), "station: cleanup fixture begins treatment")
	container.remove_child(station)
	station.free()
	t.check(not player.is_repairing() and player.velocity == Vector2.ZERO,
		"station: removal safely cancels without launching the patient")
	health.take_damage(10.0)
	t.check(health.hp == 40.0, "station: cancellation releases its immunity hold")

	t.root.remove_child(container)
	container.free()
