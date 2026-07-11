extends SceneTree
## Loopback net probe, HOST side (tools/nettest.sh drives the pair): hosts on
## NETTEST_PORT with password "sesame", waits for a second seated driver,
## starts a Grand Melee, runs the real match shell (current_scene is null
## under -s, so the auto scene-swap stands down and we mount it by hand),
## then waits for the client's deliberate cable pull and verifies the
## creditless vacate. Prints HOST-MATCH-OK and HOST-VACATE-OK; exits 0/1.

var net: Node
var done := false
var shell: Node = null

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func _port() -> int:
	var env := OS.get_environment("NETTEST_PORT")
	return env.to_int() if env.to_int() > 1023 else 43111

func _go() -> void:
	net = root.get_node("/root/Net")
	root.get_node("/root/GameState").player_name = "HostProbe"
	var err: String = net.host(_port(), "sesame", "probe garage", false)
	print("[probe] host start err='", err, "'")
	if not err.is_empty():
		quit(1)
		return
	net.lobby_changed.connect(_maybe_start)
	net.match_started.connect(_enter_match)
	create_timer(30.0).timeout.connect(_bail)

func _maybe_start() -> void:
	if done or shell != null or net.roster == null:
		return
	if net.roster.seated_ids().size() >= 2:
		print("[probe] two seated — green flag")
		net.start_match()

func _enter_match() -> void:
	if shell != null:
		return
	shell = load("res://levels/mp/mp_match.tscn").instantiate()
	root.add_child(shell)
	create_timer(3.0).timeout.connect(_check)

func _check() -> void:
	if done:
		return
	print("[probe] HOST-MATCH-OK cars=", shell._actor_cars.size(),
		" actors=", net.match_actors.size(), " live=", net.match_live)
	# Now wait out the client's cable pull and verify the vacate.
	create_timer(8.0).timeout.connect(_check_vacate)

func _check_vacate() -> void:
	if done:
		return
	done = true
	var director: Node = shell.get_node("MatchDirector")
	var slot: Dictionary = director.actors[1]
	var flagged := false
	for peer in director.scores:
		if bool(director.scores[peer].get("gone", false)):
			flagged = true
	var ok: bool = net.peers.size() == 1 and int(slot.peer) == 0 and flagged
	print("[probe] HOST-VACATE-", "OK" if ok else "FAIL",
		" peers=", net.peers.size(), " slot_peer=", int(slot.peer),
		" row_flagged=", flagged)
	create_timer(1.0).timeout.connect(func() -> void: quit(0 if ok else 1))

func _bail() -> void:
	if not done:
		print("[probe] HOST-TIMEOUT")
		quit(1)
