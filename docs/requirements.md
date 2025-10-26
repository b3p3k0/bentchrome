# Bent Chrome – System Requirements Snapshot

This document condenses the master design specs into quick-reference points we can reference while scoping tasks or writing prompts for Claude Code.

## Core Pillars
- Speedy, destructive vehicular combat with eight-directional driving, ramps, pits, and multiple surface types that affect traction.
- Distinct vehicle silhouettes and handling; each car has machine guns (infinite), a finite primary weapon, and an auto-recharging special.
- Arena structure that rewards scavenging, environmental destruction, and short-term improvisation under pressure.

## Level Progression Targets
1. **Arena (Small)** – tutorial, 1 enemy, compact onboarding.
2. **Freeway (Medium)** – 3 enemies, multi-tiered interchanges.
3. **Suburbs (Medium)** – 5 enemies, flat/destructible suburbia.
4. **Junkyard (Small+)** – single mini-boss, debris hazards.
5. **Downtown (Large)** – 7 enemies, landmark-rich city hub.
6. **Central Park (Boss)** – confined boss arena continuing Downtown’s topology.

## Enemy & AI Variety
- Archetypes: aggressor, ambusher, defender, mini-boss, boss.
- Mix behaviors per level for unpredictability: target switching, cover use, aggression ramps.

## Systems Checklist
- **Movement:** Inertia, drift, handling modifiers per surface, respect impassable deep water.
- **Combat:** Machine guns (infinite), pickup-based primaries, regenerating specials, temporary power-ups.
- **Health:** Shared major restore points (3 per level), random minor pickups, persistent inventory between levels.
- **Environment:** Destructible props, ramps, verticality, hazards (explosives, electrical, debris).

## Technical Targets
- Engine: Godot 4 (primary) with GDScript; optional C# modules.
- Physics baseline: Tilemap-first with lightweight rigid bodies.
- Rendering: 2D sprites + pseudo-lighting overlays, 16-bit grimy dystopian aesthetic.
- Input abstraction: SDL2/native for keyboard, mouse, controllers.
- Packaging: AppImage focus; 60 FPS on mid-range GPUs.

Use this page when drafting implementation prompts so we keep scope aligned with the official master plan.
