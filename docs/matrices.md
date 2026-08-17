# Bent Chrome — Stat Matrices

Every gameplay number in one place: vehicles, weapons, terrain, and the combat
modifiers that glue them together. Use it for balance passes — spot the outlier,
then edit the source file listed at the top of each section.

Numbers pulled from source on 2026-07-09 (Buzzard Run batches A/D/B); car-contract
pass 2026-07-12. This file is hand-maintained: when a `.tres` or a const changes,
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
| Razorback | Big Sarge | 3 | 6 | 4 | 8 | 7 | 7 | 156 | Red Glare | 1 | 12s | defender |
| Smoky | Officer Richard Vepsh | 7 | 6 | 4 | 7 | 7 | 6 | 143 | Taser | 3 | 90s | defender |
| Splat Kat | Juan Dough | 6 | 7 | 7 | 5 | 8 | 5 | 119 | Rusty 'Poon | 2 | 6s | ambusher |
| **Lackey** (miniboss) | Lackey | 7 | 6 | 6 | 10 | 10 | 9 | **360**¹ | Blaze & Bolt twin + Breach Turret | 2 (shared) | 120s | — |

¹ 180 base × `hp_scale 2.0` (Lackey's Arena scene). Lackey also carries: `body_scale 1.5`, `rear_weakspot 1.5` (projectiles from behind ×1.5), `ai_cooldown_scale 1.5` (fires at 2× a normal AI's rate), a `relentless` driver (runs the boss valve instead of mook RELENT; full-length BREAK arcs now), `no_mines` (crate-proof), and the LIVE Breach Turret.

### The Buzzardz (chase mode, roster-external)

Source: `data/vehicles/buzz_*.tres`, HP scaled at spawn by `chase_director.CLASS_TABLE`; all `no_mines`, all `ai_cooldown_scale 1.4` (buzzard.tscn), MG overridden to 1.7 dmg / 10 rate / 12° spread. Brains: `chase_driver.gd` ROLES (not EnemyDriver).

| Bird | Accel | Top | Handling | Armor | Mass | HP (scaled) | Armament | Behavior |
|---|---|---|---|---|---|---|---|---|
| Scrambler (bike) | 9 | 8 | 8 | 1 | 1 | ~38 (×0.55) | scrapgun MG, 0.5s bursts / 1.8s gaps, range 420 | swoops to −60/+190 dy on a 4.5s rhythm; yo-yos to keep up |
| Beater (sedan) | 5 | 6 | 4 | 2 | 4 | ~70 (×0.85) | MG bursts + Scrap Rocket (12 dmg, 90°/s, ~4.5s clock, cap 2/9s) | holds +260..430 behind, wobbly steer, aims at a 0.45s-stale snapshot; yo-yos |
| Technical (pickup) | 3 | 2 | 3 | 3 | 6 | ~90 (×0.95) | Bed Gun turret: 12 dmg / 2.2s / 700 px/s, auto-aim ≤1100, 120°/s traverse | spawns AHEAD, falls back through the field; driver never fires; no yo-yo |

Yo-yo (bike/sedan): >600px behind → max_speed rides player+80; <250px → honest stats. Buzzard-vs-buzzard damage runs the standard ×0.35 AI governor.

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
| Red Glare (Razorback) | PROJECTILE | 6 ×20 | 950 | 4.0s | none | 20-rocket 26° fan; 120 theoretical point-blank (range 1235) |
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
| Smoky / Razorback | Grass | 0.95 | 0.95 | 0.86 | 1.00 | — |
| Smoky / Razorback | Snow | 0.90 | 0.94 | 0.53 | 1.00 | — |
| Smoky / Razorback | Dirt | 0.88 | 0.92 | 0.67 | 1.00 | — |
| Smoky / Razorback | Water | 0.50 | 0.55 | 0.74 | 1.00 | shallow only |
| Cricket | Mud | 0.62 | 0.65 | 0.50 | 0.98 | no dirt DASH bonus |
| Hammertoe | Mud | 0.80 | 0.80 | 0.60 | 0.98 | big-tire advantage |
| Smoky / Razorback | Mud | 0.72 | 0.74 | 0.55 | 0.96 | partial 4WD advantage |
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
| Mountainside Mayhem | 7 | 2 floor-2 skiers, 5 floor-3 plateau deer |
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

