# SFX drop-in folder

Drop a sound file in here with one of the names below and it plays on the next
launch. No import step, no code change, no registration — the name IS the
wiring. Missing files are silent no-ops (the game never crashes over sound),
and the boot log always tells you the score:

    [sfx] loaded 3/10 events — awaiting assets: crash, skid, ...

## Rules

- **Formats:** `.ogg` or `.wav` (if both exist for one event, `.ogg` wins).
- **Names:** exact, lowercase, no spaces — `mg_fire.ogg`, not `MG Fire.ogg`.
- Freshly dropped files load raw; once the Godot editor has imported them they
  load through the importer instead (that's also what exported builds use), so
  keep files in this folder either way.
- Per-event volume trim and pitch jitter live in `game/audio_director.gd`
  (`CATALOG`) — tune there, not in the asset.

## The names

| File | Plays when | Guidance for picking the asset |
|---|---|---|
| `mg_fire` | your MG fires (12/s!) | very short tick/pop; it gets pitch-jittered |
| `missile_fire` | you fire any missile or projectile special | whoosh/launch |
| `mine_drop` | you deploy a mine | mechanical clunk |
| `crash` | you're in a real collision, either side | metal impact |
| `skid` | **loops** while your handbrake lays rubber | seamless tire squeal loop |
| `hit_mg` | MG fire hits YOU | small tink (rapid repeats) |
| `hit_weapon` | a missile/special/mine hits YOU | meaty thud |
| `player_death` | you're destroyed | big send-off |
| `npc_death` | a rival is destroyed (positional — quieter when far) | explosion |
| `spawn` | level start and every respawn | power-up / engine start |
| `ram_warn` | Goliath commits a ram charge (positional) | air horn / engine roar — the tell |

Adding a NEW event = one `CATALOG` row in `game/audio_director.gd` plus a
`play()`/`play_at()`/`loop_set()` call at the gameplay moment.
