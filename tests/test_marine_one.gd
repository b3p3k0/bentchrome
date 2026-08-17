extends RefCounted
## Marine One's signature-destructible contract: the fence census arms the
## evacuation, the spool window pays the mini_boss bounty with attribution,
## the climb rides the floor-bit ladder into an unhittable sky, flight pose
## is deterministic from the phase clock, the air kill spirals into the
## authored crash site and flips its dormant props exactly once, tombstones
## are never freed, and net rows round-trip every phase (apply-twice safe).

const MarineScript := preload("res://levels/capital/marine_one.gd")
const FloorsScript := preload("res://game/floors.gd")
const EconomyScript := preload("res://game/economy.gd")

var t

func _init(runner) -> void:
	t = runner

func _rig(with_site := false) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var site: Node2D = null
	var debris: Node2D = null
	if with_site:
		site = Node2D.new()
		site.name = "CrashSite"
		container.add_child(site)
		debris = Node2D.new()
		container.get_node("CrashSite").add_child(debris)
	var fences: Array = []
	for i in 2:
		var fence := StaticBody2D.new()
		fence.collision_layer = 4
		fence.add_to_group(&"wh_fence")
		container.add_child(fence)
		fences.append(fence)
	var marine: StaticBody2D = MarineScript.new()
	marine.authority_override = "authority"
	marine.position = Vector2(0, -1200)
	marine.exit_point = Vector2(2600, 1600)
	if with_site:
		marine.crash_site_path = NodePath("../CrashSite")
	container.add_child(marine)
	return {"container": container, "marine": marine, "fences": fences,
		"site": site, "debris": debris}

func _teardown(rig: Dictionary) -> void:
	t.current_scene = null
	t.root.remove_child(rig.container)
	(rig.container as Node).free()

func test_fence_breach_starts_the_evacuation() -> void:
	var rig := _rig()
	var marine: Node2D = rig.marine
	marine.tick(0.5)
	t.check(marine.phase == MarineScript.Phase.PARKED,
		"marine one: intact fence ring keeps the bird parked")
	(rig.fences[0] as StaticBody2D).collision_layer = 0  # a segment goes down
	marine.tick(0.1)
	t.check(marine.phase == MarineScript.Phase.SPOOLING,
		"marine one: first breach spools the rotor")
	var figures := 0
	for child in (rig.container as Node).get_children():
		if child is Area2D and child.get("kind") != null:
			figures += 1
	t.check(figures == 1, "marine one: a figure sprints from the residence")
	marine.tick(MarineScript.SPOOL_SECONDS + 0.1)
	t.check(marine.phase == MarineScript.Phase.CLIMBING,
		"marine one: the spool window closes into the climb")
	_teardown(rig)

func test_ground_kill_pays_the_bounty() -> void:
	var rig := _rig()
	var marine: Node2D = rig.marine
	var player := Node2D.new()
	player.add_to_group(&"player")
	(rig.container as Node).add_child(player)
	var keep_enabled: bool = EconomyScript.enabled
	var keep_funds: int = EconomyScript.funds
	EconomyScript.enabled = true
	EconomyScript.funds = 0
	marine.last_attacker = player
	(marine.get_node("Health") as Health).take_damage(999.0)
	t.check(marine.phase == MarineScript.Phase.DEAD and not marine._dead_air,
		"marine one: shot on the lawn dies into a lawn wreck")
	t.check(EconomyScript.funds > 0, "marine one: attributed kill pays the mini_boss tier")
	t.check(not marine.is_queued_for_deletion() and marine.collision_layer == 0,
		"marine one: the wreck is a tombstone, never freed")
	EconomyScript.enabled = keep_enabled
	EconomyScript.funds = keep_funds
	_teardown(rig)

func test_unattributed_kill_pays_nothing() -> void:
	var rig := _rig()
	var marine: Node2D = rig.marine
	var keep_enabled: bool = EconomyScript.enabled
	var keep_funds: int = EconomyScript.funds
	EconomyScript.enabled = true
	EconomyScript.funds = 0
	(marine.get_node("Health") as Health).take_damage(999.0)
	t.check(EconomyScript.funds == 0,
		"marine one: the wasteland's kill goes unpaid")
	EconomyScript.enabled = keep_enabled
	EconomyScript.funds = keep_funds
	_teardown(rig)

