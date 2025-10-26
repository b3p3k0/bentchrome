# Bent Chrome

## Welcome to the Rustbelt Circus

Bent Chrome is the busted-love letter to Twisted Metal we were promised on late-night cable but never got. It’s a top-down vehicular bloodsport where the air tastes like burnt copper, the neon never shuts off, and every fix-it ticket gets paid in shrapnel. You pilot scrapyard nightmares through corporate-owned arenas, cashing in on spectacle so the rest of the city keeps pretending the lights still work.

## Installation

1. **Grab the code**: `git clone https://github.com/b3p3k0/bentchrome.git && cd bentchrome`.
2. **Gear check**: Godot 4.2+ on your path, a GPU that survived the last EMP, and whatever OS still boots (Linux, macOS, Windows - TempleOS port coming soon.).
3. **Optional housekeeping**: `git submodule update --init` in case we stash vendor junk later.
4. **Launch**: `godot4 --path .` or open the project from the Godot launcher if you like clicking buttons.
5. **Builds**: When binaries arrive they’ll live under `builds/`. Until then, run straight from the editor and pretend crashes are deliberate explosions.

## Getting Started & Controls

The game starts with a splash screen offering Start 1P to enter character selection, or Story to view background lore. The story screen shows game background with 'Press any key to return'.

### Player Selection
When you first boot up Bent Chrome, you'll land in the Player Selection screen where you can browse through 9 hardened drivers and their combat-ready rides. Each character has unique stats and backstory that affect their performance in the arena.

**Player Selection Controls:**
- Navigate: `A/D`, `Left/Right arrows`, `D-pad Left/Right`, or `left stick X-axis` to scroll through characters
- More Info: `W` or `Square/West face button` to open detailed character bio and expanded stats
- Confirm: `Enter`, `Space`, or `Cross/South face button` to select your driver and enter the arena
- Close Bio: `W` or `Square/West face button` again to close the character bio popup

Each character has five core combat statistics rated 1-5:
- **Acceleration**: How quickly your vehicle reaches top speed
- **Top Speed**: Maximum velocity in straight-line runs
- **Handling**: Responsiveness and control precision
- **Armor**: Resistance to collision damage and weapons fire
- **Special Power**: Effectiveness of special weapon systems

After confirming your selection, you'll drop directly into the Test Arena to put your chosen driver through their paces.

### Combat Controls
- Movement: `WASD` moves strictly up/down/left/right with acceleration/deceleration for 16-bit arcade feel. Last key pressed wins; no diagonal movement. Controllers follow the same 4-direction rules (`arrow keys`, `D-pad`, `left stick` also supported).
- Aim/Fire: mouse or right stick to aim, left click / right trigger to hose bullets.
- Special Weapon: `Space` / north face button. Cooldown regenerates—don't hoard it.
- Turbo: `Shift` / left bumper for gap jumps, last-second dodges, or heroic mistakes.
- Camera: mouse edge-pan or right stick nudge, depending on your input poison.
- HUD: flashing red means you're about to join the scrap heap. Hunt for repair pods or lean into the fireworks.

First arena (Arena) is the tutorial crash-test. Freeway introduces overpasses and multipoint ambushes. Expect hidden pickups tucked behind debris piles; if you see a suspicious billboard, ram it.

## FAQs

**Keyboard or controller?**  
Both. Both inputs use the same 4-direction movement with responsive acceleration/deceleration for precise arcade control.

**Can I remap controls?**  
Yep—Settings > Controls. If something refuses to bind, log an issue and we’ll slap it back into shape.

**Multiplayer when?**  
Not yet. The wasteland is lonely on purpose, but co-op/versus are parked in the Future Hooks garage.

**How does saving work?**  
Campaign checkpoints between arenas, inventory persists, permadeath stays in the roguelike lane.

**Performance target?**  
Locked 60 FPS on mid-range GPUs. Send logs and specs if it dips; we’ll optimize instead of guessing.

**Sometimes my weapon fires in the "wrong" direction**
This is by design - get good and learn how to do trick shots ;)

**"wHy DiD u UsE aI???"**
Because I can't code and I can't draw and instead of spending hours learning how to do both I did this instead. ¯\\\_(ツ)\_/¯

## Contact, Support, Contributing

- Issues and feature requests: open a ticket with logs, repro steps, and screenshots of the carnage.
- Contributing:
  1. Fork, branch, and keep changes scoped to one arena/system.
  2. Run lint/tests (doc incoming) and attach short clips/gifs with your PR.
  3. Lore-friendly commit messages earn imaginary salvage credits.

## Acknowledgements

- Inspirations: Twisted Metal, GTA ‘97, Escape from L.A., Running Man, Cyberpunk 2020, and every late-night VHS taped over a local news broadcast.
- Engine: Godot 4, propped up by caffeine, duct tape, and a graveyard of broken RC cars.
- Shoutout to the players still willing to redline through a skyline held together with neon gum and corporate propaganda. We see you. Bring a helmet.

More lore, vehicle dossiers, and survival tips land here once the arenas stop actively collapsing. Until then, strap in and let the sparks fall where they may.
