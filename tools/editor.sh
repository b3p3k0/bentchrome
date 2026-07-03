#!/usr/bin/env bash
# Launch the Bent Chrome level editor (editor/editor_main.tscn) standalone.
# Override the engine with GODOT_BIN=/path/to/godot. Extra args pass through.
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

exec "$GODOT" --path "$PROJECT_DIR" res://editor/editor_main.tscn "$@"
