extends RefCounted
## The Spawner projectile pool: spent shots bank for reuse instead of
## queue_free churn. Unit tests drive a private pool instance directly;
## integration tests go through the REAL /root/Spawner — autoloads ARE
## instantiated in -s test runs (the [sfx] boot line is AudioDirector), so the
## mount/projectile lookup paths hit the genuine autoload here.

const SpawnerScript := preload("res://game/spawner.gd")
const MountScript := preload("res://weapons/weapon_mount.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture(with_pool := true) -> Dictionary:
	var f := {}
	if with_pool:
		var pool = SpawnerScript.new()
		pool.name = "PoolUnderTest"  # NOT "Spawner" — the real autoload owns that
		t.root.add_child(pool)
		f["pool"] = pool
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	f["container"] = container
	return f

func _done(f: Dictionary) -> void:
	t.current_scene = null
	t.root.remove_child(f.container)
	f.container.free()
	if f.has("pool"):
		t.root.remove_child(f.pool)  # _exit_tree drains it
		f.pool.free()
	SpawnerScript.pool_enabled = true
	SpawnerScript.pool_cap = 48

func _autoload() -> Node:
	return t.root.get_node_or_null(^"/root/Spawner")

func _shots(container: Node) -> int:
	var n := 0
	for c in container.get_children():
		if c is Projectile:
			n += 1
	return n

func test_release_banks_and_acquire_reuses() -> void:
	var f := _fixture()
	var p = f.pool.acquire(ProjectileScene)
	t.check(p is Projectile, "pool: acquire instantiates the scene")
	f.container.add_child(p)
	f.pool.release(p)
	for i in 3:
		await t.physics_frame
	t.check(f.pool.idle_count(ProjectileScene) == 1, "pool: released shot banks")
	t.check(p.get_parent() == null, "pool: banked shot leaves the tree")
	var again = f.pool.acquire(ProjectileScene)
	t.check(again == p, "pool: acquire returns the banked instance")
	t.check(f.pool.idle_count(ProjectileScene) == 0, "pool: reuse drains the bank")
	again.free()
	_done(f)

func test_reset_sheds_per_fire_stamps() -> void:
	var f := _fixture()
	var p = f.pool.acquire(ProjectileScene)
	f.container.add_child(p)
	p.collision_mask = 2 | 16          # pretend floor-stamped pierce shot
	p.modulate = Color.RED
	p.on_hit_effects = [RefCounted.new()]
	p.hit_sfx = &"hit_mg"
	p.setup(Vector2.ZERO, Vector2.RIGHT, 100.0, 5.0, 9.0, f.container)
	f.pool.release(p)
	for i in 3:
		await t.physics_frame
	var again = f.pool.acquire(ProjectileScene)
	t.check(again.collision_mask == 7, "pool: mask restored to the authored 7")
	t.check(again.modulate == Color.WHITE, "pool: tint restored")
	t.check(again.on_hit_effects.is_empty(), "pool: on-hit effects cleared")
	t.check(again.shooter == null, "pool: shooter reference dropped")
	t.check(again.hit_sfx == &"hit_weapon", "pool: hit sfx restored")
	again.free()
	_done(f)

func test_cap_evicts_overflow() -> void:
	var f := _fixture()
	SpawnerScript.pool_cap = 2
	for i in 3:
		var p = f.pool.acquire(ProjectileScene)
		f.container.add_child(p)
		f.pool.release(p)
	for i in 3:
		await t.physics_frame
	t.check(f.pool.idle_count(ProjectileScene) == 2, "pool: cap evicts the overflow")
	_done(f)

func test_double_release_banks_once() -> void:
	var f := _fixture()
	var p = f.pool.acquire(ProjectileScene)
	f.container.add_child(p)
	f.pool.release(p)
	f.pool.release(p)
	for i in 3:
		await t.physics_frame
	t.check(f.pool.idle_count(ProjectileScene) == 1,
		"pool: double release never aliases (got %d)" % f.pool.idle_count(ProjectileScene))
	_done(f)

func test_mount_fires_pooled_and_expiry_rebanks() -> void:
	var auto := _autoload()
	t.check(auto != null, "pool: Spawner autoload present in test runs")
	if auto == null:
		return
	auto.clear()  # earlier suites' expired shots may already be banked
	var f := _fixture(false)
	var mount = MountScript.new()
	mount.fire_rate = 12.0
	mount.projectile_scene = ProjectileScene
	mount.projectile_lifetime = 0.05
	mount.pierces_cover = true          # per-fire mask stamp exercises the reset
	f.container.add_child(mount)
	var shooter := Node2D.new()
	f.container.add_child(shooter)
	t.check(mount.try_fire(Vector2.ZERO, Vector2.RIGHT, shooter), "pool: mount fires")
	var first: Node = null
	for c in f.container.get_children():
		if c is Projectile:
			first = c
	t.check(first != null and first.collision_mask == (3 | (1 << 9)),
		"pool: pierce stamp plus soft-target mask applied on fire")
	var flashes := 0
	for c in f.container.get_children():
		var script = c.get_script()
		if script and script.resource_path.ends_with("muzzle_flash.gd"):
			flashes += 1
	t.check(flashes == 1, "pool: one muzzle flash per wave")
	for i in 12:
		await t.physics_frame
	var flashes_after := 0
	for c in f.container.get_children():
		var script = c.get_script()
		if script and script.resource_path.ends_with("muzzle_flash.gd"):
			flashes_after += 1
	t.check(flashes_after == 0, "pool: the flash banks itself")
	t.check(_shots(f.container) == 0, "pool: expired shot leaves the scene")
	t.check(auto.idle_count(ProjectileScene) == 1, "pool: expired shot banks in the autoload")
	t.check(mount.try_fire(Vector2.ZERO, Vector2.RIGHT, shooter), "pool: second shot fires")
	t.check(auto.idle_count(ProjectileScene) == 0, "pool: second shot reuses the bank")
	var second: Node = null
	for c in f.container.get_children():
		if c is Projectile:
			second = c
	t.check(second == first, "pool: same instance flies twice")
	t.check(second != null and second.collision_mask == (3 | (1 << 9)),
		"pool: reused shot re-stamped, not stale")
	for i in 12:
		await t.physics_frame  # let the reused shot expire before teardown
	auto.clear()
	_done(f)

func test_pool_disabled_falls_back_to_queue_free() -> void:
	var auto := _autoload()
	if auto == null:
		return
	auto.clear()
	SpawnerScript.pool_enabled = false
	var f := _fixture(false)
	var p = ProjectileScene.instantiate()
	f.container.add_child(p)
	p.setup(Vector2.ZERO, Vector2.RIGHT, 100.0, 1.0, 0.05, f.container)
	for i in 12:
		await t.physics_frame
	t.check(_shots(f.container) == 0, "pool: disabled -> shot leaves the scene")
	t.check(auto.idle_count(ProjectileScene) == 0, "pool: disabled -> nothing banks")
	t.check(not is_instance_valid(p), "pool: disabled -> classic queue_free")
	_done(f)
