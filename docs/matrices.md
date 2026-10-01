# Bent Chrome — Stat Matrices

Every gameplay number in one place: vehicles, weapons, terrain, and the combat
modifiers that glue them together. Use it for balance passes — spot the outlier,
then edit the source file listed at the top of each section.

Numbers pulled from source on 2026-07-09 (Buzzard Run batches A/D/B); car-contract
pass 2026-07-12; Route 666 rebuilt 2026-09-29 (the gap is the health bar). This file is hand-maintained: when a `.tres` or a const changes,
update the matching row here.

---

## Vehicles

Source: `assets/data/roster.json` (importer → `data/vehicles/*.tres`) + `data/vehicles/lackey.tres` (hand-authored, roster-external).
The roster also binds each car's special (`special_def` → `data/weapons/*.tres`) and AI temperament (`ai_archetype`); the importer validates the whole contract and `tests/test_roster_contract.gd` enforces it. Add-a-car checklist: `docs/car_authoring.md`.
> ⚠️ The numeric columns below (Accel/Top/Handling/Armor/Sp.Pwr/Mass/HP **and Cap/Recharge**) predate the 1-20 stat rebase and the 2026-07 car-tuner canonization — **`assets/data/roster.json` is the sole truth** (the golden-lock lives in `tests/test_stat_rebase.gd`). Treat this table as a lore/archetype map, not live stats, until it is refreshed.

HP derives from Armor via StatCurves (see mapping below). Special Cap/Recharge default to 1 / 12s where the roster doesn't override.

| Car | Driver | Accel | Top | Handling | Armor | Sp.Pwr | Mass | HP | Special | Cap | Recharge | Archetype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bumper | Chester J. Banks | 3 | 6 | 5 | 7 | 7 | 6 | 143 | Blunt Blaze | 2 | 90s | defender |
| Coldfront | Marta Laviini | 5 | 5 | 3 | 7 | 8 | 7 | 143 | Chilblain | 2 | 45s | opportunist |
| Cricket | Mae Hemm | 8 | 8 | 4 | 4 | 8 | 2 | 107 | Leap | 1 | 10s | aggressor |
| Cyclone | Mandy Joule | 9 | 10 | 6 | 2 | 8 | 2 | 82 | Tornado Alley | 1 | 30s | ambusher |
| Ghost | Chad Duché | 8 | 9 | 7 | 3 | 6 | 3 | 94 | Phantom Phire | 1 | 12s | aggressor |
| Hammertoe | Chuck and Vern | 5 | 5 | 3 | 7 | 7 | 8 | 143 | Toe Jam | 1 | 8s | ambusher |
| Hornet | Jimmy Kane | 6 | 6 | 6 | 6 | 6 | 5 | 131 | Molotov Cocktail | 1 | 12s | aggressor |
| Hubcap | Rex Goodyear | 8 | 4 | 9 | 5 | 8 | 3 | 119 | Pulse Wave | 1 | 25s | aggressor |
| Kandy Kane | Kandy Kane | 5 | 6 | 3 | 8 | 8 | 7 | 156 | Molotov Cocktail | 1 | 12s | mini_boss |
| Lovebug | Moonbeam | 7 | 5 | 4 | 4 | 7 | 4 | 107 | Chill Out, Man | 1 | 30s | opportunist |
| Mr. Ghastly | ??? | 8 | 8 | 7 | 2 | 9 | 1 | 82 | Scythe of the Damned | 1 | 12s | aggressor |
| War Pig | Big Sarge | 3 | 6 | 4 | 8 | 7 | 7 | 156 | Red Glare | 1 | 12s | defender |
| Smoky | Officer Richard Vepsh | 7 | 6 | 4 | 7 | 7 | 6 | 143 | Taser | 3 | 90s | defender |
| Splat Kat | Juan Dough | 6 | 7 | 7 | 5 | 8 | 5 | 119 | Rusty 'Poon | 2 | 6s | ambusher |
| **Lackey** (miniboss) | Lackey | 7 | 6 | 6 | 10 | 10 | 9 | **360**¹ | Blaze & Bolt twin + Breach Turret | 2 (shared) | 120s | — |

¹ 180 base × `hp_scale 2.0` (Lackey's Arena scene). Lackey also carries: `body_scale 1.5`, `rear_weakspot 1.5` (projectiles from behind ×1.5), `ai_cooldown_scale 1.5` (fires at 2× a normal AI's rate), a `relentless` driver (runs the boss valve instead of mook RELENT; full-length BREAK arcs now), `no_mines` (crate-proof), and the LIVE Breach Turret.

### The Buzzardz (chase mode, roster-external)

Source: `data/vehicles/buzz_*.tres`, HP scaled at spawn by `chase_director.CLASS_TABLE`; all `no_mines`, all `ai_cooldown_scale 1.4` and `ram_damage_scale 0.02` (buzzard.tscn — a third of the arena ram bill: car-to-car rams price post-collision speed difference, and at chase speeds every tap cost 20-30 HP), MG overridden to 1.3 dmg / 10 rate / 12° spread. Brains: `chase_driver.gd` ROLES (not EnemyDriver). **Top speed is NOT the .tres stat**: the director re-prices every Buzzard's ceiling at spawn to `ROLE_PACE` × the PLAYER'S honest top on asphalt, so the pack is always relevant to the car it chases (the .tres top still shapes acceleration).

| Bird | Accel | Top (× player road top) | Handling | Armor | Mass | HP (scaled) | Armament | Behavior |
|---|---|---|---|---|---|---|---|---|
| Scrambler (bike) | 15 | ×1.10 (sprint ×1.43; breakaway = your speed + 260) | 8 | 1 | 1 | ~14 (×0.2) — GLASS: one Homing Missile or a half-second MG burst | scrapgun MG re-tuned at spawn to 0.9 dmg / 20° spread (spray and pray), 0.7s bursts / 0.4s gaps on the way up, range 420 | STRAFE (below): up your tail fast, past you, and gone — 60% off the top of the screen, 40% via a 0.35-0.8s tail-show then the shoulder; 70% cut across your nose; committed (no flinch) |
| Beater (sedan) | 11 | ×1.04 (sprint ×1.30) | 4 | 2 | 4 | ~25 (×0.32) — one Fire Missile | MG bursts (0.5/1.1) on the way up, range 620 + ONE Scrap Rocket per sortie (4 dmg, 90°/s), popped from BEHIND 1.2s in | BULLY: rocket, MG up, pass, cut across to BOX 1.5-2.5s (guns silent), then the shoulder; timid: 6 damage from the PLAYER (a weapon hit or three MG rounds) sends it to the shoulder early; wobbly steer, aims at a 0.45s-stale snapshot |
| Technical (pickup) | 3 | ×0.62 | 3 | 3 | 6 | ~58 (×0.6) | Bed Gun turret: 12 dmg / 2.2s / 700 px/s, auto-aim ≤1100, 120°/s traverse | spawns AHEAD, crawls until inside its −850 mark, then FADES at your pace − 240 px/s however you drive (~5s on screen); driver never fires; no sprint |
| Blocker (sedan hull, hazard orange) | 11 | ×0.72 | 4 | 2 | 4 | ~48 (×0.6) | none — never fires | spawns AHEAD, steers into the PLAYER'S lane on a 0.6s-stale snapshot (a late juke beats it), gives the lane up once passed, fades into the pack; no sprint |

Incoming damage is probe-tuned (2026-09-29, a no-dodge autopilot over 42 runs): before — 2 wins / 5 caught / 35 wrecked; after — 18 / 14 / 10. After the 2026-09-30 polish (sorties, smash-and-pass, lane wheel, curve tax): 30 / 11 / 1. After the second-playtest pass the same day (pass-and-box sorties, glass birds, the bumper as a weapon, north-relative wheel): 40 / 2 / 0. After the third (per-class playbooks, running-start newborns, rocket 4, washouts, forward-only Leap and missile lock): **39 / 3 / 0** — the design target is now an INTERACTIVE CUTSCENE: it feels intense, but a driver who keeps the pedal down and steers is not really in danger; doing nothing (hands-off cruise is 0.80 against a pace that reaches 1.02) is what gets you robbed. The pack is the way to lose; gunfire is the pressure that makes you fight back.

**Balance probe**: `tools/chase_probe.sh [--runs N] [--skill S] [--tank] [--verbose] [car ...]` runs full 120s chases on autopilot, headless, ~3s each (`tools/probes/chase_run.gd` + `chase_autopilot.gd`), and tallies won / caught / wrecked. The autopilot never dodges fire, hunts pickups, or uses rear weapons — its win rate is a FLOOR for a real player. `--tank` measures a whole run's incoming damage; `--verbose` adds a 15s ticker, the damage sources (attributed by a FRESH attacker stamp + the hit-kind breadcrumb — a stale stamp means the road did it), a `[hit]` line with both cars' geometry for every hit ≥ 8, and the `[sortie]` census per class (flown / got by / boxed you in / broke away up the road — roughly 90% of bikes and 60-80% of sedans should get by; the rest flinch at your fire, run out of road, or arrive as the pack is on your bumper). Re-run it after touching any knob in this section.

Sorties (`chase_driver.Stage` RUSH → PASS → BOX or EXIT → PEEL; per-role knobs in `ROLES`, geometry in px relative to the player, + dy = behind):

| Stage | Where it goes | Leaves when | Fires | What it is |
|---|---|---|---|---|
| RUSH | your tail: `tail_dy` (bike 110 / sedan 170) behind, `LOITER_DX` 50 off your line, leaning at a stale read | within `ARRIVE_DIST` 70, or `RUSH_TIMEOUT` 5s | bike + sedan MG (pointed at you); the sedan's rocket (`rocket_delay` 1.2s, only from behind) | boiling out of the dust and running you down |
| PASS | out on its flank (`BESIDE_DX` 125), driving for `PASS_LEAD` 130 ahead; not clear of your flank (`PASS_CLEAR` 80) it hangs at `QUARTER_DY` 110 | its tail leads your nose by `CUT_IN_CLEAR` 75; or `PASS_TIMEOUT` 4s → PEEL | bike + sedan MG while behind and pointed at you | door to door and by |
| BOX | `BOX_DY` −120 ahead; cuts across to where you WERE if `cross` | the dealt hold (bike 0.35-0.8s / sedan 1.5-2.5s) ON station (`ON_STATION` 60), or hold + `TRANSIT_TIMEOUT` 3s | never | the body block — and your shot |
| EXIT (bikes, `exit_north`) | 2000 ahead, across your nose if `cross` | freed by the director past `FLEE_AHEAD` 950; `EXIT_TIMEOUT` 6s → PEEL | never | gone off the top on `BREAKAWAY` +260 over YOUR speed, boost included — the one cheat that beats nitro |
| PEEL | out of your lane first (`PASS_CLEAR`), then the SHOULDER (`SHOULDER_OUT` 30 past the road edge, the other verge if you're hugging that one) and straight back to `PEEL_DEPTH` 260 inside the crest | — | never | home to the pack; the director absorbs it and sends the next |

Dealt per bird from `phase`: the box hold, `exit_north` (bike 0.6 / sedan 0.0), `cross` (bike 0.7 / sedan 1.0). Moving up, a bird's ceiling is its role's `sprint` (bike 1.3 / sedan 1.25) × the ceiling the director priced — found at once, given back gently, still under a boost's 1.5× (test-locked); newborns emerge at `EMERGE_SPEED` +140 over you. `flinch` (sedan 6, bike 0 = committed) counts only damage the PLAYER lands (a barrel counts too; the pack's own strays never). **Birds pass, they never drive through you.** Station keeping: the pedal asks for the player's pace + `HOLD_GAIN` 1.2 px/s per px behind the mark, never under `MIN_PACE` 0.35 of own top, through `speed_band.gd` — a Buzzard ahead of its station BRAKES back to it. Technicals author `fade` 240 instead: inside the mark the pedal asks for your pace minus the fade. Buzzard-vs-buzzard damage runs the standard ×0.35 AI governor.

### StatCurves: design stat → engine units

Source: `resources/stat_curves.gd` — linear lerp across 1-10.

| Stat | Drives | @1 | @5 | @10 |
|---|---|---|---|---|
| Top Speed | max_speed (px/s) | 360 | 484 | 640 |
| Acceleration | base accel (px/s²)² | 80 | 207 | 365 |
| Handling | turn rate (°/s) | 130 | 183 | 250 |
| Handling | lateral grip | 4.5 | 6.9 | 10.0 |
| Armor | HP | 70 | 119 | 180 |

² Shaped further by mass: launch boost carries the standing start, taper thins pull near top. Feel bands are test-locked in `tests/test_driving_controller.gd` — see `VEHICLE_PHYSICS_PROGRESSION.md` before touching.

---

## Pickup Weapons (shared by every car)

Sources: `weapons/weapon_mount.gd` + `vehicles/vehicle.tscn` (MG), `data/weapons/missile_*.tres`, `data/weapons/mine_*.tres`, `vehicles/weapon_rack.gd` (ammo), `environment/mine.gd` (mine behavior). Max range = speed × lifetime. AI fires the MG at 3× cooldown (`ai_cooldown_scale`); every non-MG weapon runs on the same flat 2s bay lock the player has (`Vehicle.WEAPON_LOCK`). Non-special ammo slots are uncapped.

| Weapon | Dmg | Speed | Rate/Cooldown | Tracking | Max Range | Start/Cap | Notes |
|---|---|---|---|---|---|---|---|
| Machine Gun | 2/shot | 1100 | 12 shots/s | none | 1320 | ∞ | Heat 4.8/shot (≈21-shot burst to lock at 100); cools 28/s, unlocks below 35% |
| Fire Missile (M) | 26 | 1100 | 0.6s | 165°/s, lock 1200 | 4400 | 2/6 | The workhorse |
| Homing Missile (H) | 15 | 1080 | 0.8s | 280°/s, lock 1200 | 4320 | 1/3 | Finds them; doesn't finish them |
| Power Missile (P) | 45 | 1400 | 0.8s | none | 3500 | 1/2 | Dead straight — lead the shot |
| Rear Missile (R) | 26 | 1100 | 0.6s | 165°/s, lock 1200 | 4400 | 0/6 | Blue Fire Missile twin; launches from tail opposite heading |
| Land Mine (X) | 22 | — | 0.5s drop | — | rear drop | 0/4 | Arms 1s; victim deviated ±5-45°; 2s dropper grace |
| Jump Mine (J) | 0 | — | 0.5s drop | — | rear drop | 0/3 | Arms 1s; pops victim airborne (vz 450) + re-vector ±45-80° |

Crates: default `amount` 2, `respawn` 20s (per-instance in scenes). Rear missiles and mines are pickup-fed only. One former M crate per arena is now R, preserving authored pickup density. Ammo crates, chase medkits, and nitro share a 36px collection surface plus the contrast pink `pickup_cue` ring, contracting 36→0→36px at 18 pulses/minute; full resources leave the pickup banked. Airborne cars sail over mines and pits alike.

