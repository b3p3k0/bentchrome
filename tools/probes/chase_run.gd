extends SceneTree
## Route 666 balance probe: one full run on autopilot, headless, in about
## three seconds. Prints a one-line verdict ([run] ...) and, with --verbose,
## a 15-second ticker and where the damage came from. Use tools/chase_probe.sh
## to sweep cars and tally outcomes.
##
## Run: godot --headless --fixed-fps 60 --path . -s res://tools/probes/chase_run.gd -- \
##        --car=hornet [--skill=1.0] [--tank] [--verbose]
##   --tank   a bottomless hull: the run always reaches the clock (or the
##            pack), so TOOK reads the full run's incoming damage.
##   --mines  a land mine dropped off the tail every MINE_EVERY seconds (the
##            bot never uses the bay): measures what a flinch buys.
##
## The autopilot (chase_autopilot.gd) never dodges fire, hunts pickups, or
## uses rear weapons: its results are a FLOOR for what a player will do.

const Economy := preload("res://game/economy.gd")
const Wall := preload("res://levels/chase/horde_wall.gd")
const Autopilot := preload("res://tools/probes/chase_autopilot.gd")
const Brain := preload("res://levels/chase/chase_driver.gd")
const RUN_SCENE := "res://levels/chase/buzzard_run.tscn"

var _car := "hornet"
var _skill := 1.0
var _tank := false
var _verbose := false
var _mines := false
const MINE_EVERY := 15.0
var _mine_t := MINE_EVERY * 0.5

var _scene: Node = null
var _frame := 0
var _min_gap := INF
var _danger_frames := 0
var _boost_frames := 0
var _slowdowns := 0
var _was_slow := false
var _hp0 := 0.0
var _last_hp := 0.0
var _taken := 0.0
var _window := 0.0
var _heals := 0
var _max_pack := 0
var _by_source := {}   # "role (kind)" -> [damage, hits]
var _last_stamp := 0
var _finale_air := 0.0     # the show: the car's highest point over the river
var _finale_land := INF    # chunk-local d where it came down
var _finale_over := false  # it was airborne and is no longer
var _jumpers := 0
var _sorties := {}     # bird instance id -> {role, best dy per stage}: did the choreography LAND?

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--car="):
			_car = arg.substr(6)
		elif arg.begins_with("--skill="):
			_skill = float(arg.substr(8))
		elif arg == "--tank":
			_tank = true
		elif arg == "--mines":
			_mines = true
		elif arg == "--verbose":
			_verbose = true
	process_frame.connect(_setup, CONNECT_ONE_SHOT)

func _setup() -> void:
	var gs := root.get_node(^"/root/GameState")
	gs.selected_vehicle_id = StringName(_car)
	gs.game_mode = &"campaign"
	gs.dev_mode = false
	gs.devgod = false
	_scene = load(RUN_SCENE).instantiate()
	_scene.auto_advance = false   # never leave the scene: the verdict is the point
	root.add_child(_scene)
	current_scene = _scene
	Economy.god = false
	var player = _scene.get_node(^"Vehicle")
	var pilot = Autopilot.new()
	pilot.host = _scene
	pilot.skill = _skill
	player.set_driver(pilot)
	var health = player.get_node(^"Health")
	health.god = false
	_hp0 = player.get_hp()
	if _tank:
		health.max_hp = 1000000.0
		health.hp = 1000000.0
	_last_hp = player.get_hp()
	physics_frame.connect(_tick)

func _tick() -> void:
	_frame += 1
	var player = _scene.get_node(^"Vehicle")
	var over: bool = _scene.is_jacked() or _scene._won
	if _scene.has_method(&"finale_running") and _scene.finale_running():
		_watch_finale(player)
	elif not over:
		_watch(player)
		if _mines:
			_mine_t -= 1.0 / 60.0
			if _mine_t <= 0.0:
				_mine_t = MINE_EVERY
				var mine = load("res://environment/mine_land.tscn").instantiate()
				mine.dropper = player
				mine.global_position = player.global_position + Vector2(0.0, 60.0)
				_scene.add_child(mine)
	if _verbose and _frame % 900 == 0 and not over:
		print("[t=%3ds] gap %3d  pace %.2f  speed %3d  hp %3d  kills %2d  pack %d  fuel %3d  took %.1f hp/s" % [
			int(_scene.clock), int(_scene.wall_gap()), _scene.pack_pace(), int(player.velocity.length()),
			int(player.get_hp()) if not _tank else int(_hp0 - _taken), _scene.kills,
			get_nodes_in_group(&"enemies").size(), int(player.get_controller().boost_fuel), _window / 15.0])
		_window = 0.0
	if over:
		_report(player)
		paused = false
		quit(0)
	elif _frame > 60 * 170:
		print("[run] TIMEOUT  car %s  clock %.1f" % [_car, _scene.clock])
		quit(0)

## The bridge is out: how high the car flew, where it came down, and how
## many birds went into the river (a finale that lands short is a bug).
func _watch_finale(player) -> void:
	var fin = _scene._finale
	if fin == null:
		return
	_jumpers = maxi(_jumpers, fin.jumpers.size())
	var h: float = float(player.get("height"))
	if h > _finale_air:
		_finale_air = h
	elif _finale_air > 0.0 and h == 0.0 and _finale_land == INF and not fin.entry.is_empty():
		_finale_land = -player.global_position.y - float(fin.entry["start_d"])

