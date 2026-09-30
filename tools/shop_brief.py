#!/usr/bin/env python3
"""Slo Mo's shop: image-generation briefs for the PIT STOP room and its parts.

The shop (ui/garage/) paints one first-person room, assets/img/garage/bg.png,
and spotlights five parts stations in it; each category menu shows a part
illustration, assets/img/garage/items/<id>.png. This tool is the single
source of truth for WHAT those images show. Contract, review checklist and the
regeneration recipe: docs/art_briefs/slo_mos_shop.md.

    tools/shop_brief.py --list              # every image id and its one-liner
    tools/shop_brief.py room                # the room brief, to stdout
    tools/shop_brief.py engine_stage2       # one part brief, to stdout
    tools/shop_brief.py --write-all DIR     # brief_<id>.md for every image

Part briefs are run with the approved room attached as the STYLE reference,
so every part looks like it came off Mo's shelves.
"""

import sys
from pathlib import Path

# The room's first pass was inked comic; Kevin moved the shop to the 16-bit
# pixel look of assets/img/cards/level_1.png. ROOM still carries the original
# layout brief; the pixel restyle and colour grade that followed it are
# recorded in docs/art_briefs/slo_mos_shop.md.
STYLE = (
    "gritty inked comic-book illustration, heavy black cross-hatching, muted "
    "wasteland palette of amber, rust, oil-black and dirty steel"
)

PART_STYLE = (
    "16-bit-era pixel art, like a 1990s DOS or SNES adventure game: chunky, "
    "clearly visible square pixels (each art pixel about 4 screen pixels wide "
    "on this 1536-wide canvas), a limited muted palette, hand-placed dithering, "
    "crisp pixel clusters and dark outlines, no smooth gradients, no blur. The "
    "part is lit by one cool-white phone flashlight beam in an otherwise dark, "
    "grimy shop: the part is clearly lit, the background falls off into "
    "brown-black shadow. Muted, desaturated colours; no bright yellow cast"
)

ROOM = """\
Task: generate ONE raster image with the built-in image_gen tool, then copy \
the final PNG to ./{out}.png in the current working directory. Do not create \
or modify any other file besides that PNG. Finish by reporting the saved path.

Use: the full-screen background of a video-game SHOP MENU. The player stands \
just inside the door of a grimy wasteland auto-parts shop, looking in. The \
game will spotlight five parts stations in this picture one at a time, so each \
station must be a clearly separate, readable object with a little empty space \
around it.

Camera: first-person, eye height, looking straight into the shop. The back \
wall runs across the middle of the picture; the left and right walls recede \
toward it. One hanging bulb over the counter and a couple of flickering \
fluorescent tubes; oil-stained concrete floor.

The shopkeeper, SLO MO: back wall, horizontally centered, behind a cluttered \
wooden counter with an old brass cash register. An old, heavyset man, bald on \
top with a grey fringe and a big droopy grey walrus mustache, half-moon \
reading glasses on the end of his nose, greasy grey coveralls. He is hunched \
over the counter counting bolts one at a time into a coffee can, in no hurry \
at all; a cold mug of coffee sits by his elbow. He is small in the frame (he \
is across the room), calm, sleepy-eyed, patient as a sloth. Above him on the \
back wall hangs one hand-painted wooden sign.

The five parts stations, in this left-to-right order across the picture:
1. FAR LEFT, foreground: a chain hoist on a steel A-frame gantry with a car \
engine block hanging from it at chest height.
2. LEFT: a tall stack of tires on the floor and, on the left wall behind it, \
a rack of coil springs and shock absorbers.
3. (center: Mo's counter, described above; not a station.)
4. RIGHT OF CENTER: a workbench against a pegboard wall; a belt-fed machine \
gun clamped in a vise and an open wooden crate of stubby rockets beside it.
5. RIGHT: a steel shelf unit of electronics: a glowing green round radar \
scope screen (a CRT), circuit boards, antennas and tangled wires.
6. FAR RIGHT, against the right wall: thick riveted steel armor plates \
leaning in a row.

Canvas: landscape 3:2 (1536x1024), full-bleed, no border, no frame. \
COMPOSITION RULES: the game crops this to 16:9, so keep every station, Mo and \
the sign out of the top 10% and the bottom 12% of the image (ceiling pipes \
and empty floor are fine there). Stations must not overlap each other or Mo; \
leave a visible gap between neighbours. The bottom band of floor stays calm \
and uncluttered: a hint line is printed over it.

Style: {style}. Keep the room lit well enough that all five stations read at \
a glance; darkness only in the corners.

Text: the only lettering allowed anywhere in the image is the sign above Mo, \
reading exactly, verbatim: "SLO MO'S". No other words, letters, numbers or \
price tags.

Avoid: extra people, customers, cars inside the shop, real-world brand names, \
logos or badges, watermark, signature, caption, speech bubbles, UI, menus, \
photoreal rendering, 3D render look, clean vector look, fisheye distortion.
"""

