# Bent Chrome – System Requirements Snapshot

This document condenses the master design specs into quick-reference points we can reference while scoping tasks or writing prompts for Claude Code.

## Core Pillars
- Speedy, destructive vehicular combat with free-angle arcade driving (inertia, drift, surface-sensitive handling; vehicles drawn as procedural per-car bodies quantized to 16 compass steps), ramps, pits, and multiple surface types that affect traction.
- Distinct vehicle silhouettes and handling; each car has machine guns (infinite), a finite primary weapon, and an auto-recharging special.
- Arena structure that rewards scavenging, environmental destruction, and short-term improvisation under pressure.
- Regular campaign/MP arena contract: `docs/arena_field_manual.md` (machine floor in `levels/arena_contract.gd`).

## Regular Arena Targets
- Minimum four fielded cars, including boss arenas' underlying MP capacity.
- Small / medium / large = 4 / 5–7 / 7–8 target cars.
- Gross interior budget ≥1,600,000 px² per target car; short side ≥2048px.
- One authored scene serves campaign and LAN; Buzzard Run is the specialty exception.
- Depot and Coliseum are named temporary MP exceptions until neutral four-plus spawn data is separated from their boss actors.
- Every grade slows ascent and assists descent; surface terrain still composes. Ordinary pull =120 px/s²; Coliseum stairs retain 170 + row bumps.
- Four cardinal grades plus four triangular corner grades are the standard eight-sided hill approximation; solid top-side gaps use a two-floor triangular chamfer.

## Enemy & AI Variety
- Archetypes: aggressor, ambusher, opportunist — a blendable weight mix `Vector3(aggressor, ambusher, opportunist)` so pure types and hybrids share one system; plus tougher mini-boss/boss variants.
- Mix behaviors per level for unpredictability: target switching, cover use, aggression ramps.

## Systems Checklist
- **Movement:** Inertia, drift, handling modifiers per surface, respect impassable deep water.
- **Combat:** Machine guns (infinite, overheat lockout — built), pickup-fed standard/homing missiles (built), regenerating per-car specials (built, per-car caps via `VehicleStats`), temporary power-ups (pending).
- **Health:** Shared major restore points (3 per level), random minor pickups, persistent inventory between levels.
- **Environment:** Destructible props, ramps, verticality, hazards (explosives, electrical, debris).
- **Custom levels:** JSON level format + whitelisting loader + standalone graphical editor (built — `docs/level_editor.md`); in-game custom-levels menu (pending, ships with editor/game UI integration).

## Technical Targets
- Engine: Godot 4 (primary) with GDScript; optional C# modules.
- Physics baseline: Tilemap-first with lightweight rigid bodies.
- Rendering: 2D sprites + pseudo-lighting overlays, 16-bit grimy dystopian aesthetic.
- Input: Godot `InputMap` actions (keyboard, mouse, controllers) via the `InputRouter` autoload; actions validated on boot.
- Packaging: AppImage focus; 60 FPS on mid-range GPUs.

Use this page when drafting implementation prompts so we keep scope aligned with the official master plan.
