#!/usr/bin/env bash
# Bent Chrome — one-shot interactive installer.
#
# Clone the repo, run ./RUNME.sh, and this sets up everything needed to play:
# system runtime libraries, the official Godot 4.7 engine on your PATH, and a
# first asset import. Endstate: `cd` into this folder and type `godot`.
#
# Target: Ubuntu 24.04 / 26.x (apt) and macOS. Other Linux distributions get
# manual guidance and the engine download still works. Re-runnable: it skips
# anything already in place.
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
GODOT_VERSION="4.7-stable"
GODOT_VERSION_TAG="4.7.stable"            # what `godot --version` reports
GODOT_DEST="$HOME/.local/bin/godot"
GODOT_APP_DEST="$HOME/Applications/Godot.app"
RELEASE_BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}"
PATH_MARKER="# added by Bent Chrome RUNME.sh"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_NAME="$(uname -s)"

AUTO_YES=0
PLAY_MODE=0
NO_LAUNCH=0

# ---------------------------------------------------------------------------
# Pretty output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
else
  C_RESET=""; C_BOLD=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

info() { printf "%s==>%s %s\n" "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf "%s✅%s %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s⚠️ %s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%s❌%s %s\n" "$C_RED" "$C_RESET" "$*" >&2; }

ask_yesno() {
  # ask_yesno "Question?" [default:Y|N]  -> returns 0 for yes, 1 for no
  local prompt="$1" default="${2:-Y}" reply hint
  if [ "$AUTO_YES" -eq 1 ]; then
    printf '%s [auto: %s]\n' "$prompt" "$default"
    [ "$default" = "Y" ]
    return
  fi
  if [ "$default" = "Y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  read -r -p "$prompt $hint " reply || reply=""
  reply="${reply:-$default}"
  case "$reply" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# System package helpers (apt)
# ---------------------------------------------------------------------------
HAS_APT=0
command -v apt-get >/dev/null 2>&1 && HAS_APT=1

SUDO=""
ensure_sudo() {
  # Populate $SUDO with a working sudo (or empty if already root). Aborts if
  # elevation is needed but unavailable.
  if [ "$(id -u)" -eq 0 ]; then SUDO=""; return 0; fi
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    if ! sudo -v; then
      err "This step needs sudo, but authentication failed."
      return 1
    fi
    return 0
  fi
  err "This step needs root, but 'sudo' is not installed. Re-run as root."
  return 1
}

apt_install_missing() {
  # apt_install_missing pkg1 pkg2 ...  -> installs only those not already
  # present AND available in the apt cache. Unavailable names are skipped.
  local want=("$@") todo=() pkg
  for pkg in "${want[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      continue
    fi
    if ! apt-cache show "$pkg" >/dev/null 2>&1; then
      warn "package '$pkg' not found in apt cache — skipping"
      continue
    fi
    todo+=("$pkg")
  done

  if [ "${#todo[@]}" -eq 0 ]; then
    ok "all required packages already installed"
    return 0
  fi

  info "Will install: ${todo[*]}"
  if ! ask_yesno "Install these with apt now?" Y; then
    warn "Skipped package install — the game may not run without them."
    return 0
  fi
  ensure_sudo || return 1
  $SUDO apt-get update -qq
  $SUDO apt-get install -y "${todo[@]}"
  ok "packages installed"
}

# ---------------------------------------------------------------------------
# Play path
# ---------------------------------------------------------------------------
RUNTIME_PKGS=(
  curl ca-certificates unzip
  libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libxext6
  libgl1 libglx-mesa0 libasound2t64 libpulse0 libfontconfig1 libfreetype6
)

ensure_system_pkgs() {
  info "Checking system libraries Godot needs to run…"
  if [ "$OS_NAME" = "Darwin" ]; then
    ok "macOS needs no additional runtime packages"
    return 0
  fi
  if [ "$HAS_APT" -eq 0 ]; then
    warn "Non-apt system: install these yourself (names vary by distro):"
    printf '    %s\n' "${RUNTIME_PKGS[*]}"
    return 0
  fi
  apt_install_missing "${RUNTIME_PKGS[@]}"
}

detect_arch_asset() {
  # Echo the release asset filename for this machine's architecture.
  local m; m="$(uname -m)"
  if [ "$OS_NAME" = "Darwin" ]; then
    case "$m" in
      x86_64|arm64) echo "Godot_v${GODOT_VERSION}_macos.universal.zip" ;;
      *) err "Unsupported macOS architecture '$m'."; return 1 ;;
    esac
    return 0
  fi
  case "$m" in
    x86_64|amd64)   echo "Godot_v${GODOT_VERSION}_linux.x86_64.zip" ;;
    aarch64|arm64)  echo "Godot_v${GODOT_VERSION}_linux.arm64.zip" ;;
    *) err "Unsupported architecture '$m' — no matching Godot build."; return 1 ;;
  esac
}

