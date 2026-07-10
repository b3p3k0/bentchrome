extends PlayerDriver
## The forced-scroll pace pedal: hands off and the car cruises at the floor,
## W sprints — but S is a REAL brake. Slowing down (even stopping) to let
## pursuers blow past is a legal play; the rubberbanded horde wall makes it a
## calculated risk, not a rest. Everything else (steer, weapons, handbrake,
## boost) passes straight through.

static var MIN_THROTTLE := 0.45

func get_intent(vehicle, delta: float) -> Dictionary:
	var intent := super(vehicle, delta)
	var raw: float = intent["throttle"]
	intent["throttle"] = raw if raw < -0.05 else maxf(raw, MIN_THROTTLE)
	return intent
