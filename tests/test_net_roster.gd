extends RefCounted
## NetRoster: seat arbitration, the got-next queue's structural integrity
## (every exit forfeits position), death rotation, disconnect cleanup, the
## per-format reseat predicate, and the wire round-trip.

const Roster := preload("res://game/net/net_roster.gd")

var t

func _init(runner) -> void:
	t = runner

func test_seats() -> void:
	var r := Roster.new(4)
	t.check(r.claim_seat(10, 0), "roster: open seat claims")
	t.check(not r.claim_seat(11, 0), "roster: taken seat refuses — first wins")
	t.check(r.claim_seat(11, 1), "roster: loser finds another seat")
	t.check(r.claim_seat(10, 2) and r.seat_index(10) == 2 and int(r.seats[0]) == 0,
		"roster: seated peer moving frees the old seat")
	t.check(not r.claim_seat(12, 9) and not r.claim_seat(12, -1),
		"roster: out-of-range seats refuse")
	t.check(r.leave_seat(11) and not r.seated(11), "roster: leave opens the seat")
	t.check(not r.leave_seat(11), "roster: double-leave is a no-op")
	r.claim_seat(12, 0)
	r.claim_seat(13, 1)
	r.claim_seat(14, 3)
	t.check(r.open_seat() == -1 or r.seated_ids().size() < 4, "roster: seats fill honestly")
	t.check(r.seated_ids().size() == 4, "roster: four seated")
	t.check(not r.claim_seat(15, r.seat_index(10)), "roster: fifth wheel stays an observer")

func test_queue_integrity() -> void:
	var r := Roster.new(4)
	r.opt_in(20, "ghost")
	r.opt_in(21, "bumper")
	r.opt_in(22, "ghost")
	t.check(r.queue_position(20) == 0 and r.queue_position(22) == 2,
		"queue: FIFO by opt-in order")
	# The Kevin rule: any re-entry lands at the back — pick change included.
	r.opt_in(20, "kandykane")
	t.check(r.queue_position(20) == 2, "queue: re-opt-in goes to the BACK")
	t.check(r.queue_car(20) == "kandykane", "queue: re-opt carries the new wheels")
	t.check(r.queue_position(21) == 0, "queue: everyone else moves up")
	t.check(r.opt_out(21) and r.queue_position(21) == -1, "queue: opt-out removes")
	t.check(not r.opt_out(21), "queue: double opt-out is a no-op")
	var front: Dictionary = r.pop_next()
	t.check(int(front.id) == 22, "queue: pop takes the front")
	t.check(int(r.pop_next().get("id", 0)) == 20 and r.pop_next().is_empty(),
		"queue: drains to empty")

func test_seating_leaves_queue() -> void:
	var r := Roster.new(4)
	r.opt_in(30, "ghost")
	r.claim_seat(30, 0)
	t.check(r.queue_position(30) == -1, "queue: taking a seat leaves the line")

func test_rotation() -> void:
	var r := Roster.new(4)
	r.claim_seat(40, 0)
	r.set_pick(40, "bumper")
	r.opt_in(41, "ghost")
	var freed: int = r.rotate_out(40)
	t.check(freed == 0, "rotation: reports the freed seat")
	t.check(not r.seated(40), "rotation: deceased loses the seat")
	t.check(r.queue_position(40) == 1, "rotation: deceased rides to the BACK of the line")
	t.check(r.queue_car(40) == "bumper", "rotation: deceased keeps their locked pick")
	t.check(r.rotate_out(99) == -1, "rotation: unseated peer is a no-op")

func test_drop_peer() -> void:
	var r := Roster.new(4)
	r.claim_seat(50, 0)
	r.set_pick(50, "ghost")
	r.opt_in(51, "bumper")
	r.drop_peer(50)
	r.drop_peer(51)
	t.check(not r.seated(50) and r.pick_of(50).is_empty(), "drop: seat and pick cleared")
	t.check(r.queue_position(51) == -1, "drop: no place-holding in the queue")

func test_reseat_predicate() -> void:
	t.check(Roster.mid_match_reseat(&"brawl"), "policy: brawl reseats mid-match")
	t.check(Roster.mid_match_reseat(&"frag"), "policy: frag reseats mid-match")
	t.check(Roster.mid_match_reseat(&"timed"), "policy: timed reseats mid-match")
	t.check(not Roster.mid_match_reseat(&"lives"), "policy: lives elim locks the roster")

func test_unique_name() -> void:
	t.check(Roster.unique_name("Hotrod", []) == "Hotrod", "names: clean name passes")
	t.check(Roster.unique_name("Hotrod", ["Hotrod"]) == "Hotrod #2",
		"names: second Hotrod gets numbered")
	t.check(Roster.unique_name("Hotrod", ["Hotrod", "Hotrod #2"]) == "Hotrod #3",
		"names: numbering keeps counting")

func test_wire_round_trip() -> void:
	var r := Roster.new(4)
	r.claim_seat(60, 1)
	r.set_pick(60, "ghost")
	r.opt_in(61, "bumper")
	r.opt_in(62, "kandykane")
	var mirror := Roster.new(4)
	mirror.from_dict(r.to_dict())
	t.check(mirror.seat_index(60) == 1, "wire: seats survive")
	t.check(mirror.pick_of(60) == "ghost", "wire: picks survive")
	t.check(mirror.queue_position(61) == 0 and mirror.queue_position(62) == 1,
		"wire: queue order survives")
	mirror.opt_in(63, "ghost")
	t.check(mirror.queue_position(63) == 2, "wire: order counter resumes past the max")