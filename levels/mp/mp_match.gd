extends Node2D
## The MP match shell. Runs on every peer and branches on role. The HOST
## instances the arena as pure geometry (mp_managed strips the baked cars into
## spawn data), seats real simulated Vehicles per the broadcast actor table
## (PlayerDriver for itself, NetworkDriver per remote seat, EnemyDriver AI for
## Grand Melee), runs the MatchDirector, and streams snapshots + fire events.
## CLIENTS spawn one puppet per actor, render the stream, and ship their
## sampled intent back. The shell NEVER instantiates pause_menu or end_screen
## — the tree must not pause under a live simulation; ESC is mp_pause_overlay.

const Proto := preload("res://game/net/net_protocol.gd")
const Snapshot := preload("res://game/net/net_snapshot.gd")
const NetEvents := preload("res://game/net/net_events.gd")
const DirectorScript := preload("res://game/net/match_director.gd")
const Loader := preload("res://levels/level_loader.gd")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const Difficulty := preload("res://game/difficulty.gd")
const NetDriverScript := preload("res://vehicles/drivers/network_driver.gd")
const PlayerDriverScript := preload("res://vehicles/drivers/player_driver.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const EnemyScene := preload("res://vehicles/enemy_vehicle.tscn")
const PauseOverlayScene := preload("res://ui/mp_pause_overlay.tscn")
const RigScene := preload("res://levels/mp/spectator_rig.tscn")
const ImpactScene := preload("res://weapons/impact_fx.tscn")

const FEED_LINES := 4
const FEED_TTL := 4.0

var _arena: Node2D
var _director: Node
var _rig: Node2D = null        # my spectator rig (observer / eliminated / rotated out)
var _feed_box: VBoxContainer
var _feed_entries: Array = []  # [{label, born}]
var _actor_cars: Array = []      # actor index -> Vehicle (host: sim; client: puppet)
var _my_driver: Driver = null    # client: local PlayerDriver, sampled for the wire
var _my_car: Vehicle = null
var _stream_accum := 0
var _snap_tick := 0
var _visual_shots: Dictionary = {}  # u32 host shot id -> pooled client twin

# Autoloads by path, never bare identifier — this script rides the test
# runner's preload chain, where -s compilation can't bind autoload names.
@onready var _net: Node = get_node(^"/root/Net")
@onready var _flow: Node = get_node(^"/root/SceneFlow")
@onready var _pool: Node = get_node_or_null(^"/root/Spawner")

func _ready() -> void:
	print("[boot] mp match ready")
	if not _net.is_active():
		# Cold boot (smoke, curiosity): nothing to host, nothing to mirror.
		print("[mp] no session — returning to the front door")
		_flow.to_mp_menu.call_deferred()
		return
	_load_arena()
	add_child(PauseOverlayScene.instantiate())
	_build_kill_feed()
	_net.kill_feed.connect(_on_feed_line)
	_net.match_status_changed.connect(_on_status_changed)
	_net.session_changed.connect(_on_session_gone)
	if _net.is_host():
		NetEvents.armed = true
		NetEvents.queue = []
		_net.peers_changed.connect(_on_peers_changed_host)
		_spawn_host_side()
	else:
		_net.actor_swapped.connect(_on_actor_swapped_client)
		_spawn_client_side()
	if _my_actor_index() < 0:
		_deploy_rig()  # on the bench from the first green flag

func _exit_tree() -> void:
	NetEvents.reset()
	if _net and _net.is_host() and _net.roster:
		for id in _net.roster.seated_ids():
			_net.unregister_net_driver(int(id))

func _process(_delta: float) -> void:
	# Kill feed fade: lines age out, oldest first.
	var now := Time.get_ticks_msec()
	while not _feed_entries.is_empty() \
			and now - int(_feed_entries[0].born) > FEED_TTL * 1000.0:
		(_feed_entries.pop_front().label as Label).queue_free()

func _physics_process(delta: float) -> void:
	if not _net.is_active():
		return
	if _net.is_host():
		_stream_accum += 1
		if _stream_accum >= maxi(1, roundi(60.0 / Proto.snapshot_hz)):
			_stream_accum = 0
			_snap_tick += 1
			_net.broadcast_snapshot(Snapshot.pack_snapshot(
				_snap_tick, _collect_rows(), _drain_events()))
	elif _my_driver and _my_car and is_instance_valid(_my_car):
		# The client's whole contribution: this tick's sampled intent.
		var intent: Dictionary = _my_driver.get_intent(_my_car, delta)
		_net.send_input(intent)
		if intent.get("weapon_prev", false):
			_net.send_weapon_cycle(-1)
		if intent.get("weapon_next", false):
			_net.send_weapon_cycle(1)

func _load_arena() -> void:
	var cfg: Dictionary = _net.match_config
	var maps: Array = _flow.MP_MAPS
	var idx := clampi(int(cfg.get("map", 0)), 0, maps.size() - 1)
	var scene: PackedScene = load(String(maps[idx].scene))
	_arena = scene.instantiate()
	_arena.mp_managed = true  # before add_child: the arena's _ready reads it
	add_child(_arena)

# --------------------------------------------------------------------- host

func _spawn_host_side() -> void:
	var spawns: Array = _arena.mp_spawns
	var actors: Array = _net.match_actors
	if actors.is_empty():
		# Direct host without start_match (dev shortcut): improvise the table.
		_net.start_match()
		actors = _net.match_actors
	if spawns.is_empty() or actors.is_empty():
		push_warning("mp_match: no spawns or no actors — empty arena")
		return
	Difficulty.tier = int(_net.match_config.get("difficulty", Difficulty.Tier.HARD))
	for i in actors.size():
		if i >= spawns.size():
			push_warning("mp_match: more actors than spawns — extras skipped")
			break
		var actor: Dictionary = actors[i]
		var peer := int(actor.peer)
		var car_id := String(actor.car)
		if peer > 0:
			var car := _spawn_car(VehicleScene, spawns[i], car_id)
			if peer == _net.my_id():
				VehiclesHelper.mark_local(car)  # camera ships enabled
			else:
				var cam := car.get_node_or_null(^"Camera2D") as Camera2D
				if cam:
					cam.enabled = false
				var nd: Driver = NetDriverScript.new()
				car.set_driver(nd)
				_net.register_net_driver(peer, nd)
			_actor_cars.append(car)
		else:
			var ai := _spawn_car(EnemyScene, spawns[i], car_id)
			ai.get_node("Driver").mix = Loader.mix_for_car(car_id)
			_actor_cars.append(ai)
	# The director gets SHARED references — swaps and tallies write through.
	_director = DirectorScript.new()
	_director.name = "MatchDirector"
	_director.setup(_net.match_config, _net.match_actors, _actor_cars,
		_net.roster, spawns)
	_director.status_changed.connect(_push_status)
	_director.feed_line.connect(_net.push_kill_feed)
	_director.seat_swap.connect(_on_seat_swap_host)
	_director.ended.connect(_net.end_match)
	add_child(_director)

func _push_status() -> void:
	_net.push_match_status(_director.scores, _director.time_remaining(),
		_director.eliminated.keys())

## The session died under us (host loss, kick) — home to the front door,
## where the one-shot notice explains what happened.
func _on_session_gone() -> void:
	if not _net.is_active():
		_flow.to_mp_menu()

## Host: somebody's cable got pulled mid-match. Vacate their actor slot —
## either the queue's front takes the wheel where it sits (seat_swap wires
## it) or the slot goes ghost and the car is silently switched off.
func _on_peers_changed_host() -> void:
	if _director == null or not _net.match_live:
		return
	var actors: Array = _net.match_actors
	for i in actors.size():
		var peer := int(actors[i].peer)
		if peer > 1 and not _net.peers.has(peer):
			_net.unregister_net_driver(peer)
			if not _director.vacate_actor(i):
				_neutralize_car(i)
				_net.notify_actor_swap(i, 0, String(actors[i].car))

## Ghost slot: silent off-switch — no boom, no tally, the row's already
## frozen. Direct hp set so died never fires.
func _neutralize_car(idx: int) -> void:
	var car: Vehicle = _actor_cars[idx] if is_instance_valid(_actor_cars[idx]) else null
	if car == null:
		return
	var health := car.get_node_or_null(^"Health")
	if health:
		health.hp = 0.0
	car.visible = false
	car.set_physics_process(false)
	car.collision_layer = 0
	car.collision_mask = 0

# ---------------------------------------------------------------- the bench

func _my_actor_index() -> int:
	var actors: Array = _net.match_actors
	for i in actors.size():
		if int(actors[i].peer) == _net.my_id():
			return i
	return -1

## My eyes when I have no wheel: observer from the start, out of lives, or
## rotated to the back of the line.
func _deploy_rig() -> void:
	if _rig != null:
		return
	_rig = RigScene.instantiate()
	_rig.targets = _actor_cars
	var names: Array = []
	for actor in _net.match_actors:
		names.append(String(actor.name))
	_rig.actor_names = names
	add_child(_rig)

func _retire_rig() -> void:
	if _rig:
		_rig.queue_free()
		_rig = null

## Elimination reaches every machine through the status sync; each deploys
## its own rig when ITS driver is out.
func _on_status_changed() -> void:
	if _rig == null and _net.match_eliminated.has(_net.my_id()):
		var idx := _my_actor_index()
		if idx >= 0 and idx < _actor_cars.size() and is_instance_valid(_actor_cars[idx]):
			VehiclesHelper.unmark_local(_actor_cars[idx])
		_my_car = null
		_my_driver = null
		_deploy_rig()

## The rotation landed (host): the wrecked seat's CAR changes hands — restat
## to the entrant's locked pick, rewire the driver, shift camera/local marks.
func _on_seat_swap_host(actor_idx: int, from_peer: int, to_peer: int, car_id: String) -> void:
	var car: Vehicle = _actor_cars[actor_idx] if is_instance_valid(_actor_cars[actor_idx]) else null
	if car == null:
		return
	if not car_id.is_empty():
		car.set_stats(load("res://data/vehicles/%s.tres" % car_id))
	_net.unregister_net_driver(from_peer)
	var cam := car.get_node_or_null(^"Camera2D") as Camera2D
	if from_peer == _net.my_id():
		VehiclesHelper.unmark_local(car)
		if cam:
			cam.enabled = false
		_deploy_rig()  # the rig takes the host's eyes
	if to_peer == _net.my_id():
		_retire_rig()
		car.set_driver(PlayerDriverScript.new())
		VehiclesHelper.mark_local(car)
		if cam:
			cam.enabled = true
	else:
		var nd: Driver = NetDriverScript.new()
		car.set_driver(nd)
		_net.register_net_driver(to_peer, nd)
		if cam:
			cam.enabled = false
	_net.notify_actor_swap(actor_idx, to_peer, car_id)

## The rotation landed (client): restat the puppet, shift marks and camera.
func _on_actor_swapped_client(actor_idx: int, peer: int, car_id: String, _name: String) -> void:
	if actor_idx < 0 or actor_idx >= _actor_cars.size():
		return
	var car: Vehicle = _actor_cars[actor_idx] if is_instance_valid(_actor_cars[actor_idx]) else null
	if car == null:
		return
	if not car_id.is_empty():
		car.set_stats(load("res://data/vehicles/%s.tres" % car_id))
	var cam := car.get_node_or_null(^"Camera2D") as Camera2D
	if _my_car == car and peer != _net.my_id():
		# That was my ride — the rig takes my eyes, back of the line for me.
		VehiclesHelper.unmark_local(car)
		if cam:
			cam.enabled = false
		_my_car = null
		_my_driver = null
		_deploy_rig()
	if peer == _net.my_id():
		_retire_rig()
		VehiclesHelper.mark_local(car)
		_my_car = car
		_my_driver = car.get_node(^"Driver")
		if cam:
			cam.enabled = true

## The host's exit for capless brawls — wired from the pause overlay.
func host_force_end() -> void:
	if _director:
		_director.force_end("the host called it")

## One row per actor, wire order. Freed cars (AI deaths) stay as dead rows.
func _collect_rows() -> Array:
	var rows: Array = []
	for car_v in _actor_cars:
		var car: Vehicle = car_v if is_instance_valid(car_v) else null
		if car == null:
			rows.append({"alive": false, "hp": 0.0})
			continue
		var ctrl: DrivingController = car.get_controller()
		var mount: WeaponMount = car.get_mg_mount()
		var rack: WeaponRack = car.get_rack()
		var ammo: Array = []
		if rack:
			for i in Snapshot.AMMO_SLOTS:
				ammo.append(rack.ammo(i))
		rows.append({
			"pos": car.global_position, "vel": car.velocity,
			"heading": car.heading, "height": car.height,
			"floor": car.floor_index, "hp": car.get_hp(),
			"alive": car.get_hp() > 0.0,
			"boost": ctrl.boosting if ctrl else false,
			"handbrake": ctrl.handbraking if ctrl else false,
			"brake": ctrl.service_braking if ctrl else false,
			"burn": car.is_burning(), "shield": car.is_shielded(),
			"mg_locked": mount.is_locked() if mount else false,
			"heat": mount.heat_fraction() if mount else 0.0,
			"boost_fuel": ctrl.boost_fuel if ctrl else 0.0,
			"slot": rack.selected_index() if rack else 0,
			"ammo": ammo,
			"recharge": rack.recharge_fraction() if rack else 1.0,
		})
	return rows

## NetEvents drainage with node references resolved to compact actor indices.
func _drain_events() -> Array:
	var out: Array = []
	for ev in NetEvents.drain():
		if ev.get("kind") == &"hit":
			var attacker_idx := _actor_cars.find(ev.get("attacker"))
			var victim_idx := _actor_cars.find(ev.get("victim"))
			if attacker_idx < 0 or victim_idx < 0:
				continue
			ev["attacker_actor"] = attacker_idx
			ev["victim_actor"] = victim_idx
		elif ev.get("kind") == &"projectile":
			var target_actor := Snapshot.NO_TARGET
			var target: Node2D = ev.get("target")
			if target != null and is_instance_valid(target):
				var idx := _actor_cars.find(target)
				if idx >= 0:
					target_actor = idx
			ev["target_actor"] = target_actor
		out.append(ev)
	return out

# ------------------------------------------------------------------- client

func _spawn_client_side() -> void:
	var spawns: Array = _arena.mp_spawns
	var actors: Array = _net.match_actors
	Vehicle.NET_INTERP_MS = Proto.interp_delay_ms
	for i in actors.size():
		if i >= spawns.size():
			break
		var actor: Dictionary = actors[i]
		var peer := int(actor.peer)
		var scene := VehicleScene if peer > 0 else EnemyScene
		var car := _spawn_car(scene, spawns[i], String(actor.car))
		car.set_net_puppet(true)  # after add_child — @onready must be live
		if peer == _net.my_id():
			VehiclesHelper.mark_local(car)
			_my_car = car
			_my_driver = car.get_node(^"Driver")
		else:
			var cam := car.get_node_or_null(^"Camera2D") as Camera2D
			if cam:
				cam.enabled = false
		_actor_cars.append(car)
	_net.snapshot_arrived.connect(_on_snapshot)

func _on_snapshot(data: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var rows: Array = data.rows
	for i in mini(rows.size(), _actor_cars.size()):
		var car: Vehicle = _actor_cars[i] if is_instance_valid(_actor_cars[i]) else null
		if car == null:
			continue
		var row: Dictionary = rows[i]
		row["t"] = now
		car.apply_net_state(row)
	for ev in data.events:
		match int(ev.get("kind", 0)):
			Snapshot.EV_HIT:
				_present_hit_event(ev)
			Snapshot.EV_IMPACT:
				_present_impact_event(ev)
			Snapshot.EV_PROJECTILE:
				_spawn_visual_projectile(ev)

func _present_hit_event(ev: Dictionary) -> void:
	var attacker_idx := int(ev.get("attacker_actor", Snapshot.NO_TARGET))
	var victim_idx := int(ev.get("victim_actor", Snapshot.NO_TARGET))
	if attacker_idx < 0 or attacker_idx >= _actor_cars.size() \
			or victim_idx < 0 or victim_idx >= _actor_cars.size():
		return
	var attacker: Node2D = _actor_cars[attacker_idx] if is_instance_valid(_actor_cars[attacker_idx]) else null
	var victim: Vehicle = _actor_cars[victim_idx] if is_instance_valid(_actor_cars[victim_idx]) else null
	if attacker and victim:
		victim.present_combat_hit(attacker)

func _present_impact_event(ev: Dictionary) -> void:
	var style := int(ev.get("style", Projectile.ImpactStyle.NONE))
	if style > Projectile.ImpactStyle.NONE and style <= Projectile.ImpactStyle.SPATTER \
			and _arena and _pool:
		var fx := _pool.acquire(ImpactScene) as ImpactFX
		_arena.add_child(fx)
		fx.setup(ev.get("pos", Vector2.ZERO), style)
	if not ev.get("terminal", false):
		return
	var shot_id := int(ev.get("shot_id", 0))
	var shot: Node = _visual_shots.get(shot_id)
	if shot != null and is_instance_valid(shot):
		shot.call(&"_despawn")
	_visual_shots.erase(shot_id)

## A cosmetic twin of the host's shot: zero damage, zero collision, same pool.
## Dead-reckons on its own lifetime; homing tracks the target's puppet.
func _spawn_visual_projectile(ev: Dictionary) -> void:
	var path := String(ev.get("path", ""))
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return  # fuzzed path — not today
	var scene: PackedScene = load(path)
	if scene == null or _pool == null:
		return
	var shot: Node = _pool.acquire(scene)
	var target_idx := int(ev.get("target_actor", Snapshot.NO_TARGET))
	var target: Node2D = null
	if target_idx >= 0 and target_idx < _actor_cars.size() \
			and is_instance_valid(_actor_cars[target_idx]):
		target = _actor_cars[target_idx]
	shot.collision_layer = 0
	shot.collision_mask = 0  # visual-only; pool reuse re-zeroes every acquire
	_arena.add_child(shot)
	shot.setup(ev.pos, ev.dir, float(ev.speed), 0.0, float(ev.lifetime),
		null, float(ev.turn_rate), target)
	var shot_id := int(ev.get("shot_id", 0))
	if shot_id > 0:
		shot.net_shot_id = shot_id
		_visual_shots[shot_id] = shot
		shot.retired.connect(_on_visual_projectile_retired.bind(shot), CONNECT_ONE_SHOT)

func _on_visual_projectile_retired(shot_id: int, shot: Node) -> void:
	if _visual_shots.get(shot_id) == shot:
		_visual_shots.erase(shot_id)

# ---------------------------------------------------------------- kill feed

func _build_kill_feed() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15  # over the HUD, under the pause overlay
	add_child(layer)
	_feed_box = VBoxContainer.new()
	_feed_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_feed_box.offset_top = 10.0
	_feed_box.add_theme_constant_override("separation", 2)
	layer.add_child(_feed_box)

func _on_feed_line(text: String) -> void:
	if _feed_box == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.85, 0.2)
	label.custom_minimum_size = Vector2(0, 0)
	_feed_box.add_child(label)
	_feed_entries.append({"label": label, "born": Time.get_ticks_msec()})
	while _feed_entries.size() > FEED_LINES:
		(_feed_entries.pop_front().label as Label).queue_free()

# ------------------------------------------------------------------- shared

## One car at one derived spawn. Stats land before add_child so _ready applies
## them; rotation carries the authored heading (folded by Vehicle._ready).
func _spawn_car(scene: PackedScene, spot: Dictionary, pick: String) -> Vehicle:
	var car: Vehicle = scene.instantiate()
	if not pick.is_empty():
		car.stats = load("res://data/vehicles/%s.tres" % pick)
	car.position = spot.pos
	car.rotation = float(spot.heading)
	if int(spot.get("floor", -1)) >= 1:
		car.start_floor = int(spot.floor)
	_arena.add_child(car)
	return car
