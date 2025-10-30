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

## CRITICAL: Regression Prevention Rules

### 🚫 BANNED PATTERNS (High Risk)
These patterns have caused multiple regressions and MUST be avoided:

1. **NO class_name declarations** - Use constants/enums within scripts only
   - ❌ `class_name BaseMissile`
   - ✅ `const TYPE_POWER = 0`

2. **NO inline comments in project.godot [input] section** - Comments must be on separate lines
   - ❌ `#Commentaction_name={`
   - ✅ `# Comment` + `action_name={`

3. **NO cross-script enum references** - Use integer constants instead
   - ❌ `BaseMissile.MissileType.POWER`
   - ✅ `0  # TYPE_POWER`

4. **NO complex script dependencies** - Each script should be self-contained

### ✅ SAFE PATTERNS (Recommended)
1. **Use constants within scripts**: `const TYPE_POWER = 0`
2. **Use configuration dictionaries**: `const CONFIGS = {TYPE_POWER: {...}}`
3. **Validate input actions in _ready()**: Always check `InputMap.has_action()`
4. **Test compilation after changes**: Run headless test immediately

### 🔍 MANDATORY CHECKS
Before any script changes:
1. Run `godot --headless --path . --quit` to verify compilation
2. Check input actions are not corrupted in project.godot
3. Ensure no "default red car" fallback behavior
4. Test WASD movement in-game

### 📋 REGRESSION SYMPTOMS
If you see these, STOP and fix immediately:
- "Default red car" with no character selection applied (triggers `_apply_default_colors()`)
- WASD keys not responding in-game
- Script compilation errors mentioning "not declared in scope"
- Input actions showing as missing in debug output
- Parse errors during scene transitions

### 🛠️ Prevention Tools
- Health check system: `scripts/debug/health_check.gd`
- Code validator: `scripts/debug/code_validator.gd`
- Quick regression check in PlayerCar._ready()
- Auto-repair input bindings via `_ensure_core_input_bindings()`

## Development Workflow

1. **FIRST**: Check for regression symptoms before starting work
2. Reference `docs/requirements.md` for feature scope alignment
3. Ensure all changes maintain 16-bit dystopian aesthetic consistency
4. Test vehicle handling feels distinct per car while maintaining readability from top-down view
5. Prioritize environmental destruction and verticality in level design
6. Validate AI behaviors create unpredictable but fair combat encounters
7. **LAST**: Run compilation test and verify no regressions introduced