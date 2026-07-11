class_name NetworkDriver
extends Driver
## Host-side driver for a remote human. The client streams intent frames
## (unreliable, latest-wins); this driver replays the newest and HOLDS it
## across gaps — a dropped packet during a held trigger is invisible. Weapon
## cycling is edge-triggered and must fire exactly once, so those arrive as
## reliable sequence-numbered events and drain one edge per physics tick.

var _intent := {}
var _last_tick := 0    # newest applied frame; stale unreliable arrivals drop
var _cycle_queue: Array = []
var _last_seq := 0     # reliable-plane dedupe (a fuzzing client replays seqs)

## Unreliable plane: newest frame wins, stale ticks are ignored.
func feed_frame(frame: Dictionary) -> void:
	var tick := int(frame.get("tick", 0))
	if tick != 0 and tick <= _last_tick:
		return
	_last_tick = tick
	_intent = frame

## Reliable plane: one +1/-1 weapon-cycle edge, applied exactly once.
func feed_cycle(seq: int, dir: int) -> void:
	if seq <= _last_seq or dir == 0:
		return
	_last_seq = seq
	_cycle_queue.append(signi(dir))

func get_intent(_vehicle, _delta: float) -> Dictionary:
	var out := _intent.duplicate()
	out["weapon_prev"] = false
	out["weapon_next"] = false
	if not _cycle_queue.is_empty():
		var dir: int = _cycle_queue.pop_front()
		out["weapon_prev"] = dir < 0
		out["weapon_next"] = dir > 0
	return out
