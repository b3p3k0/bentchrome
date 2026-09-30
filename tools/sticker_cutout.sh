#!/usr/bin/env bash
# Bumper Stickers: turn raw image-model takes into game-ready art.
# Each take is a sticker on a PURE BLACK 1536x1024 matte (tools/sticker_brief.py
# asks for exactly that). The matte is flood-filled to transparent from the
# corners — never a global colour key, so black ink INSIDE a sticker survives —
# then trimmed and fitted, aspect kept, into a transparent 768x256 frame.
#
#   tools/sticker_cutout.sh road_king            # one sticker
#   tools/sticker_cutout.sh --all                # every source/<id>.png
#
# Reads assets/img/stickers/source/<id>.png, writes assets/img/stickers/<id>.png.
# Recipe + review checklist: docs/art_briefs/bumper_stickers.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/assets/img/stickers"

cut() {
  local id="$1" src="$DIR/source/$1.png"
  [[ -f "$src" ]] || { echo "missing $src" >&2; return 1; }
  magick "$src" -bordercolor black -border 2 -alpha set -fuzz 12% -fill none \
    -draw "color 0,0 floodfill" -shave 2x2 -trim +repage \
    -resize 752x240 -background none -gravity center -extent 768x256 \
    "$DIR/$id.png"
  echo "cut $id"
}

if [[ "${1:-}" == "--all" ]]; then
  for f in "$DIR"/source/*.png; do cut "$(basename "$f" .png)"; done
elif [[ $# -ge 1 ]]; then
  for id in "$@"; do cut "$id"; done
else
  sed -n '2,12p' "$0" >&2; exit 2
fi
