extends RefCounted
## MG overheat tests on WeaponMount: heat per real shot, lockout at max,
## resume threshold, cooling, and heat disabled when heat_per_shot is 0.
## Shots are real try_fire calls (projectiles spawn into a throwaway
## current_scene); cooling is driven manually via tick().

const MountScript := preload("res://weapons/weapon_mount.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture(heat_per_shot: float) -> Dictionary:
	var container := Node2D.new()
	var mount = MountScript.new()
	mount.heat_per_shot = heat_per_shot
	mount.heat_max = 100.0
	mount.cool_per_sec = 0.0        # tests own cooling explicitly
	mount.fire_rate = 100.0         # cooldown 0.01s between shots
	mount.projectile_scene = ProjectileScene
	var shooter := Node2D.new()
	container.add_child(mount)
	container.add_child(shooter)
	t.root.add_child(container)
	mount.set_physics_process(false)  # tests own time via tick()
	t.current_scene = container       # try_fire spawns projectiles here
	return {"container": container, "mount": mount, "shooter": shooter}

func _done(f: Dictionary) -> void:
	t.current_scene = null
	t.root.remove_child(f.container)
	f.container.free()

func _shots(f: Dictionary, n: int) -> int:
	var fired := 0
	for i in n:
		if f.mount.try_fire(Vector2.ZERO, Vector2.RIGHT, f.shooter):
			fired += 1
		f.mount.tick(0.01)  # clear the fire-rate cooldown (cool_per_sec is 0)
	return fired

func test_heat_accumulates_and_locks() -> void:
	var f := _fixture(25.0)
	t.check(_shots(f, 3) == 3, "heat: first three shots fire")
	t.check_approx(f.mount.heat, 75.0, "heat: 25 per shot")
	t.check(not f.mount.is_locked(), "heat: not locked below max")
	t.check(_shots(f, 1) == 1, "heat: fourth shot fires")
	t.check_approx(f.mount.heat, 100.0, "heat: capped at max")
	t.check(f.mount.is_locked(), "heat: locked at max")
	t.check(_shots(f, 1) == 0, "heat: locked mount refuses to fire")
	_done(f)

func test_lock_holds_until_resume_threshold() -> void:
	var f := _fixture(25.0)
	_shots(f, 4)  # heat 100, locked
	f.mount.cool_per_sec = 50.0
	f.mount.tick(1.0)  # heat 50 — above resume (35)
	t.check(f.mount.is_locked(), "resume: still locked above threshold")
	t.check(_shots(f, 1) == 0, "resume: still refuses to fire")
	f.mount.cool_per_sec = 50.0  # _shots ticked 0.01 → heat 49.5
	f.mount.tick(0.3)  # heat 34.5 — below resume
	t.check(not f.mount.is_locked(), "resume: unlocked below threshold")
	t.check(_shots(f, 1) == 1, "resume: fires again after recovery")
	f.mount.tick(10.0)
	t.check_approx(f.mount.heat, 0.0, "resume: cools all the way to zero")
	_done(f)

func test_heat_disabled_when_zero_per_shot() -> void:
	var f := _fixture(0.0)
	t.check(_shots(f, 5) == 5, "disabled: fires freely")
	t.check_approx(f.mount.heat, 0.0, "disabled: no heat accrues")
	t.check(not f.mount.is_locked(), "disabled: never locks")
	_done(f)

func test_heat_fraction() -> void:
	var f := _fixture(25.0)
	_shots(f, 2)
	t.check_approx(f.mount.heat_fraction(), 0.5, "fraction: half at 50/100")
	_done(f)
