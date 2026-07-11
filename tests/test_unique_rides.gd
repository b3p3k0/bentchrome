extends RefCounted
## ONE of each car on the battlefield: the claimed set (seated picks + queue
## picks) rejects duplicate claims at every entry point, defaults slide to
## the first free ride, and the melee AI pool excludes every claimed car.
## Session-level appliers run against the live Net autoload on a scratch port
## with injected peer rows — no sockets beyond the host bind.

const Loader := preload("res://levels/level_loader.gd")

var t
var net: Node

func _init(runner) -> void:
	t = runner
	net = runner.root.get_node("/root/Net")

func test_pick_cars_multi_exclude() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var picks: Array = Loader.pick_cars(4, "bumper", rng, ["ghost", "kandykane"])
	t.check(picks.size() == 4, "rides: pool still covers the ask")
	for banned in ["bumper", "ghost", "kandykane"]:
		t.check(not picks.has(banned), "rides: excluded '%s' never picked" % banned)

func test_claimed_set_enforced() -> void:
	var err: String = net.host(43217, "", "unique rides", false)
	t.check(err.is_empty(), "rides: test session hosts")
	# Two phantom peers on the floor (auth already unit-tested elsewhere).
	net.peers[77] = {"name": "Phantom", "modded": false, "ip": ""}
	net.peers[88] = {"name": "Wraith", "modded": false, "ip": ""}

	var host_pick: String = net.roster.pick_of(1)
	t.check(not host_pick.is_empty(), "rides: host auto-seats with a pick")

	net._apply_claim_seat(77, 1)
	var p77: String = net.roster.pick_of(77)
	t.check(not p77.is_empty() and p77 != host_pick,
		"rides: second seat defaults to a FREE ride, never the host's")

	net._apply_set_pick(77, host_pick)
	t.check(net.roster.pick_of(77) == p77,
		"rides: stealing a seated pick is rejected — first come, first serve")

	net._apply_opt_next(88, true, p77)
	t.check(net.roster.queue_position(88) == -1,
		"rides: queueing in a seated ride is rejected")
	net._apply_opt_next(88, true, "kandykane" if p77 != "kandykane" and host_pick != "kandykane" else "ghost")
	t.check(net.roster.queue_position(88) == 0, "rides: a free ride queues fine")
	var q88: String = net.roster.queue_car(88)

	net._apply_set_pick(77, q88)
	t.check(net.roster.pick_of(77) == p77,
		"rides: the queue reserves rides too — no rotation collisions")

	t.check(net.taken_cars(0).size() == 3, "rides: claimed set = two seats + one queue")
	t.check(not net.taken_cars(77).has(p77), "rides: your own claim never blocks you")

	net.leave()