# Bumper Stickers drop-in folder

Art for the achievements ("bumper stickers"), shown in the sticker book
(`ui/sticker_book.gd`), in end-screen notices, and on the finale's prize beat.
Same contract as `assets/img/jacked/` and `assets/sfx/`: the name IS the wiring,
and an absent file never breaks anything.

| File | What it is |
|---|---|
| `<id>.png` | that sticker's art, e.g. `road_king.png` (ids = `assets/data/stickers.json`) |
| `source/` | full-size originals on a black matte (`.gdignore`d: never imported, never shipped) |

## The fallback

`ui/sticker_paint.gd` takes `<id>.png` when it exists. Without it, it paints a
procedural stand-in: a seeded vinyl colour, a white die-cut border, and the
sticker's name. A sticker with no art is still fully earnable and viewable.

## Rules

- **768x256, transparent, the sticker fitted inside with its aspect kept.**
  `tools/sticker_cutout.sh` produces exactly that from a `source/` take.
- **The slogan is the only lettering, spelled exactly.** It must match the
  sticker's name in the catalog. `tests/test_sticker_art.gd` checks file names
  only; the spelling check is a human review, letter by letter.
- **Cheeky, never grim.** No gore, no real brands, no real people.

Slogans, motifs, the image brief and the regeneration recipe:
`docs/art_briefs/bumper_stickers.md`.
