# Bent Chrome

## Welcome to the Rustbelt Circus

Bent Chrome is the busted-love letter to Twisted Metal we were promised on late-night cable but never got. It’s a top-down vehicular bloodsport where the air tastes like burnt copper, the neon never shuts off, and every fix-it ticket gets paid in shrapnel. You pilot scrapyard nightmares through corporate-owned arenas, cashing in on spectacle so the rest of the city keeps pretending the lights still work.

> **Status (June 2026):** Bent Chrome is being rebuilt from the chassis up on Godot 4.7. The controls and flow below are the target spec — the current build boots a placeholder shell while each system gets re-welded one at a time. The old prototype is parked in `legacy/`.

## Installation

1. **Grab the code**: `git clone https://github.com/b3p3k0/bentchrome.git && cd bentchrome`.
2. **Gear check**: Godot 4.7 on your path, a GPU that survived the last EMP, and whatever OS still boots (Linux, macOS, Windows - TempleOS port coming soon.).
3. **Import assets (first run or after a fresh clone)**: `godot --import --path .` to generate import metadata so textures load correctly.
4. **Optional housekeeping**: `git submodule update --init` in case we stash vendor junk later.
5. **Launch**: `godot --path .` or open the project from the Godot launcher if you like clicking buttons.
6. **Builds**: When binaries arrive they’ll live under `builds/`. Until then, run straight from the editor and pretend crashes are deliberate explosions.

## Getting Started & Controls

The game starts with a splash screen offering Start 1P to enter character selection, or Story to view background lore. The story screen shows game background with 'Press any key to return'.

### Player Selection
When you first boot up Bent Chrome, you'll land in the Player Selection screen where you can browse through 9 hardened drivers and their combat-ready rides. Each character has unique stats and backstory that affect their performance in the arena.

**Player Selection Controls:**
- Navigate: `A/D`, `Left/Right arrows`, `D-pad Left/Right`, or `left stick X-axis` to scroll through characters
- More Info: `W` or `Square/West face button` to open detailed character bio and expanded stats
- Confirm: `Enter`, `Space`, or `Cross/South face button` to select your driver and enter the arena
- Close Bio: `W` or `Square/West face button` again to close the character bio popup

Each character has five core combat statistics rated 1-10:
- **Acceleration**: How quickly your vehicle reaches top speed
- **Top Speed**: Maximum velocity in straight-line runs
- **Handling**: Responsiveness and control precision
- **Armor**: Resistance to collision damage and weapons fire
- **Special Power**: Effectiveness of special weapon systems

After confirming your selection, you'll drop directly into the Test Arena to put your chosen driver through their paces.

### Combat Controls
- Movement: steer-to-drive. `W`/`Up` throttles, `S`/`Down` is the brake pedal (hard, but nothing here stops on a dime) and backs up once you're crawling, `A`/`D` or `Left`/`Right` steer (`left stick` does the same on a controller). Weight is real: a motorcycle snaps off the line while a truck grinds up to speed, and lifting the throttle coasts you down gradually — the heavier the ride, the farther it rolls.
- Handbrake: `Left Ctrl` / east face button. Yanks the rear traction — the car slides and rotates while shedding speed gently. Charge the corner, pull it, swing the nose, release, launch. Drifting is a lifestyle.
- Machine Gun: `Right click` or `Space`. Infinite ammo, chip damage, fires off the nose. Watch the heat bar — redline it and the gun locks out until it cools.
- Selected Weapon: `Left click` or `K` fires whatever slot is active. Cycle slots with `Q`/`E` or the mouse wheel: your car's signature special (recharges on its own — don't hoard it), dumb-fire missiles, and homing missiles. Run a slot dry and the rack auto-cycles to your next armed weapon — no dead clicks mid-brawl. All nine signature specials are live — flame cones, lock-on taser zaps, body-check leaps, charged rams; every driver fights different.
- Ammo: missiles are scavenged, not printed. Grab the green `M` and cyan `H` crates around the arena; crates respawn, your patience won't.
- Boost: hold `Shift` / left bumper for gap jumps, last-second dodges, or heroic mistakes. The tank burns 2% a second and nothing refills it — spend it like it's the last nitro on Earth, because this round, it is. Blue bar on the dash.
- Repairs: the white pad with the red cross in the park fully patches you up. Two charges per round, 45 seconds between them, and it only answers to you — the mob can spin donuts on it all day.
- They shoot back: every opponent runs the same arsenal you do — machine gun, missiles, their car's signature special — just on a lazier trigger finger. Cover matters now.
- Pause: `ESC` — resume, restart the arena, or quit while you're behind.
- Winning and losing: wreck every opponent and the round ends in lights; get wrecked and it ends in a shrug. Either way you get restart, a new ride, or the exit — no limping around an empty arena.
- HUD: the dash on the left tracks HP, speed, MG heat, boost, and your weapon slots (with a key cheat-sheet at the bottom); the right side keeps the radar (nose-up, enemies red) plus the opponent roster — names dim to dark red as you retire them. Everything fires where the car points — get good and learn the trick shots.

First arena (Arena) is the tutorial crash-test — a city block now: streets carved between buildings, a park with grass, dirt, and a pond that eats your momentum, and scenery that breaks. Crates and kiosks smash under gunfire or a good shoulder-check, some walls hide better loot than others, and the ramp clears more than potholes. Freeway introduces overpasses and multipoint ambushes. Expect hidden pickups tucked behind debris piles; if you see a suspicious billboard, ram it.

## FAQs

**Keyboard or controller?**  
Both. Same steer-to-drive scheme either way — throttle, brake/reverse, steer — with the same inertia and drift.

**Can I remap controls?**  
Yep—Settings > Controls. If something refuses to bind, log an issue and we’ll slap it back into shape.

**Can I build my own arena?**  
Yes. `tools/editor.sh` launches the level editor: drop in blocks, ammo crates, terrain patches, and up to four enemy starts, then hit Playtest. Levels are plain JSON in your `user://levels/` folder — swap files with other drivers freely; they're data, not code, so nothing in them can run on your machine. Full manual in `docs/level_editor.md`. (An in-game custom-levels menu is still in the garage — for now the editor's Playtest button and a `--level=` launch flag are the way in.)

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
  2. Run `tools/smoke.sh` and `tools/test.sh` (both headless, both must pass) and attach short clips/gifs with your PR.
  3. Lore-friendly commit messages earn imaginary salvage credits.

## Acknowledgements

- Inspirations: Twisted Metal, GTA ‘97, Escape from L.A., Running Man, Cyberpunk 2020, and every late-night VHS taped over a local news broadcast.
- Engine: Godot 4, propped up by caffeine, duct tape, and a graveyard of broken RC cars.
- Shoutout to the players still willing to redline through a skyline held together with neon gum and corporate propaganda. We see you. Bring a helmet.

More lore, vehicle dossiers, and survival tips land here once the arenas stop actively collapsing. Until then, strap in and let the sparks fall where they may.
