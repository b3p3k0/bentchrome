#!/usr/bin/env bash
# Route 666 balance sweep: full runs on autopilot, one headless process each
# (~3s a run), then a tally. The autopilot never dodges fire, hunts pickups,
# or uses rear weapons — read the win rate as a FLOOR for a real player.
#
#   tools/chase_probe.sh                     # every roster car, 3 runs each
#   tools/chase_probe.sh --runs 5 hornet warpig
#   tools/chase_probe.sh --tank --verbose hornet   # measure incoming damage
#
# Flags: --runs N (default 3) | --skill S (default 1.0; lower = later
#        reactions) | --tank (bottomless hull: TOOK = the whole run's damage)
#        | --verbose (15s ticker + damage sources + every big hit's geometry
#        + the sortie census: how many birds got alongside / boxed you in)
# Engine resolution: GODOT_BIN, then PATH, then ~/.local/bin/godot.
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

RUNS=3; SKILL=1.0; EXTRA=(); CARS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --skill) SKILL="$2"; shift 2 ;;
    --tank|--verbose) EXTRA+=("$1"); shift ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) CARS+=("$1"); shift ;;
  esac
done
if [[ ${#CARS[@]} -eq 0 ]]; then
  mapfile -t CARS < <(python3 -c "
import json, sys
for c in json.load(open(sys.argv[1]))['characters']:
    print(c['id'])" "$PROJECT_DIR/assets/data/roster.json")
fi

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT
for car in "${CARS[@]}"; do
  for ((i = 0; i < RUNS; i++)); do
    timeout 120 "$GODOT" --headless --fixed-fps 60 --path "$PROJECT_DIR" \
      -s res://tools/probes/chase_run.gd -- "--car=$car" "--skill=$SKILL" "${EXTRA[@]}" 2>&1 \
      | grep -E '^\[(run|src|hit|sortie|t=)' | tee -a "$OUT"
  done
done

TOTAL=$(grep -c '^\[run\]' "$OUT")
echo "== chase probe: $TOTAL runs — won $(grep -c '^\[run\] WON' "$OUT")" \
  "/ caught $(grep -c 'JACKED(caught)' "$OUT")" \
  "/ wrecked $(grep -c 'JACKED(wrecked)' "$OUT")"
