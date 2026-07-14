extends Node
## Autoload `Updater` — in-game "Check for Updates" client.
##
## Net-free and GameState-free by design (mirrors how game/net keeps its state
## isolated). It only ever CHECKS a tagged GitHub Release and DOWNLOADS the
## attached archive to a staging dir inside the repo; it never applies the
## update itself. The file-swap + reimport happen in the PLAY launcher while
## Godot is NOT running (no self-overwrite, no file-lock hazard). See
## docs/releasing.md and the plan for the full flow.

signal state_changed(state: int)
signal progress_changed(fraction: float)

enum State { IDLE, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, DOWNLOADED, ERROR }

# --- release source ----------------------------------------------------------
## Master switch for the whole feature. Left OFF until the first GitHub Release
## is published, so testers can't hit a "check" that finds nothing. Flip to true
## (one line) to light up the Settings row and go live. See docs/releasing.md.
const RELEASES_LIVE := false

const REPO := "b3p3k0/bentchrome"
const API_LATEST := "https://api.github.com/repos/%s/releases/latest" % REPO
const USER_AGENT := "BentChrome-Updater"  # GitHub 403s a request with no UA

const STAGE_DIR := "res://.updates"
const PENDING_ZIP := "res://.updates/pending.zip"
const APPLY_JSON := "res://.updates/apply.json"

var state: int = State.IDLE
var latest_version := ""
var changelog := ""
var error_text := ""
var download_fraction := 0.0

var _http: HTTPRequest
var _mode := 0  # 0 = idle, 1 = check, 2 = download
var _asset_url := ""
var _asset_size := 0
var _asset_sha256 := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	set_process(false)

func current_version() -> String:
	return BuildInfo.current()

# --- check -------------------------------------------------------------------

func check() -> void:
	if state == State.CHECKING or state == State.DOWNLOADING:
		return
	_reset_release()
	_set_state(State.CHECKING)
	_mode = 1
	_http.download_file = ""
	var headers := [
		"Accept: application/vnd.github+json",
		"User-Agent: " + USER_AGENT,
	]
	var err := _http.request(API_LATEST, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_fail("Couldn't reach the update server.")

func _on_check_completed(response_code: int, body: PackedByteArray) -> void:
	if response_code != 200:
		_fail("Update check failed (HTTP %d)." % response_code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_fail("Update server sent something unexpected.")
		return
	latest_version = String(data.get("tag_name", "")).strip_edges()
	changelog = String(data.get("body", "")).strip_edges()
	if latest_version == "":
		_fail("No published release found.")
		return
	_pick_asset(data.get("assets", []))
	if _asset_url == "":
		_fail("Release has no downloadable archive yet.")
		return
	if latest_version == current_version():
		_set_state(State.UP_TO_DATE)
	else:
		_set_state(State.AVAILABLE)

func _pick_asset(assets: Variant) -> void:
	if typeof(assets) != TYPE_ARRAY:
		return
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var name := String(a.get("name", ""))
		if not name.to_lower().ends_with(".zip"):
			continue
		_asset_url = String(a.get("browser_download_url", ""))
		_asset_size = int(a.get("size", 0))
		# GitHub returns "sha256:HEX" in `digest` on newer API responses; the
		# launcher verifies against it before extracting. Absent = no gate.
		var digest := String(a.get("digest", ""))
		_asset_sha256 = digest.trim_prefix("sha256:") if digest.begins_with("sha256:") else ""
		return

# --- download ----------------------------------------------------------------

func download() -> void:
	if state != State.AVAILABLE or _asset_url == "":
		return
	DirAccess.make_dir_recursive_absolute(STAGE_DIR)
	# Keep Godot's importer out of the staging dir — the zip is transient data,
	# not a project resource (the launcher clears it before the headless import).
	if not FileAccess.file_exists(STAGE_DIR + "/.gdignore"):
		var ig := FileAccess.open(STAGE_DIR + "/.gdignore", FileAccess.WRITE)
		if ig:
			ig.close()
	download_fraction = 0.0
	_set_state(State.DOWNLOADING)
	_mode = 2
	_http.download_file = PENDING_ZIP
	var headers := [
		"Accept: application/octet-stream",
		"User-Agent: " + USER_AGENT,
	]
	var err := _http.request(_asset_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_fail("Couldn't start the download.")
		return
	set_process(true)

func _process(_delta: float) -> void:
	if state != State.DOWNLOADING:
		set_process(false)
		return
	var total := _http.get_body_size()
	if total <= 0:
		total = _asset_size
	if total > 0:
		download_fraction = clampf(float(_http.get_downloaded_bytes()) / float(total), 0.0, 1.0)
		progress_changed.emit(download_fraction)

func _on_download_completed(result: int, response_code: int) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		_fail("Download failed — try again.")
		return
	if not FileAccess.file_exists(PENDING_ZIP):
		_fail("Download produced no file.")
		return
	var apply := {
		"version": latest_version,
		"zip": "pending.zip",
		"sha256": _asset_sha256,
	}
	var f := FileAccess.open(APPLY_JSON, FileAccess.WRITE)
	if f == null:
		_fail("Couldn't stage the update.")
		return
	f.store_string(JSON.stringify(apply, "\t"))
	f.close()
	download_fraction = 1.0
	_set_state(State.DOWNLOADED)

# --- restart / apply-on-next-launch ------------------------------------------

## Relaunch through the PLAY launcher, which applies any staged update before
## booting the game, then quit this instance. Returns false if the launcher
## couldn't be started (caller should fall back to a "close and reopen" prompt).
func relaunch() -> bool:
	var repo := ProjectSettings.globalize_path("res://")
	var launcher := repo.path_join("PLAY.cmd" if OS.get_name() == "Windows" else "PLAY.sh")
	if not FileAccess.file_exists(launcher):
		return false
	var pid := OS.create_process(launcher, [])
	if pid <= 0:
		return false
	get_tree().quit()
	return true

# --- plumbing ----------------------------------------------------------------

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	match _mode:
		1:
			_mode = 0
			if result != HTTPRequest.RESULT_SUCCESS:
				_fail("Couldn't reach the update server.")
			else:
				_on_check_completed(response_code, body)
		2:
			_mode = 0
			_on_download_completed(result, response_code)

func _reset_release() -> void:
	latest_version = ""
	changelog = ""
	error_text = ""
	_asset_url = ""
	_asset_size = 0
	_asset_sha256 = ""

func _fail(msg: String) -> void:
	error_text = msg
	_set_state(State.ERROR)

func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)
