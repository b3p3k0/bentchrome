#!/usr/bin/env bash
# Run seeded stall probes in parallel, collect their event lines, and report.
set -uo pipefail

usage() {
  echo "Usage: tools/stalls.sh <scene.tscn> [--seeds N] [--seed BASE] [--seconds S]" >&2
  echo "       [--cars N] [--jobs J] [--cell PX] [--out FILE] [--label TEXT]" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENE_ARG="$1"
shift

SEEDS=8
BASE_SEED=11
DURATION=180
CARS=5
JOBS=8
CELL=128
OUT=""
LABEL=""

while [[ $# -gt 0 ]]; do
  if [[ $# -lt 2 ]]; then
    echo "ERROR: missing value for $1" >&2
    usage
    exit 2
  fi
  case "$1" in
    --seeds) SEEDS="$2" ;;
    --seed) BASE_SEED="$2" ;;
    --seconds) DURATION="$2" ;;
    --cars) CARS="$2" ;;
    --jobs) JOBS="$2" ;;
    --cell) CELL="$2" ;;
    --out) OUT="$2" ;;
    --label) LABEL="$2" ;;
    *)
      echo "ERROR: unknown flag: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift 2
done

if [[ ! "$SEEDS" =~ ^[1-9][0-9]*$ ]] || [[ ! "$JOBS" =~ ^[1-9][0-9]*$ ]] \
    || [[ ! "$CARS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --seeds, --jobs, and --cars must be positive integers" >&2
  exit 2
fi
if [[ ! "$BASE_SEED" =~ ^-?[0-9]+$ ]]; then
  echo "ERROR: --seed must be an integer" >&2
  exit 2
fi
if [[ ! "$DURATION" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] \
    || [[ ! "$CELL" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]; then
  echo "ERROR: --seconds and --cell must be positive numbers" >&2
  exit 2
fi
if ! python3 -c 'import sys; raise SystemExit(float(sys.argv[1]) <= 0)' "$DURATION" \
    || ! python3 -c 'import sys; raise SystemExit(float(sys.argv[1]) <= 0)' "$CELL"; then
  echo "ERROR: --seconds and --cell must be greater than zero" >&2
  exit 2
fi
if [[ "$BASE_SEED" == -* ]]; then
  BASE_SEED=$((-10#${BASE_SEED#-}))
else
  BASE_SEED=$((10#$BASE_SEED))
fi

if [[ "$SCENE_ARG" == res://* ]]; then
  SCENE_PATH="$SCENE_ARG"
  SCENE_FILE="$PROJECT_DIR/${SCENE_ARG#res://}"
elif [[ "$SCENE_ARG" == /* ]]; then
  SCENE_PATH="$SCENE_ARG"
  SCENE_FILE="$SCENE_ARG"
else
  SCENE_PATH="res://${SCENE_ARG#./}"
  SCENE_FILE="$PROJECT_DIR/${SCENE_ARG#./}"
fi
if [[ ! -f "$SCENE_FILE" ]]; then
  echo "ERROR: scene not found: $SCENE_ARG" >&2
  exit 2
fi

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

if [[ -z "$OUT" ]]; then
  OUT="$(mktemp --tmpdir stalls.XXXXXX.log)"
elif [[ "$OUT" != /* ]]; then
  OUT="$PWD/$OUT"
fi
if [[ -z "$LABEL" ]]; then
  LABEL="$(basename "${SCENE_ARG%.tscn}")"
fi

LOG_DIR="$(mktemp -d)"
trap 'rm -r -- "$LOG_DIR"' EXIT
ERR_RE='SCRIPT ERROR|Parse Error|Parser Error|Failed to (load|instantiate)|^\[stall\] ERROR'

echo "== stalls: engine $("$GODOT" --version 2>/dev/null | head -n1)"
echo "== stalls: scene $SCENE_PATH seeds=$SEEDS base=$BASE_SEED jobs=$JOBS"

run_one() {
  local index="$1"
  local seed="$2"
  local log="$LOG_DIR/$index.log"
  local code=0
  timeout 900 "$GODOT" --headless --fixed-fps 60 --path "$PROJECT_DIR" \
    -s res://tools/probes/stall_probe.gd -- "--scene=$SCENE_PATH" \
    "--seed=$seed" "--seconds=$DURATION" "--cars=$CARS" "--cell=$CELL" \
    >"$log" 2>&1 || code=$?
  if [[ $code -eq 0 ]] && grep -qiE "$ERR_RE" "$log"; then
    code=1
  fi
  if [[ $code -eq 0 ]] && ! grep -qE '^\[done\]' "$log"; then
    code=1
  fi
  echo "$code" >"$LOG_DIR/$index.status"
  return "$code"
}

PIDS=()
for ((index = 0; index < SEEDS; index++)); do
  run_one "$index" "$((BASE_SEED + index))" &
  PIDS+=("$!")
  if (( ${#PIDS[@]} >= JOBS )); then
    for pid in "${PIDS[@]}"; do
      wait "$pid" || true
    done
    PIDS=()
  fi
done
for pid in "${PIDS[@]}"; do
  wait "$pid" || true
done

for ((index = 0; index < SEEDS; index++)); do
  code="$(<"$LOG_DIR/$index.status")"
  if [[ "$code" -ne 0 ]]; then
    echo "== stalls: seed $((BASE_SEED + index)) FAILED (rc=$code)" >&2
    if ! grep -im1 -E "$ERR_RE" "$LOG_DIR/$index.log" >&2; then
      sed -n '1,20p' "$LOG_DIR/$index.log" >&2
    fi
    exit 1
  fi
done

if ! : >"$OUT"; then
  echo "ERROR: cannot write output: $OUT" >&2
  exit 2
fi
for ((index = 0; index < SEEDS; index++)); do
  grep -E '^\[(stall|fall|done)\]' "$LOG_DIR/$index.log" >>"$OUT"
done

echo "== stalls: log $OUT"
python3 "$PROJECT_DIR/tools/stall_report.py" "$LABEL=$OUT"
