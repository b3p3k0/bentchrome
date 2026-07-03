#!/usr/bin/env bash
# Headless unit tests for Bent Chrome (tests/run_tests.gd). Belt-and-braces like
# smoke.sh: requires exit 0 AND the "TESTS: PASS" line AND no script errors,
# since Godot exit codes alone are unreliable with -s scripts.
# Override the engine with GODOT_BIN=/path/to/godot.
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

ERR_RE='SCRIPT ERROR|Parse Error|Parser Error|Failed to (load|instantiate)'

# Fresh checkout: class_name globals need the .godot/ cache before -s can parse.
if [[ ! -d "$PROJECT_DIR/.godot" ]]; then
  "$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true
fi

echo "== tests: engine $("$GODOT" --version 2>/dev/null | head -n1)"
# timeout guard: if the runner script fails to compile, quit() never runs and
# headless Godot idles forever — never let that hang CI.
OUT="$(timeout 120 "$GODOT" --headless --path "$PROJECT_DIR" -s res://tests/run_tests.gd 2>&1)"
CODE=$?
if [[ $CODE -eq 124 ]]; then
  echo "$OUT"
  echo "== tests: FAIL (timed out — runner likely failed to compile and never quit)"
  exit 1
fi
echo "$OUT"
if [[ $CODE -ne 0 ]] || echo "$OUT" | grep -qiE "$ERR_RE" || ! echo "$OUT" | grep -q '^TESTS: PASS'; then
  echo "== tests: FAIL"
  exit 1
fi
echo "== tests: PASS"
