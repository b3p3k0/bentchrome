#!/usr/bin/env bash
# Botlab sweep runner: N headless matches (one process each — hermetic,
# crash-isolated), seeds base+i, optional parallel slots and league spawn
# mirroring, then one aggregate pass into summary.json.
#
#   tools/botlab.sh tools/botlab/configs/sweep_ffa.json --n 20 --jobs 4
#   tools/botlab.sh tools/botlab/configs/duel.json --n 20 --swap-pairs
#
# Flags: --n N (matches, default 1) | --seed BASE (default from config/1234)
#        --jobs J (parallel, default 1) | --swap-pairs (each seed also runs
#        with entrants reversed — league fairness) | --realtime (drop
#        --fixed-fps; wall-clock validation runs) | --out DIR
# Engine resolution: GODOT_BIN, then PATH, then ~/.local/bin/godot.
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-}"
[[ -n "$CONFIG" && -f "$CONFIG" ]] || { echo "usage: tools/botlab.sh <config.json> [--n N] [--seed S] [--jobs J] [--swap-pairs] [--realtime] [--out DIR]" >&2; exit 2; }
shift

N=1; JOBS=1; SWAP=0; REALTIME=0; SEED=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --n) N="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --swap-pairs) SWAP=1; shift ;;
    --realtime) REALTIME=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

GODOT="${GODOT_BIN:-}"
if [[ -z "$GODOT" ]]; then
  if command -v godot >/dev/null 2>&1; then GODOT="godot"
  elif [[ -x "$HOME/.local/bin/godot" ]]; then GODOT="$HOME/.local/bin/godot"
  fi
fi
[[ -n "$GODOT" ]] || { echo "ERROR: Godot not found. Put it on PATH or set GODOT_BIN" >&2; exit 2; }

read_cfg() { python3 -c "import json,sys; print(json.load(open('$CONFIG')).get('$1',$2))"; }
[[ -n "$SEED" ]] || SEED="$(read_cfg seed 1234)"
[[ -n "$OUT" ]] || OUT="$(read_cfg output "'res://tools/botlab/out'")"
GIT_REV="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
FPS_ARGS=(--fixed-fps 60); [[ "$REALTIME" -eq 1 ]] && FPS_ARGS=()
ERR_RE='SCRIPT ERROR|Parse Error|Parser Error|Failed to (load|instantiate)'
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

echo "== botlab: engine $("$GODOT" --version 2>/dev/null | head -n1)"
echo "== botlab: config $CONFIG  n=$N seed=$SEED jobs=$JOBS swap=$SWAP realtime=$REALTIME"

run_one() {  # $1 = seed  $2 = tag  $3 = swap(0/1)
  local log="$LOG_DIR/$2.log"
  BOTLAB_CONFIG="$CONFIG" BOTLAB_SEED="$1" BOTLAB_TAG="$2" BOTLAB_SWAP="$3" \
  BOTLAB_OUT="$OUT" BOTLAB_GIT_REV="$GIT_REV" \
  BOTLAB_FIXED_FPS="$([[ "$REALTIME" -eq 1 ]] && echo 0 || echo 1)" \
  timeout 900 "$GODOT" --headless "${FPS_ARGS[@]}" --path "$PROJECT_DIR" \
    -s res://tools/botlab/botlab_probe.gd >"$log" 2>&1
  local rc=$?
  if [[ $rc -ne 0 ]] || ! grep -q 'MATCH-OK' "$log" || grep -qiE "$ERR_RE" "$log"; then
    echo "-- match $2 FAILED (rc=$rc):"
    grep -E '^\[botlab\]' "$log" | tail -3
    grep -iE "$ERR_RE" "$log" | head -3
    return 1
  fi
  grep -E 'MATCH-OK' "$log" | sed "s/^/-- match $2: /"
  return 0
}

FAIL=0
for ((i = 0; i < N; i++)); do
  for sw in $(if [[ "$SWAP" -eq 1 ]]; then echo "0 1"; else echo "0"; fi); do
    tag="$i"; [[ "$sw" -eq 1 ]] && tag="${i}s"
    run_one "$((SEED + i))" "$tag" "$sw" &
    while (( $(jobs -rp | wc -l) >= JOBS )); do wait -n || FAIL=1; done
  done
done
while (( $(jobs -rp | wc -l) > 0 )); do wait -n || FAIL=1; done

BOTLAB_AGGREGATE="$OUT" "$GODOT" --headless --path "$PROJECT_DIR" \
  -s res://tools/botlab/aggregate.gd 2>&1 | grep -E '^\[botlab\]' || FAIL=1

if [[ "$FAIL" -ne 0 ]]; then echo "== botlab: FAIL"; exit 1; fi
echo "== botlab: PASS  results in ${OUT#res://}/"