godot_already_ok() {
  # True if a resolvable godot reports the target version.
  local bin=""
  if command -v godot >/dev/null 2>&1; then bin="godot"
  elif [ -x "$GODOT_DEST" ]; then bin="$GODOT_DEST"
  else return 1; fi
  "$bin" --version 2>/dev/null | grep -q "^${GODOT_VERSION_TAG}"
}

install_godot() {
  info "Setting up Godot ${GODOT_VERSION}…"
  if godot_already_ok; then
    ok "Godot ${GODOT_VERSION_TAG} already installed"
    if ! ask_yesno "Re-download and reinstall anyway?" N; then
      return 0
    fi
  fi

  local asset url sums_url tmp
  asset="$(detect_arch_asset)" || return 1
  url="${RELEASE_BASE}/${asset}"
  sums_url="${RELEASE_BASE}/SHA512-SUMS.txt"

  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  info "Downloading ${asset}…"
  curl -fL --progress-bar -o "$tmp/$asset" "$url"
  info "Downloading checksums…"
  curl -fsSL -o "$tmp/SHA512-SUMS.txt" "$sums_url"

  info "Verifying SHA512…"
  local expected
  expected="$(awk -v wanted="$asset" '$2 == wanted { print $1; exit }' "$tmp/SHA512-SUMS.txt")"
  if [ -z "$expected" ]; then
    err "Could not find a checksum for ${asset} — aborting."
    return 1
  fi
  if [ "$OS_NAME" = "Darwin" ]; then
    local actual
    actual="$(shasum -a 512 "$tmp/$asset" | awk '{print $1}')"
    [ "$actual" = "$expected" ] \
      || { err "Checksum mismatch — refusing to install."; return 1; }
  else
    ( cd "$tmp" && printf '%s  %s\n' "$expected" "$asset" | sha512sum -c - ) \
      || { err "Checksum mismatch — refusing to install."; return 1; }
  fi
  ok "checksum verified"

  info "Extracting…"
  if [ "$OS_NAME" = "Darwin" ]; then
    ditto -x -k "$tmp/$asset" "$tmp/extracted"
    local extracted_app="$tmp/extracted/Godot.app"
    if [ ! -x "$extracted_app/Contents/MacOS/Godot" ]; then
      err "Could not find Godot.app inside the zip."
      return 1
    fi
    mkdir -p "$(dirname "$GODOT_APP_DEST")" "$(dirname "$GODOT_DEST")"
    rm -rf "$GODOT_APP_DEST"
    mv "$extracted_app" "$GODOT_APP_DEST"
    ln -sfn "$GODOT_APP_DEST/Contents/MacOS/Godot" "$GODOT_DEST"
    if ! codesign --verify --deep --strict "$GODOT_APP_DEST" >/dev/null 2>&1; then
      warn "macOS could not verify Godot's code signature."
      warn "Do not disable Gatekeeper; re-download or use System Settings → Privacy & Security."
    fi
    ok "installed → $GODOT_APP_DEST"
    ok "command link → $GODOT_DEST"
    return 0
  fi

  unzip -qo "$tmp/$asset" -d "$tmp"
  local extracted="$tmp/${asset%.zip}"
  if [ ! -f "$extracted" ]; then
    # Fall back to whatever executable the zip produced.
    extracted="$(find "$tmp" -maxdepth 1 -type f -name 'Godot_v*' ! -name '*.zip' -print -quit)"
  fi
  if [ ! -f "$extracted" ]; then
    err "Could not find the Godot binary inside the zip."
    return 1
  fi

  mkdir -p "$(dirname "$GODOT_DEST")"
  mv -f "$extracted" "$GODOT_DEST"
  chmod +x "$GODOT_DEST"
  ok "installed → $GODOT_DEST"
}

ensure_path() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*)
      ok "~/.local/bin already on PATH"
      return 0
      ;;
  esac
  local rc="$HOME/.bashrc"
  if [ "$OS_NAME" = "Darwin" ]; then
    case "${SHELL##*/}" in
      zsh) rc="$HOME/.zprofile" ;;
      *)   rc="$HOME/.bash_profile" ;;
    esac
  fi
  if [ -f "$rc" ] && grep -qF "$PATH_MARKER" "$rc"; then
    :  # already added on a prior run
  else
    {
      printf '\n%s\n' "$PATH_MARKER"
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$rc"
    ok "added ~/.local/bin to PATH in ${rc/#$HOME/\~}"
  fi
  warn "PATH change applies to NEW shells. For this one, run:  source ${rc/#$HOME/\~}"
}

