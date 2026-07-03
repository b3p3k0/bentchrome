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

ERR_RE='SCRIPT ERROR|Parse Error|Parser Error|Failed to (load|instantiate)|no main scene defined|MISSING'

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
