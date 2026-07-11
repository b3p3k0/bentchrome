extends RefCounted
## Vehicle puppet mode: the client-side mirror. Locks the contract — puppets
## never simulate (no collision, no subsystem ticks, driver ignored), they
## interpolate streamed samples, hp lands without damage side-effects, and
## flags drive the existing cosmetics. Fixtures use enemy_vehicle.tscn
## (faction enemies — player-group shadowing is the classic trap).

const VehicleScene := preload("res://vehicles/enemy_vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func _spawn() -> Vehicle:
	var v: Vehicle = VehicleScene.instantiate()
	t.root.add_child(v)
	return v

func _free(v: Vehicle) -> void:
	t.root.remove_child(v)
	v.free()

func test_puppet_toggles_sim_off() -> void:
	var v := _spawn()
	v.set_net_puppet(true)
	t.check(v.collision_layer == 0 and v.collision_mask == 0,
		"puppet: visual-only — collision zeroed")
	t.check(not v.get_node("Status").is_physics_processing(),
		"puppet: status DoT stops ticking locally")
	t.check(not v.get_node("WeaponRack").is_physics_processing(),
		"puppet: ammo recharge stops ticking locally")
	t.check(not v.get_node("MachineGunMount").is_physics_processing(),
		"puppet: mount heat stops ticking locally")
	v.set_net_puppet(false)
	# The restore rides _apply_ground_collision's set_deferred (mask changes
	# never land mid-physics) — give it the frame it needs.
	await t.process_frame
	t.check(v.collision_layer != 0, "puppet: switching back restores collision")
	t.check(v.get_node("Status").is_physics_processing(),
		"puppet: switching back restores subsystem ticks")
	_free(v)

func test_puppet_ignores_local_sim() -> void:
	var v := _spawn()
	v.set_net_puppet(true)
	v.global_position = Vector2(500, 500)
	v.velocity = Vector2(400, 0)  # a sim tick would move it; a puppet must not
	v._physics_process(1.0 / 60.0)
	t.check(v.global_position == Vector2(500, 500),
		"puppet: no snapshots, no movement — the driver and physics are ignored")
	_free(v)

func test_puppet_interpolates() -> void:
	var v := _spawn()
	v.set_net_puppet(true)
	var now := Time.get_ticks_msec()
	v.apply_net_state({"t": now - 150, "pos": Vector2.ZERO, "vel": Vector2(600, 0),
		"heading": 0.0, "height": 0.0})
	v.apply_net_state({"t": now - 50, "pos": Vector2(100, 0), "vel": Vector2(600, 0),
		"heading": 0.0, "height": 0.0})
	v._physics_process(1.0 / 60.0)
	t.check(v.global_position.x >= 95.0 and v.global_position.x <= 130.0,
		"puppet: renders at now-minus-delay between the two samples")
	t.check(absf(v.global_position.y) < 0.01, "puppet: off-axis stays put")
	_free(v)

func test_puppet_single_sample_snaps() -> void:
	var v := _spawn()
	v.set_net_puppet(true)
	v.apply_net_state({"pos": Vector2(7, 7), "heading": 0.3, "height": 60.0})
	v._physics_process(1.0 / 60.0)
	t.check(v.global_position == Vector2(7, 7), "puppet: first sample snaps")
	var visual: Node2D = v.get_node("Visual")
	t.check(is_equal_approx(visual.rotation, snappedf(0.3, TAU / 16.0)),
		"puppet: visual heading rides the 16-step grid")
	t.check(is_equal_approx(visual.position.y, -60.0),
		"puppet: streamed height paints depth without integrating")
	_free(v)

func test_puppet_hp_stream_has_no_side_effects() -> void:
	var v := _spawn()
	v.set_net_puppet(true)
	var died := [false]
	v.get_node("Health").died.connect(func() -> void: died[0] = true)
	v.apply_net_state({"hp": 40.0})
	t.check(is_equal_approx(v.get_hp(), 40.0), "puppet: hp mirrors the stream")
	v.apply_net_state({"hp": 0.0})
	t.check(is_equal_approx(v.get_hp(), 0.0), "puppet: zero hp mirrors too")
	t.check(not died[0],
		"puppet: mirrored death emits nothing — seat events own death, not the stream")
	_free(v)

func test_puppet_flags_drive_cosmetics() -> void:
	var v := _spawn()
	v.set_net_puppet(true)
	v.apply_net_state({"boost": true, "handbrake": true, "brake": true, "burn": true})
	var ctrl: DrivingController = v.get_controller()
	t.check(ctrl.boosting, "puppet: boost flag reaches the flame FX flag")
	t.check(ctrl.handbraking, "puppet: handbrake flag reaches the skid paint")
	var paint = v.get_node("Visual/Body")
	t.check(ctrl.service_braking and paint.brake_lights_on(),
		"puppet: service-brake flag reaches the rear lamps")
	t.check(v.is_burning(), "puppet: burn flag lights the hull licks")
	v.apply_net_state({"boost": false, "handbrake": false, "brake": false, "burn": false})
	t.check(not ctrl.boosting and not ctrl.handbraking and not ctrl.service_braking
		and not paint.brake_lights_on() and not v.is_burning(),
		"puppet: flags clear on the next slice")
	_free(v)
