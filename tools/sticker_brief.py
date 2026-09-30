#!/usr/bin/env python3
"""Bumper Stickers: one image-generation brief per sticker.

The sticker book (ui/sticker_book.gd) and the finale's prize beat show each
earned sticker as art under assets/img/stickers/<id>.png; without the file
ui/sticker_paint.gd paints a procedural stand-in. This tool is the single
source of truth for WHAT each sticker shows; it renders the brief an image
model works from. Contract, review checklist and the full regeneration
recipe: docs/art_briefs/bumper_stickers.md.

    tools/sticker_brief.py --list            # ids, exact slogans, motifs
    tools/sticker_brief.py road_king         # the brief, to stdout
    tools/sticker_brief.py --write-all DIR   # brief_<id>.md for every sticker

Ids MUST match assets/data/stickers.json (tests/test_sticker_art.gd checks).
The SLOGAN is the only lettering allowed on the sticker, verbatim — image
models misspell, so every take is read letter by letter before it ships.
"""

import sys
from pathlib import Path

# id -> (exact slogan, the one motif, the palette)
STICKERS = {
    "basic_af": (
        "BASIC AF",
        "a single plain red cartoon rocket with one tidy flame, drawn with "
        "deliberately zero flair",
        "flat red and black on plain off-white; the whole sticker is aggressively "
        "bland, like a free giveaway from a tire shop",
    ),
    "no_place_like_home": (
        "NO PLACE LIKE HOME",
        "a cartoon missile trailing a looping, curly smoke path that ends in a "
        "tiny house",
        "brick-road yellow and ruby red on emerald green",
    ),
    "straight_shooter": (
        "STRAIGHT SHOOTER",
        "one fat heavy missile flying dead level along a ruler-straight line, "
        "tick marks underneath",
        "black and safety yellow, hazard-stripe accents",
    ),
    "tailgunner": (
        "TAILGUNNER",
        "a small cartoon car seen from the side firing a rocket backwards out of "
        "its rear end, the rocket trailing blue flame",
        "navy blue and electric blue flame on white",
    ),
    "whats_mine_is_yours": (
        "WHAT'S MINE IS YOURS",
        "a round military land mine wearing a big pink gift bow on top",
        "olive drab and hot pink on cream",
    ),
    "pepper_shaker": (
        "PEPPER SHAKER",
        "a diner-style glass pepper shaker tipping over and pouring out brass "
        "bullet casings instead of pepper",
        "diner red and white checkerboard band with black lettering",
    ),
    "backyard_bbq": (
        "BACKYARD BBQ",
        "a kettle barbecue grill with cartoon flames, a tiny toy car sizzling on "
        "the grate next to two hot dogs, a flaming bottle standing beside it",
        "flame orange and charcoal black on mustard yellow",
    ),
    "shock_therapy": (
        "SHOCK THERAPY",
        "two taser prongs with a crackling lightning bolt between them, a "
        "heartbeat monitor line running through the lettering",
        "electric blue and white on black",
    ),
    "grille_kill_kult": (
        "GRILLE KILL KULT",
        "a snarling chrome car radiator grille bared like a mouth full of teeth",
        "chrome silver and blood-free black; the lettering in a spiky, "
        "hand-drawn heavy-metal style (invented, not any real band's logo)",
    ),
    "gotta_crash_em_all": (
        "GOTTA CRASH 'EM ALL",
        "a bouncing chrome hubcap mid-spin with cartoon crash stars around it",
        "bold cartoon red, white and sunshine yellow with a thick blue outline "
        "on the lettering",
    ),
    "special_delivery": (
        "SPECIAL DELIVERY",
        "a cardboard parcel box tied with string, a lit fuse sticking out of the "
        "top, a red rubber-stamp mark on its side",
        "cardboard brown, postal red and cream",
    ),
    "day_tripper": (
        "DAY TRIPPER",
        "a big 1970s sunset over a two-lane road running to the horizon",
        "retro sunset stripes of orange, amber and brown on cream",
    ),
    "long_hauler": (
        "LONG HAULER",
        "a silhouette of an 18-wheel semi truck on an endless highway, mileage "
        "marker posts along the shoulder",
        "trucker green and chrome white with a red pinstripe",
    ),
    "road_king": (
        "ROAD KING",
        "a golden crown sitting on top of a steering wheel",
        "metallic gold and royal purple",
    ),
    "student_driver": (
        "STUDENT DRIVER",
        "a black-and-yellow caution triangle containing a tiny nervous cartoon "
        "car with sweat drops flying off it",
        "caution yellow and black, like a real learner-driver sign",
    ),
    "brake_for_nobody": (
        "I BRAKE FOR NOBODY",
        "a single fresh tire track running straight across the sticker with no "
        "skid marks at all",
        "grass green and white with black tread",
    ),
    "my_other_car": (
        "MY OTHER CAR IS ALSO TOTALED",
        "a small crumpled cartoon sedan with cartoon dizzy stars and a wisp of "
        "steam",
        "white lettering on royal blue, a thin red border line",
    ),
    "thelma_and_louise": (
        "THELMA AND LOUISE",
        "a tiny silhouette of an open convertible sailing off a desert cliff edge "
        "into a sunset, no people visible",
        "desert orange, dusty pink and deep canyon red",
    ),
    "under_da_sea": (
        "UNDER DA SEA",
        "a cartoon car sinking nose-first with bubbles rising, a small smiling "
        "fish swimming past",
        "aqua, teal and sandy yellow",
    ),
    "target_practice": (
        "TARGET PRACTICE",
        "a red and white bullseye target riddled with bullet holes, a tiny "
        "cartoon car stuck dead center",
        "target red and white with black lettering",
    ),
}

