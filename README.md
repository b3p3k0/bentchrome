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

The game starts with a splash screen offering Single Player, Multiplayer, Story, or Settings. The story screen shows game background with 'Press any key to return'. Settings keeps everyday display options up front; Developer Options opens a separate playtesting panel where Developer Mode is the master breaker for DEVGOD and the campaign start-level picker. Those subordinate choices stay remembered while the breaker is off, but cannot affect a run until it is switched back on. Settings is deliberately arrow-only: Up/Down selects, Left/Right changes values, Right enters `-->` rows, and Escape backs out with every change already saved. Choices persist between sessions.

### Pick Your License
Single Player sends you past the DMV before the garage. Three license classes, one campaign each — pick before you drive, live with it until you quit back to the title:
- **LEARNER'S PERMIT** — soft hits, lazy trigger fingers, bosses that let you breathe. The Rustbelt, with training wheels.
- **ROAD RAGING COMMUTER** — they mean it out there, but you'll get a word in edgewise.
- **REVOKED LICENSE** — the ride as intended. Full damage, full cadence, bosses off the leash.

### Player Selection
License in hand, you'll land in the Player Selection screen where you can browse through 9 hardened drivers and their combat-ready rides. Each character has unique stats and backstory that affect their performance in the arena.

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
- Movement: steer-to-drive. `W`/`Up` throttles, `S`/`Down` is the brake pedal (hard, but nothing here stops on a dime) and backs up once you're crawling, `A`/`D` or `Left`/`Right` steer (`left stick` does the same on a controller). Weight is real: a motorcycle snaps off the line while a truck grinds up to speed, and lifting the throttle coasts you down gradually — the heavier the ride, the farther it rolls. Every ride carries real brake lights: dark crimson at rest, bright red while the pedal fights its current direction; handbrake slides keep their own skid language.
- Handbrake: `Left Ctrl` / east face button. Yanks the rear traction — the car slides and rotates while shedding speed gently. Charge the corner, pull it, swing the nose, release, launch. Drifting is a lifestyle.
- Camera Zoom: `G` / north face button toggles between the combat close-up and a pulled-back overview — more board, same crisp detail. Your choice sticks across levels and respawns.
- Machine Gun: `Left click` or `Space`. Infinite ammo, chip damage, fires off the nose. Watch the heat bar — redline it and the gun locks out until it cools.
- Selected Weapon: `Right click` or `K` fires whatever slot is active. Cycle slots with the mouse wheel (or `/` to step forward on keyboard): your car's signature special (recharges on its own — don't hoard it) plus four missiles with four personalities — **fire** (medium hit, steady tracking), **homing** (light hit, vicious tracking), **power** (heavy hit, flies dead straight; lead your shots), and **rear** (Fire Missile numbers and tracking, launched blue from the tail). The wheel skips anything empty and a dry slot auto-cycles to your next armed weapon — every click gives you SOMETHING, no dead clicks mid-brawl. All nine signature specials are live — flame columns, lock-on taser zaps, body-check leaps, charged rams; every driver fights different.
- Ammo: missiles are scavenged, not printed. Grab the green `M` (fire), cyan `H` (homing), orange `P` (power), and blue `R` (rear) crates around the arena; crates respawn, your patience won't. Rear missiles start at zero, just like mines. Every collectible carries a high-contrast hot-pink ring around its larger drive-over surface, including chase medkits and nitro—clip the circle and the road pays out. One P stash is behind something you'll have to break.
- Mines: red `X` and purple `J` crates load your rear dispenser — you start with zero. Land mines (`X`) drop behind you, arm in a second, and use a proximity fuse slightly wider than the painted disc; a near pass still counts. Jump mines (`J`) keep their tighter contact trigger and do no damage at all; they just launch your pursuer into the air pointing somewhere unhelpful. Hold the fire button to lay a trail.
- On fire? Burning cars actually burn now — and a shot of boost blows the flames out. Physics said no; fun said yes.
- Boost: hold `Shift` / left bumper for gap jumps, last-second dodges, or heroic mistakes. You start with 100 boost, holding it burns 5 a second, and nothing refills it — twenty total seconds of nitro per round, spent however you dare. Blue bar on the dash. (One exception: the blue nitro bottles littering Route 666 Roulette. Highway rules.)
- Repairs: hit the white pad with the red cross while hurt and it snaps you into a two-second lightning tune-up. The fight keeps moving while you're pinned, solid, disarmed, and invulnerable; when the bar fills, the pad throws you back onto the exact course and speed you brought in, wrapped in the same two-second blink shield as a respawn. Two charges per round, 45 seconds between them, and it only answers to human drivers — the mob can spin donuts on it all day.
- They shoot back: every opponent runs the same arsenal you do — machine gun, missiles, their car's signature special — just on a lazier trigger finger. Cover matters now. Pressure comes in waves: hound you too long and they peel off to line up a fresh run, so a bad ten seconds isn't a death sentence. They'll trade paint with each other too, but there's a code in the wasteland: nobody finishes a dying rival. That pink slip is yours to collect.
- Pause: `ESC` — resume, restart the arena, or quit while you're behind.
- Winning and losing: wreck every opponent and the round ends in lights; get wrecked and it ends in a shrug. Either way you get restart, a new ride, or the exit — no limping around an empty arena.
- HUD: the dash on the left tracks HP, speed, MG heat, boost, and your weapon slots (with a key cheat-sheet at the bottom); the right side carries a full-city minimap — streets, park, smashables (they vanish when you break them), the repair pad, and red blips for any rival within sensor range — plus the opponent roster with a health bar per name, dimming to dark red as you retire them. A rival beyond the camera gets a paint-matched triangle riding the play-square edge and pointing toward the trouble; land your own off-screen hit and its marker answers with a clean expanding ring, while a fatal hit earns the full little burst. Most fire follows the nose. The blue rear rocket is the trick shot that doesn't.

