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

# Difficulty select: the DMV window between title and the roster — a new
# .tscn gets zero cold-load coverage from the import stage alone.
echo "== smoke: difficulty select"
DIFF_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" res://ui/difficulty_select.tscn --quit-after 10 2>&1)"
if echo "$DIFF_OUT" | grep -qiE "$ERR_RE"; then
  echo "$DIFF_OUT" | grep -iE "$ERR_RE"
  echo "== smoke: FAIL (difficulty select)"; exit 1
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

# Campaign levels: boot each hand-authored scene cold (parse errors, broken
# instances, and load cycles in level content all surface here).
for LEVEL in levels/freeway/freeway.tscn levels/suburbs/suburbs.tscn levels/snowy/snowy.tscn levels/depot/depot.tscn levels/dock/dock.tscn levels/chase/buzzard_run.tscn levels/stadium/stadium.tscn; do
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
