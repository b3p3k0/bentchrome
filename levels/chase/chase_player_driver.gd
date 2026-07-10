extends PlayerDriver
## The forced-scroll pace pedal: player input as normal, but the throttle
## never drops below the floor — braking eases you toward the minimum band,
## full stops and reverse don't exist on the Buzzard Run. Everything else
## (steer, weapons, handbrake, boost) passes straight through.

static var MIN_THROTTLE := 0.45

func get_intent(vehicle, delta: float) -> Dictionary:
	var intent := super(vehicle, delta)
	intent["throttle"] = maxf(intent["throttle"], MIN_THROTTLE)
	return intent
