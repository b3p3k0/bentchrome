#!/usr/bin/env bash
# Bent Chrome — everyday launcher (Linux / macOS).
#
# Run this every time you want to play. It applies any update you downloaded
# from Settings -> CHECK FOR UPDATES (while the game is closed, so nothing is
# overwritten mid-run), reimports assets, then boots the game. When there is
# no pending update it just launches — fast.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATES_DIR="$REPO_DIR/.updates"
PENDING_ZIP="$UPDATES_DIR/pending.zip"
APPLY_JSON="$UPDATES_DIR/apply.json"

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
info() { printf "%s==>%s %s\n" "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s[!]%s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%s[x]%s %s\n" "$C_RED" "$C_RESET" "$*" >&2; }

# Resolve a Godot 4.7 binary the same way RUNME does: PATH first, then the
# managed install under ~/.local/bin.
resolve_godot() {
  if command -v godot >/dev/null 2>&1; then echo "godot"; return 0; fi
  if [ -x "$HOME/.local/bin/godot" ]; then echo "$HOME/.local/bin/godot"; return 0; fi
  return 1
}

# Read a top-level string field out of the small apply.json without a JSON tool.
json_field() {
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$APPLY_JSON" 2>/dev/null \
    | head -n1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/'
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

apply_pending_update() {
  [ -f "$PENDING_ZIP" ] && [ -f "$APPLY_JSON" ] || return 0

  local godot version expected actual
  godot="$(resolve_godot)" || { err "Godot 4.7 isn't installed — run ./RUNME.sh first."; return 1; }
  version="$(json_field version)"
  expected="$(json_field sha256)"

  info "Applying update ${version:-(new build)}…"

  if [ -n "$expected" ]; then
    actual="$(sha256_of "$PENDING_ZIP")"
    if [ "$actual" != "$expected" ]; then
      err "Update checksum mismatch — refusing to apply. Nothing was changed."
      warn "Re-download from Settings -> CHECK FOR UPDATES, or delete $UPDATES_DIR to skip."
      return 1
    fi
    ok "checksum verified"
  else
    warn "No checksum on this update — applying without verification."
  fi

  # Give the just-closed game a beat to fully exit before overwriting files.
  sleep 1

  info "Unpacking over the game folder…"
  if ! unzip -qo "$PENDING_ZIP" -d "$REPO_DIR"; then
    err "Unpack failed — the download may be corrupt. Nothing half-applied; retry."
    return 1
  fi

  info "Reimporting assets…"
  "$godot" --headless --path "$REPO_DIR" --import >/dev/null 2>&1 || \
    warn "Import returned non-zero; the game will still try to boot."

  rm -f "$PENDING_ZIP" "$APPLY_JSON"
  rmdir "$UPDATES_DIR" 2>/dev/null || true
  ok "update applied — you're on ${version:-the latest}"
}

main() {
  # A failed apply must not block launching the (still-working) current build.
  apply_pending_update || warn "Update was not applied — launching the current build."

  local godot
  godot="$(resolve_godot)" || { err "Godot 4.7 isn't installed — run ./RUNME.sh first."; exit 1; }
  exec "$godot" --path "$REPO_DIR"
}

main "$@"
