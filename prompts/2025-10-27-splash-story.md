# 2025-10-27: Splash Story Screen Implementation

## Original Request
Extend the splash flow with a story option and dedicated story screen while keeping the existing "Start 1P → PlayerSelect → Main" path intact.

## Implementation Approach

### 1. Splash Menu Extensions
- Added "Story" button to SplashScreen.tscn VBox, maintaining same styling as Start button
- Implemented proper focus navigation with focus_neighbor_* properties
- Updated splash_screen.gd with story_button reference and open_story() method
- Modified _unhandled_input() to route ui_accept to focused button

### 2. Story Scene Creation
- Created StoryScreen.tscn with fullscreen layout:
  - Background TextureRect using martygraz.png with STRETCH_KEEP_ASPECT_COVERED
  - ColorRect overlay matching splash (Color(0, 0, 0, 0.3), mouse_filter = IGNORE)
  - Right-side text panel (60% area, anchored 0.6→1.0)
  - MarginContainer with specified padding (40px top/right/bottom, 0 left)
  - Label with font_size = 20, autowrap_mode = WORD_SMART
  - Bottom-center helper label "Press any key to return"

### 3. Story Script Logic
- Created story_screen.gd with JSON loading from assets/data/story.json
- Implemented character capacity calculation using font metrics
- Added comprehensive input handling for keyboard/mouse/controller
- Included error handling with fallback text for missing/malformed data

### 4. Data File
- Created story.json with placeholder Marty Graz content
- Used literal newlines in JSON string, preserving formatting as requested

### 5. Documentation Updates
- Updated README.md "Getting Started & Controls" section
- Added mention of Story option and return behavior

## Key Technical Details
- Maintained is_transitioning protection in both splash and story screens
- Implemented proper focus management preserving Start as default
- Used exact ColorRect overlay settings as splash for consistency
- Applied character capacity logging for writers' reference
- Ensured any key/mouse/controller input returns to splash

## Testing Requirements
- Verify focus navigation between Start/Story buttons
- Confirm story screen loads with proper layout and text
- Test return functionality with various input methods
- Validate preserved game flow after returning from story