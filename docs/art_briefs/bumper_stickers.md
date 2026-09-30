# Bumper Stickers: art brief

Twenty parody bumper stickers, one per achievement in
`assets/data/stickers.json`. Each is a single die-cut vinyl sticker: the
sticker's name as its slogan, one small illustration, two or three flat inks.

Drop-in contract and fallback: `assets/img/stickers/README.md`.

## The three rules

1. **The slogan is the name, verbatim.** Image models misspell. Every take is
   read letter by letter against the catalog name before it ships.
2. **One sticker, flat, on pure black.** The brief asks for a straight-on,
   scanned-looking sticker on a flat `#000000` matte so the cutout can flood-fill
   the matte away without touching black ink inside the sticker.
3. **Cheeky, never grim.** The game is grimy; the stickers are jokes.

## House style

Weathered 1980s-90s vinyl: bold screen-printed spot colours plus white, chunky
legible lettering that dominates the sticker, a clean white die-cut border, a
little sun-fade, a few scuffs, one lifted corner. Readable at the gallery's
240x80 tile size.

## Stickers

`tools/sticker_brief.py` is the source of truth for each slogan, motif and
palette (`tools/sticker_brief.py --list` prints the table).

## Generating a sticker

Codex's built-in image tool generates one sticker per brief. Codex is not on
`PATH`; it ships inside the VS Code extension (use the 26.810 build; the newer
one can't run its sandbox on this host).

    CODEX=~/.vscode/extensions/openai.chatgpt-26.810.52044-linux-x64/bin/linux-x86_64/codex
    cd assets/img/stickers/source
    ../../../../tools/sticker_brief.py road_king \
        | $CODEX exec --skip-git-repo-check -s workspace-write -
    # writes ./road_king.png (originals also land in ~/.codex/generated_images/)

Review the take against the checklist below, then cut it out into place:

    tools/sticker_cutout.sh road_king     # or --all

To change a sticker, edit its entry in `tools/sticker_brief.py` and rerun. To
repair one detail of a take that is otherwise right (a single wrong letter),
attach the take with `-i`, name the single change, and list everything that must
stay; rerolling loses what already worked.

## Review checklist

| Check | Reject if |
|---|---|
| Spelling | any letter differs from the catalog name; extra words, letters or numbers |
| Matte | the background isn't flat pure black; a drop shadow or glow bleeds into it |
| Shape | more than one sticker; curled or in perspective; a car or bumper behind it |
| Legibility | the slogan doesn't read on a 240x80 tile |
| Tone | gore, blood, anything grim |
| Brands | a real logo, mascot, band mark or person |
| Cutout | after `sticker_cutout.sh`, black fringe or a missing white border on grey |
