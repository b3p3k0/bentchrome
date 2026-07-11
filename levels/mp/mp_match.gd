extends Node2D
## The MP match shell. Runs on every peer and branches on role: the HOST
## instances the arena as pure geometry (mp_managed strips the baked cars into
## spawn data), seats real simulated Vehicles (PlayerDriver for itself,
## NetworkDriver per remote seat, EnemyDriver backfill for Grand Melee), and
## runs the MatchDirector. Clients get their branch in C8b (puppets fed by the
## snapshot stream). The shell NEVER instantiates pause_menu or end_screen —
## the tree must not pause under a live simulation; ESC is mp_pause_overlay.

const Proto := preload("res://game/net/net_protocol.gd")
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

# Autoloads by path, never bare identifier — this script rides the test
# runner's preload chain, where -s compilation can't bind autoload names.
@onready var _net: Node = get_node(^"/root/Net")
@onready var _flow: Node = get_node(^"/root/SceneFlow")

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
		_spawn_host_side()
	# Client branch (puppets + snapshot apply) arrives with C8b.

func _exit_tree() -> void:
	# The shell owns the driver registry it filled.
	if _net and _net.is_host() and _net.roster:
		for id in _net.roster.seated_ids():
			_net.unregister_net_driver(int(id))

func _load_arena() -> void:
	var cfg: Dictionary = _net.match_config
	var maps: Array = _flow.MP_MAPS
	var idx := clampi(int(cfg.get("map", 0)), 0, maps.size() - 1)
	var scene: PackedScene = load(String(maps[idx].scene))
	_arena = scene.instantiate()
	_arena.mp_managed = true  # before add_child: the arena's _ready reads it
	add_child(_arena)

func _spawn_host_side() -> void:
	var spawns: Array = _arena.mp_spawns
	if spawns.is_empty():
		push_warning("mp_match: arena yielded no spawns")
		return
	# Match-wide AI difficulty is the host's lobby setting.
	Difficulty.tier = int(_net.match_config.get("difficulty", Difficulty.Tier.HARD))
	_director = DirectorScript.new()
	_director.name = "MatchDirector"
	_director.spawns = spawns
	add_child(_director)

	var seat_ids: Array = _net.roster.seated_ids()
	var spawn_i := 0
	for id_v in seat_ids:
		var id := int(id_v)
		if spawn_i >= spawns.size():
			push_warning("mp_match: more seats than spawns — extra seat skipped")
			break
		var car := _spawn_car(VehicleScene, spawns[spawn_i], _net.roster.pick_of(id))
		spawn_i += 1
		if id == _net.my_id():
			VehiclesHelper.mark_local(car)  # camera ships enabled in vehicle.tscn
		else:
			var cam := car.get_node_or_null(^"Camera2D") as Camera2D
			if cam:
				cam.enabled = false
			var nd: Driver = NetDriverScript.new()
			car.set_driver(nd)
			_net.register_net_driver(id, nd)
		_director.register_car(id, car)

	# Grand Melee: AI backfill to the map's baked car count. Host-only RNG is
	# fine under host authority — clients mirror whatever it produced (C8b).
	if StringName(String(_net.match_config.get("mode", &"melee"))) == &"melee":
		var want := spawns.size() - spawn_i
		if want > 0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var picks: Array = Loader.pick_cars(want, "", rng)
			for pick in picks:
				if spawn_i >= spawns.size():
					break
				var ai := _spawn_car(EnemyScene, spawns[spawn_i], String(pick))
				ai.get_node("Driver").mix = Loader.mix_for_car(String(pick))
				spawn_i += 1

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