BRIEF = """\
Task: generate ONE raster image with the built-in image_gen tool, then copy \
the final PNG to ./{id}.png in the current working directory. Do not create \
or modify any other file besides that PNG. Finish by reporting the saved path.

Use: an achievement badge for an indie vehicular-combat video game. \
Achievements in this game are BUMPER STICKERS: each one is a single parody \
car bumper sticker. The game is a grimy 16-bit dystopian demolition derby, \
but the stickers themselves are cheeky and funny, never grim.

The sticker: ONE long horizontal die-cut vinyl bumper sticker, roughly 3:1 \
(three times as wide as it is tall), lying perfectly flat and seen straight \
on, as if scanned. Around the whole sticker runs a clean white die-cut vinyl \
border about 3% of its height. Inside: bold screen-printed flat spot colours \
(2-3 inks plus white), a slogan in chunky, highly legible lettering that \
dominates the sticker, and ONE small illustration at the left or right end.

Slogan, exact text, verbatim, the only lettering anywhere in the image: \
"{slogan}". Spell it exactly like that. It may break onto two lines if it \
reads better. No other words, letters or numbers.

Illustration: {motif}.

Palette: {palette}.

Wear: lightly weathered 1990s vinyl: a little sun-fade, a few fine scuffs, \
one tiny lifted corner. Still bright and readable from across a parking lot.

Canvas: landscape 3:2 (1536x1024). The sticker is centred and fills about 90% \
of the canvas width. Everything around the sticker is PURE BLACK #000000, \
perfectly flat and uniform, with no texture, gradient, shadow or glow, so the \
sticker can be cut out cleanly. No drop shadow under the sticker.

Style: bold flat graphic print, clean shapes, crisp edges, retro 1980s-1990s \
bumper-sticker design sensibility.

Avoid: any lettering other than the slogan, misspellings, real-world brand \
names, logos, trademarks or mascots, real band logos, real people or \
likenesses, gore, blood, weapons pointed at people, a car bumper or car body \
behind the sticker, perspective tilt, curled sticker, photoreal rendering, \
3D render look, watermark, signature, frame, UI.
"""


def brief_for(sticker_id: str) -> str:
    slogan, motif, palette = STICKERS[sticker_id]
    return BRIEF.format(id=sticker_id, slogan=slogan, motif=motif, palette=palette)


def main(argv: list) -> int:
    if len(argv) == 2 and argv[1] == "--list":
        for sid in STICKERS:
            print("%-20s %-30s %s" % (sid, STICKERS[sid][0], STICKERS[sid][1][:60]))
        return 0
    if len(argv) == 3 and argv[1] == "--write-all":
        out = Path(argv[2])
        out.mkdir(parents=True, exist_ok=True)
        for sid in STICKERS:
            (out / ("brief_%s.md" % sid)).write_text(brief_for(sid))
        print("wrote %d briefs to %s" % (len(STICKERS), out))
        return 0
    if len(argv) == 2 and argv[1] in STICKERS:
        sys.stdout.write(brief_for(argv[1]))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
