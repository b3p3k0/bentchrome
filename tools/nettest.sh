#!/usr/bin/env bash
# Loopback end-to-end net test: two headless engine instances on 127.0.0.1
# run the whole LAN stack — auth handshake (password), lobby seat claim,
# match start, snapshot streaming onto client puppets, then a deliberate
# cable pull with a creditless host-side vacate. PASS requires both probes'
# OK markers, clean exit codes, and zero script errors.
# Override the engine with GODOT_BIN, the port with NETTEST_PORT.
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

export NETTEST_PORT="${NETTEST_PORT:-43111}"
ERR_RE='SCRIPT ERROR|Parse Error|Parser Error|Failed to (load|instantiate)'
HOST_LOG="$(mktemp)"
CLIENT_LOG="$(mktemp)"
trap 'rm -f "$HOST_LOG" "$CLIENT_LOG"' EXIT

echo "== nettest: engine $("$GODOT" --version 2>/dev/null | head -n1)"
echo "== nettest: port $NETTEST_PORT"

"$GODOT" --headless --path "$PROJECT_DIR" -s res://tools/probes/host_probe.gd \
  >"$HOST_LOG" 2>&1 &
HOST_PID=$!
sleep 2
PROBE_PW=sesame "$GODOT" --headless --path "$PROJECT_DIR" -s res://tools/probes/client_probe.gd \
  >"$CLIENT_LOG" 2>&1
CLIENT_RC=$?
wait "$HOST_PID"
HOST_RC=$?

echo "-- host --"
grep -E '^\[probe\]' "$HOST_LOG" || true
echo "-- client --"
grep -E '^\[probe\]' "$CLIENT_LOG" || true

FAIL=0
grep -q 'HOST-MATCH-OK' "$HOST_LOG" || { echo "MISSING: HOST-MATCH-OK"; FAIL=1; }
grep -q 'HOST-VACATE-OK' "$HOST_LOG" || { echo "MISSING: HOST-VACATE-OK"; FAIL=1; }
grep -q 'CLIENT-MATCH-OK' "$CLIENT_LOG" || { echo "MISSING: CLIENT-MATCH-OK"; FAIL=1; }
if grep -qiE "$ERR_RE" "$HOST_LOG" "$CLIENT_LOG"; then
  grep -iE "$ERR_RE" "$HOST_LOG" "$CLIENT_LOG" | head -5
  FAIL=1
fi
[[ "$HOST_RC" -eq 0 ]] || { echo "host exit $HOST_RC"; FAIL=1; }
[[ "$CLIENT_RC" -eq 0 ]] || { echo "client exit $CLIENT_RC"; FAIL=1; }

if [[ "$FAIL" -ne 0 ]]; then
  echo "== nettest: FAIL"; exit 1
fi
echo "== nettest: PASS"
