# Garage recon — the seams we hook (verified 2026-07-19)

> UPDATE: the promotion landed (`main` + `development` topology); work now
> lives on `feature/garage`. The branch replaced the docs-corner isolation
> constraint — the playable is real engine code, launched SCENE-DIRECT
> (`godot --path . res://ui/garage/garage_playable.tscn`, the
> custom_level.tscn precedent) so no `--garage` arg or live-flow edit was
> ever needed. Seams below are for the PLUG-IN phase; re-verify then.

## The win-flow hook (garage entry)

`ui/end_screen.gd` mid-campaign win path: `_show(true)` finds
`_campaign_next_index()`, hides the buttons, shows the `_hint` label, and
`_arm_continue()` makes ANY key run `gs.level_index = next;
flow.to_interstitial()`. **This is the PIT STOP fork**: replace the single
any-key continue with two armed choices — KEEP ROLLIN' (today's behavior) /
PIT STOP (garage scene, which exits into the same
`to_interstitial()` path). The button factory + amber `UiStyle` theming
already live in this file. Notes:
- Chase mode (Route 666) calls `_show(true)` directly — same fork works.
- The Coliseum rolling win (`win_keeps_rolling`) is the finale: no next
  level, no garage (prize ceremony stub owns that moment).
- Losses/off-campaign keep the classic button panel — no garage.

## Money storage

`GameState` already carries run-state precedent: `lives`, `level_index`,
`score` (int, "never touches disk"). Add `funds: int` beside them; reset in
`reset_campaign()`. NOTE: `score` exists but SP currently has no feeder —
don't overload it; funds is its own thing.

## Difficulty scaling

`game/difficulty.gd` TIERS is a multiplier knob table with fail-soft
`knob()` (missing = 1.0, HARD row all 1.0 by definition). Economy knobs slot
in without touching consumers' consts: proposed `&"reward_scale"`,
`&"penalty_scale"`, `&"price_scale"`.

## Earn events + attribution

- **Enemy kills:** `Vehicle.last_attacker` (+ `last_attacker_ms`) is set on
  every damage source; enemy `Health.died` + `last_attacker` in group
  `&"player"` = player kill. MP's MatchDirector already trusts this pattern
  (10s attribution window). Free-for-all note: AI-on-AI kills pay nothing —
  the mercy governor (`Combat.scale`) already funnels finishing blows to the
  player by design.
- **Destructibles/soft targets: attribution gap.** `Health.take_damage(amount)`
  carries NO source; only Vehicle tracks `last_attacker`. Props (destructible
  blocks, clutter, derelicts, ambient actors) die anonymously today, and AI
  fire DOES level cover. Needed plumbing: a light `last_hitter` tag on the
  prop damage path — `Projectile` knows its shooter, the ram path knows the
  rammer; both can duck-type-set a tag before dealing damage (mirror of
  Vehicle.last_attacker, set-and-forget). Reward only fires when the tag is
  the player's car.
- **Size-proportionate reward:** `Health.max_hp` is the honest size proxy
  (picket fence 15, chain-link 12, derelict 50, container 140, generator
  220; clutter/ambients are 1). See economy.md for the formula.

## Lose events

- **Player destroyed:** the level's lives loop / `Health.died` on the player.
- **Falls/sinks (bigger penalty):** `environment/pit_zone.gd` and
  `environment/deep_water_zone.gd` kill via `Health.kill()` (unconditional).
  The ZONES know the cause — charge the fall/sink penalty at the zone site
  (or tag a `death_cause` the economy reads); don't try to infer it from
  Health, which is cause-blind.
- **Health station use:** `environment/health_station.gd` owns activation
  (uses, cooldown, snap-refill start). Charge at refill START (the moment of
  commitment). Chase-mode drive-over medkits/boost are different items —
  exempt (specialty level, instant pickups).
- DEVGOD: pits already "cost no life" under god — economy penalties should
  follow the same courtesy (inert under DEVGOD, which is already inert in
  Driver's Ed lessons and MP).

## Where the economy lives

Recommend a dependency-free leaf `game/economy.gd` (the difficulty.gd /
combat.gd pattern: static state + static funcs, preloadable from anywhere,
no class_name, no scene refs) so zones/stations/levels can bill and award
without dependency cycles. The garage SHOP scene is separate UI that reads
and spends the same statics.

## Mod application (already built)

`VehicleLoadout.compose(base, mods)` + owned-mods list; between-level
application via `Vehicle.set_stats(compose(...))` at level spawn — the
between-levels garage means the repaint/HP-reset semantics of set_stats are
FINE (fresh level = fresh HP anyway). Contract: ../garage_seams.md.
Catalog data shape (`stat_deltas` / `capabilities` / `terrain_profile` /
`controller_overrides` / `terrain_overlay`) is already defined there.

## Interstitial

`SceneFlow.to_interstitial()` runs the loading card between levels. Garage
exit funnels INTO it, preserving the existing level-entry beat (cards, boss
banners).
