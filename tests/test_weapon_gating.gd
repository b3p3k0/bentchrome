extends RefCounted
## Weapon floor gating. Straight shots fly with the shooter's floor mask (they
## physically cannot signal a cross-floor car); tracking shots fly boundary-
## only and reach every terrace; legacy shooters keep the classic mask 7;
## contact specials filter targets to the shooter's floor; a mine only arms
## for its own terrace.

const MountScript := preload("res://weapons/weapon_mount.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")
const MineScene := preload("res://environment/mine_land.tscn")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const FloorZoneScene := preload("res://environment/floor_zone.tscn")

class FloorNode extends Node2D:
	var floor_index := -1

var t

func _init(runner) -> void:
	t = runner

func _mount_fixture(shooter_floor: int, tracking: bool, pierce := false) -> Dictionary:
	var container := Node2D.new()
	var mount = MountScript.new()
	mount.fire_rate = 100.0
	mount.projectile_scene = ProjectileScene
	if tracking:
		mount.turn_rate_deg = 200.0
		mount.acquisition_radius = 900.0
	mount.pierces_cover = pierce
	var shooter := FloorNode.new()
	shooter.floor_index = shooter_floor
	container.add_child(mount)
	container.add_child(shooter)
	t.root.add_child(container)
	t.current_scene = container  # try_fire spawns projectiles here
	return {"container": container, "mount": mount, "shooter": shooter}

func _done(f: Dictionary) -> void:
	t.current_scene = null
	t.root.remove_child(f.container)
	f.container.free()

func _fired_mask(f: Dictionary) -> int:
	t.check(f.mount.try_fire(Vector2.ZERO, Vector2.RIGHT, f.shooter), "gating: shot leaves the mount")
	var last: Node = f.container.get_child(f.container.get_child_count() - 1)
	return int(last.collision_mask)

func test_straight_shot_masks_to_own_floor() -> void:
	var f := _mount_fixture(2, false)
	t.check(_fired_mask(f) == (2 | 16), "gating: floor-2 straight shot = wall + floor bit only")
	_done(f)

func test_tracking_shot_arcs_over_floors() -> void:
	var f := _mount_fixture(3, true)
	t.check(_fired_mask(f) == (1 | 2), "gating: tracking shot flies boundary-only, hits any floor")
	_done(f)

func test_legacy_shooter_keeps_classic_masks() -> void:
	var f := _mount_fixture(-1, false)
	t.check(_fired_mask(f) == 7, "gating: legacy straight shot keeps mask 7")
	_done(f)
	var fp := _mount_fixture(-1, true, true)
	t.check(_fired_mask(fp) == 3, "gating: legacy pierces_cover still drops only the obstacle bit")
	_done(fp)

func test_targeting_same_floor_filter() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var me := FloorNode.new()
	me.floor_index = 2
	var near_roof := FloorNode.new()
	near_roof.floor_index = 3
	near_roof.position = Vector2(100, 0)
	near_roof.add_to_group(&"vehicles")
	var far_same := FloorNode.new()
	far_same.floor_index = 2
	far_same.position = Vector2(400, 0)
	far_same.add_to_group(&"vehicles")
	container.add_child(me)
	container.add_child(near_roof)
	container.add_child(far_same)
	var open: Node2D = Targeting.nearest_other(Vector2.ZERO, me, 1000.0)
	t.check(open == near_roof, "gating: floor-blind query still picks the nearest")
	var gated: Node2D = Targeting.nearest_other(Vector2.ZERO, me, 1000.0, me)
	t.check(gated == far_same, "gating: same-floor query skips the closer roof car")
	t.root.remove_child(container)
	container.free()

func test_mine_ignores_cross_floor_wheels() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var zone = FloorZoneScene.instantiate()
	zone.floor_index = 3
	zone.size = Vector2(600, 600)
	container.add_child(zone)
	var mine = MineScene.instantiate()
	mine.floor_index = 2  # dropped by a dock car before the roof grew wheels
	container.add_child(mine)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # (0,0) — on the mine, but on the roof terrace
	for i in 90:  # past ARM_DELAY (1s) with margin
		await t.physics_frame
	t.check(is_instance_valid(mine), "gating: floor-2 mine ignores the floor-3 car")
	var health = car.get_node("Health")
	t.check(health.hp >= health.max_hp, "gating: cross-floor car takes no mine damage")
	t.root.remove_child(container)
	container.free()
