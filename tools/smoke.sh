#!/usr/bin/env bash
# Headless smoke check for Bent Chrome: import the project and boot it,
# failing on any script/parse error, failed load, or missing autoload.
# Used locally and by CI. Override the engine with GODOT_BIN=/path/to/godot.
set -uo pipefail

PROJECT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

GODOT="${GODOT_BIN:-}"
if [[ -z "$GODOT" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT="godot"
  elif [[ -x "$HOME/.local/bin/godot" ]]; then
    GODOT="$HOME/.local/bin/godot"
  fi
fi
if [[ -z "$GODOT" ]]; then
  echo "ERROR: Godot not found. Put it on PATH or set GODOT_BIN=/path/to/godot" >&2
  exit 2
fi

ERR_RE='SCRIPT ERROR|Parse Error|Parser Error|Failed to (load|instantiate)|no main scene defined|MISSING|referenced non-existent resource'

echo "== smoke: engine $("$GODOT" --version 2>/dev/null | head -n1)"
echo "== smoke: project $PROJECT_DIR"

echo "== smoke: import"
IMPORT_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1)"
if echo "$IMPORT_OUT" | grep -qiE "$ERR_RE"; then
  echo "$IMPORT_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (import)"; exit 1
fi

echo "== smoke: boot"
BOOT_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" --quit-after 5 2>&1)"
echo "$BOOT_OUT" | grep -E '^\[boot\]' || true
if echo "$BOOT_OUT" | grep -qiE "$ERR_RE"; then
  echo "$BOOT_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (boot)"; exit 1
fi

# Mode select: the garage door between title and the SP chain.
echo "== smoke: mode select"
MODE_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/mode_select.tscn --quit-after 10 2>&1)"
if echo "$MODE_OUT" | grep -qiE "$ERR_RE"; then
  echo "$MODE_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (mode select)"; exit 1
fi

# Difficulty select: the DMV window between mode select and the roster — a new
# .tscn gets zero cold-load coverage from the import stage alone.
echo "== smoke: difficulty select"
DIFF_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/difficulty_select.tscn --quit-after 10 2>&1)"
if echo "$DIFF_OUT" | grep -qiE "$ERR_RE"; then
  echo "$DIFF_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (difficulty select)"; exit 1
fi

# Level select: SINGLE BATTLE's fight card between the DMV and the roster.
echo "== smoke: level select"
LVLSEL_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/level_select.tscn --quit-after 10 2>&1)"
if echo "$LVLSEL_OUT" | grep -qiE "$ERR_RE"; then
  echo "$LVLSEL_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (level select)"; exit 1
fi

# Cold roster load: car_select pulls every vehicle .tres -> weapon defs ->
# projectile scenes. This entry path exposes circular resource loads (the
# boot stage never touches the roster, and the test runner warms the class
# cache in a cycle-free order — both miss them).
echo "== smoke: roster (car select)"
ROSTER_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/car_select.tscn --quit-after 10 2>&1)"
if echo "$ROSTER_OUT" | grep -qiE "$ERR_RE"; then
  echo "$ROSTER_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (roster)"; exit 1
fi

# Multiplayer front door: cold-boot the menu (Net autoload wiring, net module
# preloads, and the panel builders all surface here; no sockets get opened).
echo "== smoke: mp menu"
MP_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/mp_menu.tscn --quit-after 10 2>&1)"
if echo "$MP_OUT" | grep -qiE "$ERR_RE" || ! echo "$MP_OUT" | grep -q '^\[boot\] mp menu ready'; then
  echo "$MP_OUT" | grep -iE "$ERR_RE" || true
  echo "== smoke: FAIL (mp menu)"; exit 1
fi

# Garage lobby: cold-boot with no session (must render the dark-garage path).
echo "== smoke: mp lobby"
LOBBY_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/mp_lobby.tscn --quit-after 10 2>&1)"
if echo "$LOBBY_OUT" | grep -qiE "$ERR_RE" || ! echo "$LOBBY_OUT" | grep -q '^\[boot\] mp lobby ready'; then
  echo "$LOBBY_OUT" | grep -iE "$ERR_RE" || true
  echo "== smoke: FAIL (mp lobby)"; exit 1
fi

# MP match shell: cold-boot with no session (must bail to the front door
# without touching an arena or a socket).
echo "== smoke: mp match"
MATCH_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://levels/mp/mp_match.tscn --quit-after 10 2>&1)"
if echo "$MATCH_OUT" | grep -qiE "$ERR_RE" || ! echo "$MATCH_OUT" | grep -q '^\[boot\] mp match ready'; then
  echo "$MATCH_OUT" | grep -iE "$ERR_RE" || true
  echo "== smoke: FAIL (mp match)"; exit 1
fi

# Scoreboard: cold-boot with no verdict (must render the empty-record path).
echo "== smoke: mp scoreboard"
SCORE_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/mp_scoreboard.tscn --quit-after 10 2>&1)"
if echo "$SCORE_OUT" | grep -qiE "$ERR_RE" || ! echo "$SCORE_OUT" | grep -q '^\[boot\] mp scoreboard ready'; then
  echo "$SCORE_OUT" | grep -iE "$ERR_RE" || true
  echo "== smoke: FAIL (mp scoreboard)"; exit 1
fi

# Campaign levels: boot each hand-authored scene cold (parse errors, broken
# instances, and load cycles in level content all surface here).
for LEVEL in levels/arena_assault/arena_assault.tscn levels/downtown/downtown.tscn levels/freeway/freeway.tscn levels/suburbs/suburbs.tscn levels/snowy/snowy.tscn levels/depot/depot.tscn levels/dock/dock.tscn levels/chase/buzzard_run.tscn levels/construction/ground_floor_gore.tscn levels/stadium/stadium.tscn levels/tutorial/drivers_ed.tscn; do
  echo "== smoke: level ($LEVEL)"
  LEVEL_BOOT="$("$GODOT" --headless --path "$PROJECT_DIR" "res://$LEVEL" --quit-after 10 2>&1)"
  if echo "$LEVEL_BOOT" | grep -qiE "$ERR_RE" || ! echo "$LEVEL_BOOT" | grep -q '^\[boot\] level ready'; then
    echo "$LEVEL_BOOT" | grep -iE "$ERR_RE" || true
    echo "== smoke: FAIL ($LEVEL)"; exit 1
  fi
done

echo "== smoke: custom level (fixture)"
LEVEL_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://levels/custom_level.tscn --quit-after 10 -- --level=res://tests/fixtures/sample_level.json 2>&1)"
echo "$LEVEL_OUT" | grep -E '^\[boot\]' || true
if echo "$LEVEL_OUT" | grep -qiE "$ERR_RE" || ! echo "$LEVEL_OUT" | grep -q '^\[boot\] custom level ready'; then
  echo "$LEVEL_OUT" | grep -iE "$ERR_RE" || true
  echo "== smoke: FAIL (custom level)"; exit 1
fi

echo "== smoke: editor"
EDITOR_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://editor/editor_main.tscn --quit-after 10 2>&1)"
echo "$EDITOR_OUT" | grep -E '^\[boot\]' || true
if echo "$EDITOR_OUT" | grep -qiE "$ERR_RE" || ! echo "$EDITOR_OUT" | grep -q '^\[boot\] editor ready'; then
  echo "$EDITOR_OUT" | grep -iE "$ERR_RE" || true
  echo "== smoke: FAIL (editor)"; exit 1
fi

echo "== smoke: PASS"
