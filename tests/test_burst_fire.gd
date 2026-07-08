extends RefCounted
## Burst waves (rocket volleys): one try_fire = one consume/cooldown but
## bursts × pellets projectiles over time; a dead shooter cancels the tail.
## Pumps real frames (SceneTreeTimers drive the follow-up waves).

const MountScript := preload("res://weapons/weapon_mount.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container  # projectiles spawn here
	var mount = MountScript.new()
	mount.fire_rate = 0.25  # long cooldown — one shot per test
	mount.pellets = 4
	mount.spread_deg = 10.0
	mount.bursts = 3
	mount.burst_interval = 0.1
	mount.projectile_scene = ProjectileScene
	container.add_child(mount)
	var shooter := Node2D.new()
	container.add_child(shooter)
	return {"container": container, "mount": mount, "shooter": shooter}

func _done(f: Dictionary) -> void:
	t.current_scene = null
	t.root.remove_child(f.container)
	f.container.free()

func _shots(container: Node) -> int:
	var n := 0
	for c in container.get_children():
		if c is Projectile:
			n += 1
	return n

func test_burst_fires_waves_over_time() -> void:
	var f := _fixture()
	t.check(f.mount.try_fire(Vector2.ZERO, Vector2.RIGHT, f.shooter), "burst: shot leaves the mount")
	t.check(not f.mount.try_fire(Vector2.ZERO, Vector2.RIGHT, f.shooter),
		"burst: one cooldown covers the whole volley")
	t.check(_shots(f.container) == 4, "burst: wave 1 fires immediately (got %d)" % _shots(f.container))
	for i in 30:  # 0.5s — both follow-up waves land
		await t.physics_frame
	t.check(_shots(f.container) == 12, "burst: 3 waves x 4 rockets (got %d)" % _shots(f.container))
	_done(f)

func test_burst_dies_with_the_shooter() -> void:
	var f := _fixture()
	f.mount.try_fire(Vector2.ZERO, Vector2.RIGHT, f.shooter)
	f.container.remove_child(f.shooter)
	f.shooter.free()
	for i in 30:
		await t.physics_frame
	t.check(_shots(f.container) == 4, "burst: dead shooter takes the volley with them (got %d)" % _shots(f.container))
	_done(f)

func test_single_burst_unchanged() -> void:
	var f := _fixture()
	f.mount.bursts = 1
	f.mount.try_fire(Vector2.ZERO, Vector2.RIGHT, f.shooter)
	for i in 20:
		await t.physics_frame
	t.check(_shots(f.container) == 4, "burst: bursts=1 is the classic instant fan (got %d)" % _shots(f.container))
	_done(f)
