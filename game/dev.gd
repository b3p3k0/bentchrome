extends Node
## Dev mode — toggled from the settings menu (DEVELOPER MODE row) and persisted
## with the other settings; the old `--dev` cmdline flag is retired. Gates
## dev-only tools like the F1 tuning dashboard; off by default so shipped
## builds never show dev UI. The settings screen flips this live.

var enabled := false

func _ready() -> void:
	# Dev sits BEFORE GameState in the autoload order, so its settings haven't
	# loaded yet — sync after the boot frame settles.
	_sync_from_settings.call_deferred()

func _sync_from_settings() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	enabled = gs.dev_mode if gs else false
	if enabled:
		print("[dev] on")
