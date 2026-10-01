# Route 666 billboards drop-in folder

Illustrated faces for the parody billboards along Route 666
(`levels/chase/highway_deco.gd`, kind `billboard`). Same contract as
`assets/img/jacked/` and `assets/img/stickers/`: the name IS the wiring, and an
absent file never breaks anything — a board without art draws its copy as
text.

| File | What it is |
|---|---|
| `<slug>.png` | that copy line's painted face, 1360×520, opaque |
| `source/` | briefs, logs and full-size originals (`.gdignore`d: never imported, never shipped; the PNGs stay local) |

## The slug rule

`HighwayDeco.slug_for(copy)`: the copy's FIRST line, lowercased, every run of
anything but a-z0-9 folded to one `_`, none leading or trailing. `SLO MO'S` →
`slo_mo_s`, `LAWYER?` → `lawyer`, `THE BUZZARDZ` → `the_buzzardz`. Slugs are
unique across `BILLBOARD_COPY` and the truckstop's `DINER_COPY`
(`mercy_diner`); `tests/test_chase_course.gd` `test_billboard_art` locks that
and rejects any PNG here not named for a line in the table.

## What the game does with it

`art_for(copy)` finds `res://assets/img/billboards/<slug>.png` (imported or a
raw drop-in) and `_draw_billboard` draws it as the board face with
`draw_texture_rect` — the posts, the dark backing, the frame line, the bulb
strip and the sunset's long shadow are drawn around it as on a text board,
and NO text is drawn over it: the painting carries the copy. Nearest
filtering is the project default, so the 4× art reads crisp at the chase's
0.55 zoom.

## Rules

- **1360×520, opaque, a flat matte with the picture and the lettering on it.**
  No frame, no posts, nothing outside the board. `tools/billboard_brief.py
  --normalize SRC DST` makes exactly that from a `source/` take.
- **The copy is the only lettering, spelled exactly** as `BILLBOARD_COPY` has
  it. The test lints file names only; the spelling check is a human review,
  letter by letter.
- **16-bit pixel art, silly, never grim.** No real brands.

## After adding or replacing a PNG

Run `tools/smoke.sh` (or open the project in the editor) once: it imports the
project, and Godot's import cache does not refresh on its own — until it does,
the game falls back to the raw file via `Image.load_from_file`, which works
but costs a decode on every board that spawns.

Pictures, matte colours, the image brief and the regeneration recipe:
`docs/art_briefs/billboards.md`.
