# BGM drop-in folder

Background music, same contract as `assets/sfx/`: drop `bgm_<name>.ogg` in
here and it plays on the next launch — the name IS the wiring, a missing file
is a silent no-op, and the boot log tells the score:

    [bgm] loaded 1/11 tracks — awaiting assets: bgm_menu, ...

`game/music_director.gd` owns WHICH track plays: it maps the current scene
through its `TRACKS` table, crossfades between two players (1.6s), keeps
playing DUCKED (-10 dB) while the tree is paused (pause menu, end screens,
the Goliath cutscene), and stamps every stream looping. Tracks are authored
as **seamless loops** — `tools/synth_bgm.py` composes one extra bar and
wrap-crossfades it over the head, so never hand-trim these files.

## Rules

- **Formats:** `.ogg` or `.wav` (`.ogg` wins when both exist). Stereo.
- **Names:** exact, lowercase — the `bgm_` prefix is what routes soundboard
  rows to the music director instead of the SFX pools.
- Loudness convention: every track masters through the same chain to the same
  RMS target (`tools/bgm/master.py`), so no per-track trim exists in-game.
- Regenerate with `./venv312/bin/python tools/synth_bgm.py [track ...]`
  (repo venv; `pip` deps: numpy, scipy, pedalboard — dev-box only, the game
  ships zero synthesis code). Only re-render tracks whose recipe changed:
  every regeneration re-adds the full blob to git history.

## The tracks

| File | Plays in | Brief |
|---|---|---|
| `bgm_menu` | title, all menus, MP lobby/scoreboard, Driver's Ed | slow doom-drone ambient (~72 BPM) |
| `bgm_arena` | Downtown Derby (+ custom-level fallback) | industrial rock stomp, 122 BPM — the style exemplar |
| `bgm_freeway` | Freeway Firefight | speed rock, 160 BPM |
| `bgm_suburbs` | Suburban Slaughter | drop-tuned grunge sludge, 95 BPM |
| `bgm_snowy` | Mountainside Mayhem | cold synth-led industrial, 110 BPM |
| `bgm_depot` | Lackey's Arena | menacing miniboss industrial, 126 BPM |
| `bgm_buzzard_run` | Route 666 Roulette | digital-hardcore chase, 175 BPM |
| `bgm_dock` | Piers of Pain | odd-groove heavy, 100 BPM |
| `bgm_ground_floor_gore` | Ground Floor Gore | industrial metal + machine-room textures, 135 BPM |
| `bgm_stadium_p1` | Goliath's Arena phase 1 | doom-stomp boss theme, 90 BPM |
| `bgm_stadium_p2` | Goliath's Arena phase 2 (via `start_phase2` override) | same riffs, double-time enraged, 150 BPM |

The interstitial loading card plays the UPCOMING level's track (same-track
requests are no-ops, so it rolls straight into the level). MP matches resolve
through the instanced arena — same table as single player; nothing touches
the wire. Scenes not in the table fall back to `bgm_menu`.

Reference links for vibe-matching passes live in `refs.md` (analysis-only —
character/spectrum/tempo get cloned, audio and melodies never do). The
dev-options SOUNDBOARD (Settings → Developer Options) lists every `bgm_*`
row after the SFX events; RIGHT toggles PLAY/STOP through the real music
players.
