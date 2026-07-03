# Level editor

A standalone graphical editor for building custom arenas — drag-drop placement,
grid snapping, one-click playtest. It writes the JSON format described in
[level_format.md](level_format.md); the game loads those files through
`LevelLoader`, which only instantiates whitelisted entity types, so shared fan
levels are data, never code.

## Launching

```
tools/editor.sh
# or directly:
godot --path . res://editor/editor_main.tscn
```

It lives in this repo and shares the game's scenes and autoloads, which is what
makes the playtest button and later in-game integration cheap.

To play a level without the editor:

```
godot --path . res://levels/custom_level.tscn -- --level=user://levels/mylevel.json
```

## Controls

| Action | Input |
|---|---|
| Pan | Middle-mouse drag, or hold Space + left drag |
| Zoom | Mouse wheel (anchored on the cursor) |
| Place entity | Click a palette tool, then click the canvas (repeats until ESC/right-click) |
| Paint terrain | Dirt/Ice/Water tool, drag a rectangle (128px grid) |
| Select / move | Select tool: click an entity, drag to move (64px snap) |
| Delete | Select something, press Delete or Backspace |
| Undo / redo | Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y |
| Save | Ctrl+S or the toolbar |

Notes that surprise people:

- The **player start always exists** — placing it again moves it. It can't be
  deleted. The green arrow shows spawn facing (edit the angle in the inspector).
- **Enemy starts are position-only markers** (max 4). The game picks random
  opponents for them at load; each car brings its own locked AI personality.
- The **wall band is generated from the level bounds** — you don't place
  boundary walls, you resize the level in the right-hand panel (128px steps).
- **Validate** and the status-bar problem count run the same rules the game
  enforces at load; **Playtest refuses an invalid level** and lists why.

## The playtest loop

Playtest saves your working state (even unsaved edits) to
`user://levels/_playtest.json` and boots the game into it. ESC in-game shows a
**Return to Editor** button that brings back exactly what you playtested; your
real file is only written by explicit Save.

## Packaging rules (for whoever creates export presets)

No `export_presets.cfg` exists yet. When presets land:

- **Game presets must exclude `editor/*`** (resource exclude filter), or the
  editor ships inside the game pack.
- An **editor build** is a second preset with a custom feature tag
  `level_editor` — `project.godot` already maps
  `run/main_scene.level_editor` to the editor scene, so no code changes needed.

## Adding a new placeable entity (ramp/pit team, read this)

The editor and loader share one whitelist: `levels/entity_catalog.gd`. To make
your entity placeable:

1. Ship it as one **self-contained `.tscn`** under `environment/`, root a
   Node2D-family node. It must work instanced under a plain Node2D with only
   `position`/`rotation` set before `add_child` — no assumptions about siblings,
   parents, or the arena scene.
2. All per-instance config is **typed `@export` vars with sane defaults**,
   settable before `add_child`. No per-instance scripts, no required setup calls.
3. Register a catalog entry: id, `list_key`, scene path, props (with min/max/
   step), ghost color/half-size/tag. Add the list key + validation rules to
   `levels/level_schema.gd` and document the fields in `level_format.md`.
4. Use the **named collision layers** (1 ground / 2 wall / 3 obstacle /
   8 terrain); don't invent unnamed layers.
5. Schema changes are **additive-only** — new optional keys, never repurposed
   ones. Propose the JSON shape before landing so the schema, docs, and loader
   bump together.
6. Keep footprints grid-friendly (multiples of 64/128) and visuals
   approximable as a flat polygon for the ghost until sprites land.

## Manual test checklist (what headless gates can't cover)

The smoke gate boots the editor and a fixture level headless; unit tests cover
schema, loader, and document logic. Still needs eyes and a mouse:

- Pan/zoom feel; ghost colors vs the same level playtested.
- Palette → place → drag-move → Delete round trip for every entity type.
- Terrain drag preview and 128px snapping.
- Open/Save dialogs land in `user://levels`; Levels Folder button opens it.
- Full loop: edit → Playtest → drive → ESC → Return to Editor → edits intact.
- Unsaved-changes confirm on New/Open/window close; undo after each of the above.