func test_climb_rides_the_floor_bit_ladder() -> void:
	var rig := _rig()
	var marine: Node2D = rig.marine
	marine.phase = MarineScript.Phase.CLIMBING
	marine.phase_elapsed = 0.0
	marine.tick(0.1)
	t.check((marine.collision_layer & FloorsScript.floor_bit(1)) != 0,
		"marine one: low climb carries the floor-1 bit — anyone can hit it")
	marine.phase_elapsed = MarineScript.CLIMB_SECONDS * 0.5
	marine.tick(0.01)
	t.check((marine.collision_layer & FloorsScript.floor_bit(2)) != 0,
		"marine one: mid climb needs terrace height")
	marine.phase_elapsed = MarineScript.CLIMB_SECONDS * 0.9
	marine.tick(0.01)
	t.check((marine.collision_layer & FloorsScript.floor_bit(3)) != 0,
		"marine one: high climb is rooftop reach")
	marine.phase_elapsed = MarineScript.CLIMB_SECONDS
	marine.tick(0.01)
	t.check(marine.phase == MarineScript.Phase.ESCAPED and marine.collision_layer == 0
			and not marine.visible and not marine.is_queued_for_deletion(),
		"marine one: floor 4 is the sky — hidden, collisionless, never freed")
	_teardown(rig)

func test_flight_pose_is_deterministic() -> void:
	var rig_a := _rig()
	var rig_b := _rig()
	for rig in [rig_a, rig_b]:
		var m: Node2D = rig.marine
		m.phase = MarineScript.Phase.CLIMBING
		m.phase_elapsed = MarineScript.CLIMB_SECONDS * 0.4
		m._apply_flight_pose()
	t.check((rig_a.marine as Node2D).global_position.is_equal_approx(
			(rig_b.marine as Node2D).global_position),
		"marine one: the phase clock IS the position — host and client agree")
	_teardown(rig_a)
	_teardown(rig_b)

func test_air_kill_spirals_into_the_crash_site() -> void:
	var rig := _rig(true)
	var marine: Node2D = rig.marine
	var debris: Node2D = rig.debris
	t.check(not debris.visible,
		"marine one: crash-site props sleep hidden until the fall")
	marine.phase = MarineScript.Phase.CLIMBING
	marine.phase_elapsed = MarineScript.CLIMB_SECONDS * 0.4
	(marine.get_node("Health") as Health).take_damage(999.0)
	t.check(marine.phase == MarineScript.Phase.DYING and marine._dead_air,
		"marine one: an air kill starts the smoke spiral")
	marine.tick(MarineScript.SPIRAL_SECONDS + 0.1)
	t.check(marine.phase == MarineScript.Phase.DEAD,
		"marine one: the spiral ends on the ground")
	t.check(marine.global_position.is_equal_approx((rig.site as Node2D).global_position),
		"marine one: it lands exactly on the authored crash site")
	t.check(debris.visible, "marine one: the debris field wakes on impact")
	t.check(not t.root.get_tree().paused,
		"marine one: no theatre without a real player — the tree stays live")
	_teardown(rig)

func test_net_rows_round_trip_every_phase() -> void:
	var rig := _rig()
	var host: Node2D = rig.marine
	var client: StaticBody2D = MarineScript.new()
	client.authority_override = "client"
	(rig.container as Node).add_child(client)
	for p in [MarineScript.Phase.PARKED, MarineScript.Phase.SPOOLING,
			MarineScript.Phase.CLIMBING, MarineScript.Phase.ESCAPED]:
		host.phase = p
		host.phase_elapsed = 1.5
		var row: Dictionary = host.capture_arena_state([])
		client.apply_arena_state(row, false)
		client.apply_arena_state(row, false)  # repeats must be safe
		t.check(client.phase == p, "marine one: phase %d survives the wire twice" % p)
	# A late joiner lands mid-crash: dead + WARNING = the air-crash tombstone.
	host.phase = MarineScript.Phase.DEAD
	host._dead_air = true
	host.get_node("Health").hp = 0.0
	var dead_row: Dictionary = host.capture_arena_state([])
	client.apply_arena_state(dead_row, true)
	t.check(client.phase == MarineScript.Phase.DEAD and client._dead_air
			and client.collision_layer == 0 and not client.is_queued_for_deletion(),
		"marine one: initial dead state converges to a silent tombstone")
	_teardown(rig)
