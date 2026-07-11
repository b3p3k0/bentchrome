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
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const EnemyScene := preload("res://vehicles/enemy_vehicle.tscn")
const PauseOverlayScene := preload("res://ui/mp_pause_overlay.tscn")

var _arena: Node2D
var _director: Node
var _actor_cars: Array = []      # actor index -> Vehicle (host: sim; client: puppet)
var _my_driver: Driver = null    # client: local PlayerDriver, sampled for the wire
var _my_car: Vehicle = null
var _stream_accum := 0
var _snap_tick := 0

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
	if _net.is_host():
		NetEvents.armed = true
		NetEvents.queue = []
		_spawn_host_side()
	else:
		_spawn_client_side()

func _exit_tree() -> void:
	NetEvents.reset()
	if _net and _net.is_host() and _net.roster:
		for id in _net.roster.seated_ids():
			_net.unregister_net_driver(int(id))

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
	_director = DirectorScript.new()
	_director.name = "MatchDirector"
	_director.spawns = spawns
	add_child(_director)
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
			_director.register_car(peer, car)
			_actor_cars.append(car)
		else:
			var ai := _spawn_car(EnemyScene, spawns[i], car_id)
			ai.get_node("Driver").mix = Loader.mix_for_car(car_id)
			_actor_cars.append(ai)

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
			"burn": car.is_burning(), "shield": car.is_shielded(),
			"mg_locked": mount.is_locked() if mount else false,
			"heat": mount.heat_fraction() if mount else 0.0,
			"boost_fuel": ctrl.boost_fuel if ctrl else 0.0,
			"slot": rack.selected_index() if rack else 0,
			"ammo": ammo,
			"recharge": rack.recharge_fraction() if rack else 1.0,
		})
	return rows

## NetEvents drainage with node targets resolved to actor indices.
func _drain_events() -> Array:
	var out: Array = []
	for ev in NetEvents.drain():
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
		_spawn_visual_projectile(ev)

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