Two ways up, learn both: **jump pads** are the striped caution pyramids — hit one with speed from any side and you're airborne; **ramps** are driveable slopes — no launch, just climb. Gravity takes a small bite going up and pays it back going down, while the surface still matters (a grass ramp is a hill, a snowed one is a prayer). Triangular corner slopes fill the diagonals, so a blocky eight-sided hill is as round as this wasteland needs. The ground catches a fixed northwest light and its pattern foreshortens down each face; your car and its shadow rise continuously with the grade. Any open ledge is a way down; one storey is free, two costs you.

The ground knows what you're driving. Ice spins the tires and lets the nose swing while your momentum keeps its old appointment; enter straight and you'll stay honest, start correcting and you're bargaining with a slide. Cricket is built for the dirt—faster, sharper, and her Leap hits 15% harder when launched there—with a smaller grass advantage. Hammertoe's big tires shrug off more rough ground, while Smoky and Razorback's 4WD softens (but never erases) grass, snow, dirt, shallow-water, and mud penalties. Mud is its own wet-soil surface: launch and top speed suffer, the rear wanders, and pavement-tuned Cyclone suffers most. Everybody else keeps the standard surface rules, and nobody gets a special deal on ice.

The wasteland is not empty yet. Downtown office workers, vendors, vagrants, and badge-flashing police still work the sidewalks; the suburbs have joggers, bikes, loose dogs, skaters, and stubborn lawn mowers; skiers and a deer herd haunt Mountainside Mayhem; dockhands pace every level of the harbor; hard-hatted crews work all three storeys of Ground Floor Gore. They scatter from a charging car, but they are scenery rather than objectives—no score and no punishment. Police take harmless potshots. Anyone caught by the real fight leaves a brief red stain, and tires crossing it carry a short pair of red tracks down the road.

Gunfire talks back now: machine-gun rounds throw a few faint sparks from walls, cars, and containers; missiles answer with a tight flash and ring; rounds passing through the living scenery leave only a tiny red fleck and keep flying. These marks are visual only—no hidden splash damage, shove, or camera kick.

Smoky's Taser and Bumper's Blunt Blaze are brief bad news: two seconds of beam or flame, then a full fifteen seconds before either can fire again. Smoky and Bumper regrow a charge every 90 seconds; Lackey stole both barrels and pays 120 seconds per shared charge. Finishing either of his barrels locks the pair for the same fifteen-second silence.

