# Custom level format (v1)

A Bent Chrome custom level is one JSON file describing an arena: its size, where
the walls are, and what's placed inside. The level editor writes these files for
you; this page is for anyone hand-editing one, building tools around them, or
debugging why a level won't load.

Levels are plain data — no scripts, no scene files. The game only instantiates
entity types it knows about, so a level file from a stranger can change your
arena, never your machine.

## Where files live

`user://levels/*.json` — on Linux that's
`~/.local/share/godot/app_userdata/Bent Chrome/levels/`. The editor's
"Levels Folder" toolbar button opens it so you never have to remember that
path. To install someone else's level, drop the `.json` in that folder.

## Example

```json
{
	"format": "bentchrome-level",
	"version": 1,
	"name": "Scrap Bowl",
	"author": "kevin",
	"description": "",
	"grid": 128,
	"bounds": { "width": 2944, "height": 2816 },
	"player_spawn": { "pos": [0, 0], "heading_deg": 0 },
	"enemy_spawns": [ { "pos": [448, -256] }, { "pos": [-704, 384] } ],
	"blocks":  [ { "pos": [-448, -256], "size": [128, 128] } ],
	"pickups": [ { "pos": [640, -128], "kind": "standard", "amount": 2, "respawn_seconds": 20.0 } ],
	"dummies": [ { "pos": [448, 128], "max_hp": 60.0 } ],
	"terrain": [ { "type": "dirt", "rect": [-1152, -768, 640, 512] } ]
}
```

## Coordinates

World pixels, origin at the center of the arena. `pos` is always an entity's
center. `rect` is `[x, y, w, h]` with `x, y` the top-left corner. The game
synthesizes 40px-thick boundary walls just inside the `bounds` edges — you
don't place walls, you get them for free, and nothing can be placed inside
that band.

## Fields

| Field | Required | Meaning |
|---|---|---|
| `format` | yes | Always `"bentchrome-level"`. |
| `version` | yes | Always `1`. Bumps only on breaking changes. |
| `name`, `author`, `description` | no | Shown in menus later. Defaults: `"Untitled"`, `""`, `""`. |
| `grid` | no | Always `128` in v1 (written for forward-compat). |
| `bounds` | yes | `width`/`height` of the arena including walls. Multiples of 128, each side 1280–4864. |
| `player_spawn` | no | `pos` + `heading_deg` (degrees, 0 = facing up). Defaults to arena center. |
| `enemy_spawns` | yes | 1–4 entries, `pos` only. The game picks random opponents for them — each car brings its own AI personality. |
| `blocks` | no | Solid cover. `pos` (center) + `size [w, h]`, each side 64–1024. |
| `pickups` | no | Ammo crates. `kind`: `"standard"` or `"homing"`; `amount` 1–9 (default 2); `respawn_seconds` 1–120 (default 20). |
| `dummies` | no | Stationary practice targets. `max_hp` 1–999 (default 60). |
| `terrain` | no | Surface patches. `type`: `"dirt"`, `"grass"`, `"ice"`, or `"water"`; `rect` values must be multiples of 128. Unpainted floor is road. |

## Validation rules

A level must pass all of these before the game will load it (the editor's
Validate and Playtest buttons run the same checks and show the same messages):

- Exactly one player spawn, 1–4 enemy spawns.
- Spawns at least 192px apart, at least 168px clear of the bounds edge, and not
  on top of a block.
- Point entities (pickups, dummies) at least 104px clear of the bounds edge.
- Blocks and terrain rects entirely inside the walls.
- All kinds/types from the lists above — anything unknown is an error.
- Numeric fields inside the ranges above.

Unknown *top-level* keys are ignored with a warning instead of an error, so
files written by a newer game version still load where possible.

## For tool authors

The schema lives in one place: `levels/level_schema.gd` (`parse`, `serialize`,
`validate`, `make_empty`). Adding a new entity type to the format means a new
top-level list key, validation rules there, and a whitelist entry in the entity
catalog — schema changes are additive-only; keys are never repurposed.
