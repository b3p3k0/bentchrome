#!/usr/bin/env bash
set -euo pipefail

MISSING=()

check_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING+=("$cmd")
    printf "❌ %-8s not found\n" "$cmd"
    return 1
  fi
  printf "✅ %-8s %s\n" "$cmd" "$(command -v "$cmd")"
}

detect_godot() {
  local candidates=("godot4" "godot" "godot4.2" "godot4.1" "godot4.0")
  for candidate in "${candidates[@]}"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf "✅ %-8s %s\n" "$candidate" "$(command -v "$candidate")"
      return 0
    fi
  done

  if [ -n "${GODOT_BIN:-}" ] && [ -x "${GODOT_BIN}" ]; then
    printf "✅ %-8s %s (from \$GODOT_BIN)\n" "godot" "$GODOT_BIN"
    return 0
  fi

  local search_dirs=("$HOME/Applications" "$HOME/bin" "/opt/godot" "/usr/local/bin")
  for dir in "${search_dirs[@]}"; do
    if [ -d "$dir" ]; then
      local found
      found="$(find "$dir" -maxdepth 2 -type f -iname 'godot*' -print -quit 2>/dev/null || true)"
      if [ -n "$found" ]; then
        printf "✅ %-8s %s (detected via search)\n" "godot" "$found"
        return 0
      fi
    fi
  done

  if command -v flatpak >/dev/null 2>&1 && flatpak list | grep -q "org.godotengine.Godot"; then
    echo "✅ Godot available via Flatpak (run 'flatpak run org.godotengine.Godot')"
    return 0
  fi

  MISSING+=("godot (4.x)")
  echo "❌ godot 4.x not found (set \$GODOT_BIN or add the binary to PATH)"
  return 1
}

echo "== Bent Chrome Dev Environment Check =="
check_cmd git
check_cmd python3
check_cmd rg  || true
detect_godot || true

echo
if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "All core tools detected. You're ready to collaborate!"
else
  echo "Missing tools:"
  for tool in "${MISSING[@]}"; do
    echo " - $tool"
  done
  cat <<'EOM'

Recommended setup steps:
1. Install Godot 4 Standard build and ensure the binary is on your PATH.
2. Install ripgrep (rg) for fast searches (e.g., `sudo apt install ripgrep`).
3. Confirm Python 3.10+ is available for scripting and automation.
EOM
  exit 1
fi
