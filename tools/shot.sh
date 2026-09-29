#!/usr/bin/env bash
# Render a PackedScene to a PNG through the level-shot SubViewport probe.
# Usage: tools/shot.sh <scene.tscn> <out.png> [--center=X,Y] [--zoom=Z]
#        [--size=W,H] [--frames=N]
# In fit mode (--zoom omitted or 0), --center defaults to the arena centre.
set -uo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: tools/shot.sh <scene.tscn> <out.png> [--center=X,Y] [--zoom=Z] [--size=W,H] [--frames=N]" >&2
  echo "       In fit mode (--zoom omitted or 0), --center defaults to the arena centre." >&2
  exit 2
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "ERROR: xvfb-run not found. Install it with: sudo apt install xvfb" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

SCENE_ARG="$1"
OUT_ARG="$2"
shift 2

if [[ "$SCENE_ARG" == res://* ]]; then
  SCENE_PATH="$SCENE_ARG"
else
  SCENE_PATH="${SCENE_ARG#./}"
  SCENE_PATH="res://$SCENE_PATH"
fi

if [[ "$OUT_ARG" == /* ]]; then
  OUT_PATH="$OUT_ARG"
else
  OUT_PATH="$PWD/$OUT_ARG"
fi

LOG="$(timeout 120 xvfb-run -a "$GODOT" --rendering-driver opengl3 \
  --path "$PROJECT_DIR" -s res://tools/probes/level_shot.gd -- \
  "--scene=$SCENE_PATH" "--out=$OUT_PATH" "$@" 2>&1)"
CODE=$?
echo "$LOG"

if [[ $CODE -eq 124 ]]; then
  echo "[shot] ERROR: timed out after 120s" >&2
  exit 1
fi
if [[ $CODE -ne 0 ]] || [[ ! -f "$OUT_PATH" ]] \
    || ! grep -qF '[shot] wrote' <<<"$LOG"; then
  echo "[shot] ERROR: capture failed" >&2
  exit 1
fi
