# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bent Chrome** is a top-down vehicular combat game being developed in Godot 4. This is a greenfield project in early planning stages with design documents but no code implementation yet.

### Key Design Elements
- Top-down 16-bit retro arcade style with grimy dystopian flair
- Eight-directional driving with inertia, drift, and surface-based handling modifiers
- Three weapon types per vehicle: machine guns (infinite), primary weapons (ammo-limited), and special weapons (auto-recharging)
- Environmental destruction, verticality through ramps/pits, and scavenging-based gameplay
- Six progressive levels from tutorial arena to final boss fight

## Development Environment Setup

Run `./RUNME.sh` to check for required dependencies:
- **Godot 4.2+** Standard build (binary must be on PATH)
- **Python 3.10+** for scripting and automation
- **git** and **rg** (ripgrep) for tooling
- SDL2 development libraries may be needed for native modules later

## Architecture Guidelines

### Core Systems to Implement
1. **Movement System**: Inertia-based eight-directional driving with surface modifiers (road, dirt, shallow/deep water)
2. **Combat System**: Three-tier weapon architecture with different ammo/recharge mechanics
3. **Health System**: Major restore points (3 shared per level) and minor random pickups
4. **Environment System**: Destructible props, hazards, and vertical elements
5. **AI System**: Multiple archetypes (aggressor, ambusher, defender, mini-boss, boss)

### Technical Targets
- **Engine**: Godot 4 with GDScript (optional C# modules)
- **Physics**: Tilemap-based terrain with lightweight rigid-body vehicles
- **Rendering**: 2D sprites with pseudo-lighting overlays
- **Performance**: 60 FPS locked on mid-range GPUs
- **Packaging**: AppImage for Linux distribution

## Key Design Documents

- **`master_design.txt`**: Complete game design specification (reference only, do not modify)
- **`docs/requirements.md`**: Condensed technical requirements and system checklist
- **`prompts/README.md`**: Guidelines for documenting Claude Code interactions

## Level Progression Structure

1. **Arena (Small)** - Tutorial with 1 enemy
2. **Freeway (Medium)** - 3 enemies, multi-tiered interchanges
3. **Suburbs (Medium)** - 5 enemies, flat destructible terrain
4. **Junkyard (Small+)** - Mini-boss with debris hazards
5. **Downtown (Large)** - 7 enemies, landmark-rich city
6. **Central Park (Boss)** - Final boss arena continuing Downtown topology

## Prompt Documentation

When working on features, log interactions in `prompts/` using the format:
- Filename: `YYYY-MM-DD-feature-name.md`
- Include: original prompt, Claude's plan, follow-up notes/edits

This helps track implementation decisions and reuse effective prompt patterns.

## Development Workflow

1. Reference `docs/requirements.md` for feature scope alignment
2. Ensure all changes maintain 16-bit dystopian aesthetic consistency
3. Test vehicle handling feels distinct per car while maintaining readability from top-down view
4. Prioritize environmental destruction and verticality in level design
5. Validate AI behaviors create unpredictable but fair combat encounters