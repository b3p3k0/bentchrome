#!/usr/bin/env python3
"""Route 666 billboards: one image-generation brief per illustrated board.

The roadside billboards (levels/chase/highway_deco.gd, kind `billboard`) deal
their copy from BILLBOARD_COPY; a drop-in assets/img/billboards/<slug>.png is
drawn as the board face instead of the text, so the painting has to CARRY the
copy, letter for letter. This tool is the single source of truth for what each
illustrated board shows; it renders the brief an image model works from.
Contract, review checklist and the full recipe: docs/art_briefs/billboards.md.

    tools/billboard_brief.py --list            # slugs, copy, matte
    tools/billboard_brief.py kandy_kane        # the brief, to stdout
    tools/billboard_brief.py --write-all DIR   # brief_<slug>.md for every board
    tools/billboard_brief.py --normalize SRC DST   # trim the matte strips + fill 1360x520

The slug is highway_deco.gd's slug_for(): the copy's first line lowercased,
runs of anything but a-z0-9 folded to one underscore. The copy here must match
BILLBOARD_COPY verbatim — the test (test_billboard_art) only lints file names;
the spelling check against the table is a human review, letter by letter.
"""

import re
import subprocess
import sys
from pathlib import Path

# Canvas the model paints (its native landscape) and the band the game keeps:
# the board is 340x130 world px (2.6:1), so the middle strip of a 3:2 canvas
# is cropped out and scaled to 4x the board. Everything that matters lives
# inside the band; the strips above and below are matte and get cut away.
CANVAS = (1536, 1024)
BOARD = (1360, 520)
BAND_TOP = 0.22   # the band spans 22%..78% of the canvas height