import_project() {
  info "Importing project assets (first-run, generates .godot cache)…"
  local bin="$GODOT_DEST"
  command -v godot >/dev/null 2>&1 && bin="godot"
  if "$bin" --headless --path "$REPO_DIR" --import >/dev/null 2>&1; then
    ok "assets imported"
  else
    warn "Import returned a non-zero status. Try 'tools/smoke.sh' for detail."
  fi
}

# ---------------------------------------------------------------------------
# Dev path (option 2)
# ---------------------------------------------------------------------------
DEV_PKGS=(ripgrep python3 python3-venv)

install_dev_tools() {
  info "Installing additional developer tools…"
  if [ "$HAS_APT" -eq 0 ]; then
    warn "Non-apt system: install these yourself: ${DEV_PKGS[*]}"
    return 0
  fi
  apt_install_missing "${DEV_PKGS[@]}"
}

# ---------------------------------------------------------------------------
# Verification summary (kept from the old dev-check)
# ---------------------------------------------------------------------------
report_tool() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  %s✅%s %-8s %s\n" "$C_GREEN" "$C_RESET" "$cmd" "$(command -v "$cmd")"
  else
    printf "  %s—%s  %-8s (not installed)\n" "$C_YELLOW" "$C_RESET" "$cmd"
  fi
}

verify_summary() {
  echo
  info "Environment summary:"
  report_tool git
  if command -v godot >/dev/null 2>&1; then
    printf "  %s✅%s %-8s %s (%s)\n" "$C_GREEN" "$C_RESET" "godot" \
      "$(command -v godot)" "$(godot --version 2>/dev/null | head -n1)"
  elif [ -x "$GODOT_DEST" ]; then
    printf "  %s✅%s %-8s %s (%s)\n" "$C_GREEN" "$C_RESET" "godot" \
      "$GODOT_DEST" "$("$GODOT_DEST" --version 2>/dev/null | head -n1)"
  else
    printf "  %s❌%s %-8s (not installed)\n" "$C_RED" "$C_RESET" "godot"
  fi
  report_tool rg
  report_tool python3
}

launch_hint() {
  echo
  ok "Setup complete."
  echo
  printf "  To play:\n"
  printf "      %scd %s%s\n" "$C_BOLD" "$REPO_DIR" "$C_RESET"
  printf "      %sgodot%s\n" "$C_BOLD" "$C_RESET"
  echo
  if ! command -v godot >/dev/null 2>&1; then
    warn "'godot' isn't on this shell's PATH yet. Either open a new terminal,"
    warn "or launch directly with: $GODOT_DEST"
  fi
  if [ "$NO_LAUNCH" -eq 1 ]; then
    return 0
  fi
  if ask_yesno "Launch Bent Chrome now?" N; then
    local launch_bin="$GODOT_DEST"
    command -v godot >/dev/null 2>&1 && launch_bin="godot"
    "$launch_bin" --path "$REPO_DIR"
  fi
}

# ---------------------------------------------------------------------------
# Menu / main
# ---------------------------------------------------------------------------
run_play_path() {
  ensure_system_pkgs
  install_godot
  ensure_path
  import_project
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --play) PLAY_MODE=1 ;;
      --yes) AUTO_YES=1 ;;
      --no-launch) NO_LAUNCH=1 ;;
      -h|--help)
        echo "Usage: ./RUNME.sh [--play] [--yes] [--no-launch]"
        exit 0
        ;;
      *) err "Unknown option: $1"; exit 2 ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  printf "%s%s== Bent Chrome — Installer ==%s\n" "$C_BOLD" "$C_BLUE" "$C_RESET"
  echo "Top-down vehicular combat, built in Godot 4.7."
  echo

  if [ "$PLAY_MODE" -eq 1 ]; then
    run_play_path
    verify_summary
    launch_hint
    return 0
  fi

  if [ "$OS_NAME" = "Darwin" ]; then
    echo "  1) Just Play! — install everything needed to run the game"
    echo "  2) Quit"
    echo
    local mac_choice
    read -r -p "Choose [1/2]: " mac_choice || mac_choice="2"
    case "$mac_choice" in
      1) run_play_path; verify_summary; launch_hint ;;
      2|q|Q) echo "Bye." ;;
      *) err "Unrecognized choice: '$mac_choice'"; exit 1 ;;
    esac
    return 0
  fi

  echo "  1) Just Play!               — install everything needed to run the game"
  echo "  2) Install additional dev tools (ripgrep, python3) — not needed in most cases"
  echo "  3) Quit"
  echo
  local choice
  read -r -p "Choose [1/2/3]: " choice || choice="3"

  case "$choice" in
    1)
      run_play_path
      verify_summary
      launch_hint
      ;;
    2)
      run_play_path
      install_dev_tools
      verify_summary
      launch_hint
      ;;
    3|q|Q)
      echo "Bye."
      exit 0
      ;;
    *)
      err "Unrecognized choice: '$choice'"
      exit 1
      ;;
  esac
}

main "$@"