**Floor gating (multi-floor levels only):** tracking weapons can cross floors. Fire, Homing, and Rear — plus the tracking specials (Chilblain, Molotov, Chill Out, Man, Rusty 'Poon) — include cover on the shooter's floor and locked target's floor while arcing over intermediate terraces; Phantom Phire's explicit `pierces_cover` remains boundary-only. Everything else (MG, Power, Scythe, Red Glare, Breach Turret) is physically same-floor — a cross-floor car is never even signaled. Mines only trigger on the floor they were dropped on.

| Projectile impact style | Presentation | Terminal? |
|---|---|---|
| SPARK | 4–6 faint yellow-white flecks; standard bullets/projectiles | yes on ordinary bodies/walls |
| MISSILE | compact flash + expanding ring + 3 tiny fragments | yes |
| SPATTER | 3 minimal red flecks on a living soft target | no; shot continues |
| GLITTER | 9-12 pink-purple sparkle dots — a peace round evaporating | yes |
| NONE | no impact cue; harmless police tracers | n/a |

Off-screen personal hit confirmation is separate from world impacts: meaningful nonfatal hits flash only the tracker's 0.22× outer ring with a 0.25s per-target cooldown; a fatal hit bypasses that cooldown and uses the complete small debris burst. On-screen victims, other attackers, and sub-1 damage never cue the tracker.

---

## Specials (one per car)

Sources: `data/weapons/*.tres` + `vehicles/special_controller.gd` consts. Kind legend — PROJECTILE fires from the SecondaryMount; BEAM/DASH/TRIGGER/FLAME/DROP/TORNADO/PULSE have handlers in SpecialController. Cap/Recharge in the Vehicles table. **Lockout column** = the unified **2s non-MG bay lock** (`Vehicle.WEAPON_LOCK`): firing ANY non-MG weapon (missile/mine/special) holds the whole bay 2s, players and AI alike; bosses (`fixed_loadout`) instead keep the def's authored long lockout (Lackey's 15s twin) and the Route 666 chase opts out (`weapon_lock_exempt`). Non-special ammo slots are uncapped (`WeaponRack.UNCAPPED`). Hubcap also runs the fleet's only staggered dual MG (`mg_points`: one mount, standard 12/s and heat, origin alternates barrels).

| Special (Car) | Kind | Dmg | Speed | Cooldown | Tracking | The rest of the story |
|---|---|---|---|---|---|---|
| Blunt Blaze (Bumper) | FLAME | 34 dps | — | 2s bay lock | — | 2s nose column (300×70px) per ammo; 68 direct theoretical; bathed targets ignite: burn 4 dps / 10s |
| Leap (Cricket) | DASH | ram @1400 | 1400 | per use | lock ≤700 | 0.4s body-check (~560px), sails over obstacles; dirt activation snapshots ×1.15 ram damage through surface crossings; hit: victim slow ×0.5/2s, caster invuln 2s |
| Chilblain (Coldfront) | PROJECTILE | 12 | 1000 | 2.0s | 165°/s, lock 1200 | Fire-missile tracking; on hit: freeze 3s, re-hits while frozen don't extend (no pedals, no triggers; momentum damps to a stop at `Vehicle.FREEZE_DECEL` 900); snowflake roof marker + dimmed HUD rack; ICE burst; fixed_loadout bosses immune (range 4000) |
| Phantom Phire (Ghost) | PROJECTILE | 32 | 950 | 3.0s | 240°/s, lock 3000 | Pierces cover; 6s lifetime ≈ map-wide (5700) |
| Toe Jam (Hammertoe) | TRIGGER | 60 flat | — | per arm | — | Armed charge replaces next ram's damage; expires unspent after 5s; bumper glows |
| Molotov (Kandy Kane / Hornet) | PROJECTILE | 12 | 850 | 2.0s | 100°/s, lock 1200 | On hit: burn 3 dps / 15s (range 1360); one recipe, two families; gentle launch lean, not quite homing |
| Chill Out, Man (Lovebug) | PROJECTILE | 0 | 1050 | 2.0s | 100°/s, lock 1200 | On hit: disarm 3s, re-hits while disarmed don't extend (MG + weapons offline; driving/ramming fine); purple roof marker + dimmed HUD rack; GLITTER burst; fixed_loadout bosses immune (range 2100); gentle launch lean |
| Tornado Alley (Cyclone) | TORNADO | 20 dps | — | per use | — | 3s self-centered spin, AoE 2.2× visual footprint (the wind-swirl ring draws exactly at the boundary), same-floor; caught cars: land-mine spin-out + 220 shove once each (launch_immune exempt); steer ×0.3 while spinning; random exit heading; AI holds to 250px |
| Pulse Wave (Hubcap) | PULSE | 35 → 8.75 | 600 wave | per use | — | Neon ring expands to 270px (speed×lifetime, 0.45s), anchored at cast position; damage + radial shove (380 → 95) fall off center-to-rim, one crossing per body, same-floor, launch_immune shove-proof; caster pops a ~15px hop; ring = the hitbox; AI holds to 250px |
| Scythe (Mr. Ghastly) | PROJECTILE | 70 | 780 | 2.5s | none | Biggest single hit in the game; slow shot (range 2340) |
| Red Glare (War Pig) | PROJECTILE | 6 ×20 | 950 | 4.0s | none | 20-rocket 26° fan; 120 theoretical point-blank (range 1235) |
| Taser (Smoky) | BEAM | 18 dps | instant | 2s bay lock | lock ≤200 | 2s latch / 36 direct theoretical + slow ×0.5; lockout starts after natural/early end; breaks past 400, on LoS block, or if either car changes floor |
| Rusty 'Poon (Splat Kat) | PROJECTILE | 10 | 820 | 2.0s | 100°/s, lock 1200 | On hit: slow ×0.5 / 3s (range 1804); gentle launch lean |
| **Breach Turret (Lackey)** | TURRET | 45 | 1400 | 2.8s | auto-aim, 120°/s traverse | LIVE turret on the hull: tracks the player inside ~1100px independent of heading, LoS-gated, fires through break-offs. Aim lag is the dodge. |
| **Blaze & Bolt (Lackey)** | FLAME+BEAM twin | 34 dps / 18 dps | — | shared 15s post-fire (boss exception — keeps the def gate); pool 2 / 120s | One magazine, two 2s barrels: taser when latchable (≤400 + LoS), torch otherwise; ending either barrel locks both |

