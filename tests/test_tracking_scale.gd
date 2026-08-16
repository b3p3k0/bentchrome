extends RefCounted
## Garage Improved Lock: the SHOOTER's tracking_scale multiplies lock reach and
## homing turn at every tracking seam — mount waves, taser latch + hold, dash
## lock — while weapon defs keep their authored radii and stock shooters are
## bit-identical. Driven by run_tests.gd.

const MountScript := preload("res://weapons/weapon_mount.gd")
const ControllerScript := preload("res://vehicles/special_controller.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")
const ProjectileScript := preload("res://weapons/projectile.gd")

var t

class TrackShooter extends CharacterBody2D:
	var stats = null  # optionally a VehicleStats carrying tracking_scale
	var heading := 0.0

class PreyCar extends CharacterBody2D:  # CollisionObject2D — _los_clear demands it
	var hp := 100.0
	func get_hp() -> float:
		return hp

func _init(runner) -> void:
	t = runner

func _scaled_stats(scale: float) -> VehicleStats:
	var s := VehicleStats.new()
	s.tracking_scale = scale
	return s

func _prey(pos: Vector2) -> PreyCar:
	var prey := PreyCar.new()
	prey.position = pos
	prey.add_to_group(&"vehicles")
	return prey

## Mount wave: acq 400 / turn 100 vs a target at 600 — stock whiffs the lock
## and keeps the authored turn; a 2.0x shooter latches and steers twice as hard.
func test_mount_wave_scales_lock_and_turn() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var mount = MountScript.new()
	mount.projectile_scene = ProjectileScene
	mount.turn_rate_deg = 100.0
	mount.acquisition_radius = 400.0
	mount.fire_rate = 100.0
	container.add_child(mount)
	var shooter := TrackShooter.new()
	container.add_child(shooter)
	var prey := _prey(Vector2(600, 0))
	container.add_child(prey)
	t.check(mount.try_fire(Vector2.ZERO, Vector2.RIGHT, shooter), "mount: stock shot fires")
	var stock := _last_projectile(container)
	t.check(stock != null and stock.target == null,
		"mount: stock shooter can't lock 600 with a 400 radius")
	t.check(stock != null and is_equal_approx(stock.turn_rate, deg_to_rad(100.0)),
		"mount: stock turn rate is the authored 100 deg/s")
	shooter.stats = _scaled_stats(2.0)
	mount.tick(0.02)  # clear the fire-rate cooldown
	t.check(mount.try_fire(Vector2.ZERO, Vector2.RIGHT, shooter), "mount: scaled shot fires")
	var sharp := _last_projectile(container)
	t.check(sharp != null and sharp.target == prey,
		"mount: 2.0x shooter locks the 600px target")
	t.check(sharp != null and is_equal_approx(sharp.turn_rate, deg_to_rad(200.0)),
		"mount: turn rate doubled for the scaled shooter")
	t.check(is_equal_approx(mount.acquisition_radius, 400.0),
		"mount: the mount's authored radius never mutates")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func _last_projectile(container: Node) -> Node:
	var found: Node = null
	for child in container.get_children():
		if child is ProjectileScript:
			found = child
	return found

## Taser: def radius 400 vs prey at 600 — stock refuses the latch, a 2.0x
## shooter latches; the def's authored radius survives. The held latch then
## honors the scaled base x BEAM_HOLD_FACTOR before breaking.
func test_taser_latch_and_hold_scale() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var def: WeaponDef = load("res://data/weapons/taser.tres")
	var base_radius: float = def.acquisition_radius
	var shooter := TrackShooter.new()
	container.add_child(shooter)
	var ctrl = ControllerScript.new()
	shooter.add_child(ctrl)
	var prey := _prey(Vector2(base_radius * 1.5, 0))
	container.add_child(prey)
	t.check(not ctrl._beam(true, shooter.global_position, Vector2.RIGHT, shooter, def),
		"taser: stock shooter can't latch past the authored radius")
	shooter.stats = _scaled_stats(2.0)
	t.check(ctrl._beam(true, shooter.global_position, Vector2.RIGHT, shooter, def),
		"taser: 2.0x shooter latches at 1.5x the authored radius")
	t.check(is_equal_approx(def.acquisition_radius, base_radius),
		"taser: the def's authored radius never mutates")
	# Hold: scaled base x BEAM_HOLD_FACTOR (2.0) = 4x authored radius.
	prey.position = Vector2(base_radius * 3.5, 0)
	ctrl._beam_tick(0.016)
	t.check(ctrl._beam_t > 0.0, "taser: hold survives inside the scaled break distance")
	prey.position = Vector2(base_radius * 4.5, 0)
	ctrl._beam_tick(0.016)
	t.check(ctrl._beam_t <= 0.0, "taser: hold breaks past the scaled distance")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

## Dash: lock range 700 vs prey at 1000 — stock leaps blind, 2.0x locks on.
func test_dash_lock_scales() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var shooter := TrackShooter.new()
	container.add_child(shooter)
	var ctrl = ControllerScript.new()
	shooter.add_child(ctrl)
	var prey := _prey(Vector2(1000, 0))
	container.add_child(prey)
	ctrl._dash(true, shooter.global_position, Vector2.RIGHT, shooter)
	t.check(ctrl._dash_target == null, "dash: stock leap can't lock past 700")
	ctrl.cancel_dash()
	shooter.stats = _scaled_stats(2.0)
	ctrl._dash(true, shooter.global_position, Vector2.RIGHT, shooter)
	t.check(ctrl._dash_target == prey, "dash: 2.0x shooter locks the 1000px target")
	t.check(is_equal_approx(ControllerScript.DASH_LOCK_RANGE, 700.0),
		"dash: the authored lock constant never mutates")
	ctrl.cancel_dash()
	t.root.remove_child(container)
	container.free()
