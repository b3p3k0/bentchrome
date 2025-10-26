# Player Selection Screen Implementation

**Date:** 2025-10-26
**Feature:** First-pass data-driven Player Selection screen
**Status:** Completed

## Original User Request

Implement a comprehensive Player Selection screen that lets users browse 9 characters, show text overlays on portraits, display "More Info" dialog, and confirm into the existing Test Arena. Flow should be single-player with the choice stored for later systems to access.

### Key Requirements
- Character portraits from `assets/img/bios/` (9 total)
- Data-driven roster with writer-editable JSON
- Input mapping for selection navigation (separate from gameplay)
- Full viewport UI with portrait display and stat overlay
- "More Info" popup with expanded character details
- Integration with existing TestArena via Main.tscn
- SelectionState autoload for cross-scene character data

## Claude's Implementation Plan

### 1. Data Infrastructure
- ✅ **`assets/data/roster.json`** - 9 alphabetical character entries (Bumper → Splat Cat)
  - Writer-friendly header comment and ASCII-only format
  - Ornery flavor text, believable 1-5 stats, portrait paths
- ✅ **`scripts/managers/selection_state.gd`** - Autoloaded singleton for roster management
  - `load_roster()`, `set_selection()`, `get_selection()`, `has_selection()`

### 2. Input System
- ✅ **Updated `project.godot`** with new selection actions:
  - `select_prev_car` / `select_next_car` (A/D, arrows, D-pad, left stick X)
  - `select_more_info` (W, Square/West button)
  - `select_confirm` (Enter, Space, Cross/South button)
  - Enhanced existing move actions with arrow keys + D-pad + stick support

### 3. UI Implementation
- ✅ **`scenes/ui/PlayerSelect.tscn`** - Full viewport Control layout
  - Center portrait TextureRect with KEEP_ASPECT_CENTERED
  - Overlay containers for car/driver names and stat grid
  - Navigation helpers (arrow indicators, instruction text)
  - PopupPanel for "More Info" with expanded details
- ✅ **`scripts/ui/player_select.gd`** - Navigation and state management
  - A/D cycling with wraparound, W toggles popup
  - Enter confirms → SelectionState.set_selection() → Main.tscn
  - Graceful error handling for missing portraits

### 4. Game Integration
- ✅ **Updated `scripts/vehicles/player_car.gd`**
  - SelectionState.has_selection() check in _ready()
  - Logging of selected character info
  - Temporary stat mapping: `max_speed = 150 + top_speed * 25`
  - TODO comments for future handling model integration
- ✅ **Changed main_scene** from Main.tscn to PlayerSelect.tscn

### 5. Documentation
- ✅ **Updated `README.md`** with Player Selection section
  - Controls explanation, stat descriptions, flow overview
- ✅ **Created this prompt documentation**

## Implementation Notes

### Technical Decisions
- **JSON Format**: Used commented JSON with ASCII-only content for writer accessibility
- **Input Isolation**: Selection actions don't conflict with gameplay WASD bindings
- **Navigation Logic**: Popup blocks character cycling to prevent confusion
- **Stat Integration**: Simple linear mapping with clear TODO markers for future expansion
- **Error Handling**: Graceful fallbacks for missing portraits/malformed data

### Character Data Structure
```json
{
  "id": "bumper",
  "car_name": "Bumper",
  "driver_name": "Tank Morrison",
  "flavor": "2-3 sentence ornery backstory...",
  "stats": {
    "acceleration": 2, "top_speed": 3, "handling": 2,
    "armor": 5, "special_power": 4
  },
  "portrait": "res://assets/img/bios/bumper.png"
}
```

### Key UI Behaviors
- **A/D Navigation**: Cycles through 9 characters with wraparound
- **W Toggle**: Opens/closes More Info popup, blocks navigation when open
- **Enter Confirm**: Sets SelectionState and transitions to Main.tscn
- **Visual Feedback**: Portrait updates, stat display, helper text visibility

## Testing & Verification

Tested with: `godot4 --headless --path . --quit`
- ✅ Project loads without errors
- ✅ New main scene (PlayerSelect.tscn) initializes correctly
- ✅ SelectionState autoload registers properly
- ✅ Input mappings load without conflicts

## Follow-up Tasks & Future Enhancements

### Immediate TODOs
- **Stat Mapping**: Replace temporary linear formulas with proper handling model
- **Visual Polish**: Add selection highlight/tween animations
- **Audio**: Selection/navigation sound effects
- **Portrait Validation**: Better fallback system for missing/corrupted images

### Future Integration Points
- **Handling Model**: Map stats.handling to turn rate/drift coefficients
- **Armor System**: stats.armor affects collision/weapon damage resistance
- **Special Weapons**: stats.special_power modifies cooldown/effectiveness
- **Visual Variation**: Character-specific vehicle sprites/colors
- **Campaign Integration**: Save selected character across levels
- **Multiplayer Prep**: Multiple character selection for split-screen/co-op

## Files Created/Modified

### New Files
- `assets/data/roster.json` - Character roster data
- `scripts/managers/selection_state.gd` - Selection state singleton
- `scenes/ui/PlayerSelect.tscn` - Player selection scene
- `scripts/ui/player_select.gd` - Selection navigation logic
- `prompts/2025-10-26-player-select.md` - This documentation

### Modified Files
- `project.godot` - Input actions, autoload, main scene
- `scripts/vehicles/player_car.gd` - SelectionState integration
- `README.md` - Player Selection documentation

## Reusable Patterns

This implementation establishes several patterns for future UI work:
- **Data-driven approach**: JSON + singleton state management
- **Input action separation**: UI vs gameplay input namespacing
- **Popup dialog pattern**: Modal overlay with input state management
- **Graceful degradation**: Fallbacks for missing/invalid assets
- **TODO-marked integration points**: Clear extension hooks for future systems

The SelectionState singleton provides a foundation for any future character/loadout selection screens, and the input pattern can be reused for other menu navigation systems.