Deliberately unscaled: enemy counts, lives (3), mook RELENT valve, AI theater governors (×0.35 / mercy), environmental flat damage (barrels, falls, pits, deep water, horde wall — none route through `Combat.scale`), jackknife cadence (first follow-up knob if easy Goliath still runs hot). A mine whose dropper died deals full damage on every tier (null shooter — pre-existing shape).

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

The mutable archetype `PURE` table and all statics above live in `enemy_driver.gd`, except the three `FOCUS_*` statics in `ai/fight_director.gd`. `assets/data/ai_profiles.json` remains unconsumed design notes. Range-aware weapon selection, repair/ammo planning, cover utility, and terrain preference are intentionally deferred until this movement/attention pass clears playtesting.

Floor navigator (multi-floor levels): cross-floor targets score −0.1 · NAVIGATE rides authored FloorConnectors (approach lead 220, exit lead 260, 6s timeout, boost on jump commits, grade commits never boost, commit leg ignores feelers) · ambusher/opportunist blends with an armed tracking secondary hold roof vantage up to 8s, raining missiles cross-floor (walls-only LoS), before descending · MG and non-tracking specials never fire cross-floor · hazard curbs (invisible, AI-feeler-only) rail every pit/deep-water rim — Snowy's cliffs included.

---

## Campaign

Source: `game/scene_flow.gd` CAMPAIGN profiles + `levels/arena_contract.gd`; full language and brief: `docs/arena_field_manual.md`. Route 666 Roulette (specialty) and the three `placeholder` slots are excluded from the arena contract. Absolute floor: 4 target cars, 1,600,000 gross px²/car, short side 2048 — except `duel` arenas (`mp_avail: false`, exactly 2 cars / 1 station; aquarium floors still apply per-car). Small/med/large target cars = 4 / 5-7 / 7-8; stations = 1 / 1-2 / 2-3. Boss campaign overlays may field two actors but underlying target stays ≥4. Slot order is test-pinned (`tests/test_ground_floor.gd`); placeholder slots are sceneless, ride the shared `level_X.png` sawhorse interstitial card (any key detours past), and flip to real entries with `optional: true` (STAY/DETOUR chooser) once buildable — Arena Assault is the first graduate.

| # | Level | Size (interior px) | Target cars | Campaign enemies | Stations | Signature hazards |
|---|---|---|---:|---:|---:|---|
| 1 | Arena Assault | SMALL 2560×2560 | 2 (duel; mp_avail false) | 1 | 1 | derby pit: dirt infield in an asphalt lane, jersey ring, center station, wall-lane M/M/H/P/X crates, barrel chains, wreck cover; `optional: true` while in test |
| 2 | Piers of Pain | LARGE 5120×3584 | 8 | 7 | 2 | 3 floors: lowland / quay / roofs + 1704px ship deck; deep water + piers; 2 sky bridges + crane underpasses; chain-link quay fence (12 HP); 8 jump pads; roof crates |
| 3 | Downtown Derby | MED 3712×3584 | 5 | 4 | 1 | park pond, secret courtyard, smashables; NW+N rooftops + bridge, garage ramp, 1 jump pad |
| 4 | Freeway Firefight | LARGE 2176×5376 | 7 | 6 | 3 | ring + crossover, guardrails (20 HP), 2 jump pads |
| 5 | Lackey's Arena | MED 3072×3072 | 4 planned MP | 1 (Lackey) | 1 | live turret; destructible container cover (140 HP), chain-link runs, barrel clusters, containment square, one jump pad; named MP exception |
| 6 | Suburban Savagery | MED 3584×3456 | 7 | 6 | 2 | 20 houses (120 HP), east lake, school/gas anchors |
| 7 | Terminal Terror | PLACEHOLDER (unbuilt) | — | — | — | sawhorse card; chains into slot 8 |
| 8 | Slaughter on the Strip | PLACEHOLDER (unbuilt) | — | — | — | sawhorse card; chains into Route 666 |
| 9 | Route 666 Roulette | SPECIALTY ~130k px streamed | — | runtime horde | medkits | excluded from arena contract; `optional: true` (STAY/DETOUR) |
| 10 | Mountainside Mayhem | MED 3456×3456 | 7 | 6 | 1 | snow/ice, west cliff + chasm (pits) + jump pad; `DriveableHill` at (896,−672), 848 summit + 240 grades = exact 1088 road-to-road footprint, pull 180; slope building blocks floors 2+3; paired AI routes all faces |
| 11 | Ground Floor Gore | LARGE 4608×3840, 3 floors | 8 | 7 | 2 | dirt/mud/water; RAINY DUSK (night_arena, 5 shootable 8-HP worklights, headlight beams on EVERY car); foundation + scaffold ring over a courtyard pit; ALL 16 ring rails breakaway 12-HP; east-strip 2↔3 ramp (courtyard pinch gone); fl-2 rim fully open (floor-1-only walls); 4 slab columns; spoil heap (848 fl-2 apron + 448 fl-3 cap, mine crate on top) + SW twin heaps (320 fl-2); NW parking lot (7 synced derelicts); 220-HP generator (arm 55) w/ 90%/75% distress sparks at (-1420,-60); junk 15 HP; ids 1,10-17,20-74; MP ready |
| 12 | Capital City Carnage | PLACEHOLDER (unbuilt) | — | — | — | sawhorse card; auto-detours to the finale |
| 13 | Goliath's Arena | LARGE 4608×3584, 2 floors | 4 planned MP | 1 (Goliath) | 1 | grandstand ramps pull 170 + stair bumps; continuous crown; 4 solid chamfers; boss overlay; named MP exception |

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

