# Slo Mo's shop: art brief

The PIT STOP shop (`ui/garage/`) is one painted room. You stand just inside
Slo Mo's door after hours; the shop is barely lit, and your phone flashlight
picks out one parts station at a time. Mo counts bolts at the counter in the
back. Opening a station shows that category's menu over the darkened room, and
each part in the menu has its own illustration.

| File | Size | Shows |
|---|---|---|
| `assets/img/garage/bg.png` | 1280×720 | the room (graded; see below) |
| `assets/img/garage/items/<id>.png` | 384×288 | one part, one per catalog id |
| `assets/img/garage/source/room_pixel2.png` | 1536×1024 | the room master, before crop and grade |

All of them are drop-in: a missing file falls back to a plain background or no
picture, with no code change. `source/` carries a `.gdignore`, so Godot never
imports the master.

`tools/shop_brief.py` is the source of truth for the scene text
(`tools/shop_brief.py --list` prints the summary).

## Look

16-bit pixel art in the manner of `assets/img/cards/level_1.png`: chunky
visible pixels, a limited muted palette, dithering, dark outlines. The room
was first generated as inked comic art and moved to pixel art at Kevin's
request; the part briefs are pixel art from the start.

The painting is NOT dark. It carries full detail at a muted, desaturated
grade, and `shaders/shop_spotlight.gdshader` does the lighting at runtime:

- the room sits at a low ambient (`ShopRoom.ROOM_AMBIENT`, 0.25);
- each overhead fixture in `ShopRoom.LAMPS` throws a warm pool that hangs a
  little below it, plus a small halo on the fixture itself;
- the phone flashlight is a cool-white ellipse over the selected station, a
  touch brighter than the art (`beam_gain` 1.2), with a soft spill and a
  few pixels of handheld sway.

## The room

- First-person, just inside the door, eye height.
- **Slo Mo** at the back wall, centered, behind a cluttered counter and a brass
  cash register: old, heavyset, bald with a grey fringe, a droopy grey walrus
  mustache, half-moon glasses, greasy coveralls. He counts bolts into a coffee
  can one at a time. He is in no hurry.
- A junk cart overflows in the middle of the floor. It is scenery, not a
  station: you walk around it, like a cluttered flea market.
- The only lettering is the sign above Mo: `SLO MO'S`.
- The five stations, left to right, are the order the arrow keys walk:

| Station | Category |
|---|---|
| engine block on a chain hoist | ENGINE |
| tire stack + spring/shock rack | SUSPENSION |
| MG on the bench, rocket crate | WEAPONS |
| electronics shelf, green radar CRT | CPU |
| riveted plates leaning on the wall | ARMOR |

`ShopRoom.HOTSPOTS` (the flashlight targets) and `ShopRoom.LAMPS` (the
fixtures) are measured on the installed `bg.png`. If the painting changes,
re-measure both: overlay an 80 px grid on the image and read off each
station's bounding box and each fixture's center.

### How the room was made

Four Codex passes, each attaching the previous keeper:

1. `tools/shop_brief.py room`: three fresh takes; Kevin picked take 3.
2. Edit: add the junk cart to the empty center floor, change nothing else
   (three goes; edit 1 kept).
3. Restyle: redraw edit 1 as 16-bit pixel art, with `cards/level_1.png`
   attached as the style reference (three goes; pixel 2 kept →
   `source/room_pixel2.png`).
4. Grade with ImageMagick: crop to 16:9, then cut saturation and cool it
   slightly. Run it as two steps; that reproduces `bg.png` exactly:

       magick source/room_pixel2.png -gravity center -crop 1536x864+0+0 \
           +repage -resize 1280x720 /tmp/room_1280.png
       magick /tmp/room_1280.png -modulate 100,55,100 \
           -channel B -evaluate multiply 1.06 +channel bg.png

## The parts

One object per image, lit by the same cool flashlight against a dark workbench
and pegboard, no text. Every part brief runs with the graded room attached as
the style reference, so the parts match the shop.

## Generating

Images come from Codex's built-in image tool. Codex is not on `PATH`; it
ships inside the VS Code extension. Use the 26.810 build (the 26.917 build's
sandbox fails on this host).

    CODEX=~/.vscode/extensions/openai.chatgpt-26.810.52044-linux-x64/bin/linux-x86_64/codex
    tools/shop_brief.py mg_cooling \
        | $CODEX exec --skip-git-repo-check -s workspace-write -C <workdir> \
            -i <workdir>/room.png -
    # writes <workdir>/mg_cooling.png

Run two or three takes at once and keep the best. To repair one detail of a
take that is otherwise right, attach the take itself and name the single
change plus everything that must stay; rerolling loses what you had.

Normalize a part into place (3:2 in, 4:3 out):

    magick mg_cooling.png -gravity center -crop 1365x1024+0+0 +repage \
        -resize 384x288 assets/img/garage/items/mg_cooling.png

## Review checklist

| Check | Reject if |
|---|---|
| Stations | any of the five is missing, merged with a neighbour, or unreadable at 1280×720 |
| Order | stations don't run ENGINE, SUSPENSION, (Mo), WEAPONS, CPU, ARMOR left to right |
| Crop zone | a station, Mo or the sign sits in the top 10% or bottom 12% |
| Mo | young, thin, menacing, or crowded by a station |
| Lettering | anything besides `SLO MO'S`; misspellings |
| Part | several objects, a person or hand, text, or the part isn't recognizable at 384×288 |
| Palette | a strong yellow cast, or bright saturated colour the room doesn't have |
| Brands | a real badge, logo or brand name |
| Style | smooth painting, photoreal or 3D instead of chunky pixel art |