On Piers of Pain's stacked battlefield, tracking missiles can arc between floors without ghosting through the destination's defenses: cover on both the launch floor and the locked target's floor can take the hit, while scenery on an intermediate terrace is passed over. Power Missiles keep their straight same-floor flight, and explicitly cover-piercing weapons keep their exception.

After Piers of Pain, **Ground Floor Gore** is where the road turns ugly: an eight-car construction yard fighting through a rainy dusk — worklights burning, every explosion blooming against the gloom. A dry dirt recovery loop rings three mud basins, a poured floor-2 foundation sprouting the first columns of a skyscraper, and a floor-3 scaffold ring circling a courtyard fight pit — guardrails where the site inspector won, bare hazard-taped drops where he lost, and three rails so flimsy you can smash through and yeet clean off the deck. The south is one giant spoil heap: drive up any face of the dirt pile, raid the mine crate on its crown, and launch off however you came. Heavy machines are permanent cover; containers, fuel barrels, the crew's parked cars, and eight porta-potties are not. The dark-blue generator starts spitting sparks the moment you hurt it, and at its last quarter of health a warning ring gives you 1.2 seconds to break line of sight or leave floor 1 before the wounded grid arcs. Destroying it trades that recurring hazard for one large, impartial electrical blast. Survive the site and Goliath's Arena waits next.

The campaign rolls out of town. **Downtown Derby**: streets carved between rooftop-topped buildings, a park with grass, dirt, and a pond that eats your momentum, and scenery that breaks — some walls hide better loot than others. Now with a skyline: two blocks wear driveable rooftops joined by a bridge, a parking-garage ramp grades up one, the jump pad clears you onto the other. **Freeway Firefight**: a long concrete ring with a grass infield, leftover guardrails that crumple if you look at them hard, and broken-overpass jump pads. **Suburban Slaughter**: little houses that were not built to code — bulldoze your own shortcuts, but mind the lake. **Mountainside Mayhem**: iced switchbacks, a couple of cliffs that do not give your car back, and a summit now — the eight-sided snow hill climbs from every direction, the top is slick, and the crates up there are worth the slide. **Lackey's Arena**: a military staging yard and one very large problem named **Lackey**. His breach cannon is a turret now — it turns to face you no matter which way he's driving, so the old trick of dodging his nose is dead; outrun the barrel instead. Up close he burns, at range he zaps, and both drink from the same magazine. The yard itself takes sides: container cover crumbles as the fight rages, the fences won't save either of you, and his front armor still laughs — the engineers cut corners around the exhaust. Circle him. Beat him and learn the ugly truth — he was only the doorman. **Route 666 Roulette**: leave the yard and the rules change — a three-minute forced sprint up a dying highway with The Buzzardz on your tail. They're not the competition; they're a swarm — dirtbike scouts that swerve in close to spray and peel off, beater sedans lobbing rockets at where you *were*, and bed-gun technicals rolling in from ahead and drifting back through the field, thumping the whole way. Behind all of it: the horde itself, a wall of dust and headlights that always — always — keeps up. Your dash swaps the minimap for a GPS that reads the road a few turns ahead; the countdown is your only finish line. W sprints, and S is a real brake: stopping to let the pack scream past you is a legal play — the wall just makes it a loan you repay with interest. Thread the potholes, smash the logs (they cost momentum, not much else), hit the launch pads to fly over the mess, and grab medkits and nitro bottles off the asphalt without lifting. Die and you respawn rolling at 45 — the run never stops. **Piers of Pain**: the harbor fights on three levels. Dirt flats down by the waterline, warehouse streets above them, and rooftops and a container-ship deck above those — jump pads go up, any ledge goes down, and sky bridges span the rooftops: take them on top or duck underneath, same for the crane booms. The chain-link along the quay will not save you; it barely slows you. Short drops are free; drop two storeys and your suspension sends the bill. Machine guns and dumb rockets can't cross floors, homing missiles arc happily between them, and the deep water past the quay keeps every car it catches (watch the bubbles). The minimap tracks the stack: a red dot is on your floor, `^` is above you, `v` is below. **Goliath's Arena**: the road ends at a stadium with your name on the fight card. **Goliath** — the coliseum's undefeated king — fights in two acts. Trailered, he keeps his distance and lets the trailer battery talk; crowd him and you meet the grille or the tail (sixty feet of trailer swings like a stegosaurus with a grudge — the skid marks are your warning). Aim for the hitch: the armor forgot the connection. Break the trailer and he doesn't quit — he revs. Bobtail, he hunts you in a rhythm: when the stacks belch black smoke, get OFF his line, because the charge doesn't steer — and a semi that misses you keeps its appointment with the wall instead. A stunned truck is a free truck. One more tip from the pit lane: all that armor was paid for from below. There are exactly two crates of land mines in the building — the stands are a ramp, drive up the seating anywhere, lap the crown, drop through the corner tunnels, and go get them. You get **three lives** for the whole campaign — die in an arena and you respawn at your start point with a two-second shield; run dry and it's back to Downtown Derby with a fresh slate. Between levels, catch your breath and press any key.

