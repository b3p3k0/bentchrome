extends RefCounted
## The callsign roulette's pantry: comment/blank skipping, the NAME_MAX trim,
## user-copy-over-shipped preference, the copy-on-first-visit, graceful
## degradation to a lone Wastelander, and a reroll that never repeats.

const TMP := "user://_test_callsigns.txt"
const Roulette := preload("res://ui/callsigns.gd")

var t

func _init(runner) -> void:
	t = runner

func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_loader_and_roulette() -> void:
	DirAccess.remove_absolute(TMP)
	_write("# a comment\n\nRust Bucket\n  Mad Mags  \nA Name Far Too Long For Any Dashboard Plate\n")
	var names: Array[String] = Roulette.load_names(TMP)
	t.check(names.size() == 3, "callsigns: comments and blanks skipped")
	t.check(names[0] == "Rust Bucket" and names[1] == "Mad Mags",
		"callsigns: whitespace trimmed")
	t.check(names[2].length() == Roulette.NAME_MAX,
		"callsigns: long names trimmed to the handshake cap")

	# A missing user copy falls back to the shipped list.
	var shipped: Array[String] = Roulette.load_names("user://_no_such_file.txt")
	t.check(shipped.size() >= 30, "callsigns: shipped roster loads and is stocked")

	var lonely: Array[String] = Roulette.load_names("user://_no_a.txt", "user://_no_b.txt")
	t.check(lonely.size() == 1 and lonely[0] == "Wastelander",
		"callsigns: both files gone degrades to a lone Wastelander")

	# Copy-on-first-visit: lands once, then never clobbers edits.
	DirAccess.remove_absolute(TMP)
	Roulette.ensure_user_copy(TMP)
	t.check(FileAccess.file_exists(TMP), "callsigns: first visit copies the shipped list")
	_write("Only Me\n")
	Roulette.ensure_user_copy(TMP)
	var kept: Array[String] = Roulette.load_names(TMP)
	t.check(kept.size() == 1 and kept[0] == "Only Me",
		"callsigns: an edited user copy is never clobbered")

	_write("Alpha\nBravo\n")
	var never_repeats := true
	for i in 12:
		if Roulette.random_name("Alpha", TMP) != "Bravo":
			never_repeats = false
	t.check(never_repeats, "callsigns: reroll never repeats when the list offers a choice")
	var spins := {}
	for i in 24:
		spins[Roulette.random_name("", TMP)] = true
	t.check(spins.size() >= 2, "callsigns: the roulette actually spins")

	DirAccess.remove_absolute(TMP)