# slug -> (copy lines verbatim from BILLBOARD_COPY, matte colour, the picture)
BOARDS = {
    "slo_mo_s": (
        ["SLO MO'S", "PARTS FOR THE ROAD", "next stop, or the one after"],
        "faded mustard yellow",
        "A grinning, heavy-lidded, very slow-looking mechanic in greasy overalls "
        "leans on a mountain of mismatched car parts (hubcaps, a bumper, a muffler, "
        "one tire) with a wrench in one hand and a steaming mug in the other, "
        "clearly in no hurry at all. A snail sits on his shoulder. The lettering is "
        "chunky hand-painted shop-sign type, the big name in red with a black "
        "drop shadow, the tagline underneath in smaller painted script.",
    ),
    "kandy_kane": (
        ["KANDY KANE", "ICE CREAM", "we deliver. we do not stop."],
        "bubblegum pink",
        "A candy-striped pink-and-white ice cream truck roaring straight at the "
        "viewer at full speed, headlights blazing, a cloud of dust behind it, ice "
        "cream cones and sprinkles flying off the roof, the tires smoking. A "
        "smiling cartoon ice cream cone mascot clings to the hood for dear life. "
        "The lettering is swirly, dripping, candy-coloured ice-cream-parlour type "
        "in white with a cherry-red outline, the tagline below in smaller plain "
        "painted capitals.",
    ),
    "wanted": (
        ["WANTED", "HUBCAP", "reward: a hubcap"],
        "parchment tan",
        "An old-west WANTED poster, tacked up with four rusty nails and torn at "
        "one corner: in the centre, a mugshot-style portrait of a single chrome "
        "hubcap wearing a tiny bandit's mask, drawn deadly serious. The big word "
        "WANTED across the top in heavy black western slab-serif type, HUBCAP "
        "underneath it, the reward line along the bottom in smaller western type.",
    ),
    "visit_mercy": (
        ["VISIT MERCY", "POP. 0", "and falling"],
        "chamber-of-commerce sky blue",
        "A cheerful tourist-board welcome sign gone wrong: a dusty desert town "
        "skyline of boarded-up shacks and a water tower under a hot sun, one "
        "vulture perched on the sign's edge, a tumbleweed rolling through. The "
        "population number is painted on a little hanging wooden tag that has been "
        "crossed out and repainted several times, now reading 0. VISIT MERCY in "
        "big friendly rounded white letters with a navy outline, POP. 0 in plain "
        "black block capitals, 'and falling' in smaller hand-scrawled paint.",
    ),
    "bent_chrome": (
        ["BENT CHROME", "MOTORS", "as seen on the shoulder"],
        "charcoal black",
        "A used-car-lot ad: a proud chrome-grilled muscle car on a pedestal with "
        "a big price tag, lit by a chrome starburst behind it — except the car is "
        "visibly crumpled, one headlight dangling, the bumper bent into a smile, "
        "a wheel missing and replaced by a cinder block. The lettering is bold "
        "chrome-effect 1980s dealership type with a red-and-white racing stripe "
        "through it; MOTORS underneath in plain white block capitals; the tagline "
        "small and plain along the bottom.",
    ),
    "are_you": (
        ["ARE YOU", "SAVED?", "have you tried nitro"],
        "deep purple",
        "A revival-tent gospel billboard: golden rays of light bursting from "
        "behind a single glowing nitrous-oxide bottle (a blue steel bottle with a "
        "gauge and hose) that floats in a halo of light above the clouds like a "
        "holy relic, two small cartoon buzzards kneeling before it on a cloud. ARE "
        "YOU in tall white serif church-sign capitals, SAVED? below it even "
        "bigger in gold, the question in smaller plain white letters at the "
        "bottom.",
    ),
    "the_buzzardz": (
        ["THE BUZZARDZ", "PLAY TONIGHT", "wherever you are"],
        "scorched black with a red glow",
        "A heavy-metal gig poster: a snarling buzzard in a spiked leather jacket "
        "playing a guitar built out of an exhaust muffler, lit from below by a "
        "ring of car headlights like stage lights, dust and flames behind, a "
        "crowd of raised fists and wrenches. THE BUZZARDZ in jagged, spiky, "
        "dripping heavy-metal band lettering in blood red with a white edge, PLAY "
        "TONIGHT in plain white stencil capitals, the tagline small underneath.",
    ),
    "roadkill": (
        ["ROADKILL", "CAFE", "you hit it, we grill it"],
        "diner-sign cream",
        "A greasy-spoon diner ad: a flattened cartoon possum, X's for eyes and a "
        "tire-tread stripe across its back, served up on a diner plate with a "
        "sprig of parsley and a side of fries, a fat smiling chef in a stained "
        "apron and paper hat presenting it with a spatula. ROADKILL in big red "
        "retro diner script with a neon-tube look, CAFE in plain bold black "
        "capitals, the tagline in smaller black painted letters at the bottom.",
    ),
}

