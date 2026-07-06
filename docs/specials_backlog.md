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
| Mr. Ghastly | Scythe of the Damned | PROJECTILE | Straight, heavy (70), 780 px/s. |
| Razorback | Red Glare | PROJECTILE | 20-rocket 26° salvo, 950 px/s. |
| Ghost | Phantom Phire | PROJECTILE | Map-wide aggressive homing; pierces cover (`pierces_cover`). |
| Kandy Kane | Molotov Cocktail | PROJECTILE | Impact burst + 15s burn (3 dps). |
| Splat Cat | Splat Effect | PROJECTILE | Paint glob; victim at half speed for 3s. Cap 2 / 6s. |
| Bumper | Blunt Blaze | FLAME | Nose-anchored flame column (~300px, 1s per ammo, 30 dps); bathed targets ignite 10s (4 dps). Hold to chain bursts — recharge keeps the torch lit. |
| Smoky | Taser | BEAM | Latches nearest car ≤200px, 4s zap (12 dps + slow); breaks on line-of-sight block or far escape. Cap 3 / 8s. |
| Cricket | Leap | DASH | Lock-on body-check ≤700px at 1400 px/s over obstacles; connect = ram damage + victim slow + 2s invuln. Cap 1 / 10s. |
| Hammertoe | Toe Jam | TRIGGER | Armed charge (bumper glows) held until the next landed ram: flat 60 replaces crash damage. Cap 1 / 8s. |

## Follow-ups (not scheduled)
- AI never fires specials — archetype-driven usage is its own card.
- Balance pass once all nine are HI-playtested together.
- Art/FX polish: beam, dash trail, burn/slow tints are placeholder-grade.
