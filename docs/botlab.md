# Botlab — headless match harness, balance telemetry, and the bot league

Botlab runs playerless matches headless and writes per-match telemetry JSON so
coding agents (and humans) can measure roster balance and iterate custom AI
drivers. Nothing here ships in the game: the probe mounts arenas through the
same `mp_managed` seam the MP shell uses, and the only game-code hooks are the
`Combat` governor knobs and inert `bc_hit_kind` meta breadcrumbs.

## Quickstart

```sh
# balance sweep: stock-AI free-for-all, 20 seeded matches, 4 at a time
tools/botlab.sh tools/botlab/configs/sweep_ffa.json --n 20 --jobs 4

# bot league: Claude vs GPT, spawn-mirrored pairs
tools/botlab.sh tools/botlab/configs/duel.json --n 20 --swap-pairs

# one-off harness check
tools/botlab.sh tools/botlab/configs/duel_smoke.json
```

Results land in `tools/botlab/out/` (gitignored): one `match_<seed>[_tag].json`
per match plus `summary.json`, the per-car sweep table (win rate, K/D, damage
economy, accuracy, first-death rate, survival, damage-taken-by-kind).

Flags: `--n N` matches, `--seed BASE` (seeds run base..base+N-1), `--jobs J`
parallel processes, `--swap-pairs` (each seed also runs with entrants
reversed — league spawn fairness), `--realtime` (drop `--fixed-fps`; wall-clock
validation), `--out DIR`.

## Config

```json
{
	"arena": "res://levels/arena/arena.tscn",
	"seed": 1234,
	"max_seconds": 180,
	"governor": "lethal",
	"entrants": [
		{"car": "hornet", "driver": "stock"},
		{"car": "razorback", "driver": "res://ai/bots/claude_bot.gd", "mix": null}
	],
	"fill_stock": 0,
	"fight_director": false,
	"output": "res://tools/botlab/out"
}
```

- `driver: "stock"` seats the shipping `EnemyDriver`; optional `mix: [a, b, o]`
  overrides the roster archetype blend. Any other value is a `Driver` subclass
  script path mounted via `Vehicle.set_driver`.
- `fill_stock: N` pads the field with distinct seeded roster picks
  (`Loader.pick_cars`), never duplicating an entrant.
- `governor`:
  - `"lethal"` (the data baseline) — `Combat.AI_VS_AI_DAMAGE = 1.0`,
    `AI_MERCY_HP = 0.0`. The shipping governor (0.35× AI-vs-AI, sub-10%-HP
    mercy immunity, non-lethal ram floor) makes a playerless match literally
    unendable; lethal mode measures full-strength balance.
  - `"stock"` — shipping rules untouched; measures the theater damage economy
    (who gets focused, who bleeds), always ends at the cap.
- `fight_director: true` attaches the `AIFightDirector` for FFA realism
  (leases are player-focused, so it mostly idles in playerless fields).
- Two entrants duel from the farthest spawn pair; bigger fields take the
  arena's authored spawn order. Entrants are capped at the arena's spawn count.
- Env overrides (the shell sets most): `BOTLAB_CONFIG`, `BOTLAB_SEED`,
  `BOTLAB_OUT`, `BOTLAB_TAG`, `BOTLAB_SWAP=1`, `BOTLAB_GIT_REV`,
  `BOTLAB_FIXED_FPS`.

## What gets measured

Per car per match: kills, killed_by (attribution-window credit or
`wasteland`), death_cause, damage dealt/taken split by kind (`mg`, `weapon`,
`ram`, `mine`, `special`, `burn`, `environment`), per-victim damage matrix
(`dealt_to`), shots fired (per pellet, via the NetEvents tap), vehicle hits,
wall hits, accuracy, damage-weighted average engagement range, frames alive,
distance traveled, stationary frames, boost frames/fuel, heal gained, pickups,
special casts, secondary shots, MG lockouts, and a half-second HP timeline.
Match level: frames, first blood, kill order, verdict (last standing; at the
cap best HP → kills → damage, ties are joint), and full metadata (seed, arena,
governor, timing mode, engine, git rev).

Attribution mirrors the MP MatchDirector but counts PHYSICS FRAMES (600 = 10
sim-seconds), never the wall clock — `--fixed-fps 60` runs sim time faster
than realtime with per-tick deltas identical to a live session. Burn DoT is
credited to the igniter without refreshing the window, kill() deaths (pits,
deep water) are environmental unless a fresh shove says otherwise, and barrel
blasts are deliberately creditless (canon).

## Determinism

Stock AI is RNG-free; the probe seeds the global RNG (weapon spread,
cosmetics) and threads a seeded generator into roster picks. Same seed + same
machine ⇒ identical matches (verified byte-identical minus metadata). Godot
physics is not cross-platform bit-exact, and `--realtime` reintroduces
wall-clock jitter in the EnemyDriver revenge window. Draw statistical
conclusions from ≥20 seeds, not one match.

## Bot authoring contract (the league)

A bot is a **pure `Driver`** (`ai/bots/claude_bot.gd`, `ai/bots/gpt_bot.gd`):

- Override `get_intent(vehicle, delta) -> Dictionary` with keys `throttle`,
  `steer`, `fire_mg`, `fire_selected`, `weapon_prev`, `weapon_next`,
  `handbrake`, `boost`.
- **Read only the EnemyDriver surface**: the vehicle's duck-typed API
  (`global_position`, `heading`, `velocity`, `get_speed()`,
  `get_real_velocity()`, `get_hp_fraction()`, `current_terrain`,
  `get_rack()`), scene group scans (`get_nodes_in_group(&"vehicles")`,
  pickups), and `vehicle.get_world_2d().direct_space_state` raycasts (the
  feeler pattern, `enemy_driver.gd`).
- **Never** mutate the scene, other cars, autoloads, statics, or metas. No
  perfect-information reads of other drivers' internals.
- Both bots ride `enemy_vehicle.tscn`, so the AI MG trigger discipline (3×
  mount cooldown) and the unified 2s non-MG `WEAPON_LOCK` apply equally.

League format: `--n 20 --swap-pairs` on `configs/duel.json` (each seed runs
both spawn assignments), wins first, aggregate HP margin as the tiebreak.
Iterate: edit your bot → run → read `summary.json` and the per-match JSONs →
repeat. Techniques that generalize get folded into `enemy_driver.gd` knobs and
behaviors with normal test coverage — the league is a lab, not a shipping
target, and the player-is-the-main-event doctrine stays the filter.

## Guarantees & tests

`tests/test_botlab.gd` locks: shipping governor defaults (0.35 / 0.10) and the
mercy floor, the lethal override round trip, the `ram_clamp` AI floor at
defaults (and pass-through when mercy is off), recorder damage-kind
classification, kill attribution, and wasteland/environment deaths. The smoke
config is the end-to-end check. Run `tools/smoke.sh` and `tools/test.sh` after
touching any harness or game script, as always.
