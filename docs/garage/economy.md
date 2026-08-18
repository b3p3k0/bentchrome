# Garage economy — v1 LIVE (wired into the campaign 2026-07-19; ×10 inflation applied)

RIVAL SCALING: rivals mirror `Economy.RIVAL_KEEPUP` (0.5) of the player's
POSITIVE stat deltas at enemy re-roll — the field keeps pace; bosses stay
authored. Tune in the sim harness or live play.

Currency of the tournament: **BOLTS** (decided 2026-07-19; HUD/garage glyph
TBD — a hex-nut/bolt mark; ⚙ is the mockup placeholder). Players start at
**0**. Integer money, US-flavored copy.

## Earning

| event | reward (HARD baseline) | notes |
|---|---|---|
| enemy kill (mook) | 1000 | attribution: victim's `last_attacker` is the player |
| enemy kill (mini_boss archetype) | 2500 | kandykane-class |
| boss kill (Lackey — Goliath pays no bounty v1, finale) | 5000 | finale money is mostly ceremonial |
| chase-mode kill (buzzards) | 250 | 180s clock self-caps farming |
| destructible smashed | `clamp(round(max_hp × 2.0), 1, 300)` | fence 15→30, barrel ~80, derelict 50→100, container 140→280, generator 220→300 |
| soft target / clutter (1 HP) | 1 | ambient folk & street furniture |
| **per-level SALVAGE CAP** | **3000** | applies to destructibles + soft targets ONLY; kills never capped. HUD shows a subtle "salvage tapped" once hit |

Income envelope (sanity): a MED arena ≈ 4-7 kills (400–700) + salvage ≤300
→ ~6–10k/level gross; 8 combat levels ≈ **50–70k per campaign run** before
penalties. Prices below assume that envelope.

## Losing (percentages of CURRENT funds — always hurts the same, rich or poor)

| event | penalty (HARD baseline) | notes |
|---|---|---|
| player destroyed | −20% | charged per death, at respawn |
| player falls in a pit / sinks | −30% | the wasteland taxes clumsiness harder than combat |
| health station activation | −10% | charged at refill START; chase drive-over medkits exempt |

Properties worth keeping: percentages never bankrupt to negative, floor at 0
via `floori`, and DEVGOD makes all penalties inert (matches "pits cost no
life" courtesy).

## Difficulty scaling (slots into difficulty.gd TIERS, HARD = 1.0)

| knob | EASY | MEDIUM | HARD | reads at |
|---|---|---|---|---|
| `reward_scale` | 1.0 | 1.0 | 1.0 | award sites |
| `penalty_scale` | 0.5 | 0.75 | 1.0 | penalty sites |
| `price_scale` | 0.75 | 0.9 | 1.0 | shop UI |

**DECIDED (2026-07-19):** easier tiers keep earning identical (the fun
part) but pay gentler penalties and shop cheaper — training wheels without
inflating the economy.

## Price bands (draft, HARD)

**Staging model (DECIDED 2026-07-19):** staged categories are prerequisite
CHAINS of distinct parts, and each stage's listed price IS the incremental
cost of that step (no difference-math). Example chains from Kevin: engine =
NA→boosted → bigger blower → bigger injectors; suspension = new springs →
reinforced frame. Standalone swaps (tires, kits) coexist beside chains.

| category | item | price | effect sketch (garage_seams.md shapes) |
|---|---|---|---|
| ENGINE ch.1 | Stage 1: Bolt-On Boost (NA→boosted) | 3000 | +1 accel |
| ENGINE ch.2 | Stage 2: Bigger Blower | 4500 | +1 accel +1 top (req S1) |
| ENGINE ch.3 | Stage 3: Bigger Injectors | 6000 | +1 accel +1 top (req S2) |
| SUSP ch.1 | Stage 1: New Springs | 2500 | +1 handling |
| SUSP ch.2 | Stage 2: Reinforced Frame | 4500 | +1 handling +1 armor (req S1) |
| SUSP swap | Offroad Tires | 3500 | terrain_overlay: grass/dirt/mud/snow up, asphalt greasy |
| SUSP swap | Lowering Kit | 4000 | +2 handling + terrain_overlay: asphalt up, soft ground down |
| WEAPONS | MG Cooling | 4000 | `mg_heat_scale` 0.7 — heat builds 30% slower |
| WEAPONS | Bay Expansion | 6000 | +2 special cap, −handling −armor |
| WEAPONS | Improved Lock | 5000 | `tracking_scale` 1.3 + `detectability` 1.5 tradeoff |
| CPU | Radar Jammer | 4500 | `detectability` 0.8 — sensors and AI eyes find you later |
| CPU | Extended Radar | 5000 | `radar_range_scale` 1.5 over the 2200px base sensor range |
| ARMOR | Plating | 5000 | +2 armor, −1 handling |

Envelope check: full campaign income ~50–70k; the full engine chain runs
13,500, a themed build ~25–35k — real choices every pit stop, a
death-heavy run visibly shops lighter. Tune in playtest.

## Purchase model (DECIDED except where flagged)

- Buy-to-own for the rest of the run; **parts survive death — money is the
  only thing you lose** (decided). The % penalty is the sting; the build is
  never bricked.
- Chains: must own stage N−1 to buy stage N; price = that step's increment.
- Swap items within a category slot replace each other (tires); chains and
  swaps can coexist where physical sense allows — catalog data decides.
- No sell-back in v1 (keeps the ledger simple); revisit if builds feel trapped.

## Open questions (remaining)

1. Health station: flat −10% per use, or first use free per level?
2. Salvage cap: flat 300/level (drafted) vs scaled by arena size (LARGE 400)?
3. Should the garage sell consumables (one-level boosts, repair-on-entry)?
   Drafted: NO for v1 — parts only, gravy not the main dish.
4. Currency glyph/art for BOLTS (hex nut? lug nut stack?) — art pass.
