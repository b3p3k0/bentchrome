# Signature specials — status

All nine signature specials are implemented (July 2026). Each is a `WeaponDef`
wired via `VehicleStats.special`; per-car ammo cap / recharge live in
`assets/data/roster.json` (`special_ammo_cap`, `special_recharge_seconds`,
defaults 1 / 12s). Kinds dispatch in `vehicles/special_controller.gd`:
PROJECTILE fires through SecondaryMount; BEAM / DASH / TRIGGER have dedicated
handlers there. On-hit status effects are `StatusEffectSpec` sub-resources in
the weapon `.tres` (see `data/weapons/splat_effect.tres` for the pattern).

| Car | Special | Kind | Behavior |
|-----|---------|------|----------|
| Mr. Ghastly | Scythe of the Damned | PROJECTILE | Spinning bone-pale reaper blade in a red aura, dragging a crimson trail. Straight, heavy (70), 780 px/s. |
| Razorback | Red Glare | PROJECTILE | Three quick waves of four red rockets in a 10° shotgun choke (950 px/s), each wave off the moving truck. |
| Ghost | Phantom Phire | PROJECTILE | Map-wide aggressive homing; pierces cover (`pierces_cover`). |
| Kandy Kane | Molotov Cocktail | PROJECTILE | Spinning green bottle with a burning rag, lobbed hard. Impact burst + 15s burn (3 dps). |
| Splat Cat | Splat Effect | PROJECTILE | Cobbled-iron harpoon; the skewered victim runs at half speed for 3s. Cap 2 / 6s. |
| Bumper | Blunt Blaze | FLAME | Nose-anchored flame column (~300px, one fixed 3s burst per press, 27 dps); bathed targets ignite 10s (4 dps). Cap 2 / 15s — a committed play, not a hose. |
| Smoky | Taser | BEAM | Living lightning bolt latches nearest car ≤400px (breaks past 800 or on LoS block), 4s zap (12 dps + slow). Cap 3 / 8s. |
| Cricket | Leap | DASH | Lock-on body-check ≤700px at 1400 px/s over obstacles; connect = ram damage + victim slow + 2s invuln. Cap 1 / 10s. |
| Hammertoe | Toe Jam | TRIGGER | Armed charge (exhaust stacks smoke) — smash something within 5s or the charge is lost unspent: flat 60 replaces crash damage on a landed ram. Cap 1 / 8s. |

## Follow-ups (not scheduled)
- AI never fires specials — archetype-driven usage is its own card.
- Balance pass once all nine are HI-playtested together.
- Art/FX polish: dash trail and burn/slow tints are placeholder-grade (beam, harpoon, molotov, scythe, red glare done July 2026).