BRIEF = """\
Task: generate ONE raster image with the built-in image_gen tool, then copy \
the final PNG to ./{slug}.png in the current working directory. Do not create \
or modify any other file besides that PNG. Finish by reporting the saved path.

Use: the painted FACE of a roadside billboard in a top-down 16-bit vehicular \
combat video game set on a grimy dystopian desert highway. The game draws the \
billboard's posts, frame and bulbs itself; this image is ONLY the flat painted \
face of the board. It is a parody advertisement: one strong image and a \
catchy slogan. The slogan IS the joke, so the lettering must be big, bold and \
readable at a glance.

Attached image: a loading card from the same game. Role = STYLE REFERENCE \
ONLY: match its 16-bit pixel-art look — chunky visible pixels, limited \
palette, dithered shading, grimy and sun-faded — not its subject. Do not copy \
anything from it.

Picture: {scene}

Lettering, verbatim and complete, every letter exactly as written: {copy}
Spell each line EXACTLY as given, same capitals, same punctuation, nothing \
added, nothing missing, no other words, letters or numbers anywhere. The first \
two lines are the headline and must be the biggest things on the board \
(letter height at least 18% of the board's height); the last line is the \
tagline, smaller but still chunky painted lettering (at least 8% of the \
board's height). All lettering painted ON the board as sign-painter's work, \
weathered and sun-faded like the rest.

Canvas: landscape {cw}x{ch}. COMPOSITION RULE: the board is WIDE (2.6:1), so \
the game keeps only the horizontal band from {band_lo}% to {band_hi}% of the \
canvas height and cuts the rest away. Put the ENTIRE picture and ALL \
lettering inside that band, clear of its top and bottom edges by a little \
margin; fill the strips above and below the band with the flat matte colour \
and nothing else. The board's background inside the band is a flat matte of \
{matte} (weathered, lightly scuffed) — opaque everywhere, nothing transparent, \
no border, no frame, no posts, no sky or ground outside the board.

Style: 16-bit pixel art, as the attached card. Hand-painted sign-shop \
lettering with drop shadows and outlines so it pops off the matte. Grimy, \
sun-bleached, a few peeling patches and rust streaks. Silly and sarcastic, \
never grim.

Avoid: real-world brand names, logos, badges or mascots; real people; \
photoreal rendering, 3D render look, clean vector look, smooth gradients; \
tiny text or fine print; any words beyond the exact lettering above; \
misspellings; gore or blood; anything drawn outside the board face (posts, \
frame, sky, road, landscape around the board); transparency; watermark; \
signature; UI.
"""


def slug_for(copy):
    """Mirror of highway_deco.gd's slug_for(): first line, lowercased, folded."""
    head = str(copy[0]).lower()
    return "_".join(p for p in re.split(r"[^a-z0-9]+", head) if p)


def brief_for(slug):
    copy, matte, scene = BOARDS[slug]
    lines = ", ".join('"%s"' % line for line in copy if line != "")
    return BRIEF.format(
        slug=slug, scene=scene, copy=lines, matte=matte,
        cw=CANVAS[0], ch=CANVAS[1],
        band_lo=int(BAND_TOP * 100), band_hi=int((1.0 - BAND_TOP) * 100),
    )


FRAME = 32   # the game's frame line sits 8 world px in = 32 art px: the art fits inside it


def normalize(src, dst):
    """Trim the flat matte strips the model paints above and below the band,
    fit what is left inside the game's frame line, and pad out to the 4x
    board with the strip's own matte colour (the model paints lettering to
    the very edge; under the frame it would be clipped). Opaque, stripped."""
    matte = subprocess.check_output(
        ["magick", str(src), "-format", "%[pixel:p{2,2}]", "info:"], text=True).strip()
    cmd = [
        "magick", str(src),
        "-fuzz", "6%", "-trim", "+repage",
        "-resize", "%dx%d" % (BOARD[0] - 2 * FRAME, BOARD[1] - 2 * FRAME),
        "-background", matte, "-gravity", "center", "-extent", "%dx%d" % BOARD,
        "-alpha", "off", "-strip", str(dst),
    ]
    return subprocess.call(cmd)


def main(argv):
    if len(argv) == 2 and argv[1] == "--list":
        for slug in BOARDS:
            copy, matte, _ = BOARDS[slug]
            print("%-14s %-46s %s" % (slug, " / ".join(copy), matte))
        return 0
    if len(argv) == 3 and argv[1] == "--write-all":
        out = Path(argv[2])
        out.mkdir(parents=True, exist_ok=True)
        for slug in BOARDS:
            (out / ("brief_%s.md" % slug)).write_text(brief_for(slug))
        print("wrote %d briefs to %s" % (len(BOARDS), out))
        return 0
    if len(argv) == 4 and argv[1] == "--normalize":
        return normalize(argv[2], argv[3])
    if len(argv) == 2 and argv[1] in BOARDS:
        sys.stdout.write(brief_for(argv[1]))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    for _slug, (_copy, _, _) in BOARDS.items():
        assert slug_for(_copy) == _slug, "slug drift: %s vs %s" % (_slug, slug_for(_copy))
    sys.exit(main(sys.argv))
