class_name NetRoster
extends RefCounted
## Seats, observers, and the "I got Next!" queue — the pure lobby model the
## host owns and clients mirror. Queue integrity is STRUCTURAL: opt_in always
## lands at the back, and every path out of the queue (opt-out, pick change,
## seating, disconnect) goes through opt_out first — position never survives
## an exit. Observers are implicit: any connected peer without a seat.

const Proto := preload("res://game/net/net_protocol.gd")

var seats: Array = []  # seat index -> peer id (0 = open)
var picks := {}        # peer id -> car id String (seated garage pick)
var queue: Array = []  # [{id, car, order}] — FIFO by monotonic order
var _order := 0

func _init(seat_count: int = Proto.MAX_PLAYERS) -> void:
	seats.resize(seat_count)
	seats.fill(0)

# ------------------------------------------------------------------- seats

func seat_index(id: int) -> int:
	return seats.find(id)

func seated(id: int) -> bool:
	return seat_index(id) >= 0

func seated_ids() -> Array:
	return seats.filter(func(id: int) -> bool: return id != 0)

func open_seat() -> int:
	return seats.find(0)

## First claim wins (the host processes requests serially); a seated peer
## claiming another open seat moves. Seating always leaves the queue.
func claim_seat(id: int, idx: int) -> bool:
	if id == 0 or idx < 0 or idx >= seats.size() or seats[idx] != 0:
		return false
	var current := seat_index(id)
	if current >= 0:
		seats[current] = 0
	seats[idx] = id
	opt_out(id)
	return true

func leave_seat(id: int) -> bool:
	var idx := seat_index(id)
	if idx < 0:
		return false
	seats[idx] = 0
	return true

func set_pick(id: int, car: String) -> void:
	picks[id] = car

func pick_of(id: int) -> String:
	return String(picks.get(id, ""))

# ------------------------------------------------------------------- queue

## Opt in (or re-opt to change the car): ALWAYS the back of the line.
func opt_in(id: int, car: String) -> int:
	opt_out(id)
	_order += 1
	queue.append({"id": id, "car": car, "order": _order})
	return queue.size() - 1

func opt_out(id: int) -> bool:
	for i in queue.size():
		if int(queue[i].id) == id:
			queue.remove_at(i)
			return true
	return false

func queue_position(id: int) -> int:
	for i in queue.size():
		if int(queue[i].id) == id:
			return i
	return -1

func queue_car(id: int) -> String:
	var pos := queue_position(id)
	return String(queue[pos].car) if pos >= 0 else ""

## Front of the line, removed. {} when nobody's waiting.
func pop_next() -> Dictionary:
	return {} if queue.is_empty() else queue.pop_front()

## Death rotation: the seat opens, the deceased rides to the BACK of the
## queue in the car they already picked. Returns the freed seat index.
func rotate_out(id: int) -> int:
	var idx := seat_index(id)
	if idx < 0:
		return -1
	seats[idx] = 0
	opt_in(id, pick_of(id))
	return idx

## Disconnect/kick/ban cleanup: no place-holding of any kind.
func drop_peer(id: int) -> void:
	leave_seat(id)
	opt_out(id)
	picks.erase(id)

# ----------------------------------------------------------------- policy

## Lives Elimination locks rosters mid-match; every other format reseats on
## the unified seat-fill rule (open seat + non-empty queue => front seats).
static func mid_match_reseat(format: StringName) -> bool:
	return format != &"lives"

## Host-side callsign dedupe: second Hotrod becomes "Hotrod #2".
static func unique_name(base: String, taken: Array) -> String:
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s #%d" % [base, n]):
		n += 1
	return "%s #%d" % [base, n]

# ------------------------------------------------------------------- wire

func to_dict() -> Dictionary:
	return {
		"seats": seats.duplicate(),
		"picks": picks.duplicate(),
		"queue": queue.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	var raw_seats: Array = d.get("seats", [])
	seats.fill(0)
	for i in mini(raw_seats.size(), seats.size()):
		seats[i] = int(raw_seats[i])
	picks = {}
	var raw_picks: Dictionary = d.get("picks", {})
	for k in raw_picks:
		picks[int(k)] = String(raw_picks[k])
	queue = []
	_order = 0
	for entry in d.get("queue", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var order := int(entry.get("order", _order + 1))
		queue.append({"id": int(entry.get("id", 0)), "car": String(entry.get("car", "")),
			"order": order})
		_order = maxi(_order, order)
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.order) < int(b.order))
