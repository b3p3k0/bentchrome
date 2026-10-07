# Lessons Learned

## Target designation

- A durable target is vehicle state, not weapon state. Keeping it in a small child component gives weapons and presentation one owner without expanding the near-limit `Vehicle` script.
- Driver target preference and stable-nearest fallback are separate policies. The shared designator can reuse AI commitment while player and network drivers remain free of targeting state.
- Stateless nearest-query fallbacks remain useful for fixtures and non-vehicle callers. The weapon cutover should preserve that compatibility while making real vehicles authoritative through their designator.