Contact specials (Taser, Blunt Blaze, Leap, Toe Jam, mines, barrel blasts) are all same-floor only. Cross-floor specials come in two flavors: the tracking class (Chilblain, Molotov, Chill Out, Man, Rusty 'Poon) arcs between the shooter's and locked target's floors, while Phantom Phire crosses via explicit `pierces_cover` (boundary-only). Lackey's turret shots are straight (same-floor on terrace levels).

---

## Terrain

Sources: `vehicles/driving_controller.gd` `TERRAIN` + typed `VehicleTerrainModifier` entries imported from `assets/data/roster.json`. The controller multiplies the global surface values below by the current vehicle's profile; omitted entries are neutral ×1.0. Road = the unpainted floor.

| Terrain | Accel | Top Speed | Grip | Steer | Feel |
|---|---|---|---|---|---|
| Road | 1.00 | 1.00 | 1.00 | 1.00 | baseline |
| Grass | 0.90 | 0.90 | 0.80 | 1.00 | a lawn, not a bog |
| Snow | 0.85 | 0.90 | 0.45 | 1.00 | dirt-slow, half the bite |
| Dirt | 0.80 | 0.85 | 0.60 | 1.00 | loose |
| Ice | 0.55 | 1.00 | 0.08 | 1.20 | spinning tires; eager nose, stubborn travel bearing |
| Water | 0.40 | 0.45 | 0.70 | 1.00 | momentum eater — AI wades out after 1.2s |
| Mud | 0.55 | 0.60 | 0.42 | 0.90 | wet soil: spinning launch, low ceiling, broad slide |

### Vehicle terrain profiles (effective results)

These are the final global × vehicle values seen by the shared player/AI controller. Every unlisted ride/surface equals the global table; ice is deliberately unmodified for the whole fleet except Coldfront.

| Vehicle | Surface | Accel | Top | Grip | Steer | Extra |
|---|---|---:|---:|---:|---:|---|
| Cricket | Dirt | 1.12 | 1.08 | 0.81 | 1.15 | DASH launched here snapshots ×1.15 ram damage |
| Cricket | Grass | 1.01 | 1.01 | 0.92 | 1.08 | — |
| Hammertoe | Grass | 0.97 | 0.97 | 0.88 | 1.00 | — |
| Hammertoe | Snow | 0.94 | 0.95 | 0.56 | 1.00 | — |
| Hammertoe | Dirt | 0.94 | 0.95 | 0.72 | 1.00 | — |
| Hammertoe | Water | 0.66 | 0.70 | 0.77 | 1.00 | shallow only |
| Lovebug | Water | 1.00 | 1.00 | 1.00 | 1.00 | floats like the commercial — shallow water = dry road; test-locked |
| Coldfront | Snow | 1.00 | 1.00 | 1.00 | 1.00 | twenty winters — snow = plowed asphalt |
| Coldfront | Ice | 1.00 | 1.00 | 1.00 | 1.00 | the fleet's only ice profile; test-locked |
| Cyclone | Road | 1.10 | 1.05 | 1.25 | 1.10 | slicks on pavement; test-locked |
| Cyclone | Grass/Snow/Dirt | ×0.75 | ×0.80 | ×0.60 | 1.00 | penalty box (dirt nets 0.60/0.68/0.36; test-locked) |
| Cyclone | Water | 0.28 | 0.34 | 0.56 | 1.00 | slicks in a river |
| Smoky / War Pig | Grass | 0.95 | 0.95 | 0.86 | 1.00 | — |
| Smoky / War Pig | Snow | 0.90 | 0.94 | 0.53 | 1.00 | — |
| Smoky / War Pig | Dirt | 0.88 | 0.92 | 0.67 | 1.00 | — |
| Smoky / War Pig | Water | 0.50 | 0.55 | 0.74 | 1.00 | shallow only |
| Cricket | Mud | 0.62 | 0.65 | 0.50 | 0.98 | no dirt DASH bonus |
| Hammertoe | Mud | 0.80 | 0.80 | 0.60 | 0.98 | big-tire advantage |
| Smoky / War Pig | Mud | 0.72 | 0.74 | 0.55 | 0.96 | partial 4WD advantage |
| Cyclone | Mud | 0.36 | 0.40 | 0.25 | 0.78 | pavement slicks punished |

Future-car recipe: add `terrain_modifiers` entries to its `assets/data/roster.json` record, run `godot --headless --path . -s res://tools/import_roster.gd`, verify current surface and effective accel/top/grip/steer in the F1 handling dashboard (use F2 to tune the global surface table live), then run straight-entry, correction, committed-slide, recovery, collision, and AI terrain feel tests. Unknown terrain/property names make the importer fail.

Shallow water (the terrain above) slows; **deep water** (`environment/deep_water_zone.gd`) is a hazard, not a terrain — grounded cars sink and die (see Floors & Falls). Beaches are authored shallow strips between land and deep.

---

## Ambient Life

Sources: `environment/ambient_actor.gd`, `ambient_population.gd`, and the four authored level scenes. These are cosmetic-local soft targets: 1 HP, no score/radar/targeting, nonblocking to cars and shots, and unsynchronized over LAN.

| District | Population | Authored mix |
|---|---:|---|
| Downtown Derby | 18 + 2 carts | 12 business people, 2 vagrants, 2 police, 2 vendors; carts are separate debris props |
| Suburban Savagery | 18 | 5 joggers, 4 cyclists, 2 dogs, 2 skateboarders, 3 route-locked mowers, 2 police |
| Freeway Firefight | 11 | 5 truckers, 2 clerks, 1 dog, 1 hitchhiker, 2 farm hands; all on floor 1 |
| Capital City Carnage | 21 | 6 stationary food-truck vendors, 8 mall/museum business figures, 2 police on the monument loop, 2 K St vagrants, 2 joggers, 1 Ellipse dog |
| Mountainside Mayhem | 7 | 2 floor-2 skiers on the trailhead route, 5 floor-3 knoll deer |
| Piers of Pain | 18 | 15 workers across floors 1/2/3, 3 floor-2 police |
| Ground Floor Gore | 16 baseline | 10 floor-1 workers, 4 floor-2 workers, 2 floor-3 carriers; up to 8 porta escapees |

| Rule | Value |
|---|---|
| Run-over threshold | 90 px/s; slower contact makes the actor evade |
| Civilian scatter | vehicle within 240px, held 1.25s; police evade inside 140px |
| Police fire | nearest same-floor human ≤480px + LoS; one 0-damage tracer every randomized 1.4–2.2s |
| Splat | 5s lifetime, fades in final 1s |
| Tire transfer | 1.25s red track carry, 3s fade; shared 24-node skidmark cap |

Authoring: add one or more `AmbientPopulation` nodes before the vehicle nodes, choose `WANDER`, `ROUTE`, or `STATIONARY`, author safe bounds or a closed `route_points` loop, set the terrace explicitly, and verify the population budget plus wall/floor behavior at both camera zooms. Custom-level schema/editor support is intentionally not exposed yet.

---

## Floors & Falls (multi-floor levels)

Source: `game/floors.gd`, `vehicles/vehicle.gd`, `environment/deep_water_zone.gd`. Floors are terraced — every point has one driveable floor (1 = sea level, 2 = street/dock, 3 = rooftops). Legacy levels run at floor −1 and none of this applies.

| Rule | Value | Detail |
|---|---|---|
| Going up | jump pads (landing) or RAMPS (at grade) | jumps land you on the zone under you; driveable ramps (ramp-flagged zones) grade your floor over mid-slope, both directions, no hop, no damage |
| Going down | drive off any open edge | ledge hop: vz 240 per floor dropped |
| Fall damage | 25% max HP (`fall_damage_frac`, F2-tunable) | only on landing 2+ floors below takeoff; 1-floor drops, all jumps up, and every ramp grade are free |
| Size cue | visuals ×0.94 / ×1.00 / ×1.06 by floor | 0.25s tween; collision radius NEVER changes |
| Floor lift | floor-3 cars ride +32px visually (`Vehicle.FLOOR_LIFT`) | body AND shadow rise together (tight shadow = driving, not floating); separation only on real jumps; tweens in as a ramp carries you up |
| Deep water | sink kill, grounded only | pit rules: 48px rim inset, ignores shields, airborne sails over; splash + bubbles; DEVGOD death comped |
| Cross-floor ram | impossible | different floors don't collide, physically |
| Underpass fade | structure → 45% alpha (`UNDER_FADE`, dock_deco.gd) | bridges/crane booms go translucent while a car drawing below them is beneath; eases at 6.0/s; rails stay opaque |
| Spawns | `start_floor` authored per car | roof/deck spawns pre-adopt their terrace at boot |

---

## Status Effects

Source: `vehicles/status_receiver.gd` + effect specs in weapon `.tres` files. Same-kind effects refresh (longest duration wins), never stack.

| Effect | Sources | Magnitude | Duration | Notes |
|---|---|---|---|---|
| Burn | Molotov / Blunt Blaze | 3 dps / 4 dps | 15s / 10s | Visible hull fire; **boost extinguishes it**; DoT bypasses the AI-vs-AI governor |
| Slow | Splat / Taser / Leap hit | ×0.5 speed | 3s / while latched / 2s | Multiplies accel + top |
| Invuln | Spawn shield / Leap connect | full immunity | 2s | Blink FX; does NOT survive pits |
| Disarm | Chill Out, Man | — | 3s | Re-application while active ignored; MG + weapons offline, driving fine; purple peace marker + dimmed rack; fixed_loadout immune |
| Freeze | Chilblain | — | 3s | Re-application while active ignored; all intent stripped; velocity damps to zero at `Vehicle.FREEZE_DECEL` 900 px/s²; snowflake marker + dimmed rack; fixed_loadout immune; flags2 bit over LAN |

---

## Visual Wear (damage tiers)

Source: `vehicles/paint/wear.gd` (marks) + `vehicles/drive_fx.gd` (tier poll + smoke). Purely visual — no handling change; puppets converge off mirrored hp with zero wire state; turntables (car select/garage) always FRESH.

| Knob | Value | Notes |
|---|---|---|
| Tiers | FRESH > 2/3 hp · BANGED ≥ 1/3 · BUSTED below | `DriveFX.wear_tier`; exact thirds land BANGED; no hysteresis (heals are chunky) |
| Marks | scratches+dents (BANGED) / +soot+chips+nose crumple (BUSTED) | deterministic per style+palette seed; BUSTED extends BANGED's RNG stream (damage accumulates) |
| Count scale | `4·l·w / REF_AREA 1144`, clamped 0.4–1.6 | bikes 1-2 marks, APC/trailer cap; `tail_len` keeps Coldfront's plow clean |
| Smoke | amounts [0, 6, 12] · lifetime [—, 1.1, 1.8] · gray wisps / dark trail | one lazy world-space CPUParticles2D at the rear midpoint; death cuts it, the wreck keeps its dents |
| Exceptions | Goliath phase 2 resets wear with the pool (fresh bobtail) · trailer plates stay FRESH · derelicts keep their WRECK_TINT instead | |

---

## Combat Modifiers (the fine print)

Sources: `vehicles/vehicle.gd`, `game/combat.gd`, `weapons/projectile.gd`, `vehicles/drivers/enemy_driver.gd`, `levels/combat_level.gd`.

| Rule | Value | Detail |
|---|---|---|
| Ram damage | (rel.speed − 220) × 0.06 | 0.3s cooldown per rammer; impact speed sampled pre-slide |
| Ram lethality | player↔AI lethal; AI↔AI floors at 1% HP | crashes never let AI finish each other |
| Toe Jam ram | flat 60 replaces the formula | still needs a real hit (> 220 rel) |
| Collision bounce | ×0.35 of into-surface speed | below 100 px/s contact = smooth grinding |
| Ram punch-through | kill a prop → keep entry speed × clamp(1 − max_hp/200, 0.55, 0.95) | game-wide; 1-HP trash barely slows you, 60-HP crates cost ~30%; a SURVIVING prop still stops you (knobs `punch_*` in vehicle.gd Ram group) |
| AI-vs-AI damage | ×0.35 | the governor: their brawls are theater |
| AI mercy | victim < 10% HP → AI damage ×0 | player damage ×1 both directions on hard; easier tiers soften incoming only (see Difficulty) |
| Rear weak spot | ×1.5 (Lackey) | projectiles whose travel direction ≈ victim facing |
| AI fire rate | ×3 cooldown (Lackey ×1.5) | **MG only** (heat self-scales; × `ai_fire_cooldown` difficulty knob; turrets too). Non-MG weapons run the flat 2s `Vehicle.WEAPON_LOCK` for player and AI alike; bosses (`fixed_loadout`) exempt, Route 666 chase opts out |
| Boost | 100 tank, −5/s held | ×2.0 accel, ×1.5 top; extinguishes burn; no refill — except chase nitro bottles (+35, `boost_pickup.tscn`) |
| Handbrake | grip ×0.15, decel 400 | the drift tool |
| Jump-pad launch | vz 760, gravity 1300 | needs ≥120 px/s; airborne = wall-collisions only; pads are square 224 omnidirectional caution pyramids, floor-locked on terrace levels (`floor_index`) |
| Driveable grades | grounded transition both ways | `Ramp`: rectangular halves, standalone downhill pull 120; `CornerRamp`: high right-angle triangle + low trapezoid, 45° low edge; ordinary grades interpolate visual floor lift/scale continuously; local priority-100 terrain composes road/grass/snow/dirt/ice/water/mud; Goliath's Arena stairs opt out and retain pull 170 + row nicks/bumps |
| Scaffold network | 256px runs / 448px platforms | multiple connected routes; paired grades; explicit `edge` drops; 640×448 repair platform; floor-gated rewards; every deck edge classified rail/gate/seam/drop (`ScaffoldDeck` exports — gate shoulders build statics, gate_width 256 default, per-deck gate_offset); hazard-taped drop lips; breakaway rails = 12-HP `deco="rail"` blocks (z 2, net id) + AI-only curbs over drop lips; posts/plates/cast shadow on an understructure canvas that survives the under-fade (shared `under_fade.gd` 0.42/6.0) |
| Signature arena state | protocol 8 repeated rows | u16 stable ID + flags + HP fraction + phase timer + 8-actor target mask; host authority; dead props persist as visible noncolliding remains (flatten-in-place, `environment/remains_paint.gd`) |
| Driveable hill | one root / one skin / eight faces | `DriveableHill`: compact pull 180; footprint = summit size + grade length; corner leg = grade length ÷ 2; substrate-reset + terrain skin; NW relief 0.22, projection 1.55, slope darkening 0.06, crest 0.10/18px, foot 0.12/20px, shadow (12,14)/0.20; all connector pairs generated; seam props carry both floor bits |
| Terrace chamfer | solid right triangle | top-side corner cap carries obstacle + BOTH terrace bits; reusable `TerraceChamfer` follows the Goliath's Arena buttress convention |
| Arena radar | live combatants within `2200 × viewer radar_range_scale × target detectability` px (`Vehicles.sensed_others` — edge arrows share the bound; HP sidebar stays map-wide) | vehicle `body_color` + contrast outline; dots same-floor, chevrons above/below; includes LAN humans; no difficulty/DEVGOD gate; Route 666 GPS excluded |
| DEVGOD (Developer Options) | immune, ∞ ammo | Developer Mode master-gates every effect while preserving the stored toggle; pits/deep water still kill but the life is comped |
| Jump-mine pop | vz 450 | ~0.7s air |
| Mine sensing | land 52px / jump 26px | land paint remains 14px; only the damaging mine has proximity reach |
| Lives / respawn | 3 lives; 1.6s delay, 2s shield | shield also fires at level start; full-wipe on 0 |
| Health station | 2s linear full heal, 2 uses, 45s cd | human-only; snap-center solid/disarmed/invulnerable hold; restores entry heading + velocity; successful exit grants shared 2s respawn shield; no resurrection |
| Pits | instant kill, grounded only | kill area inset 48px from the painted rim; ignores shields |
| Deep water | instant sink, grounded only | same rules as pits, wetter exit; see Floors & Falls |
| Fall damage | 25% max HP | landing 2+ floors below takeoff; see Floors & Falls |

---

## Difficulty (license classes)

Source: `game/difficulty.gd` — ONE static table, every value a multiplier on the hard baseline (HARD row all ×1.0 by definition, locked by `tests/test_difficulty.gd`). Tier is run state: picked at the DMV screen after title SINGLE PLAYER, fixed until Quit to Title (end-screen Restart keeps it). Read at use sites only — no declared const/static ever moves.

| Knob | EASY (Learner's Permit) | MEDIUM (Road Raging Commuter) | HARD (Revoked License) | Read at |
|---|---|---|---|---|
| `player_damage_taken` | ×0.55 | ×0.75 | ×1.0 | `combat.gd scale()` — every AI→player path: shots, rams, mines, beam, flame |
| `player_damage_dealt` | ×1.0 | ×1.0 | ×1.0 | `combat.gd scale()` — dormant knob, player→AI |
| `ai_fire_cooldown` | ×1.75 | ×1.35 | ×1.0 | vehicle.gd mount push + turret.gd — covers chase cars and boss turrets |
| `boss_hit_budget` | ×0.6 (30 dmg) | ×0.8 (40) | ×1.0 (50) | enemy_driver.gd boss valve — Lackey breaks off sooner |
| `boss_engage_limit` | ×0.7 (4.9s) | ×0.85 (5.95s) | ×1.0 (7s) | enemy_driver.gd boss valve |
| `boss_break_time` | ×1.6 (3.2-8.8s) | ×1.25 (2.5-6.9s) | ×1.0 (2.0-5.5s) | enemy_driver.gd `_boss_break_time` — scales the lerp output, dominance shape intact |
| `goliath_hp` | ×0.7 (700/630) | ×0.85 (850/765) | ×1.0 (1000/900) | goliath_boss.gd — both phase pools + the sentinel refill |
| `goliath_ram_cooldown` | ×1.5 (67.5s) | ×1.2 (54s) | ×1.0 (45s) | goliath_driver.gd — phase-2 charge spacing |
| `chase_pace` | ×0.92 | ×0.96 | ×1.0 | horde_wall.gd `tier_pace()` — Route 666's pack runs slower; surge and mercy untouched |

Deliberately unscaled: enemy counts, lives (3), mook RELENT valve, AI theater governors (×0.35 / mercy), environmental flat damage (barrels, falls, pits, deep water — none route through `Combat.scale`; Route 666's pack deals no damage at all), jackknife cadence (first follow-up knob if easy Goliath still runs hot). A mine whose dropper died deals full damage on every tier (null shooter — pre-existing shape).

---

## AI Archetypes & Behavior Numbers

Source: `vehicles/drivers/enemy_driver.gd`. Every driver is a blend `mix = (aggressor, ambusher, opportunist)`; traits interpolate.

| Trait | Aggressor | Ambusher | Opportunist |
|---|---|---|---|
| Engagement band (near-far px) | 110-300 | 160-420 | 260-560 |
| Flees below HP | 10% | 22% | 35% |
| Target scoring | nearest | nearest (flanks 35°) | weakest (0.3 near + 1.0 weak) |

Global behavior: scan 1200 / fire range 1000 (LoS-gated) · HUNT map-wide when scan is empty · target commitment 2s, rescore 0.5s, switch margin +0.20; invalid/dead/shunned targets replace immediately · revenge +0.5 for 6s, player priority +0.2 · predictive pursuit leads real target velocity up to 0.75s (240px/s denominator floor) · ordinary BREAK snapshots an endpoint 420px through + 140px beside the predicted target, arrives within 100px or times out at 2.5s, and must separate 1.5× near before rearming · weave ±0.2 steer on long approaches · low-HP EVADE 3s then 7s re-engagement · RELENT vs player after 6s pressure or 30 HP dealt (3.5s no-fire disengage; final duel uses 2s) · `relentless` bosses preserve the old live-bearing full-length BREAK and boss valve (50 dmg / 7s, dominance-scaled 2.0-5.5s) · WADE out after 1.2s · dry hunters scavenge crates.

`AIFightDirector` is scene-local: refresh 0.25s · one 8s player-focus lease below 5 ordinary enemies, two at 5+ · multi-human arenas cover an uncovered player before doubling up · nonholders take a −0.35 player score while any lease is filled, unless that player is their fresh revenge target · dead holders hand off immediately. Exactly one living human + one eligible ordinary enemy forces the duel target, bars new EVADE episodes, and repeats attack run → short reposition → return; death/respawn clears/restores the assignment. SP/custom levels run it locally; Grand Melee runs it on the host with no protocol state. `relentless`, `fixed_loadout`, Goliath, and Buzzard drivers are excluded.

| Main-event static | Value | Purpose |
|---|---:|---|
| `TARGET_COMMIT_TIME` / `TARGET_REEVAL_TIME` | 2.0s / 0.5s | readable ownership without stale invalid targets |
| `TARGET_SWITCH_MARGIN` | +0.20 | challenger must materially beat the current score |
| `REVENGE_WINDOW` / `REVENGE_BONUS` | 6.0s / +0.5 | retaliation without endless AI grudge cascades |
| `PLAYER_PRIORITY` / `NON_FOCUS_PLAYER_PENALTY` | +0.2 / −0.35 | player thumb; free-for-all room outside the spotlight |
| `FOCUS_REFRESH` / `FOCUS_LEASE_TIME` | 0.25s / 8.0s | scene-director cadence and rotation |
| `FOCUS_TWO_AT` | 5 enemies | second simultaneous player-pressure slot |
| `PURSUIT_MAX_LEAD` / `PURSUIT_SPEED_FLOOR` | 0.75s / 240px/s | bounded moving-target intercept |
| `BREAK_TIME` / `BREAK_EXIT_DIST` | 2.5s / 420px | committed fly-through budget and depth |
| `BREAK_LATERAL_OFFSET` / `BREAK_ARRIVE` | 140px / 100px | pass side and endpoint tolerance |
| `BREAK_REARM_MULT` | 1.5× near | real separation before another drive-by |
| `EVADE_TIME` / `EVADE_COOLDOWN` | 3.0s / 7.0s | episodic flee, mandatory re-engagement |
| `DUEL_RELENT_TIME` | 2.0s | final-rival reposition beat |

The mutable archetype `PURE` table and all statics above live in `enemy_driver.gd`, except the three `FOCUS_*` statics in `ai/fight_director.gd`. `assets/data/ai_profiles.json` remains unconsumed design notes. Range-aware weapon selection, repair/ammo planning, and cover utility are intentionally deferred; the lethal-hazard layer of terrain awareness landed August 2026 (below).

Floor navigator (multi-floor levels): cross-floor targets score −0.1 · NAVIGATE rides authored FloorConnectors (approach lead 220, exit lead 260, 6s timeout, boost on jump commits, grade commits never boost, commit leg ignores feelers) · ambusher/opportunist blends with an armed tracking secondary hold roof vantage up to 8s, raining missiles cross-floor (walls-only LoS), before descending · MG and non-tracking specials never fire cross-floor · hazard curbs (invisible, AI-feeler-only) rail every pit/deep-water rim — Snowy's cliffs included.

Lethal-hazard avoidance (any level with deep water/pits): the kill zones are unraycastable (layer 0), so drivers query `game/hazards.gd` — zones join `&"lethal_hazards"`, rects cached once per physics frame across all drivers. The service reads painted extents conservatively; its `KILL_INSET` is 24px per side, matching `PitZone.KILL_INSET = 48px` as the full collision-size reduction. Four layers: a post-ladder GUARD over every mode's intent (real-travel lookahead; steering overridden pre-clamp to the tangent along the face the car entered — unless the line to the committed goal is itself clear, then only speed is shed; throttle staged by time-to-impact; boost vetoed; fire untouched; airborne and NAVIGATE jump commits exempt) · endpoint validation (`escape_direction()` tries the requested bearing, an outward exit, both face tangents, then reverse; a hop is skipped when every landing is unsafe, while CLEAR directions and BREAK exits reroute or finish short) · soft scoring thumbs (never a veto — HUNT stays unfiltered) · `Mode.DETOUR` (a blocked same-floor beeline routes around the blocking rect's end — river-gap ends ARE the bridges, zero authored markers; committed two-phase bridgehead run on the NAVIGATE idiom, arrival by plane-crossing because a heavy's turning circle out-radiuses any arrive circle, phase 1 committed, greedy one-rect-per-leg replans; entry only from PURSUE).

| Hazard static | Value | Purpose |
|---|---:|---|
| `Hazards.KILL_INSET` | 24px per side | Mirrors the `PitZone` kill shape's 48px full-size reduction when validating an escape from a forgiveness band |
| `Hazards.GUARD_MARGIN` | 20px | hard-guard inflation (< the zones' 24px/side kill inset — bridge lanes stay legal) |
| `Hazards.PLAN_MARGIN` / `Hazards.DETOUR_CLEARANCE` | 72px / 128px | detour/scoring inflation; waypoint reach past a rect end |
| `HAZARD_REACT_TIME` / `HAZARD_REACT_BASE` | 0.9s / 120px | guard lookahead envelope (speed-scaled + floor) |
| `HAZARD_CUT_TTI` / `HAZARD_BRAKE_TTI` | 1.2s / 0.5s | time-to-impact: throttle ×0.4 / brake −0.4 |
| `HAZARD_GUARD_GAIN` | 2.5 | rim-tangent steering authority |
| `HAZARD_LINE_PENALTY` / `HAZARD_CRATE_PENALTY_DIST` | −0.35 / 1500px | cross-hazard target / crate thumbs |
| `ESCAPE_HOP_RANGE` | 280px | `escape_direction()` landing reach; unsafe bearings deflect along the entered face and no safe result cancels the hop |
| `DETOUR_TIMEOUT` / `DETOUR_ARRIVE` / `DETOUR_LANE_HALF` | 6s per leg / 90px / 140px | leg clock; radius + plane-crossing arrival corridor |
| `DETOUR_ENTRY_LEAD` / `DETOUR_EXIT_LEAD` | 220px / 260px | bridgehead offsets along the gap normal |
| `DETOUR_CHECK_TIME` / `DETOUR_REPLAN_MIN` | 0.5s / 1.0s | blocked/cleared cadence; replan throttle |

Coverage is linted: `tests/test_hazard_coverage.gd` samples every zone rim in the master level list — protected means curbed (32px flush-mount tolerance), chained into a sibling rect, walled (boundary or floor-bit retaining walls), or inside an authored FloorConnector launch corridor (600×±160 — a stunt-jump runway never owes a curb across itself). `tests/test_hazard_avoidance.gd` holds the geometry/guard/endpoint/detour locks plus the live-sim anti-suicide gate (a real Hammertoe crosses a gapped water column and closes on prey).

---

## Campaign

Source: `game/scene_flow.gd` CAMPAIGN profiles + `levels/arena_contract.gd`; full language and brief: `docs/arena_field_manual.md`. Route 666 Roulette (specialty) and the three `placeholder` slots are excluded from the arena contract. Absolute floor: 4 target cars, 1,600,000 gross px²/car, short side 2048 — except `duel` arenas (`mp_avail: false`, exactly 2 cars / 1 station; aquarium floors still apply per-car). Small/med/large target cars = 4 / 5-7 / 7-8; stations = 1 / 1-2 / 2-3. Boss campaign overlays may field two actors but underlying target stays ≥4. Slot order is test-pinned (`tests/test_ground_floor.gd`); placeholder slots are sceneless, ride the shared `level_X.png` sawhorse interstitial card (any key detours past), and flip to real entries with `optional: true` (STAY/DETOUR chooser) once buildable — Arena Assault is the first graduate.

| # | Level | Size (interior px) | Target cars | Campaign enemies | Stations | Signature hazards |
|---|---|---|---:|---:|---:|---|
| 1 | Arena Assault | SMALL 2560×2560 | 2 (duel; mp_avail false) | 1 | 1 | derby pit: dirt infield in an asphalt lane, jersey ring, center station, wall-lane M/M/H/P/X crates, barrel chains, wreck cover; `optional: true` while in test |
| 2 | Piers of Pain | LARGE 5120×3584 | 8 | 7 | 2 | 3 floors: lowland / quay / roofs + 1704px ship deck; deep water + piers; 2 sky bridges + crane underpasses; chain-link quay fence (12 HP); 8 jump pads; roof crates |
| 3 | Downtown Derby | MED 3712×3584 | 5 | 4 | 1 | park pond, secret courtyard, smashables; NW+N rooftops + bridge, garage ramp, 1 jump pad |
| 4 | Freeway Firefight | LARGE 4096×5376, 3 floors | 8 | 7 | 3 | floor-2 raised highway plate + floor-1 farm/truck-stop lowland + floor-3 country-road overpass; 5 grades, 3 jump pads, 16 synced 12-HP deck rails, retaining seam with 4 chamfers, fuel-chain blasts; MP ready |
| 5 | Lackey's Arena | MED 3072×3072 | 4 planned MP | 1 (Lackey) | 1 | live turret; destructible container cover (140 HP), chain-link runs, barrel clusters, containment square, one jump pad; named MP exception |
| 6 | Suburban Savagery | MED 3584×3456 | 7 | 6 | 2 | 20 houses (120 HP), east lake, school/gas anchors |
| 7 | Terminal Terror | PLACEHOLDER (unbuilt) | — | — | — | sawhorse card; chains into slot 8 |
| 8 | Slaughter on the Strip | PLACEHOLDER (unbuilt) | — | — | — | sawhorse card; chains into Route 666 |
| 9 | Route 666 Roulette | SPECIALTY ~130k px streamed, 120s | — | runtime horde | medkits | excluded from arena contract; `optional: true` (STAY/DETOUR); caught or wrecked = robbed, then the tour rolls on (no retry) |
| 10 | Mountainside Mayhem | MED 4096×4096 | 5 | 4 | 1 | generated SW→NE mountain pass on a 32×32×128 grid; 8 asphalt legs, snow infill, 3 ice bends; chasm rows 12–13 with 3-cell bridge + unrailed human jump lane; floor-3 knoll and one-exit runaway ledge; 42 breakaway 12-HP rails, ids 100–141; MP ready |
| 11 | Ground Floor Gore | LARGE 4608×3840, 3 floors | 8 | 7 | 2 | dirt/mud/water; RAINY DUSK (night_arena, 5 shootable 8-HP worklights, headlight beams on EVERY car); foundation + scaffold ring over a courtyard pit; ALL 16 ring rails breakaway 12-HP; east-strip 2↔3 ramp (courtyard pinch gone); fl-2 rim fully open (floor-1-only walls); 4 slab columns; spoil heap (848 fl-2 apron + 448 fl-3 cap, mine crate on top) + SW twin heaps (320 fl-2); NW parking lot (7 synced derelicts); 220-HP generator (arm 55) w/ 90%/75% distress sparks at (-1420,-60); junk 15 HP; ids 1,10-17,20-74; MP ready |
| 12 | Capital City Carnage | LARGE 6144×3840 (biggest interior; FLAT — knoll only) | 8 | 7 | 3 | THUNDERSTORM (night_arena StormTint, flash/dip cycle, slashing rain, headlight beams); Potomac shallow banks + lethal deep channel, 2 straight bridges w/ destructible rails + VISIBLE 20-HP rim guardrails (ids 60-65); Lincoln/Capitol flat painted plazas, Monument `DriveableHill` knoll w/ summit crates; Penn Ave K-to-Capitol diagonal + traffic circle + Maryland diagonal + 5 side streets + 3 pocket parks + tan sidewalk trails on road ribbons; 1024px Reflecting Pool w/ coping + algae (`pool_surround`); WH iron-fence ring (8×30 HP, ids 10-17) around **Marine One** (id 1: breach→POTUS+3-guard sprint→spool 6s→2-stage floor-bit climb→sky; air kill = spiral crash + Ellipse cache; any kill = 2500 mini_boss); 6 food trucks (128×60) + vendors on Constitution; net ids 1,10-17,20-23,30-35,40-65 sparse (43 total); `optional: true` while in test |
| 13 | Goliath's Arena | LARGE 4608×3584, 2 floors | 4 planned MP | 1 (Goliath) | 1 | grandstand ramps pull 170 + stair bumps; continuous crown; 4 solid chamfers; boss overlay; named MP exception |

---

## Freeway Firefight (raised highway knobs)

Sources: `levels/freeway/freeway_plan.gd` is the dependency-free signed layout;
`levels/freeway/freeway.tscn` mirrors it. `tests/test_freeway_level.gd` compares
the scene against the plan and live-simulates the cross-floor jumps, grades,
retaining stops, garage drive-through, and fuel chain. Change the plan first,
then update its scene mirror; the tests prove the relationship.

### Plan constants

| Plan constant | Signed value | What it owns |
|---|---|---|
| `ARENA_RECT` | `Rect2(-1088,-2688,4096,5376)` | Complete playfield; floor-2 plate is `x=-1088…1088`, floor-1 lowland is `x=1088…3008` |
| `FLOOR_ZONES` | `FZPlate`: floor 2, `Rect2(-1088,-2688,2176,5376)`<br>`FZLowland`: floor 1, `Rect2(1088,-2688,1920,5376)`<br>`FZDeck`: floor 3, `Rect2(-1088,-928,2176,320)`<br>`FZLanding`: floor 2, `Rect2(1472,-928,256,320)`<br>`FZShelfN`: floor 2, `Rect2(1088,-2304,256,512)`<br>`FZShelfS`: floor 2, `Rect2(1088,256,256,512)` | Winning floor at every driveable XY point |
| `RAMPS` | `RampW`: 2→3, `Rect2(-1088,-608,256,384)`, high north<br>`RampA`: 2→3, `Rect2(1088,-928,384,320)`, high west<br>`RampB`: 1→2, `Rect2(1728,-928,384,320)`, high west<br>`RampN`: 1→2, `Rect2(1088,-1792,256,512)`, high north<br>`RampS`: 1→2, `Rect2(1088,-256,256,512)`, high south | Five road grades and their floor/direction contract |
| `WALLS` | Layer 12: `RetainE_1 Rect2(1088,-2688,24,384)`; `RetainE_2 Rect2(1088,-1792,24,864)`; `RetainE_3 Rect2(1088,-608,24,864)`; `RetainE_4 Rect2(1088,768,24,1920)`; `ShelfN_E Rect2(1344,-2304,24,512)`; `ShelfN_N Rect2(1088,-2328,280,24)`; `ShelfS_E Rect2(1344,256,24,512)`; `ShelfS_S Rect2(1088,768,280,24)`; `LandingN Rect2(1472,-952,256,24)`; `LandingS Rect2(1472,-608,256,24)`; `RampAN Rect2(1088,-952,384,24)`; `RampAS Rect2(1088,-608,384,24)`; `RampBN Rect2(1728,-952,384,24)`; `RampBS Rect2(1728,-608,384,24)`.<br>Layer 20: `DeckEastStop Rect2(1064,-928,24,320)` | Layer 12 is obstacle + floor-1, so lowland traffic stops and floor-2 traffic may hop down. Layer 20 is obstacle + floor-2 and stops plate traffic from driving under the deck's east end into `RampA`. |
| `CHAMFERS` | `ChamferNE`: corner `(1112,-2688)`, legs `(128,128)`<br>`ChamferAN`: corner `(1112,-952)`, legs `(128,-128)`<br>`ChamferAS`: corner `(1112,-584)`, legs `(128,128)`<br>`ChamferSE`: corner `(1112,2688)`, legs `(128,-128)` | Four 45° retaining-corner triangles; `chamfer_points()` derives their three vertices |
| `COUNTRY_ROAD` | `Rect2(2112,-896,896,256)` | Floor-1 country road east of `RampB` |
| `PASTURE` | `Rect2(1400,-2688,1608,1688)` | Priority-5 grass under the farm |
| `FARM_FIELD` | `Rect2(2176,-1920,768,640)` | Crop-row paint and farm-hand wander footprint |
| `TRUCK_STOP` | `TruckStopLot Rect2(1664,320,1344,1856)`; `FrontageRoad Rect2(2560,-640,256,960)` | Priority-10 floor-1 road zones |
| `TRUCK_STOP_IDS` | `Tanker 200`; `DieselPump1/2 201/202`; `Barrel1/2/3 203/204/205`; `Pump1/2/3/4 206/207/208/209`; `Store 210`; `GarageW/E 211/212`; `Semi1/2 213/214` | Stable LAN ledger for the truck stop |
| `RAILS` | computed by `_build_rails(FZDeck, RampW, RampA)` | Deck-edge rectangles; see below |
| Helpers | `rect_of`, `floor_at`, `plate_east_edge_covered`, `chamfer_points` | Test-facing lookup, floor precedence, complete seam proof, and chamfer geometry |

### Deck rail constants

| Constant / scene value | Value | Effect |
|---|---:|---|
| `RAIL_THICKNESS` | 12px | Short axis of every deck rail |
| `RAIL_INSET` | 8px | Rail centerline inset from the deck edge |
| `RAIL_MAX_LENGTH` | 256px | Maximum generated segment length |
| `RAIL_BREAK_CLEARANCE` | 16px | Gap between segments and clearance before the deck's east end |
| North run | 8 × `256×12`, `x=-1088…1072`, center `y=-920` | Full north edge from the west corner to the east clearance |
| South run | 8 × `224×12`, `x=-832…1072`, center `y=-616` | Begins after `RampW`'s 256px mouth and ends at the east clearance |
| Durability / floor / draw | 12 HP / floor 3 / `z_index = 2` | Breakaway deck guards on the floor-3 draw plane |
| `arena_net_id` | `100–115` | Contiguous ID in computed rail order |
| AI curb rule | none | A floor-blind curb on the deck would wall off floor-2 highway traffic underneath |

### `Signage`

`environment/signage.gd` paints words only. Place billboards and pylons at
`z_index = 1` when they are overhead; a storefront band remains at z 0.

| Export / helper | Default | Rule |
|---|---|---|
| `kind` | `billboard` | `billboard`, `pylon`, or `band`; an unknown kind falls back to billboard paint |
| `size` | `384×160` | Panel footprint and the text-fitting box |
| `text` / `sub_text` | `BENT CHROME` / empty | Main and optional secondary copy |
| `face_color` | `Color(0.16,0.15,0.17)` | Panel face |
| `text_color` | `Color(0.92,0.85,0.55)` | Live-letter ink |
| `frame_color` | `Color(0.30,0.30,0.34)` | Frame, pylon trim, or band edge |
| `weathering` | `0.5`, range `0…1` | Deterministic grime, peel, or band chips |
| `dead_letters` | `0` | Number of alphabetic characters darkened across both copy lines |
| `paint_seed` | `0` | Nonzero fixes weather/dead-letter selection; zero derives it from global position |
| `text_fits()` | computed | Returns whether the selected font sizes fit the authored panel; use it in level tests for final copy |
| Parent lifetime | signal-driven | Hide on a parent's `flattened` or `Health.died`; show again on `restored` when that signal exists |

### `DestructibleBlock` road-site styles and blasts

| `deco` | Purpose / knobs |
|---|---|
| `semi` | Parked box trailer and fleet cab; long axis follows `size`, `livery` chooses the work-truck palette |
| `tanker` | Rounded fuel cylinder and fleet cab; same size/livery rules, plus the explosive row below |
| `hay` | Round bale with straw coils, twine, and seeded whiskers |
| `storefront` | Flat gravel roof and explicit shop face; `front` is `south` by default and accepts `north`, `west`, or `east`. HVAC count is 0 when the short side is below 192px, otherwise 2 when the long side is at least 320px, otherwise 1. Signage remains a level-owned child. |

| `BLASTS` key | Radius | Flat damage | Query shape |
|---|---:|---:|---|
| `barrel` | 130px | 25 | Circle from the fixture center |
| `tanker` | 200px | 40 | Capsule following a nonsquare hull's spine; a square fixture keeps the circle |

Blasts affect same-floor Health-bearing cars, obstacles, and soft targets and
may chain other explosives. They deliberately carry environment hit identity,
not a shooter credit. Blocks emit `flattened` when they become collisionless
remains and `restored` when applied network state brings them back.

### `freeway_deco.gd`

This script is paint-only. Author terrain, floors, columns, walls, and other
collision separately.

| Export | Default | What it changes |
|---|---|---|
| `kind` | `overpass_deck` | Selects `overpass_deck`, `overpass_shadow`, `canopy`, `embankment`, `lot_marks`, or `crop_rows` |
| `size` | `768×160` | Exact paint footprint; long-run details follow the longer local axis |
| `paint_seed` | `0` | Nonzero fixes scattered wear/detail; zero derives it from position |
| `accent` | `Color(0.72,0.16,0.14)` | Canopy outline/logo and lot-mark entrance stripe |
| Under-fade | `overpass_deck`, `canopy` only | Builds the shared `UnderFade` area and eases alpha while lower-floor traffic is beneath |

---

## Mountainside pass (generated geometry knobs)

Sources: `levels/snowy/pass_grid.gd` owns the signed layout and furniture data;
`levels/snowy/pass_builder.gd` turns it into the five generated scenes. The
level instances those scenes and supplies its asphalt, snow, and ice materials
in `levels/snowy/snowy.tscn`. Generated scenes are checked against the builder
by `tests/test_mountain_pass.gd`.

### Grid and rails

| Grid constant | Value | What it changes |
|---|---:|---|
| `CELL` | 128px | Cell pitch used by every authored span and grid/world conversion |
| `N` | 32 | Row and column count |
| `OVERLAP` | 64px | Vertical overlap between neighboring main-drop pit bands |
| `ORIGIN` | `(-2048,-2048)` | World position of grid cell `(0,0)` |
| `ARENA_SIZE` | `4096×4096` | Playfield size |
| `ARENA_RECT` | `Rect2(-2048,-2048,4096,4096)` | Bounds clipping and closed-side bleed |
| `CHASM_ROWS` | `12–13` | Two grid rows replaced by west pit, bridge, and east pit |
| `BRIDGE_COLS` | `17–19` | Three driveable bridge columns through the chasm |
| `SOUTH_CAP_MOUNTAIN_COLS` | `10` | Last mountain column on the south cap row; later columns are drop |

| Rail constant / builder value | Value | What it changes |
|---|---:|---|
| `RAIL_THICKNESS` | 12px | Short axis of every breakaway rail rectangle |
| `RAIL_RIM_INSET` | 8px | Places a rail back from its lethal lip |
| `RAIL_END_CLEARANCE` | 16px | Clears each generated run end |
| `RAIL_MAX_LENGTH` | 256px | Splits a long run into damageable sections |
| Rail count | 42 | Generated segments along the drop, chasm, and bridge sides |
| `max_hp` | 12 | Durability of every generated segment |
| `floor_index` / `z_index` | `2` / `0` | Floor-2 collision with ground-level draw order |
| `arena_net_id` | `100–141` | Contiguous LAN identity range in generated order |

### `MountainWall`

The one Mountainside instance wraps 17 authored layer-54 mountain rectangles.
The layer combines wall, obstacle, floor-mid, and floor-high bits; the skin
paints their union and keeps the authored rectangles available to static
inspection.

| Export or knob | Mountainside value | What it changes |
|---|---:|---|
| `bounds` | `Rect2(-2048,-2048,4096,4096)` | Declares closed arena sides for straight outward bleed |
| `bleed` | 96px | Extends blocks past a closed side before unioning |
| `overhang` | 12px | Expands rock paint beyond the solid union |
| `jitter` | 6px | Organic displacement range on open rim subdivisions |
| `face_width` | 52px | Width of the exposed rock face between rim and snow cap |
| `chamfer_leg` | 128px | Maximum leg of derived notch-filling corner chamfers |
| `shadow_offset` | `(30,36)` | Southeast rock-skin shadow displacement |
| `shadow_alpha` | 0.26 | Rock-skin shadow opacity |
| `pine_spacing` | 150px | Candidate spacing for painted summit pines |
| `rim_step` | 56px | Maximum span between organic rim samples |
| `paint_seed` | 4096 | Deterministic rim, pine, and detail seed |
| `substrate_material` | `SM_asphalt` | Repaints the mountain top substrate before snow |
| `terrain_material` | `SM_snow` | Snow-cap material supplied by `snowy.tscn` |
| `top_snow_opacity` | 0.82 | Alpha forced onto the copied snow-cap material |
| `chamfer_exclusions` | `Rect2(-1920,640,640,256)` | Keeps the runaway spur and ledge notch square and open |
| `CREST_WIDTH` | 3px | Lit snow-cap crest stroke |
| `STRIATION_WIDTH` | 1.25px | Rock-face striation stroke |
| `PINE_GROVE_THRESHOLD` | 0.40 | Value-noise cutoff for painted pine clusters |
| `PINE_RADIUS_MIN` / `PINE_RADIUS_MAX` | 26px / 40px | Painted mountain-pine size band |
| `MAX_PINES` | 220 | Uniform cap on painted mountain pines |

### `DropField`

One root wraps 33 authored `PitZone`s with `paint = false` and 34 authored AI
curbs. The main southeast void uses one band per grid row, with the final row
ending at the arena bound; the two chasm pits are the separate two-row bands.

| Export or knob | Mountainside value | What it changes |
|---|---:|---|
| `bounds` | `Rect2(-2048,-2048,4096,4096)` | Declares closed arena sides for straight outward bleed |
| `PitZone.paint` | `false` | Suppresses each pit's standalone paint so `DropField` can draw one continuous skin; leave it true for a pit without a field wrapper |
| `bleed` | 96px | Extends closed-side pit paint beyond the playfield |
| `rim_step` | 56px | Maximum span between organic rim samples |
| `rim_jitter` | 14px inward | Breaks up the lip without painting onto the driveable side |
| `corner_round` | 40px | Rounds convex cliff-union corners |
| `paint_seed` | 4096 | Deterministic rim, cracks, pines, and bottom detail seed |
| `FLOOR_GROVE_THRESHOLD` | 0.45 | Value-noise cutoff for bottom-of-drop pine clusters |
| `DEPTH_BAND_INSETS` | `[100,220,380,580]` px | Successive inset contours on the distant drop floor |
| `DEPTH_BAND_DARKENING` | `[0.05,0.10,0.15,0.20]` | Darkening paired with the four depth contours |
| `GAP_EROSION` | 32px | Insets the union for kill-gap validation |
| `MAX_RIM_INSET` | 20px | Keeps the organic rim inside authored pit collision on the void side |
| `PitZone.KILL_INSET` | 48px full-size reduction | Insets the lethal shape 24px from every painted edge; `Hazards.KILL_INSET` mirrors the per-side value |
| `PitZone.SNOW_CAP_WIDTH` | 12px | Snow lip depth inside the authored pit boundary |
| `PitZone.CLIFF_FACE_WIDTH` | 52px | Visible cliff-face depth between lip and void floor |
| `PitZone.STRIATION_GAP` | 9px | Spacing of the rock-face depth strokes |
| `PitZone.OCCLUSION_OFFSET` | `(0,12)` | Pulls the dark void and occlusion layers south beneath the rim |
| `PitZone.BOTTOM_SNOW_COLOR` | `Color(0.29,0.34,0.43)` | Base color of the distant drop floor |
| `PitZone.BOTTOM_PINE_SPACING` | 28px | Candidate spacing for bottom-of-drop pines |
| `PitZone.BOTTOM_PINE_MIN_RADIUS` / `MAX_RADIUS` | 4px / 6.5px | Painted bottom-pine size band |
| `MAX_PINES` | 280 | Uniform cap on painted bottom pines |

### `TerrainField`

The `SnowCover` root wraps 35 collision-only snow `TerrainZone` rectangles and
produces one warning-free surface silhouette. Grip and radar continue to read
the rectangles, not the paint.

| Export or knob | Mountainside value | What it changes |
|---|---:|---|
| `terrain_material` | `SM_snow` | Material used by the generated union polygon |
| `fill_color` | `Color(0.82,0.85,0.92,0.55)` | Fallback fill when no material is supplied; unused here |
| `corner_radius` | 48px | Pull-in distance for softened union corners |
| `edge_step` | 96px | Approximate spacing between organic edge samples |
| `edge_jitter` | 10px | Perpendicular wobble on open surface edges |
| `bounds` | `Rect2(-2048,-2048,4096,4096)` | Declares closed sides that remain straight |
| `bleed` | 96px | Extends a tile beyond a closed arena side before unioning |
| `paint_seed` | 4096 | Deterministic softened-edge seed |

### `Boulder`

All four Mountainside boulders are permanent Health-free obstacle cover. Their
authored `Col` rectangles remain the collision truth; the script stamps the
floor bit and paints the organic rock.

| Export or knob | Mountainside value | What it changes |
|---|---:|---|
| `size` | `128×128` | Required authored collision rectangle and paint footprint |
| `floor_index` | 2 | Adds the floor-mid collision bit |
| `paint_seed` | `11, 12, 13, 14` | Unique deterministic outlines for Trailhead, SouthGate, Saddle, Overlook |
| `snow` | `true` | Enables the partial snow cap |
| `shadow_offset` | `(12,14)` | Southeast contact-shadow displacement |
| `shadow_alpha` | 0.26 | Contact-shadow opacity |
| `EDGE_STEP` | 40px | Maximum straight-edge subdivision length |
| `SMALL_CORNER_CUT_RANGE` | `16–30` px | Seeded cut range for three corners |
| `LARGE_CORNER_CUT_RANGE` | `40–52` px | Seeded cut range for the fourth corner |
| `EDGE_JITTER` | 7px | Organic edge and corner displacement |
| `PAINT_BLEED` | 6px | Maximum paint extension outside the authored rectangle |
| `CAP_INSET` | 8px | Pulls the snow cap inside the rock rim |
| `TOP_SNOW_OPACITY` | 0.82 | Snow-cap alpha shared with `MountainWall` |

---

## Slide moves (the whip & the side slide)

Source: `vehicles/driving_controller.gd` (whip) + `vehicles/vehicle.gd` (slide impact). Player-only in practice — AI never handbrakes.

| Knob | Value | Notes |
|---|---|---|
| `whip_min_speed` | 240 px/s | whip entry gate; the latch exits at 25% of it (a started whip finishes) |
| `whip_turn_light` / `whip_turn_heavy` | 2.4 / 1.4 | steer-rate multiplier lerped by mass 1-10: sporty ~0.35s to 180, mid ~0.5s, land yacht ~1s |
| dir_sign pin | while handbraking | steer rotates the nose the way you push — no mid-slide counter-steer stall |
| reverse cap | powered reverse only | backward-facing slides keep momentum; S-gear still capped at `reverse_max_speed` |
| `side_slide_bonus` | 1.5 (per-car: Car Tuner SLIDE column) | multiplies the slider's uncharged ram bill (Toe Jam charge stays its own economy) |
| `whip_scale` | 1.0 (per-car: Car Tuner WHIP column) | trims the mass-lerped whip factor per ride; rides StatCurves.apply, exports/folds through the roster pipeline |
| `slide_min_speed` / `SLIDE_LAT_FRAC` / `SLIDE_GRACE` | 250 / 0.8 (~53°) / 0.6s | is_side_sliding: speed floor, slip fraction, brake-recency window (excludes icy AI slip) |
| One-way bill | victim's ram loop skips a slider | dash-style; slider also shielded from third-party rams mid-slide (directional gate = follow-up if LAN abuse shows) |

---

## Driver's Ed (tutorial yard knobs)

Sources: `levels/tutorial/tutorial_director.gd` / `tutorial_card.gd` static vars; yard geography in `levels/tutorial/drivers_ed.tscn` (2816×2816, zero enemies, every solid floor-authored — the ghost-mode lint `tests/test_floor_props.gd` sweeps this and every other floor-tagged level). Outside `CAMPAIGN` — contract-exempt, no interstitial, end screen never auto-advances. Entry: title → SINGLE PLAYER → mode select DRIVER'S ED → sign-up dialog (FIRST TIME DRIVER = lessons, JUST HERE FOR A TEST DRIVE = free roam with the gate already open) → car select, difficulty skipped (`GameState.game_mode` = `tutorial` / `test_drive`; ROAD TRIP = `campaign`). Exit: north tunnel → confirm (KEEP PRACTICING default) → title; pause-menu Quit works any time. **DEVGOD is inert in the lesson lane** (`GameState.is_devgod_enabled()` gates on `game_mode` — god mode blocks the ammo-delta and repair checks); the test-drive lane keeps it.

| Knob | Value | Where | Detail |
|---|---|---|---|
| `INPUT_LOCK` | 1.2 s | tutorial_card.gd | any-key lock on every lesson card (interstitial idiom) |
| `HOLD_MOVE` | 0.25 s | tutorial_director.gd | per-direction W/S/A/D accumulation, lesson 1 |
| `HOLD_CONTROL` | 0.3 s | tutorial_director.gd | brake / handbrake / boost each, lesson 2 (service brake is NOT-handbrake — chords don't count, phases do) |
| `ADVANCE_DELAY` | 1.0 s | tutorial_director.gd | savor beat between nailing a lesson and the next card — hint flips to a green ✓ while the result plays out; applies to the closing card too |
| `DING_HP` | 40 | tutorial_director.gd | lesson-4 fender ding on card dismissal; skipped when hull ≤ ding+15 |
| `JUMP_HEIGHT` | 40 px | tutorial_director.gd | airborne threshold for lesson 5 (jump now leads the ramp) |
| `JUMP_LANE` | Rect2(346, −400, 460, 1300) | tutorial_director.gd | pad + flight corridor; air outside it never counts (deck ledge hops can't cheat) |
| `SMASH_COUNT` | 3 | tutorial_director.gd | yard kills counted from the BOOT baseline (free-play vandalism before the lesson counts), clamped to what stood at boot; ≥1 barrel unless none remain — a taste, not a chore; the rest is extra credit |

Yard fixtures: CENTER helipad (`tutorial_deco` kind `helipad`, 380px worn H-ring — the spawn marker; player boots on it) with a dashed taxiway pointing north to the EXIT chevrons, 4 streetlight pools + 2 manhole steams around it; NW 2×3 terrain grid (256px patches — grass/dirt/mud over snow/ice/water, exactly the lesson-7 set — on 144px asphalt borders; asphalt IS the road sample); NE-corner floor-2 deck (768×768 — boundary closes north+east, south segments flank the ramp, open west ledge, one floor-2 trash prop); jump pad (576, 224) east of center with a dashed run-up; S pickup row (all six ammo kinds + 4-use repair bay — NO drive-over heal/boost, those are chase-exclusive); W firing range (3 derelict wrecks + 2 crates); 2 more wrecks + a SW junk cluster as ambient debris; SE `tutorial_smash` yard (6 crates / 3 barrels / 3 picket fences / 4 clutter = 16 pieces, all `floor_index = 1`). Lesson copy lives in the `LESSONS` const (content, not tunables); the closing card is Kevin's copy verbatim. UI layers: hint 55, lesson card 61, exit confirm 62.

---

## Route 666 Roulette (chase mode knobs)

Sources: `levels/chase/*.gd` static vars, `game/robbery.gd`, `ui/hud_chase.gd`, `ui/speed_lines.gd`. Course distance d = −world_y; north is up. **The gap is the health bar**: every speed below is a fraction of ONE number, `SpeedBand.road_top()` — the car's controller ceiling on asphalt (garage build + road terrain profile in, boost out), read live.

Pack speed = `road_top × (pace + SURGE_PER_PX × max(gap − LEASH_GAP, 0))`. Flat-out resting gap = `LEASH_GAP + (1 − pace) / SURGE_PER_PX` = `210 + 1250 × (1 − pace)`, identical for every car.

| Beat | Start | Pace | Cap | Spawn every | Resting gap |
|---|---|---|---|---|---|
| Green flag | 0s | 0.80 | 2 | 4.0s | 460px |
| First blood | 8s | 0.86 | 4 | 3.5s | 385px |
| Breath | 25s | 0.84 | 3 | 5.0s | 410px |
| Squeeze | 32s | 0.90 | 6 | 3.0s | 335px |
| Breath | 55s | 0.88 | 4 | 4.5s | 360px |
| Frenzy | 62s | 0.96 | 8 | 2.6s | 260px |
| All in | 90s | 1.00 | 8 | 2.2s | 210px |
| Last mile | 110s | 1.02 | 8 | 2.0s | closes 10 px/s: a clean dry run just makes it |

| Knob | Value | Where | Detail |
|---|---|---|---|
| Run length / win | 120s | buzzard_run `RUN_SECONDS` | timed win drives the end screen directly; `suppress_group_win` + `suppress_loss` make the host the sole arbiter |
| Run end | caught OR wrecked | buzzard_run `loss_cause()` | no lives loop, no respawn, no retry; a tie with the clock goes to the pack |
| Jack beat | 1.2s | `JACK_BEAT` | the pack swallows the car (`no_mercy`, keeper off, caught driver's hands off the wheel) before the robbery card |
| Rolling start | cruise (0.80 × top) | `_roll_speed()` | the green flag only — nobody respawns |
| Leash / surge | 210px / +0.0008 of top per px | horde_wall `LEASH_GAP` / `SURGE_PER_PX` | surge time constant `1 / (top × 0.0008)` ≈ 2.0-2.8s |
| Clamp / start | 760 / 600px | `MAX_GAP` / `START_GAP` | a boost pushes the pack off screen for ~2s |
| Catch | gap ≤ 50px | `CATCH_MARGIN` | REPORTED by `caught()`; the wall never touches Health, no backstop |
| Danger zone | gap < 180px | `DANGER_GAP` | rumble, HUD strobe, war horn, daredevil accrual |
| Mercy | < 200px: closing ≤ 45 px/s | `MERCY_GAP` / `MERCY_CLOSE` | over the car's own northward speed — a 3.3s stretch (dead stops no longer exist; it covers a bad smash) |
| Curve tax | pack speed × `road_cos` | horde_wall `road_cos()` | through a sweeper the front covers less north per second, exactly like the car |
| Lane wheel | ±24° off NORTH | chase_player_driver `LANE_YAW_DEG` / `LANE_GAIN` 4 | L/R = a lane change; hands-off returns to north — **sweepers are the driver's to steer** (no rails: the cone out-turns every bend chunk as a whole, and the steepest leg gets <90px away at full lock, test-locked); handbrake eaten; player keeps the 2s bay lock |
| Smash and pass | prop dies on contact; momentum × heft clamp; bite 0.12 × prop HP | Vehicle `smash_and_pass` / `smash_bite`, chase_player.tscn + buzzard.tscn | nothing on the road stops a car; pillars are 60 HP `pillar` destructibles; a ram that WRECKS a car keeps `punch_keep_max` of the entry momentum too |
| The bumper | ram scale 0.12 from 80 px/s (arena: 0.06 from 220) | chase_player.tscn `ram_damage_scale` / `ram_min_speed` | the chase car's ram is a weapon: a bird that boxes you in can be shot OR driven through |
| Forward-only Leap | cone 24° (= the lane wheel) | chase_player.tscn `SpecialController.dash_cone_deg` | Cricket rams a Buzzard inside the cone, surges straight up the road when it's empty (~300px of gap, obstacles pass under a leap), drops a target that slips past her nose; arenas 0 = nearest any bearing |
| Forward missile lock | cone 70° of the launch direction | chase_player.tscn `SecondaryMount.lock_cone_deg` | tracking shots lock what you're pointing at (rear missiles look behind) — the classic lock took the bird on your tail, which a missile can't home on, and went dumb; arenas 0 |
| Pedal band | cruise 0.80 / floor 0.55 | speed_band `CRUISE_FRAC` / `FLOOR_FRAC` | W flat out; hands-off settles at cruise; S brakes to the floor and HOLDS; never reverse; live boost ungoverned |
| Pace keeper | floor 0.45 at 1400 px/s² | pace_keeper `KEEP_FRAC` / `KEEP_PUSH` | level-side northward floor after crashes and whips; skips airborne / dashing / dead |
| Pin escape | 0.15s → lean 1800 px/s², max 260 px/s | `PIN_TIME` / `NUDGE_PUSH` / `NUDGE_MAX` | toward the free side; hands-off dead-centre hit on a 200px obstacle clears in ~1.7s |
| Spawns | emerge 90px inside the crest / ahead −1600 (tech, blocker) | chase_director `EMERGE_DEPTH` / `SPAWN_AHEAD` | pace-matched entry |
| The picture | 11 riders, 150 + 80 dust particles | horde_deco `RIDERS` / `LOW_DUST` / `HIGH_DUST` | real Buzzard paint bodies lead the dust; billows are ragged lumps; flashes and tracers scale with pressure |
| Absorb | 180px inside the crest | `ABSORB_DEPTH` | freed quietly: no wreck, no bounty, no nitro |
| Nitro on kill | +4 fuel | `KILL_NITRO` | of 100 (5/s burn) — ~0.8s of boost per wreck; a good run wrecks ~10 glass birds |
| Purse | 3000 bolts | buzzard_run `PURSE` | `Economy.award_flat`, paid at the line only |
| Daredevil | 100/s in danger, cap 2000 | `DAREDEVIL_RATE` / `DAREDEVIL_CAP` | dies with the run if caught |
| Difficulty | pace ×0.92 / ×0.96 / ×1.0 | difficulty `chase_pace` | EASY / MEDIUM / HARD |
| Camera | lead −140, zoom pinned 0.55 | chase_player.tscn / Vehicle `camera_zoom_lock` | overview toggle still works; smoothing lag costs ~0.2 × speed px of look-ahead |
| Course pre-roll | 130k px, seeded | chase_course `TARGET_LEN` | pickup lane ≤ every ~9k (`PICKUP_EVERY`), landmarks ≥ 15k apart (`RARE_SPACING`), meander ±800 (`SPINE_BOUND`) |
| Road | half_w 360 (narrow 260) + 90px verge | chunk_defs / chunk_builder | verge = grass/dirt grip penalty; embankment wall past it |
| Obstacles | rails 20 HP · logs 15 · junk 20 · barriers 25 · pumps 40 · pillars 60 | chunk defs/builder | smash and pass: a derelict costs a quarter of your momentum, a log a tenth |
| Road hazards | OIL SLICK r44 = ice zone · POTHOLE r38 = dirt zone | chunk_builder `_slick` / `_pothole`; the `bad_road` chunk mixes 2 + 3 | never HP, airtime clears both. Oil: TRUE black, smooth curvy edge, one bright glint — the car keeps going where it was going. Pothole: jagged dark grey, pale cracked lip, rubble — a bump that bleeds speed |
| Washouts | dirt edge to edge over d 160-1240 of a 1400 chunk, one 190px paved ribbon ±130 across | chunk_defs `washout_l`/`washout_r` (`washout` block), `ChunkDefs.washout_lane`, builder `_build_washout` | hold the ribbon = your pace; miss it = dirt (×0.85 top) while the pack isn't — off-road tires earn their bolts here; the crossover (260px over 540) is test-locked holdable at full lock; the pair mirror and chain; weight 0.7 each, `NO_REPEAT` |
| Off the tour | no wheel | buzzard_run `_open_robbery` | SINGLE BATTLE / direct launch: caught or wrecked goes straight to the classic loss panel (nothing to take, nowhere to roll on to) |
| Pickups | heal +25 · nitro +35 · M/P crates | heal/boost_pickup + ammo | player-only, one-shot, no respawn |
| Speed streaks | fade in 0.90 → full 1.35 of top | speed_lines `THRESHOLD_FRAC` / `FULL_FRAC` | nothing at cruise, a whisper flat out, full on the boost |
| GPS window | −800..+3500 px of course | chase_gps `BACK`/`AHEAD` | blips ≤1500; technicals = amber diamond; horde drawn at its true position, pulses in danger |
| Audio | roar gain 0.22 → 1.0 · horn ≥6s apart | horde_wall `ROAR_FLOOR` / `HORN_COOLDOWN` | `horde_roar` loop via `AudioDirector.loop_gain`; `jacked` sting on the robbery card |

### Dusk to night, and the roadside

Source: `buzzard_run.gd` (`SKY_KEYS`, `sky_at`, `_light_the_cars`), `horde_deco.gd` (`RIDER_BEAM_*`), `chunk_builder.gd` (`_road_wear`, `_highway_dressing`, `_tollbooth`, `_jackknife`), `levels/chase/highway_deco.gd`.

| Knob | Value | Where | Detail |
|---|---|---|---|
| The sky | golden (1.0, 0.93, 0.82) → sunset @0.35 (0.92, 0.72, 0.6) → dusk @0.65 (0.66, 0.58, 0.72) → night @0.85 (0.48, 0.52, 0.74) | `SKY_KEYS` | a CanvasModulate in `night_arena` driven from the clock; night is the Coliseum's brightness so obstacles still read; the finale is dark |
| Headlights | length 460 · spread 56° · energy 0.7 · viewer (0.85, 0.9, 1.0) · others (1.0, 0.9, 0.7) | `BEAM_*` | GFG's lazy group-scan attach on every `vehicles` node (meta `chase_beam`) |
| Rider beams | length 260 · energy 0.45 | horde_deco `RIDER_BEAM_*` | every painted rider in the dust burns one; reads once the sky goes |
| Lit landmarks | truckstop neon + 2 lamp pools · toll plaza 2 pools · burning wrecks glow 110px | chunk_builder | `LightKit.make_light` |
| Highway signs | one per `SIGN_EVERY` 1400px, sides alternate, nudged ≥120px off seams · board 210×70, type 24/19 · green/white | `_highway_dressing`, `HIGHWAY_COPY` (kind `highway_sign`; `sign` still accepted) | DIRECTIONAL/INFORMATIONAL copy only — town names and distances carry the humour (MERCY 40, HOPE 3 (CLOSED), GRIEF NEXT EXIT); never on a cutoff's trail side or a river; the toll plaza's is always `TOLL_COPY` |
| Speed signs | one per `SPEED_SIGN_EVERY` 2500px, sides alternate (even → left), same skips · board 90×110, number 44 over MPH 20 · white/black | highway_deco `SPEED_LIMITS` (kind `speed_sign`) | plausible limits 55/65/45/35/80/15 — never jokes |
| Mile markers | EXACT: d = n × `MILE_PX` 1600, number `MILE_START` 95 + n, RIGHT verge only · board 72×64, MILE 18 over the number 30 · green/white | highway_deco `mile_at(d)` / `d_of_mile(m)` (kind `mile_marker`) | the odometer ("the clutter at mile 98"); nudged ≤120 off a seam with the number dealt from the unnudged n; skipped on a right-hand cutoff's trail mouths and the river; the dev HUD readout and the probe's `[hit]`/`[finale]` lines print the mile |
| Billboards | one per `BILLBOARD_EVERY` 4300px · board 340×130, type 34/28/15 · on the verge | `BILLBOARD_COPY`, `BOARD_TINTS` | the ADS — snark lives here and nowhere else; the truckstop's is always MERCY DINER (`DINER_SEED`) |
| Life | vultures over convoy / log_run / jackknife (and 40% of ≥3-prop chunks) · a wreck in three burns · a tumbleweed on 30% of plain straights at 42 px/s | `_highway_dressing`, `_place_props` | paint and FX only — nothing collides |
| Road wear | 3-5 marks per chunk (+3 on busy kinds): skids, tar patches, cracks, stains, splats | `_road_wear` | z −1 over the marks |
| Surfaces | the arenas' paint: `Catalog.TERRAIN_COLORS` + `LevelLoader._speckle_material` on every zone Vis and opaque bed · asphalt = the scenes' SM_asphalt (0.11/0.11/0.13, speckle 0.06, d 0.4, i 0.35, s 6) + the 128px survey grid clipped to the road · concrete (0.36/0.37/0.40) = pavement | `levels/chase/surface_paint.gd` (`dress`, `asphalt_material`, `concrete_material`, `RoadGrid`) | a surface looks here as it does in an arena; toll plaza + truckstop forecourt are road-handling zones at priority 1 over the verge; the cutoff clearing is a real grass zone, its ditch (mud) priority 1; washout/trail beds are the arena dirt with torn edges (their zones' Vis bare); slick = black pool with the arena ice as a thin rim (`SLICK_RIM` 1.16), pothole = a disc of arena dirt under the lip; embankment `SLOPE_FILL` is not a surface and keeps its own tone |
| Toll plaza | 4 `booth` blocks 44×90 / 60 HP · 3 `barrier` arms / 25 HP · weight 0.7 · `NO_REPEAT` | `tollbooth` def, `_tollbooth` | pick a gate |
| Jackknife | `trailer` block 230×72 / 90 HP angled 0.5-0.75 rad across two lanes · cab derelict · weight 0.7 · `NO_REPEAT` | `jackknife` def, `_jackknife` | the open lane is the line; a nitro bottle past it |

### They flinch (ordnance in the dust)

Source: `horde_wall.flinch` / `pace_mult`, `horde_deco.flinch`, `buzzard_run._physics_process` (the fuse), `mine.blow()`.

| Knob | Value | Where | Detail |
|---|---|---|---|
| The fuse | `FLINCH_INSET` 40px inside the crest | buzzard_run | every tick, any live mine you dropped or non-MG missile you fired past the line goes off there (explosion FX, gone); the pack's own mines, your MG rounds and anything still in front of the crest are left alone; a mine dropped early pops when the crest rolls over it |
| The cut | `FLINCH_CUT` 0.25 (mine) · `MISSILE_CUT` 0.18 · `FLINCH_SECONDS` 1.5 | horde_wall | pace × (1 − cut) while it lasts: ~0.25 × 465 × 1.5 ≈ 175px of gap at a 484 top; a second bang refreshes the clock and keeps the bigger cut, never compounds; `pace_mult` also folds in `LOST_SIGHT_CUT` 0.3 (cutoffs) and the two stack |
| The recoil | `FLINCH_RECOIL` 40px · `FLINCH_RECOIL_T` 0.6s | horde_deco | the riders are shoved south and ease back, headlights stutter, a one-shot puff of dust off the crest; the roar halves while flinching |
| Probe | `--mines` | chase_run | a mine off the tail every `MINE_EVERY` 15s; every `[run]` line reports `flinches` — with eight of them a run's danger time roughly halves |

### The back roads (cutoffs)

Source: `chunk_defs.gd` `cutoff_l`/`cutoff_r` (`cutoff` block, `cutoff_x`), `chunk_builder._build_cutoff` / `_build_embankment` runs, `buzzard_run.on_trail`, `horde_wall.lost_sight`, `chase_gps`, `chase_autopilot`.

| Knob | Value | Where | Detail |
|---|---|---|---|
| The chunk | len 2000 · road `path` bulges ±200 over d 300–1700 · weight 0.6 each · `NO_REPEAT` | chunk_defs | rolled like any chunk (2-3 per run), never a landmark; the pair mirror |
| The trail | stations [100, ∓200] → [860, ∓520] → [1180, ∓520] → [1760, ∓300] · width 150 | `cutoff.trail` (offsets from the chunk ENTRY x) | every leg ≤ tan 24° (test-locked); the first station is in the near lane — line up before the mouth (cones at d 240, TRAIL on the GPS) |
| The mouths | gaps [300, 780] and [1280, 1700] on the trail side · `FUNNEL_LEN` 260 | `cutoff.gaps`, builder | the embankment is built in runs with the gaps open; each resuming run's end is chamfered — a late car is deflected back onto the road; the trail is inside the wall line at each mouth's road end and clear of the embankment at its wild end (test-locked) |
| The fence | `trees_x` ∓690 ± 25 jitter · r 26 every ~85px · mud `Ditch` between trail and foot | builder | one layer-2 body, a circle per pine, too close to thread; the clearing paints under the walls |
| Lost sight | `LOST_SIGHT_CUT` 0.3 · roar × 0.35 · headlights sweep ±30 | horde_wall, horde_deco | `on_trail()` = the chunk has a cutoff, the car inside the trail's reach and out past the shoulder on its side; the birds' road clamp never follows |
| What it buys | dirt ×0.85 top vs pack ×0.7 pace | — | the gap opens ~150-170px over the trail, then the leash re-tightens: what a cutoff really buys is a beat out of the danger zone |
| Bot | `take_trails` 0.5 · `TRAIL_LEAD` 700 | chase_autopilot, `--trail=F` | lines up from the chunk before with the whole cone; `trails` in every `[run]` line |

### The bridge is out (the clock-out finale)

Source: `levels/chase/finale_director.gd`, `finale_driver.gd`, `finale_bird_driver.gd`, `horde_wall.halt_at`, `chunk_defs.gd` `bridge_out`, `chunk_builder._bridge_out`. Toggle: `buzzard_run.finale_enabled` (tests about "the line pays" turn it off for the instant win).

| Knob | Value | Where | Detail |
|---|---|---|---|
| The cut | `FINALE_LEAD` 900px | finale_director | the river mile splices in at the first chunk boundary at least this far ahead — past the top of the frame (140 + 360/0.55 ≈ 795), so it rolls into view ~1.5s later; `CourseStreamer.invalidate_from` BEFORE `ChaseCourse.splice` |
| The river | bank 600 · brink 1000 · deep to 1650 · shallows to 1750 · lip 878 | `bridge_out` `river` block (chunk-local d) | kill rect = channel − 24 each end (1024–1626); `river_y(entry, key)` puts any of them in the world; three `straight` chunks of run-out follow |
| The arc | `LAUNCH_SPEED` 700 · `FINALE_VZ` 860 | finale_driver | 2·860/1300 = 1.323s of air × 700 = 926px from the brink ⇒ lands at d ≈ 1926, 300px past the kill rect and past the shallows, whatever the car (forced velocity, no drag — test-locked) |
| The fools | `BIKE_JUMP_SPEED` 480 · stock `jump_launch` 760 · `JUMPERS` 2 · `TRAIL_DY` 260 | finale_bird_driver, finale_director | 1.169s × 480 = 561px off the lip ⇒ into the channel with ~280px to spare either side; two bikes are always cast (spawned if fewer live); brakers stop `STOP_AHEAD` 40 short of the bank on their shoulder |
| The halt | `HALT_BRAKE` 320 · `HALT_CREEP` 40 · `HALT_ROAR_FADE` 1.5s | horde_wall | speed ramps to zero over the last 320px, creeps the last inches, snaps onto the bank, never crosses it; the MAX_GAP drag is off; three `brake` crunches; `horde_deco.halted` damps the riders over 0.5s and lays their skids once |
| The camera | `FINALE_CAM_D` 1250 · `FINALE_CAM_ZOOM` 0.45 · `FINALE_CAM_TIME` 0.6s | finale_director | a scene Camera2D takes over at the pop (no tree pause): the bank at the bottom edge, the river low, the landing in frame; slide `FINALE_CAM_D` down to see more riders, up to see more road |
| The card | `FINALE_BEAT` 1.5s · `FINALE_MAX` 10s | finale_director | the classic paused fork with the purse note, a beat after the second splash — or ten seconds after the pop regardless |
| Free deaths | `chase_director.kill_hooks` | chase_director | `finale_mode()` freezes spawns/absorbs and the died hook reads the gate when it FIRES: a bird going into the river rings no bell, pays no bounty, siphons no nitro, tumbles no wreck |

The whole show runs ~7-9s of game time; the probe prints `[finale] air / landed d / jumpers gone / show` on every won run, and `tests/test_chase_finale.gd` boots it compressed.

### The robbery wheel

Source: `game/robbery.gd` (`WHEEL`, `REDEAL_ORDER`, `REDEAL_BITE`). Ten wedges, uniform spin, landing rolled and billed before the card opens.

| Wedge | Count | Takes | Unpayable when | Re-deals into |
|---|---|---|---|---|
| BOLTS 25% | 2 | a quarter of the wallet (× `penalty_scale`) | wallet is 0 | PARTS → BAY → DIGNITY |
| BOLTS 50% | 2 | half the wallet | wallet is 0 | same |
| EVERYTHING | 1 | the whole wallet | wallet is 0 | same |
| PARTS | 3 | one random garage part nothing else you own `requires` | no removable part | BOLTS 25% → BAY → DIGNITY |
| THE BAY | 1 | every rack counter (carry ammo = seven zeros) | nothing in the bay beyond the special's first round | BOLTS 25% → PARTS → DIGNITY |
| BLOOD | 1 | one campaign life | on the last life | BOLTS 25% → PARTS → BAY → DIGNITY |
| DIGNITY | re-deal only | nothing | — | — |

BLOOD is never a re-deal target, so the wheel holds at most one. DEVGOD makes every wedge inert (the flow still plays). Splash art ladder: `assets/img/jacked/<car_id>.png` → `_generic.png` → bruised bio portrait → beat skipped.

---

## Goliath (Goliath's Arena boss knobs)

Sources: `vehicles/goliath/*.gd` static vars, `data/vehicles/goliath.tres` / `goliath_ph2.tres`, `data/weapons/goliath_turret.tres` (F2-editable), boss instance exports in `levels/stadium/stadium.tscn`.

### The rig

| Knob | Value | Where | Detail |
|---|---|---|---|
| Stats ph1 / ph2 | acc 3/5 · top 4/6 · hand 2/4 · mass 10/8 | goliath.tres / goliath_ph2.tres | ph2 deck applied via StatCurves ONLY (never set_stats) |
| Body scale / weakspots | 1.6 · rear 1.75× · mine 6.0× | Enemy1 exports | mine_weakness = the soft underbelly, both phases |
| Immunities | launch_immune, no_mines | Enemy1 / goliath.tres | pads roll under, jump mines crush, land mines can't spin (damage ×6 still bites) |
| Tow geometry | bar 180 · body 210×64 · hitch 52 · kingpin→center 96 | goliath_trailer | assumes body_scale 1.6; MAX_ARTIC 75° fold clamp |
| Trailer forwarding | ×0.45 body · ×2 nose quarter (NOSE_FRAC 0.25) | TRAILER_DMG_FRAC / WEAK_MULT | never-dying proxies → cab pool; plates part_of-stamped |
| Battery | 2 turrets · 30 dmg · 2.6s · 1300 px/s | goliath_turret.tres | fire FOR the cab (shooter_path); own plating LoS-excluded |

### Phase 1 (trailered)

| Knob | Value | Where | Detail |
|---|---|---|---|
| Pool | 1000 | goliath_boss PHASE1_HP | depletion gate can NEVER fire died (sentinel refill) |
| Loop | 12 marks · arrive 260 · gain 2.2 · throttle 0.85 | goliath_driver LOOP_* | GoliathLoop markers; nearest-mark rejoin |
| Approach / re-engage | 520 px / 2.5s | APPROACH_TRIGGER / REENGAGE_COOLDOWN | front arc 45° → RAM 1.4s (boost + MG cone 0.35) |
| Jackknife | window 1.1s · sway 0.35/0.75 splits · steer 1.0 · throttle 0.9 | JACKKNIFE_* | 3-beat whip-crack; gated: 6s cooldown + ≥320 real px/s |
| Tail strike | 26 dmg · 900 fling · 140° spin · 0.5s stun · 1.2s cd | goliath_trailer JACKKNIFE_* / SWING_* | arms past 2.6 rad/s swing; skids past 1.2 rad/s (the telegraph) |
| Unstick | trip 40 px/s × 1.2s · reverse 1.6s | STUCK_* / RECOVER_REVERSE_TIME | real-velocity sense; stun-exempt |

### Transition cutscene

| Knob | Value | Where |
|---|---|---|
| Camera on him | zoom 0.55 over 0.7s | goliath_cutscene CAM_* |
| Trailer cook-off | 6 booms × 0.4s gap | EXPLOSION_* |
| Stack rev | 2.2s, 2 smoke pulses | REV_TIME / REV_PULSES |
| Ride home | 1.2s track-back through zoom 0.42 | HANDBACK_* |

### Phase 2 (bobtail)

| Knob | Value | Where | Detail |
|---|---|---|---|
| Pool | 900 | PHASE2_HP | fresh bar; kill = win |
| Charge gates | windup 0.7s · align 0.18 rad · ≤850 px | CHARGE_WINDUP/ALIGN/MAX_DIST | commit ≤850 so the tell is on screen |
| Charge | 1300 px/s · 0.9s · dead straight | CHARGE_SPEED/TIME | is_forcing() bypasses the controller; obstacle mask ON |
| The tell | stack belch + ram_warn sfx | _ram_cue | ram_warn = registered AudioDirector event awaiting an asset |
| Connect | ram bill + 1000 fling · 140° spin · 0.7s stun | CHARGE_HIT_* | then RETREAT lap 2.5s at full throttle |
| The bait | 120 self-dmg + 2.0s stun | CHARGE_SELF_DMG / CHARGE_STUN | scenery hit; stuck-detector-exempt sitting duck |
| Pacing | 45s per attempt | RAM_COOLDOWN | track by default; crowding draws MG (throttle 0.8), never steel |
| Arc cap | steer ≤0.6 | BOBTAIL_STEER_CAP | all ph2 steering — no j-turns |

### Bling pass (Batch F knobs)

| Knob | Value | Where | Detail |
|---|---|---|---|
| Grade bias | 170 px/s² | Ramp.downhill_pull (stadium slopes) | environment-side; up bleeds, down builds |
| Tier bumps | shake 2.2 + uphill speed ×0.9 per 44px row | Ramp.stairs / STAIR_SHAKE / STAIR_SPEED_NICK | shake player-only; the nick hits every climber |
| Chamfers | solid 384-leg right triangles, layer 28 | ChamferNE/NW/SE/SW | one continuous caution pattern; deflect floor-1, wall floor-2; paint = collision |
| Fan rails | 10 segs, 12 HP, blue | fan_rail deco flavor | gaps at slope centers + mouths |
| Jumbotron | marquee 110 px/s, poll 1 Hz, z 1 overhead + under-fade 0.45 | stadium_deco | GOLIATH / RAMPAGE / NEW KING; per-char clip |
| Floodlight HP | 30 | stadium_deco FLOOD_HP | ~1s MG burst or one fast ram; sparks + the corner goes DARK |
| Night tint | (0.5, 0.56, 0.82) | stadium.gd NIGHT_TINT | CanvasModulate dusk; HUD/menus (CanvasLayers) unaffected |
| Lights | flood r520 e0.9 · jumbo r300 e0.55 · player r340 e0.55 · boom e1.6 · shell e1.1 | stadium_deco/_make_light + explosion.gd | PointLight2D, night_arena group gates the explosion bloom |
| Rolling win layout | title top-center, hint bottom-center after 1.2s | end_screen _show_rolling_win | any key -> prize stub (classic panel) |
| Fireworks | every 0.9s, 30% double | stadium.gd FIREWORK_* | win-card backdrop, 5 shell colors |
| Victory lap | throttle 0.8, arrive 260 | victory_lap_driver LAP_* | god-moded; end_screen.win_keeps_rolling |
| Quit confirm | ESC on title | ui/title.gd | "Awww, giving up so soon?" — NO default |
| Single-player entry | SINGLE PLAYER | ui/title.gd | mode select → difficulty → garage (Road Trip) or → fight card → garage (Single Battle) |
| Single Battle | mode select row 3 | ui/mode_select.gd + ui/level_select.gd | stamps `game_mode &"single_battle"` + MEDIUM tier; fight card lists melee arenas selectable, placeholder slots greyed, boss/chase off-card; pick stamps `GameState.battle_level_index` (run state); end screen shows the classic panel, Restart re-runs the slot with fresh lives |
| Developer Options | modal under Settings | ui/settings.gd + game_state.gd | Arrow-only: Up/Down select, Left/Right change, Right enters submenu/actions, ESC backs out; WASD/Enter/Space/controller ignored; changes autosave; Developer Mode master-gates the preserved DEVGOD choice (START LEVEL retired — jump to a level via SINGLE BATTLE) |

## Netplay (LAN multiplayer knobs)

Source: `game/net/*.gd` statics + `game/net/match_config.gd` bounds. Host-authoritative
listen server: 4 seats + 8 observers (12 ENet peers). Wire changes bump `PROTOCOL_VERSION`.

| Knob | Value | Where | Notes |
|---|---|---|---|
| PROTOCOL_VERSION | 10 | net_protocol.gd (const) | handshake + snapshot header gate; 7 ammo slots, brake + repair flags, flags2 disarm/flame/tornado/armed/freeze bits, arena-state rows, tinted shot events |
| default_game_port | 42998 | net_protocol.gd | host-screen overridable |
| discovery_port | 42999 | net_protocol.gd | UDP beacon/browse; one browser per box |
| snapshot_hz | 30 | net_protocol.gd | host→all state rate (~26 B/car/row) + projectile/hit/impact events |
| input_hz | 60 | net_protocol.gd | client intent frames (7 B each) |
| interp_delay_ms | 50 | net_protocol.gd | puppet render-behind; raise 75-100 on jittery wifi |
| ENET_CHANNELS | 8 | net_protocol.gd (const) | connection-time; sized past CH_CONTROL/STATE/INPUT |
| auth nonce / SALT | 16 B / "bentchrome-v1" | net_auth.gd | proof = SHA256(nonce + SHA256(SALT+pw)); NAME_MAX 24 |
| BEACON_INTERVAL / ENTRY_TTL | 1.0s / 3.0s | net_discovery.gd | browser card refresh/expiry |
| RESPAWN_DELAY / SHIELD_TIME | 1.6s / 2.0s | match_director.gd | MP respawn loop (farthest derived spawn) |
| ATTRIBUTION_MS | 10000 | match_director.gd | kill-credit window (pit-shoves count) |
| STATUS_SYNC_S | 1.0 | match_director.gd | scores/clock heartbeat to clients |
| frag_target | 1-50 (default 10) | match_config.gd | FRAG format |
| time_limit | 180-600s (default 300) | match_config.gd | TIMED format; ties = joint winners |
| lives | 1-9 (default 3) | match_config.gd | LIVES format; eliminated → spectator rig |
| brawl_frag_cap / brawl_time_cap | 0=off / 0 or 180-1200s | match_config.gd | BRAWL optional caps; capless = host END MATCH |
| observers / gotnext | true / true | match_config.gd | SEATS ONLY caps admits at 4; queue = every-death rotation |
| PAN_SPEED / PAN_BOOST | 900 / 2.0 | spectator_rig.gd | free-roam camera |
| FEED_LINES / FEED_TTL | 4 / 4.0s | mp_match.gd | kill-feed overlay |
| NET_INTERP_MS | 50 (synced) | vehicle.gd static | shell syncs from interp_delay_ms at match start |
| MP_MAPS cars | 5/7/7/7/8/8 | scene_flow.gd | melee backfill totals per arena, including Ground Floor Gore |
| fx plane (reliable) | — | net_events.gd fx queue + Net.rpc_fx | beams/pulse rings/mines; drops must never vanish |
| mine twin | cosmetic flag | environment/mine.gd | client mirror: draws + arm-blinks, never scans/bills |
| callsign roulette | assets/data/callsigns.txt → user://callsigns.txt | ui/callsigns.gd | one name/line, '#' comments; user copy wins |
| MP screen memory | mp_join_ip/port, mp_host_port/garage/strict | game_state.gd SETTINGS_KEYS | passwords never persist |
| ALERT_HOLD_S | 12.0 | ui/mp_menu.gd (static) | join-failure hold; scanner can't stomp it |
| THE DEAL | MatchConfig.describe() | match_config.gd | plain-language ruleset, 3 sentences, unit-tested |
| garage_name | lobby sync key | net_session.gd | marquee mirrored to every peer (header + counts strip) |
| Arena-state row | 7 bytes, repeated | net_snapshot.gd | u16 ID, u8 flags, u8 HP, u16 timer ms, u8 actor mask; protocol 8 |

Policies (locked): ONE of each car on the battlefield (claimed set = seats + queue; AI pool
excludes it — short pool = fewer bots); every queue exit = back of the line; unattributed
deaths feed THE WASTELAND (own scoreboard row); disconnects vacate creditless; v1 joins
land in the lobby only. E2E: `tools/nettest.sh` (loopback host+client, cable-pull vacate).

## SFX (sound events & thresholds)

Assets are procedural: `tools/synth_sfx.py` regenerates every `assets/sfx/*.ogg`
(naming contract in `assets/sfx/README.md`, reference-link form in
`assets/sfx/refs.md`). Dev-options SOUNDBOARD auditions any event from Settings.

| Knob | Value | Where | What it does |
|---|---|---|---|
| CRASH_HARD_SPEED | 420 px/s | vehicle.gd | impact-into-surface speed splitting crash_soft/crash_hard (audio gate stays bounce_min_speed×2 = 200) |
| SPLASH_MIN_SPEED | 200 px/s | vehicle.gd | min speed entering water terrain to cue a splash |
| BRAKE_MIN_SPEED | 233 px/s (~35 mph) | drive_fx.gd | service-brake grind loop floor; phases with brake lights, never handbrake |
| POOL_GLOBAL / POOL_POSITIONAL / POOL_UI | 8 / 6 / 3 | audio_director.gd | one-shot player pools; UI pool is PROCESS_MODE_ALWAYS (pause-immune — stingers + menu clicks) |
| UI_EVENTS | ui_*/stings/mp_*/shop_* | audio_director.gd | events routed through the pause-immune pool; a UI_EVENTS loop (shop_hum) gets a pause-immune looper |
| volume_db / pitch_jitter | per event | audio_director.gd CATALOG | per-asset trim + repeat-variation; tune here, not in the asset |
| overheat cue | once per lock | weapon_mount.gd | player-only, fires when heat crosses heat_max |
| pickup cue | player-only | ammo_pickup.gd / heal_pickup.gd | AI crate grabs stay silent |
| mp_join/mp_leave | lobby only | mp_lobby.gd | peer-count diff on peers_changed (name syncs don't cue) |
| pit/water death sound | pit_fall / sink replace the death boom | vehicle.gd _on_died | `_falling` gates the generic explosion sound like it already gated the visual |
| sp_<special> events | 13 (9 assets live) | special_controller.gd special_sfx_event | per-car special voices: sp_ + def basename; taser/blaze loop with the effect, toe_jam voices the LANDED hit, red_glare repeats per rocket; PROJECTILE fallback = missile_fire via WeaponMount.sfx_override |
| brake cue | one-shot on hard-brake start | drive_fx.gd _was_braking_hard | was a loop; Kevin redesigned to a single quick bite (2026-07-14) |
| boost voice | roar edge + whoosh loop | drive_fx.gd _was_boosting | boost one-shot at ignition, boost_loop rides ctrl.boosting |
| splat/crunch | coinflip on living soft targets | ambient_actor.gd _die | leaves_splat gates the coinflip; props always crunch; positional |
| env_* alerts | 4 (genny wired) | power_generator.gd _present_death (host+client paths) | once-per-level global stage alerts; siren/panic/chopper await stage events |
| announcer_<car>_wins/_loses | 28 baked lines | end_screen._announce (win = rolling/finale-only; lose = any wipe) | espeak-ng dev-bake + PA chain in synth_sfx.py; loses pitched lower; pause-immune pool (lose screen freezes the tree); no runtime TTS; 0.8s after the sting |

## BGM (background music knobs)

Assets are procedural: `./venv312/bin/python tools/synth_bgm.py` regenerates
`assets/bgm/*.ogg` (naming contract in `assets/bgm/README.md`, reference form
in `assets/bgm/refs.md`; engine in `tools/bgm/`). `game/music_director.gd`
(autoload) picks the track by scene, crossfades, and ducks; the dev-options
SOUNDBOARD lists `bgm_*` rows with PLAY/STOP toggles.

| Knob | Value | Where | What it does |
|---|---|---|---|
| TRACKS | scene path -> bgm_* | music_director.gd | which track a scene plays; UPCOMING = interstitial plays the next level's track; RESOLVE_CHILD = mp_match keys off its instanced arena; SILENT = no track (the boot sequence carries its own sting); unknown scenes = bgm_menu |
| CROSSFADE / PHASE_CROSSFADE | 1.6s / 0.9s | music_director.gd | scene-to-scene fade / in-level override fade (Goliath p1->p2 gear change) |
| DUCK_DB / DUCK_RATE_DB | -10 dB / 40 dB/s | music_director.gd | music dim while tree-paused or a named duck holds (end_screen rolling win) |
| same-event no-op | structural | music_director.gd _request | interstitial->level, pause-Restart, and respawn continuity |
| loop stamp | code, not .import | music_director.gd _looped | every resolved stream loops; assets bake the seam (wrap-crossfaded tail bar) |
| SEED / BPM / BARS | per track | tools/bgm/tracks/*.py | deterministic composition constants (arena: 0xD3B1 / 122 / 72) |
| TARGET_RMS_DB / PEAK_DB | -18 / -1 | tools/bgm/master.py | one loudness convention across all tracks — no per-track trim in-game |
| audio buses | Master / Music / SFX | default_bus_layout.tres (default path, no project setting needed) | MusicDirector players ride Music, all AudioDirector pools ride SFX; bus-less contexts fall back to Master |
| MASTER/MUSIC/SFX VOLUME | 0-100% in 5% steps | ui/settings.gd + GameState.volume_* | persisted sliders; GameState.apply_audio_settings() pushes linear_to_db onto the buses at boot/adjust/reset; 0% mutes the bus |

## Boot sequence (startup card knobs)

Sources: `ui/boot_splash.gd` static vars (the `run/main_scene`); sting recipe in
`tools/synth_boot.py`; drop-in contract, art briefs, and the cue table in
`assets/boot/README.md`. Copy and card order are test-locked
(`tests/test_boot_splash.gd`). Only a launch plays the cards.

| Knob | Value | Where | What it does |
|---|---|---|---|
| `TIMING` | card 1: 1.2 / 4.8 / 0.8 s; card 2: 0.5 / 5.4 / 1.2 s | boot_splash.gd | fade-in / hold / fade-out per card; cut to the sting's cue points |
| `LEAD_IN` / `GAP` | 0.3 s / 0.3 s | boot_splash.gd | black before the first card / between the cards |
| total run | 14.5 s | boot_splash.gd `total_duration()` | unskipped length; test band 10-18 s |
| `INPUT_LOCK` | 0.5 s | boot_splash.gd | any-key skip stays dead this long after launch |
| `SKIP_FADE` | 0.3 s | boot_splash.gd | curtain + sting fade on a skip |
| `STING_DB` | 0 dB | boot_splash.gd | sting trim on top of the SFX bus slider |
| `ART_FILTER` | linear | boot_splash.gd | card upscale filter; nearest = crunchy pixels |
| card size | 640x360 | assets/boot/README.md (magick recipe) | the softness knob — ship larger art for a crisper card |
| BOOT INTRO | ON | ui/settings.gd (Graphics) + GameState.boot_intro | persisted; OFF hands the launch straight to the title |
| `DUR` / `SWELL_TOP` / `ARRIVE` / `CHIMES` / `LAST_CHIME` / `FADE_FROM` | 14.5 / 6.4 / 7.4 / 7.6 / 11.9 / 13.2 s | tools/synth_boot.py | sting cue points — mirror `TIMING`, move them together |
| `BEND` | -1.6 semitones | tools/synth_boot.py | how far the last chime sags (the knockoff tell); 0 or `--no-bend` plays it straight |
| `PEAK_DB` | -1 dBFS | tools/synth_boot.py | sting peak ceiling |
| `stroke` / `slot` | 82 / 28 px | tools/boot_emblem.py | FanStation S: ribbon width / gap between strokes (before `scale`) |
| `half` | 100 px | tools/boot_emblem.py | cap centres sit at +-half along the strokes: loop length |
| `thick` | 14 px | tools/boot_emblem.py | plate edge height |
| `scale` / `fscale` | 1.15 / 1.15 | tools/boot_emblem.py | S size / F size about its own foot |
| `foot` | 764,548 | tools/boot_emblem.py | where the F's foot lands on the 1536x1024 card; the S follows it |
| `ang_d` / `ang_w` | 21 / 19 deg | tools/boot_emblem.py | stroke axis above horizontal / across axis below it: the viewing angle |
| `bands` | -0.34, 0.34 | tools/boot_emblem.py | yellow-teal and teal-blue edges, as a fraction of the S's reach |
| `ext` | 8 px | tools/boot_emblem.py | how far each hidden terminal runs on under / behind the F |

## Bumper Stickers (achievement knobs)

Sources: `assets/data/stickers.json` (every goal is data — retune there, no code);
`game/stickers.gd` constants; the family roll-up in `game/hit_tags.gd`. Single-player
only; goals are hidden from players (the book shows locked stickers as `???`).

| Knob | Value | Where | What it does |
|---|---|---|---|
| weapon goals | 50 kills each | stickers.json `kills.<id-or-family>` | Basic AF, No Place Like Home, Straight Shooter, Tailgunner, What's Mine Is Yours, Pepper Shaker, Backyard BBQ (`fire`), Shock Therapy (`electric`), Grille Kill Kult (`ram`) |
| death goals | 25 each | stickers.json `deaths`, `deaths.fall/drown/enemy_fire` | My Other Car (any death), Thelma and Louise, Under da Sea, Target Practice |
| splat goal | 100 | stickers.json `splats` | I Brake For Nobody (local player's run-overs and shots only) |
| campaign goals | 1 win per tier | stickers.json `campaign_won.easy/medium/hard` | Day Tripper / Long Hauler / Road King; HARD cascades down |
| roster goals | every roster car / every damaging special | `set_covers_roster` / `set_covers_specials` | Gotta Crash 'Em All (finish the campaign in each car), Special Delivery; both grow with roster.json |
| `ATTRIBUTION_MS` | 10000 ms | stickers.gd | how fresh the local player's last hit must be for a kill (and a rival's for `enemy_fire`) |
| `element` | `fire` / `electric` | WeaponDef .tres | family membership; any def with a burn effect must be `fire` (lint) |
| `can_earn()` | campaign, single battle | stickers.gd | off in Net sessions, custom levels, and under DEVGOD; Driver's Ed records only graduation |
| profile | `user://stickers.json` | stickers.gd `PROFILE_PATH` | saved on every change; headless runs never save |
| notice sound delay | 0.9 s | end_screen.gd | `sticker_earned` waits for the win/lose sting |
| art | 768x256 PNG | assets/img/stickers/ | drop-in; missing art paints a seeded vinyl stand-in |

## Slo Mo's shop (PIT STOP knobs)

Sources: `ui/garage/garage.gd` (state, input, purchase rules), `ui/garage/shop_room.gd`
(room, lighting), `shaders/shop_spotlight.gdshader`. Art contract and re-measure recipe:
`docs/art_briefs/slo_mos_shop.md`.

| Knob | Value | Where | What it does |
|---|---|---|---|
| sounds | shop_enter −8 / shop_hum −20 (loop) / shop_buy −4 / shop_deny −8 dB | audio_director.gd CATALOG | door bell on opening, room tone while visible, cha-ching on a deal, no-sale on a refused part; recipes in tools/synth_sfx.py |
| `GUARD_SEC` | 0.25 s | garage.gd | after every mode change (and on opening), Enter/Escape are ignored this long |
| `MO_LINES` | idle / confirm / locked / short / owned / bought | garage.gd | Slo Mo's lines at the bottom of the menu |
| `HOTSPOTS` | 5 stations, left to right | shop_room.gd | category, label, flashlight rect (1280×720 px) and Mo's quip per station; order = ←/→ order |
| `LAMPS` | 3 fixtures | shop_room.gd | Vector4(x, y, pool rx, pool ry) of each overhead light |
| `ROOM_AMBIENT` / `MENU_AMBIENT` | 0.25 / 0.14 | shop_room.gd | room brightness outside the beam and lamp pools |
| `ROOM_BEAM` / `MENU_BEAM` | 1.0 / 0.55 | shop_room.gd | flashlight strength in the room / behind an open menu |
| `BEAM_PAD` / `BEAM_MIN_RADIUS` | 1.15 / 90 px | shop_room.gd | beam ellipse = hotspot half-size × pad, never smaller than the minimum |
| `SWAY_PX` | 3 px | shop_room.gd | handheld wobble of the beam |
| `SPOT_MOVE_SEC` | 0.15 s | shop_room.gd | beam travel time between stations (runs under the paused tree) |
| `beam_gain` / `beam_tint_amount` | 1.2 / 0.10 | shop_spotlight.gdshader | how much brighter and cooler the beam is than the painting |
| `lamp_strength` / `lamp_halo` / `lamp_halo_radius` | 0.45 / 0.22 / 70 px | shop_spotlight.gdshader | warm pool under each fixture, and the glow on the fixture itself |
