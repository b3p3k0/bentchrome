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

The game starts with a splash screen offering Start 1P to enter character selection, Story to view background lore, or Settings. The story screen shows game background with 'Press any key to return'. Settings covers zoom depth, screen shake, a campaign start-level picker for practice runs, and the DEVGOD/developer toggles for playtesting — choices persist between sessions.

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
- Handbrake: `E` / east face button. Yanks the rear traction — the car slides and rotates while shedding speed gently. Charge the corner, pull it, swing the nose, release, launch. Drifting is a lifestyle.
- Camera Zoom: `Left Ctrl` / north face button toggles between the combat close-up and a pulled-back overview — more board, same crisp detail. Your choice sticks across levels and respawns.
- Machine Gun: `Left click` or `Space`. Infinite ammo, chip damage, fires off the nose. Watch the heat bar — redline it and the gun locks out until it cools.
- Selected Weapon: `Right click` or `K` fires whatever slot is active. Cycle slots with the mouse wheel (or `/` to step forward on keyboard): your car's signature special (recharges on its own — don't hoard it) plus three missiles with three personalities — **fire** (medium hit, steady tracking), **homing** (light hit, vicious tracking), and **power** (heavy hit, flies dead straight; lead your shots). The wheel skips anything empty and a dry slot auto-cycles to your next armed weapon — every click gives you SOMETHING, no dead clicks mid-brawl. All nine signature specials are live — flame columns, lock-on taser zaps, body-check leaps, charged rams; every driver fights different.
- Ammo: missiles are scavenged, not printed. Grab the green `M` (fire), cyan `H` (homing), and orange `P` (power) crates around the arena; crates respawn, your patience won't. One P stash is behind something you'll have to break.
- Mines: red `X` and purple `J` crates load your rear dispenser — you start with zero. Land mines (`X`) drop behind you, arm in a second, and send whoever rolls over them off-course with a bang. Jump mines (`J`) do no damage at all; they just launch your pursuer into the air pointing somewhere unhelpful. Hold the fire button to lay a trail.
- On fire? Burning cars actually burn now — and a shot of boost blows the flames out. Physics said no; fun said yes.
- Boost: hold `Shift` / left bumper for gap jumps, last-second dodges, or heroic mistakes. You start with 100 boost, holding it burns 5 a second, and nothing refills it — twenty total seconds of nitro per round, spent however you dare. Blue bar on the dash.
- Repairs: the white pad with the red cross in the park fully patches you up. Two charges per round, 45 seconds between them, and it only answers to you — the mob can spin donuts on it all day.
- They shoot back: every opponent runs the same arsenal you do — machine gun, missiles, their car's signature special — just on a lazier trigger finger. Cover matters now. Pressure comes in waves: hound you too long and they peel off to line up a fresh run, so a bad ten seconds isn't a death sentence. They'll trade paint with each other too, but there's a code in the wasteland: nobody finishes a dying rival. That pink slip is yours to collect.
- Pause: `ESC` — resume, restart the arena, or quit while you're behind.
- Winning and losing: wreck every opponent and the round ends in lights; get wrecked and it ends in a shrug. Either way you get restart, a new ride, or the exit — no limping around an empty arena.
- HUD: the dash on the left tracks HP, speed, MG heat, boost, and your weapon slots (with a key cheat-sheet at the bottom); the right side carries a full-city minimap — streets, park, smashables (they vanish when you break them), the repair pad, and red blips for any rival within sensor range — plus the opponent roster with a health bar per name, dimming to dark red as you retire them. Everything fires where the car points — get good and learn the trick shots.

Two ways up, learn both: **jump pads** are the striped caution pyramids — hit one with speed from any side and you're airborne; **ramps** are driveable slopes — no launch, just climb, and whatever's paved on them is how they drive (a grass ramp is a hill, a snowed one is a prayer). Any open ledge is a way down; one storey is free, two costs you.

The campaign rolls out of town. **Downtown**: streets carved between rooftop-topped buildings, a park with grass, dirt, and a pond that eats your momentum, and scenery that breaks — some walls hide better loot than others. Now with a skyline: two blocks wear driveable rooftops joined by a bridge, a parking-garage ramp grades up one, the jump pad clears you onto the other. **Freeway Loop**: a long concrete ring with a grass infield, leftover guardrails that crumple if you look at them hard, and broken-overpass jump pads. **Suburbs**: little houses that were not built to code — bulldoze your own shortcuts, but mind the lake. **Snowy Pass**: iced switchbacks, a couple of cliffs that do not give your car back, and a summit now — snow-hill ramps climb the plateau, the top is slick, and the crates up there are worth the slide. **The Depot**: a military staging yard and one very large problem named **Lackey**. His cannon ends arguments in two hits and his front armor laughs at you; the engineers cut corners around the exhaust. Circle him. Beat him and learn the ugly truth — he was only the doorman. **The Docks**: the harbor fights on three levels. Dirt flats down by the waterline, warehouse streets above them, and rooftops and a container-ship deck above those — jump pads go up, any ledge goes down, and sky bridges span the rooftops: take them on top or duck underneath, same for the crane booms. The chain-link along the quay will not save you; it barely slows you. Short drops are free; drop two storeys and your suspension sends the bill. Machine guns and dumb rockets can't cross floors, homing missiles arc happily between them, and the deep water past the quay keeps every car it catches (watch the bubbles). The minimap tracks the stack: a red dot is on your floor, `^` is above you, `v` is below. You get **three lives** for the whole run — die and you respawn at your start point with a two-second shield; run dry and it's back to Downtown with a fresh slate. Between levels, catch your breath and press any key.

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