Sources: `levels/chase/*.gd` static vars, `ui/hud_chase.gd`, `ui/speed_lines.gd`. Course distance d = −world_y; north is up.

| Knob | Value | Where | Detail |
|---|---|---|---|
| Run length / win | 180s | buzzard_run `RUN_SECONDS` | timed win drives the end screen directly (`suppress_group_win`) |
| Rolling respawn | 300 px/s (~45 mph), in place | `ROLL_SPEED` | x clamped onto the asphalt, nose north, shield 2s, clock keeps running |
| Pace floor | throttle ≥ 0.45 (no-input) | chase_player_driver `MIN_THROTTLE` | S passes through — real braking, stop allowed; W sprints |
| Wall comfort / surge | 900 px / +0.35 px/s per px | horde_wall `COMFORT_GAP` / `CATCHUP_RATE` | ~855 px/s closure from the clamp — globally inescapable |
| Wall clamp / kill / reset | 2400 / 50 / 1400 px | `MAX_GAP` / `KILL_MARGIN` / `RESPAWN_GAP` | kill via Health (shield + DEVGOD respected); backstop blocks reversing through |
| Wall rumble | gap < 500 px | `RUMBLE_GAP` | add_shake ramp, screen-shake toggle respected |
| Director arc | 7 phases, cap 2→8 | chase_director `PHASES` | wall cruise 300→420; breathers @50 & @110; finale @168 = no spawns, wall surge |
| Spawns | behind +1100 / ahead −1600 (tech) | `SPAWN_BEHIND` / `SPAWN_AHEAD` | pace-matched entry; cull 2600 behind; 2.5s held fire after a player death |
| Buzzard yo-yo | far 600 / near 250 / +80 px/s | chase_driver `YOYO_*` | bikes+sedans only |
| Course pre-roll | 130k px, seeded | chase_course `TARGET_LEN` | pickup lane ≤ every ~9k (`PICKUP_EVERY`), landmarks ≥ 15k apart (`RARE_SPACING`), meander ±800 (`SPINE_BOUND`) |
| Road | half_w 360 (narrow 260) + 90px verge | chunk_defs / chunk_builder | verge = grass/dirt grip penalty; embankment wall past it |
| Obstacles | rails 20 HP · logs 15 · junk 20 · pumps 40 · potholes r36 dirt | chunk defs/builder | low HP by design — blow through at a momentum cost |
| Pickups | heal +25 · nitro +35 · M/P crates | heal/boost_pickup + ammo | player-only, one-shot, no respawn |
| Speed streaks | fade in 480 → full 640 px/s | speed_lines `THRESHOLD`/`FULL` | play-square overlay |
| GPS window | −500..+3500 px of course | chase_gps `BACK`/`AHEAD` | blips ≤1500; technicals = amber diamond; wall band pulses < 600 gap |

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
| UI_EVENTS | ui_*/stings/mp_* | audio_director.gd | events routed through the pause-immune pool |
| volume_db / pitch_jitter | per event | audio_director.gd CATALOG | per-asset trim + repeat-variation; tune here, not in the asset |
| overheat cue | once per lock | weapon_mount.gd | player-only, fires when heat crosses heat_max |
| pickup cue | player-only | ammo_pickup.gd / heal_pickup.gd | AI crate grabs stay silent |
| mp_join/mp_leave | lobby only | mp_lobby.gd | peer-count diff on peers_changed (name syncs don't cue) |
| pit/water death sound | pit_fall / sink replace the death boom | vehicle.gd _on_died | `_falling` gates the generic explosion sound like it already gated the visual |
| sp_<special> events | 13 (9 assets live) | special_controller.gd special_sfx_event | per-car special voices: sp_ + def basename; taser/blaze loop with the effect, toe_jam voices the LANDED hit, red_glare repeats per rocket; PROJECTILE fallback = missile_fire via WeaponMount.sfx_override |
| brake cue | one-shot on hard-brake start | drive_fx.gd _was_braking_hard | was a loop; Kevin redesigned to a single quick bite (2026-07-14) |
| boost voice | roar edge + whoosh loop | drive_fx.gd _was_boosting | boost one-shot at ignition, boost_loop rides ctrl.boosting |
| splat/crunch | coinflip on living soft targets | ambient_actor.gd _die | leaves_splat gates the coinflip; props always crunch; positional |
| announcer_<car>_wins/_loses | 28 baked lines | end_screen._announce (win = rolling/finale-only; lose = any wipe) | espeak-ng dev-bake + PA chain in synth_sfx.py; loses pitched lower; pause-immune pool (lose screen freezes the tree); no runtime TTS; 0.8s after the sting |

## BGM (background music knobs)

Assets are procedural: `./venv312/bin/python tools/synth_bgm.py` regenerates
`assets/bgm/*.ogg` (naming contract in `assets/bgm/README.md`, reference form
in `assets/bgm/refs.md`; engine in `tools/bgm/`). `game/music_director.gd`
(autoload) picks the track by scene, crossfades, and ducks; the dev-options
SOUNDBOARD lists `bgm_*` rows with PLAY/STOP toggles.

| Knob | Value | Where | What it does |
|---|---|---|---|
| TRACKS | scene path -> bgm_* | music_director.gd | which track a scene plays; UPCOMING = interstitial plays the next level's track; RESOLVE_CHILD = mp_match keys off its instanced arena; unknown scenes = bgm_menu |
| CROSSFADE / PHASE_CROSSFADE | 1.6s / 0.9s | music_director.gd | scene-to-scene fade / in-level override fade (Goliath p1->p2 gear change) |
| DUCK_DB / DUCK_RATE_DB | -10 dB / 40 dB/s | music_director.gd | music dim while tree-paused or a named duck holds (end_screen rolling win) |
| same-event no-op | structural | music_director.gd _request | interstitial->level, pause-Restart, and respawn continuity |
| loop stamp | code, not .import | music_director.gd _looped | every resolved stream loops; assets bake the seam (wrap-crossfaded tail bar) |
| SEED / BPM / BARS | per track | tools/bgm/tracks/*.py | deterministic composition constants (arena: 0xD3B1 / 122 / 72) |
| TARGET_RMS_DB / PEAK_DB | -18 / -1 | tools/bgm/master.py | one loudness convention across all tracks — no per-track trim in-game |
| audio buses | Master / Music / SFX | default_bus_layout.tres (default path, no project setting needed) | MusicDirector players ride Music, all AudioDirector pools ride SFX; bus-less contexts fall back to Master |
| MASTER/MUSIC/SFX VOLUME | 0-100% in 5% steps | ui/settings.gd + GameState.volume_* | persisted sliders; GameState.apply_audio_settings() pushes linear_to_db onto the buses at boot/adjust/reset; 0% mutes the bus |