func _watch(player) -> void:
	var gap: float = _scene.wall_gap()
	_min_gap = minf(_min_gap, gap)
	if gap < Wall.DANGER_GAP:
		_danger_frames += 1
	var ctrl = player.get_controller()
	if ctrl.boosting:
		_boost_frames += 1
	var slow: bool = player.velocity.length() < ctrl.max_speed * 0.5
	if slow and not _was_slow:
		_slowdowns += 1
	_was_slow = slow
	_max_pack = maxi(_max_pack, get_nodes_in_group(&"enemies").size())
	var hp_now: float = player.get_hp()
	if hp_now < _last_hp:
		var hit: float = _last_hp - hp_now
		_taken += hit
		_window += hit
		# A FRESH attribution stamp names the shooter; a stale one means the
		# road did it (a smash bite, a barrel) — never bill that to whoever
		# happened to land the last bullet.
		var who = player.get("last_attacker")
		var stamp: int = player.last_attacker_ms
		var source := "road"
		if stamp != _last_stamp and who != null and is_instance_valid(who):
			var driver = who.get_node_or_null(^"Driver")
			source = String(driver.role) if driver != null and "role" in driver else "other"
		_last_stamp = stamp
		if _verbose and hit >= 8.0 and source != "road":
			var brain = who.get_node_or_null(^"Driver")
			print("[hit] t=%5.1f  %4.1f from %s  stage %s  dy %4d  dx %4d  their v (%d, %d)  your v (%d, %d)" % [
				_scene.clock, hit, source,
				Brain.Stage.keys()[brain.stage] if brain != null and "stage" in brain else "-",
				int(who.global_position.y - player.global_position.y), int(who.global_position.x - player.global_position.x),
				int(who.velocity.x), int(who.velocity.y), int(player.velocity.x), int(player.velocity.y)])
		# The botlab breadcrumb names the kind (hit_mg / hit_weapon / ram / environment).
		var kind := "?"
		if player.has_meta(&"bc_hit_kind"):
			kind = String(player.get_meta(&"bc_hit_kind"))
			player.remove_meta(&"bc_hit_kind")
		source += " (%s)" % kind
		var row: Array = _by_source.get(source, [0.0, 0])
		_by_source[source] = [row[0] + hit, row[1] + 1]
	elif hp_now > _last_hp:
		_heals += 1
	_last_hp = hp_now
	# Sortie census: how far up each bird actually got on each station.
	for bird in get_nodes_in_group(&"enemies"):
		var brain = bird.get_node_or_null(^"Driver")
		if brain == null or not ("stage" in brain) or not Brain.ROLES[brain.role].get("sortie", false):
			continue
		var flight: Dictionary = _sorties.get_or_add(bird.get_instance_id(), {"role": brain.role})
		var dy: float = bird.global_position.y - player.global_position.y   # + = behind the player
		flight[brain.stage] = minf(float(flight.get(brain.stage, INF)), dy)

func _report(player) -> void:
	var verdict := "WON" if _scene._won else "JACKED(%s)" % _scene.jack_cause
	if _scene._won and _scene._finale != null:
		var fin = _scene._finale
		var r: Dictionary = fin.entry["def"]["river"] if not fin.entry.is_empty() else {}
		var sunk := 0
		for j in fin.jumpers:
			if not is_instance_valid(j):
				sunk += 1
		print("[finale] air %d  landed d %s (channel to %s, shallows to %s)  jumpers %d  gone %d  show %.1fs" % [
			int(_finale_air), str(int(_finale_land)) if _finale_land != INF else "-",
			str(r.get("deep_to", "?")), str(r.get("shallow_to", "?")), _jumpers, sunk, _scene.clock - _scene.RUN_SECONDS])
	print("[run] %-16s car %-10s at %5.1fs  min gap %3d  danger %4.1fs  slowdowns %2d  boost %4.1fs  hp %3d/%d  TOOK %3d  heals %d  kills %d  max pack %d  dare %d  flinches %d" % [
		verdict, _car, _scene.clock, int(_min_gap), _danger_frames / 60.0, _slowdowns,
		_boost_frames / 60.0, int(maxf(_hp0 - _taken, 0.0)) if _tank else int(player.get_hp()),
		int(_hp0), int(_taken), _heals, _scene.kills, _max_pack, _scene.daredevil_bonus(), _scene.flinches])
	if _verbose:
		for source in _by_source:
			print("[src] %-32s %6.1f dmg in %3d hits (%.0f%%)" % [source, _by_source[source][0],
				_by_source[source][1], 100.0 * _by_source[source][0] / maxf(_taken, 1.0)])
		# Did the sorties land? Per class: flown (got out of the rush), got by
		# (its tail led your nose), and how it left — boxed you in, or broke
		# away up the road.
		for kind in [&"bike", &"sedan"]:
			var flown := 0
			var got_by := 0
			var boxed := 0
			var away := 0
			for id in _sorties:
				var flight: Dictionary = _sorties[id]
				if flight["role"] != kind or not flight.has(Brain.Stage.PASS):
					continue
				flown += 1
				if flight.has(Brain.Stage.BOX) or flight.has(Brain.Stage.EXIT):
					got_by += 1
				if float(flight.get(Brain.Stage.BOX, INF)) < -40.0:
					boxed += 1
				if float(flight.get(Brain.Stage.EXIT, INF)) < -300.0:
					away += 1
			print("[sortie] %-5s %2d flown  %2d got by  %2d boxed you in  %2d broke away up the road" % [
				kind, flown, got_by, boxed, away])
