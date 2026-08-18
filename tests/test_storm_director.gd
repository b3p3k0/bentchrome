extends RefCounted
## Capital thunderstorm: the strike cycle runs boom -> lead -> blinding flash
## -> darkness dip -> eased recover, cadence stays inside its bounds, distant
## strikes skip the flash, the tint joins night_arena, and nothing ever
## touches the tree pause. Statics are restored after every mutation.

const StormScript := preload("res://levels/capital/storm_director.gd")

var t

func _init(runner) -> void:
	t = runner

func _fresh() -> Node2D:
	var storm: Node2D = StormScript.new()
	t.root.add_child(storm)
	return storm

func test_full_strike_cycle_ordering() -> void:
	var keep_distant: float = StormScript.DISTANT_CHANCE
	StormScript.DISTANT_CHANCE = 0.0  # force a full flash strike
	var storm := _fresh()
	var tint: CanvasModulate = storm.get_node("StormTint")
	t.check(tint.color == StormScript.BASE_TINT, "storm: opens on the base tint")
	t.check(tint.is_in_group(&"night_arena"), "storm: tint joins night_arena for blooms")
	storm.phase_timer = 0.01
	storm.tick(0.02)  # IDLE expires -> boom + LEAD
	t.check(storm.phase == StormScript.Phase.LEAD, "storm: strike leads with the boom")
	storm.tick(StormScript.THUNDER_LEAD + 0.01)
	t.check(storm.phase == StormScript.Phase.FLASH and tint.color == StormScript.FLASH_TINT,
		"storm: the sky tears open after the lead")
	t.check(tint.color.r > StormScript.BASE_TINT.r, "storm: flash is brighter than base")
	storm.tick(StormScript.FLASH_SECONDS + 0.01)
	t.check(storm.phase == StormScript.Phase.DIP and tint.color == StormScript.DIP_TINT,
		"storm: flash plunges into the readjustment dip")
	t.check(tint.color.r < StormScript.BASE_TINT.r, "storm: dip is darker than base")
	storm.tick(StormScript.DIP_SECONDS + 0.01)
	t.check(storm.phase == StormScript.Phase.RECOVER, "storm: dip eases into recover")
	storm.tick(StormScript.RECOVER_SECONDS * 0.5)
	t.check(tint.color.r > StormScript.DIP_TINT.r and tint.color.r < StormScript.BASE_TINT.r,
		"storm: recover lerps between dip and base")
	storm.tick(StormScript.RECOVER_SECONDS)
	t.check(storm.phase == StormScript.Phase.IDLE and tint.color == StormScript.BASE_TINT,
		"storm: cycle closes back on the waiting base")
	t.check(storm.phase_timer >= StormScript.CADENCE_MIN
		and storm.phase_timer <= StormScript.CADENCE_MAX,
		"storm: next strike lands inside the cadence bounds")
	t.check(not t.root.get_tree().paused, "storm: never touches the tree pause")
	StormScript.DISTANT_CHANCE = keep_distant
	t.root.remove_child(storm)
	storm.free()

func test_distant_strike_is_sound_only() -> void:
	var keep_distant: float = StormScript.DISTANT_CHANCE
	StormScript.DISTANT_CHANCE = 1.0  # every strike stays beyond the river
	var storm := _fresh()
	var tint: CanvasModulate = storm.get_node("StormTint")
	storm.phase_timer = 0.01
	storm.tick(0.02)
	t.check(storm.phase == StormScript.Phase.IDLE and tint.color == StormScript.BASE_TINT,
		"storm: distant strike skips the flash entirely")
	StormScript.DISTANT_CHANCE = keep_distant
	t.root.remove_child(storm)
	storm.free()

func test_thunder_event_registered() -> void:
	var catalog: Dictionary = load("res://game/audio_director.gd").CATALOG
	t.check(catalog.has(&"thunder"), "storm: thunder rides the drop-in sfx registry")
