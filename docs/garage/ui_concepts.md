# Garage UI concepts — round 1 (nothing locked)

Both mockups use the house palette (amber #ffd833 chrome, panel #121218,
blocky borders, monospace) at the 1280×720 base viewport. SVGs render in
VSCode's preview. ⚙ is the placeholder currency glyph.

## Concept A — THE BAY (`mockups/concept_a_the_bay.svg`)

The garage IS the menu: a diegetic shop interior. Your actual ride (real
CarPaint render in-engine, side-silhouette in the mock) sits on a hydraulic
lift center-stage; the five categories are physical stations arranged around
the room — tire rack (suspension), engine hoist, electronics shelf (CPU),
weapons bench, armor plates. A/D walks the highlight between stations, W/S
browses that station's stock in the bottom item strip, ENTER installs, ESC
rolls out (KEEP ROLLIN').

- Pros: maximum vibe; every category gets an illustration by construction;
  the car center-stage sells ownership; "installed" pips under the lift.
- Cons: most paint work (each station is a little scene); item details are
  squeezed into a one-line strip — stat-delta preview is cramped; adding a
  6th category means redecorating the room.
- Static bg placeholder: one paint-only script (the `stadium_deco.gd` /
  `tutorial_deco.gd` house pattern) drawing wall/door/floor/stations —
  cheap, and each station doubles as its own selection highlight target.

## Concept B — THE CATALOG (`mockups/concept_b_the_catalog.svg`)

A two-page parts catalog spread ("if it bolts on, it counts"). Left page:
category tabs with icon glyphs + ownership counts, and a YOUR RIDE panel —
top-down mini render + stat bars where **amber outline segments preview the
delta of the highlighted part before you buy**. Right page: item cards with
an illustration, green benefit chips / red tradeoff chips, price, and state
variants (selected / affordable / can't-afford with "SHORT 360 ⚙" taunt;
locked staged items show the prerequisite).

- Pros: information-dense — the delta preview IS the shopping decision;
  trivially extensible (tabs+cards scale forever); cheapest to build well;
  card states handle lock/owned/broke cleanly.
- Cons: less theatrical; the ride is a thumbnail, not the star.
- Static bg placeholder: dark shop blur + the spread panel; nearly free.

## Concept C — PIT ROW (sketch only, no mock yet)

Your car drives INTO the frame on a horizontal pit lane; stations are stalls
along the row and the car physically rolls to the selected stall (same
station art as A, but staged linearly). Maximum arcade charm, most motion
work; revisit if A's room layout fights the viewport.

## Recommendation (soft)

**B's information design inside A's room.** Ship order: build B first (the
catalog logic is the real machine — cards, deltas, wallet, lock states),
skinned minimally; A's painted room can replace the backdrop later and
reuse every card/preview component in the bottom strip or as a station
pop-over. That keeps vibe ambitions from blocking the economy loop.

## Shared mechanics (either concept)

- Entry: end screen win → PIT STOP; exit always funnels to
  `SceneFlow.to_interstitial()` (KEEP ROLLIN' skips the shop entirely).
- Input: keyboard + mouse both (car-select precedent, NOT the settings
  arrow-contract — the garage is a full screen, not a settings dialog).
- Wallet + NEXT-level tag always visible; buys are instant-apply to the
  owned-mods list (`VehicleLoadout.compose` at next level spawn).
- Delta preview everywhere a number changes (the car tuner's engine-feedback
  formatting — px/s + mph — is reusable here).
- Sounds: UiSfx move/select + a till "cha-ching" event via AudioDirector's
  drop-in contract.
