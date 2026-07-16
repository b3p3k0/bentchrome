# Garage economy — DRAFT v0.2 (numbers are proposals; rules are DECIDED)

Currency of the tournament: **BOLTS** (decided 2026-07-19; HUD/garage glyph
TBD — a hex-nut/bolt mark; ⚙ is the mockup placeholder). Players start at
**0**. Integer money, US-flavored copy.

## Earning

| event | reward (HARD baseline) | notes |
|---|---|---|
| enemy kill (mook) | 100 | attribution: victim's `last_attacker` is the player |
| enemy kill (mini_boss archetype) | 250 | kandykane-class |
| boss kill (Lackey / Goliath) | 500 | finale money is mostly ceremonial |
| chase-mode kill (buzzards) | 25 | 180s clock self-caps farming |
| destructible smashed | `clamp(round(max_hp × 0.2), 1, 30)` | fence 15→3, barrel ~8, derelict 50→10, container 140→28, generator 220→30 |
| soft target / clutter (1 HP) | 1 | ambient folk & street furniture |
| **per-level SALVAGE CAP** | **300** | applies to destructibles + soft targets ONLY; kills never capped. HUD shows a subtle "salvage tapped" once hit |

Income envelope (sanity): a MED arena ≈ 4-7 kills (400–700) + salvage ≤300
→ ~600–1,000/level gross; 8 combat levels ≈ **5–7k per campaign run** before
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
| ENGINE ch.1 | Stage 1: Bolt-On Boost (NA→boosted) | 300 | +1 accel |
| ENGINE ch.2 | Stage 2: Bigger Blower | 450 | +1 accel +1 top (req S1) |
| ENGINE ch.3 | Stage 3: Bigger Injectors | 600 | +1 accel +1 top (req S2) |
| SUSP ch.1 | Stage 1: New Springs | 250 | +1 handling |
| SUSP ch.2 | Stage 2: Reinforced Frame | 450 | +1 handling +1 armor (req S1) |
| SUSP swap | Offroad Tires | 350 | terrain profile swap (awd_utility-style) |
| SUSP swap | Lowering Kit | 400 | pavement/handling up, offroad down |
| WEAPONS | MG Cooling | 400 | `mg_heat_scale` (reserved axis) |
| WEAPONS | Bay Expansion | 600 | +ammo caps, −handling −armor |
| WEAPONS | Improved Lock | 500 | `lock_time_scale` + `detectability` tradeoff |
| CPU | Radar Jammer | 450 | `radar_range_scale` vs enemies (reserved) |
| CPU | Extended Radar | 500 | reserved until base radar range lands |
| ARMOR | Plating | 500 | +2 armor, −1 handling |

Envelope check: full campaign income ~5–7k; the full engine chain runs
1,350, a themed build ~2.5–3.5k — real choices every pit stop, a
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
