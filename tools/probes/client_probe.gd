extends SceneTree
## Loopback net probe, CLIENT side: dials 127.0.0.1:NETTEST_PORT with the
## password from PROBE_PW, claims seat 2, waits for the green flag, runs the
## client shell, verifies puppets exist and the snapshot stream landed state
## on all of them — then deliberately pulls the cable (abrupt quit) so the
## host side can verify the creditless vacate. Prints CLIENT-MATCH-OK.

var net: Node
var done := false

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func _port() -> int:
	var env := OS.get_environment("NETTEST_PORT")
	return env.to_int() if env.to_int() > 1023 else 43111

func _go() -> void:
	net = root.get_node("/root/Net")
	root.get_node("/root/GameState").player_name = "ClientProbe"
	net.join_failed.connect(_on_fail)
	create_timer(20.0).timeout.connect(_bail)
	var err: String = net.join("127.0.0.1", _port(), OS.get_environment("PROBE_PW"))
	print("[probe] join dial err='", err, "'")
	_run()

func _run() -> void:
	while net.mode != net.Mode.JOINED:
		await net.session_changed
	print("[probe] joined as peer ", net.my_id())
	net.request_claim_seat(1)
	while not (net.roster and net.roster.seated(net.my_id())):
		await net.lobby_changed
	print("[probe] seated — waiting on the green flag")
	await net.match_started
	var shell: Node = load("res://levels/mp/mp_match.tscn").instantiate()
	root.add_child(shell)
	await create_timer(3.0).timeout
	var cars: Array = shell._actor_cars
	var streamed := 0
	for c in cars:
		if not c._net_b.is_empty():
			streamed += 1
	var mine_ok: bool = shell._my_car != null and shell._my_car.net_puppet \
		and shell._my_car.is_in_group(&"local_player")
	done = true
	var ok: bool = cars.size() >= 2 and streamed == cars.size() and mine_ok
	print("[probe] CLIENT-MATCH-", "OK" if ok else "FAIL",
		" cars=", cars.size(), " streamed=", streamed, " my_puppet=", mine_ok)
	print("[probe] pulling the cable")
	quit(0 if ok else 1)  # abrupt exit mid-match: the host must vacate us

func _on_fail(reason: String) -> void:
	if done:
		return
	done = true
	print("[probe] CLIENT-REJECTED: ", reason)
	quit(1)

func _bail() -> void:
	if not done:
		print("[probe] CLIENT-TIMEOUT")
		quit(1)