PART = """\
Task: generate ONE raster image with the built-in image_gen tool, then copy \
the final PNG to ./{out}.png in the current working directory. Do not create \
or modify any other file besides that PNG. Finish by reporting the saved path.

Use: the illustration of ONE car part in a video-game shop menu. The part \
is shown on its own, like a catalog shot drawn in pixels.

Attached image: the shop this part is sold in. Role = STYLE REFERENCE ONLY. \
Match its pixel-art style, pixel size, palette and mood exactly. Do NOT copy \
its composition, the shopkeeper, or the room.

The part: {part}

Composition: the part alone, centered, big and fully in frame, filling about \
65% of the picture, with a bold readable silhouette (it is shown at 384x288 in \
the game). Behind it: a dark, simple workbench top and a shadowy pegboard, \
out of focus and quiet. Keep the whole part inside the central 80% of the \
width; the edges get cropped.

Canvas: landscape 3:2 (1536x1024), full-bleed, no border, no frame.

Style: {style}.

Text: no words, letters or numbers anywhere in the image.

Avoid: people, hands, cars, several copies of the part, real-world brand \
names, logos or badges, watermark, signature, caption, UI, photoreal \
rendering, 3D render look, clean vector look, smooth high-resolution \
painting, soft airbrushed shading.
"""

# id -> (one-liner, the part as the image model should draw it)
PARTS = {
    "engine_stage1": (
        "A small turbo with a chopped open cone filter",
        "Stage 1: Bolt-On Boost. A small, grimy turbocharger (the snail-shell "
        "housing) with a crude open cone air filter bolted straight onto its "
        "intake, hose clamps and a short length of rubber hose hanging off it.",
    ),
    "engine_stage2": (
        "A big supercharger blower with a belt pulley",
        "Stage 2: Bigger Blower. A big, brutal roots-type supercharger blower "
        "for a V8, with a ribbed rotor case, a belt pulley on the front, and a "
        "tall scoop on top. Bigger and meaner than a turbo; well used, oil "
        "streaked.",
    ),
    "engine_stage3": (
        "A fuel rail of oversized injectors",
        "Stage 3: Bigger Injectors. A steel fuel rail fitted with a row of "
        "eight oversized fuel injectors, braided steel fuel lines coiling off "
        "the end, one drip of fuel hanging from a nozzle.",
    ),
    "susp_stage1": (
        "A pair of fresh coil springs",
        "Stage 1: New Springs. A pair of fresh heavy coil springs standing "
        "upright side by side, freshly painted rust-red, the only clean thing "
        "in the shop.",
    ),
    "susp_stage2": (
        "A welded, gusseted subframe section",
        "Stage 2: Reinforced Frame. A heavy section of car chassis subframe: "
        "square steel tubing with triangular gusset plates and fat fresh weld "
        "beads, a cross brace bolted across it.",
    ),
    "tires_offroad": (
        "A big knobby off-road tire caked in mud",
        "Offroad Tires. One big knobby off-road tire on a steel wheel, standing "
        "upright, its deep chunky tread caked with dried mud and a tuft of grass.",
    ),
    "tires_lowering": (
        "Two short coilovers beside a low-profile tire",
        "Lowering Kit. Two short, stubby adjustable coilover shocks lying "
        "crossed in front of a thin low-profile street tire on a wide rim.",
    ),
    "mg_cooling": (
        "An MG barrel in a finned cooling jacket, frosted",
        "MG Cooling. A machine-gun barrel wrapped in a finned cooling jacket, "
        "frost on the fins and wisps of cold vapor curling off it.",
    ),
    "bay_expansion": (
        "An extended six-tube rocket pod",
        "Bay Expansion. A bolt-on rocket pod with six launch tubes in two rows, "
        "extra mounting brackets welded on, the noses of stubby rockets "
        "showing in the tubes.",
    ),
    "improved_lock": (
        "An opened missile seeker head with a glowing eye",
        "Improved Lock. The nose cone of a missile opened up to show its seeker: "
        "a gimbal-mounted round sensor eye glowing red, wires and small gears "
        "around it.",
    ),
    "radar_jammer": (
        "A battered black box sprouting antennas, crackling",
        "Radar Jammer. A battered black electronics box sprouting several "
        "whip antennas, a small screen on its face showing only static, little "
        "crackles of interference around the antennas.",
    ),
    "extended_radar": (
        "A radar dish on a short mast",
        "Extended Radar. A dish radar antenna on a short rotating mast with a "
        "cable coiled at its base, the dish scuffed and dented.",
    ),
    "armor_plating": (
        "A stack of thick riveted steel slabs",
        "Plating. A stack of three thick slabs of riveted steel armor plate, "
        "scarred by old bullet dings, with a handful of big bolts beside them.",
    ),
}

ROOM_LINE = "Slo Mo at the counter, five parts stations around the room"


def brief_for(image: str, out: str = "") -> str:
    out = out or image
    if image == "room":
        return ROOM.format(out=out, style=STYLE)
    return PART.format(out=out, style=PART_STYLE, part=PARTS[image][1])


def main(argv: list) -> int:
    ids = ["room"] + sorted(PARTS)
    if len(argv) == 2 and argv[1] == "--list":
        print("%-15s %s" % ("room", ROOM_LINE))
        for part in sorted(PARTS):
            print("%-15s %s" % (part, PARTS[part][0]))
        return 0
    if len(argv) == 3 and argv[1] == "--write-all":
        out = Path(argv[2])
        out.mkdir(parents=True, exist_ok=True)
        for image in ids:
            (out / ("brief_%s.md" % image)).write_text(brief_for(image))
        print("wrote %d briefs to %s" % (len(ids), out))
        return 0
    if len(argv) in (2, 3) and argv[1] in ids:
        sys.stdout.write(brief_for(argv[1], argv[2] if len(argv) == 3 else ""))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
