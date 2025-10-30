# Bent Chrome – AI Opponent Architecture Draft

This document captures the scaffolding handed off to Claude Code for building our AI opponent stack. No gameplay logic has been written yet—everything here is structure and marching orders.

## Data Flow Overview

- **Roster Source** – `assets/data/roster.json` already defines per-car stats, colors, and lore. Every AI car must reference this file so we never duplicate numbers.
- **AI Behavior Config** – `assets/data/ai_profiles.json` (new) maps roster IDs to archetype-level behavior. It ships with defaults plus a single template entry Claude should replicate for the full roster.
- **Loader Singleton** – `scripts/ai/ai_profile_loader.gd` is a stub that will become the runtime bridge between JSON data and in-game enemy controllers.
- **Archetype Registry** – `scripts/ai/ai_archetype_registry.gd` holds shared knobs for each archetype (aggressor, ambusher, defender, mini_boss, boss). Treat it as a central place to expose tuning for designers.

```
roster.json (stats/colors)
        │
        │  +----> ai_profiles.json (behavior tuning)
        │  │
        ▼  ▼
AIProfileLoader (autoload) ──> EnemyCar controller(s) ──> GameManager.spawn_enemy(...)
```

## Implementation Tasks for Claude

1. **Populate `ai_profiles.json`**
   - Iterate over every roster ID.
   - Choose an archetype and fill out state weights, weapon usage heuristics, mobility preferences, and triggers.
   - Respect the defaults block so only deviations need explicit values.

2. **Finish `AIProfileLoader`**
   - Parse the JSON, merge the `defaults` block with per-profile overrides, and expose helper accessors (`get_profile`, `get_profiles_by_archetype`, etc.).
   - Hook the singleton into Godot’s Autoload list to make it available everywhere.
   - Provide validation logs so missing roster IDs or malformed data surface cleanly.

3. **Implement `AIArchetypeRegistry`**
   - Back it with either a Resource, the JSON loader, or both—whatever keeps iteration fast.
   - Supply editor-visible properties (reaction delays, aggression curves, special-weapon rules) so designers can tweak without diving into code.

4. **Prepare Enemy Controller Skeleton**
   - Duplicate the shared vehicle controller once it exists (goal: split player input from vehicle physics) and attach AI decision layers driven by the profile data.
   - Use the loader to initialize each enemy at spawn time, aligning stats with the roster entry and behavior with the profile.

5. **Integrate With GameManager**
   - `GameManager.spawn_enemy` calls `set_ai_type`; evolve this API to pass the roster ID or profile key so the enemy knows which config to pull.
   - Emit useful debug info (state, target, timers) for tuning overlays.

## Follow-Up Notes

- Reaction/aim numbers mentioned in chat should live in either the defaults block or archetype registry so designers can tune globally.
- Keep all new JSON strictly ASCII and comment-free; rely on `_meta` sections for human-readable notes.
- When adding brand-new cars, the workflow should be:
  1. Append to `roster.json`.
  2. Add a companion entry in `ai_profiles.json`.
  3. (Optional) Update archetype baseline if the car adds a new behavior twist.

Ping Codex before shipping major changes so we can keep the docs aligned with reality.
