extends RefCounted
## NetBanlist: bans persist across instances (host restarts), unban sticks,
## corrupt files degrade to empty, junk input is ignored. Throwaway path only.

const TMP := "user://_test_banlist.json"
const Bans := preload("res://game/net/net_banlist.gd")

var t

func _init(runner) -> void:
	t = runner

func test_banlist_lifecycle() -> void:
	DirAccess.remove_absolute(TMP)
	var bans := Bans.new(TMP)
	t.check(not bans.is_banned("10.0.0.66"), "banlist: fresh list bans nobody")

	bans.ban("10.0.0.66")
	bans.ban("192.168.1.9")
	bans.ban("")
	t.check(bans.is_banned("10.0.0.66"), "banlist: ban lands")
	t.check(bans.all() == ["10.0.0.66", "192.168.1.9"], "banlist: sorted, empty ip ignored")

	var reloaded := Bans.new(TMP)
	t.check(reloaded.is_banned("10.0.0.66") and reloaded.is_banned("192.168.1.9"),
		"banlist: bans survive a host restart")

	reloaded.unban("10.0.0.66")
	var third := Bans.new(TMP)
	t.check(not third.is_banned("10.0.0.66") and third.is_banned("192.168.1.9"),
		"banlist: unban persists too")

	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{corrupt")
	f.close()
	var corrupt := Bans.new(TMP)
	t.check(not corrupt.is_banned("192.168.1.9"), "banlist: corrupt file degrades to empty")

	DirAccess.remove_absolute(TMP)
