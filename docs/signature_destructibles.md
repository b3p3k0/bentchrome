# Signature destructible contract

Signature destructibles are opt-in, level-specific landmarks whose state can
change a fight. The Ground Floor Gore generator is the prototype. This contract
keeps future landmarks readable, counterable, and deterministic without making
every ordinary crate a bespoke network system.

## Design contract

- **DEFAULT:** a regular arena may feature one macro-readable signature
  destructible. It earns its space through a distinct pressure pattern and
  counterplay, not merely a larger explosion.
- **MUST:** its silhouette, dangerous phases, effective floor/range, and escape
  option remain legible at combat zoom. Warning precedes unavoidable output.
- **DEFAULT:** the landmark telegraphs damageability early with visual-only
  distress FX driven off its locally mirrored HP fraction — host and client
  puppets both read Health directly, so the tiers need zero wire state and
  never touch the phase machine.
- **MUST:** cover, distance, floor changes, destruction, or another explicitly
  documented player action counters the hazard.
- **MUST:** difficulty does not silently re-price environmental phase timing or
  damage. Any scaling is an authored exception with tests.
- **MUST:** environmental damage clears player attribution unless the landmark
  explicitly belongs to a player-controlled weapon.
- **MUST:** AI receives a navigation-only danger cue during committed danger
  phases. It does not deliberately focus the landmark unless the encounter says
  otherwise; incidental fire and rams may still damage it.
- **DEFAULT (implemented game-wide):** destruction leaves a persistent,
  nonblocking aftermath that helps
  players read the changed battlefield.

## Host-authoritative state

A stateful arena entity joins `arena_net_entities` and exposes:

```gdscript
@export_range(1, 65535, 1) var arena_net_id: int
func capture_arena_state(actor_lookup: Array) -> Dictionary
func apply_arena_state(row: Dictionary, initial_state: bool) -> void
```

- **MUST:** `arena_net_id` is nonzero, stable across releases, and unique within
  the arena. IDs are content identity, not instance IDs or scene-tree order.
- **MUST:** the host alone advances phase timers, chooses random outcomes,
  applies damage/status/shove, and decides destruction.
- **MUST:** clients only apply presentation and collision state from repeated
  snapshots. Applying the same row twice is safe.
- **MUST:** destruction leaves a noncolliding tombstone in the scene so
  its terminal state continues to replicate. Do not free a networked entity.
- **MUST:** a client receiving the destroyed state initially suppresses the
  death burst; a live→dead edge may present it once. Missing IDs, malformed
  rows, stale rows, and invalid actor indices fail safely.

Protocol 8 arena rows encode `u16 id`, `u8 flags`, normalized `u8 HP`, `u16`
phase milliseconds, and an `u8` actor-target mask. The repeated row is the
truth; reliable one-shot RPCs are not sufficient for critical arena state.
Shared flags currently name alive, armed, warning, active, and escape states.
Entity-specific phase meaning remains behind the duck-typed interface.

## Phase checklist

For each new landmark, document and test:

1. Dormant/readable state, HP, footprint, floor bits, and ordinary cover rules.
2. Activation threshold or trigger and whether it can be crossed in one hit.
3. Warning duration, geometry, and what the player can do about it.
4. Active duration, target selection, line of sight, floor gating, damage,
   status, and AI danger cue.
5. Cooldown start point and exact cadence, independent of difficulty unless
   named otherwise.
6. Death radius/falloff, impulse, chain-reaction eligibility, attribution, and
   aftermath.
7. Host/client convergence from a fresh join during every phase and after death.

## Prototype precedent: power generator

Ground Floor Gore proves the contract with a 220 HP floor-1 cabinet. Below 90%
HP it pops intermittent insulator sparks and a smoke wisp (amplified below
75%) — the early "this is interactive" cue. At 25% HP it warns 1.2s, arcs to
every visible same-floor car within 480px for 2s, then waits 60s. Its 16-damage full latch and interference are environmental. Death
deals 50→15 and shoves 420→140 across 420px, can chain through site cover, and
leaves a charred pad. See
[`arena_briefs/ground_floor_gore.md`](arena_briefs/ground_floor_gore.md) for the
arena context and network ID allocation.