## FAQs

**Keyboard or controller?**  
Both. Same steer-to-drive scheme either way — throttle, brake/reverse, steer — with the same inertia and drift.

**Can I remap controls?**  
Yep—Settings > Controls. If something refuses to bind, log an issue and we’ll slap it back into shape.

**Can I build my own arena?**  
Yes. `tools/editor.sh` launches the level editor: drop in blocks, ammo crates, terrain patches, and up to four enemy starts, then hit Playtest. Levels are plain JSON in your `user://levels/` folder — swap files with other drivers freely; they're data, not code, so nothing in them can run on your machine. Full manual in `docs/level_editor.md`. (An in-game custom-levels menu is still in the garage — for now the editor's Playtest button and a `--level=` launch flag are the way in.)

**Multiplayer when?**  
NOW. LAN parties are back: title screen > MULTIPLAYER. One of you hosts a garage (pick a port, set a password if your friends can't be trusted — they can't), everyone else finds it in the LAN browser or dials the IP direct (works over the internet too if the host forwards the port). Four seats, up to eight watching from the bench, and the host runs the whole show — the simulation lives on their machine, so bring your beefiest box to host.

Two flavors: **Grudge Match** (humans only, settle it) and **Grand Melee** (the empty seats fill with AI at whatever difficulty the host picks). Four rulesets: **Rotation Brawl** (endless scoreboard scrap, optional kill/time caps, host calls it from ESC), **Frag Target** (first to N), **Timed** (most wrecks at the horn — ties split the crown), and **Lives Elimination** (run dry and you're benched, last one rolling wins). Every car is one-of-one on the floor — first come, first serve on the roster, and the carousel tags claimed rides.

The bench is a lifestyle: observers get a free camera (cycle drivers with the weapon keys, WASD to roam, G to zoom) and an **I GOT NEXT** queue — pick your ride when you opt in, and when someone gets wrecked you take the wheel while they ride the pine. Changing wheels mid-queue sends you to the back; you were warned. Hosts can kick, ban sticks (by IP, survives restarts), and modded builds get flagged — or bounced, host's call.

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
  2. Arena work starts with [`docs/arena_field_manual.md`](docs/arena_field_manual.md) and its copy-paste brief.
  3. Run `tools/smoke.sh` and `tools/test.sh` (both headless, both must pass) and attach short clips/gifs with your PR.
  4. Lore-friendly commit messages earn imaginary salvage credits.

## Acknowledgements

- Inspirations: Twisted Metal, GTA ‘97, Escape from L.A., Running Man, Cyberpunk 2020, and every late-night VHS taped over a local news broadcast.
- Engine: Godot 4, propped up by caffeine, duct tape, and a graveyard of broken RC cars.
- Shoutout to the players still willing to redline through a skyline held together with neon gum and corporate propaganda. We see you. Bring a helmet.

More lore, vehicle dossiers, and survival tips land here once the arenas stop actively collapsing. Until then, strap in and let the sparks fall where they may.
