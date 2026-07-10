extends RefCounted
## The living breach turret: tracks the player-group target with a traverse
## clamp (aim lag is the dodge), fires its def's shot when aligned + in range
## + LoS-clear, self-gates on cooldown, and holds still when nobody's in
## range. Uses the mount fixture pattern (t.current_scene container).

const TurretScript := preload("res://weapons/turret.gd")
const MissileScene := preload("res://weapons/missile.tscn")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func _def() -> WeaponDef:
	var d := WeaponDef.new()
	d.display_name = "Test Breach"
	d.cooldown = 2.8
	d.damage = 45.0
	d.projectile_speed = 1400.0
	d.projectile_lifetime = 3.0
	d.projectile_scene = MissileScene
	return d

func _fixture(player_at: Vector2) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var body := CharacterBody2D.new()  # the fake hull the turret rides
	container.add_child(body)
	var visual := Node2D.new()
	visual.name = "Visual"
	body.add_child(visual)
	var turret = TurretScript.new()
	visual.add_child(turret)
	turret.set_weapon(_def())
	var player = VehicleScene.instantiate()  # real car: joins "player" group
	player.position = player_at
	container.add_child(player)
	return {"container": container, "turret": turret, "player": player}

func _done(f: Dictionary) -> void:
	t.current_scene = null
	t.root.remove_child(f.container)
	f.container.free()

func _shots(f: Dictionary) -> int:
	var n := 0
	for child in f.container.get_children():
		if child is Projectile:
			n += 1
	return n

func test_fires_at_aligned_target_then_cools() -> void:
	var f := _fixture(Vector2(600, 0))  # dead ahead of the +x barrel
	for i in 4:
		await t.physics_frame
	t.check(_shots(f) == 1, "turret: one shot at the aligned target (got %d)" % _shots(f))
	t.check(f.turret._cooldown > 2.0, "turret: cooldown armed after the shot")
	for i in 4:
		await t.physics_frame
	t.check(_shots(f) == 1, "turret: cooldown holds the second shot")
	var p: Node = null
	for child in f.container.get_children():
		if child is Projectile:
			p = child
	t.check(p != null and is_equal_approx(p.damage, 45.0), "turret: power-class damage rides the shot")
	_done(f)

func test_traverse_clamps_the_slew() -> void:
	var f := _fixture(Vector2(0, 600))  # 90 degrees off the barrel
	var before: float = f.turret.global_rotation
	await t.physics_frame
	await t.physics_frame
	var moved: float = absf(f.turret.global_rotation - before)
	var max_step: float = TurretScript.TRAVERSE * (2.5 / 60.0)  # 2 ticks + slack
	t.check(moved > 0.0, "turret: slews toward the target")
	t.check(moved <= max_step, "turret: slew respects TRAVERSE (moved %.3f)" % moved)
	t.check(_shots(f) == 0, "turret: holds fire while off-aim")
	_done(f)

func test_out_of_range_stays_quiet() -> void:
	var f := _fixture(Vector2(2000, 0))  # past RANGE
	var before: float = f.turret.global_rotation
	for i in 4:
		await t.physics_frame
	t.check(_shots(f) == 0, "turret: no shots past RANGE")
	t.check(is_equal_approx(f.turret.global_rotation, before), "turret: no tracking past RANGE")
	_done(f)

## Goliath's trailer mounts: shooter_path credits the cab, los_exclude_paths
## keeps the rig's own plating out of the LoS ray, and the projectile's
## part_of pass-through lets the shot sail over the trailer into the target.
func test_trailer_mount_shoots_for_its_cab() -> void:
	var f := _fixture(Vector2(600, 0))
	var cab := CharacterBody2D.new()  # the vehicle this mount shoots FOR
	f.container.add_child(cab)
	var part := StaticBody2D.new()    # the rig's own plating, mid-flight-path
	part.collision_layer = 4 | 8
	part.position = Vector2(250, 0)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 240)
	col.shape = shape
	part.add_child(col)
	f.container.add_child(part)
	part.set_meta(&"part_of", cab.get_path())
	f.turret.shooter_path = f.turret.get_path_to(cab)
	var excludes: Array[NodePath] = [f.turret.get_path_to(part)]
	f.turret.los_exclude_paths = excludes
	var health = f.player.get_node("Health")
	var hp_before: float = health.hp
	for i in 4:
		await t.physics_frame
	t.check(_shots(f) == 1, "trailer mount: own plating never denies the shot (got %d)" % _shots(f))
	for i in 36:  # let the round cross the plating and reach the target
		await t.physics_frame
	t.check(health.hp < hp_before, "trailer mount: the shot passed through and landed")
	t.check(f.player.last_attacker == cab, "trailer mount: the CAB gets the credit")
	_done(f)

func test_cover_denies_the_shot() -> void:
	var f := _fixture(Vector2(600, 0))
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = Vector2(300, 0)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 240)
	col.shape = shape
	wall.add_child(col)
	f.container.add_child(wall)
	for i in 4:
		await t.physics_frame
	t.check(_shots(f) == 0, "turret: cover between barrel and target denies the shot")
	_done(f)
