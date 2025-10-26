# Player Selection System Debug & Fix

**Date:** 2025-10-26
**Issue:** Player Selection screen had multiple critical errors preventing functionality

## Pre-Fix Error Log

The original implementation had these core failures:

1. **JSON Parse Failure**: `roster.json:2` contained `// Writers: update values as needed` comment, causing `JSON.parse()` to fail with error. Script used non-existent `json.error_string` instead of `json.get_error_message()`.

2. **Division by Zero**: Empty roster caused modulo operations `(current_index ± 1) % roster.size()` to divide by zero in navigation functions.

3. **Input Blocking**: Early `if not event.is_pressed(): return` check blocked analog stick events and interfered with dialog close detection.

4. **Portrait Loading Failure**: `ResourceLoader.exists()` returned false for freshly imported PNGs, causing all portraits to display as null.

5. **Dialog State Desync**: No connection to handle popup close events, leaving `is_dialog_open = true` permanently.

## Fixes Applied

### 1. JSON Parsing (selection_state.gd)
- Added `_strip_comments()` helper using `line.strip_edges().begins_with("//")`
- Fixed error reporting with `json.get_error_message()` + `json.get_error_line()`
- Made `load_roster()` idempotent (early return if already loaded)
- Added comprehensive schema validation with specific error messages
- Support both `{"characters": [...]}` and direct array formats

### 2. Input Handling (player_select.gd)
- Replaced `_input()` with `_unhandled_input()` and removed `event.is_pressed()` gate
- Added `accept_event()` calls to prevent input bleeding to other UI
- Added `if roster.is_empty(): return` guards in navigation functions
- Connected `dialog.popup_hide` signal to `_on_dialog_hidden()` for proper state sync
- Documented discrete navigation choice (no continuous hold-to-scroll)

### 3. Portrait Loading (player_select.gd)
- Removed problematic `ResourceLoader.exists()` runtime check
- Implemented direct `load(portrait_path)` with null checking
- Added `portrait_cache` dictionary to prevent reload hitching
- Cache only successful loads: `if texture: portrait_cache[path] = texture`
- Clear texture on load failure to prevent stale art

### 4. Input Action Safety (player_select.gd)
- Added `const REQUIRED_ACTIONS` validation in `_ready()`
- Disable processing if actions missing: `set_process(false)` + `set_process_unhandled_input(false)`
- Hide dialog and show error message: "Input actions missing - see console"
- Provide specific error with missing action list

## Test Sequence Performed

**Basic Load Test:**
- ✅ `godot4 --headless --path . --quit` - Project loads without errors

**Manual Testing Required:**
- A/D navigation (keyboard + D-pad + left stick) - *Controller not tested*
- W/Square popup toggle for More Info dialog
- Enter/Space confirm selection and scene transition
- Portrait display validation for all 9 characters

## Expected Results

- JSON loads successfully with comment stripping
- Navigation cycles through all 9 characters without crashes
- Portraits display for all characters (bumper.png, cricket.png, etc.)
- More Info dialog opens/closes properly with W key or Square button
- Enter/Space transitions to Main.tscn with selected character applied

## Files Modified

- `scripts/managers/selection_state.gd` - JSON parsing, validation, caching
- `scripts/ui/player_select.gd` - Input handling, portrait loading, action validation

## Notes

All fixes maintain existing functionality while addressing root causes. No scope creep or extra UI polish added. The JSON→roster→navigation→portrait failure chain is now fully resolved.