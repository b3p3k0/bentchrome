# Jacked cards drop-in folder

The last beat of a Route 666 robbery (`ui/robbery_screen.gd`): the driver and
their ride, left on the shoulder. Same contract as `assets/sfx/` and
`assets/boot/`: the name IS the wiring, and an absent file never breaks
anything.

| File | What it is |
|---|---|
| `<car_id>.png` | that car's jacked card, e.g. `hornet.png` (ids = `assets/data/roster.json`) |
| `_generic.png` | optional shared card for any car without its own |
| `source/` | full-size originals and rejected takes (`.gdignore`d: never imported, never shipped) |

## The fallback ladder

`robbery_screen.gd::art_path()` takes the first rung that exists:

1. `assets/img/jacked/<car_id>.png`
2. `assets/img/jacked/_generic.png`
3. `assets/img/bios/<car_id>.png`, shown bruised (dark red tint) as a stand-in
4. nothing: the splash beat is skipped and the verdict rolls straight on

## Rules

- **1536x1024, landscape 3:2**, the same as `assets/img/bios/`. Any size
  letterboxes over black, but matching the portraits keeps the set consistent.
- **Keep the bottom 15% clear.** The caption strip covers it.
- **Continuity is the whole job.** The driver and car must be the ones from
  the selection carousel. `tests/test_jacked_art.gd` only lints file names;
  likeness is a human review.
- **Humiliated, not hurt.** Cheeky, never grim: no gore, no wounds.

Scenes, the image brief, and the regeneration recipe:
`docs/art_briefs/jacked_cards.md`.
