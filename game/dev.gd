extends Node
## Dev mode — enabled by launching with the `--dev` flag, e.g.
##   godot --path . -- --dev
## (args after `--` reach the game via OS.get_cmdline_user_args()).
## Gates dev-only tools like the tuning dashboard; off by default so shipped
## builds never show dev UI.

var enabled := false

func _ready() -> void:
	enabled = "--dev" in OS.get_cmdline_user_args()
	if enabled:
		print("[dev] on")
