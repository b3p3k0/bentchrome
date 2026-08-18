#!/usr/bin/env python3
"""One-shot roster.json schema-v2 migration (2026-07 stats rebase).

Phases (run from anywhere; edits assets/data/roster.json in place):
  --profiles-only     extract shared terrain tables into named top-level
                      terrain_profiles and point the cars at them (step 3).
  (default)           the scale flip (step 4): profiles if still pending,
                      then every 1-10 design int (5 stats + mass) -> 2v-1 on
                      the 1-20 scale, and a schema_version: 2 stamp.
  --car ID --dry-run  preview one car's migration, write nothing.
  --dry-run           preview the whole fleet, write nothing.
  --fold EXPORT.json  fold an in-game F3 car-tuner export (user://
                      car_tuner_export.json) into roster.json — surgical int
                      updates only, formatting preserved — then auto-run the
                      headless importer so the .tres match. --roster PATH
                      retargets the roster (testing; skips the auto-import).

The 2v-1 mapping is feel-frozen by construction: StatCurves' 20-slot tables
put every odd slot exactly on the legacy 1-10 line (see tests/test_stat_rebase.gd).
Committed for audit; safe to re-run (each phase no-ops once applied).
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROSTER = Path(__file__).resolve().parent.parent / "assets" / "data" / "roster.json"

# profile name -> (car whose table becomes the profile, cars that must carry an
# identical table and join the profile). Lovebug's single water entry stays
# inline on purpose: it keeps the per-car overlay path exercised.
PROFILE_SOURCES = {
    "awd_utility": ("warpig", ["smoky"]),
    "monster_tires": ("hammertoe", []),
    "dirt_racer": ("cricket", []),
    "racing_slicks": ("cyclone", []),
    "snowplow": ("coldfront", []),
}

STAT_KEYS = ["acceleration", "top_speed", "handling", "armor", "special_power"]
MPH_PER_PXS = 0.15  # ui/hud.gd display anchor (US units only)
ENGINE_RANGES = {   # legacy lo/hi, for the dry-run readout
    "acceleration": (80.0, 365.0, "px/s^2"),
    "top_speed": (360.0, 640.0, "px/s"),
    "handling": (130.0, 250.0, "deg/s"),
    "armor": (70.0, 180.0, "HP"),
}


def legacy_engine(v, lo, hi):
    return lo + (hi - lo) * (v - 1) / 9.0


def table_engine(s, lo, hi):
    return lo + (hi - lo) * (s - 1) / 18.0


def replace_key(d, old_key, new_key, new_val):
    """Swap old_key for new_key/new_val preserving the entry's position."""
    items = [(new_key, new_val) if k == old_key else (k, v) for k, v in d.items()]
    d.clear()
    d.update(items)


def extract_profiles(data):
    if "terrain_profiles" in data:
        return False
    cars = {c["id"]: c for c in data["characters"]}
    profiles = {}
    for name, (source_id, twins) in PROFILE_SOURCES.items():
        table = cars[source_id]["terrain_modifiers"]
        for twin in twins:
            if cars[twin]["terrain_modifiers"] != table:
                sys.exit(f"migrate: {twin} table differs from {source_id}; "
                         f"refusing to merge into '{name}'")
        profiles[name] = table
        for cid in [source_id, *twins]:
            replace_key(cars[cid], "terrain_modifiers", "terrain_profile", name)
    items = list(data.items())
    items.insert(0, ("terrain_profiles", profiles))
    data.clear()
    data.update(items)
    return True


def rescale(data):
    if data.get("schema_version") == 2:
        return False
    for c in data["characters"]:
        for k in STAT_KEYS:
            c["stats"][k] = 2 * c["stats"][k] - 1
        c["mass"] = 2 * c["mass"] - 1
    items = list(data.items())
    items.insert(0, ("schema_version", 2))
    data.clear()
    data.update(items)
    return True


def preview(data, only_id):
    migrated = data.get("schema_version") == 2
    for c in data["characters"]:
        if only_id and c["id"] != only_id:
            continue
        print(f"== {c['id']} (roster values are {'1-20' if migrated else '1-10'})")
        for k in STAT_KEYS + ["mass"]:
            old = c["stats"][k] if k != "mass" else c["mass"]
            new = old if migrated else 2 * old - 1
            line = f"  {k:14} {old:>2} -> {new:>2}"
            if k in ENGINE_RANGES:
                lo, hi, unit = ENGINE_RANGES[k]
                before = legacy_engine(old if not migrated else (old + 1) // 2, lo, hi)
                after = table_engine(new, lo, hi)
                line += f"   engine {before:.6f} -> {after:.6f} {unit}"
                if k == "top_speed":
                    line += f" ({before * MPH_PER_PXS:.1f} -> {after * MPH_PER_PXS:.1f} mph)"
                if before != after:
                    line += "   *** FEEL MOVED ***"
            print(line)
        pname = c.get("terrain_profile")
        if pname:
            surfaces = ", ".join(data.get("terrain_profiles", {}).get(pname, {}))
            print(f"  terrain_profile '{pname}' ({surfaces})")
        if c.get("terrain_modifiers"):
            print(f"  inline terrain_modifiers: {', '.join(c['terrain_modifiers'])}")


# --- fold: F3 car-tuner export -> roster.json (game truth) --------------------

# prop -> (band lo, band hi, is_float, roster default or None if always present)
FOLD_PROPS = {
    "acceleration": (1, 20, False, None),
    "top_speed": (1, 20, False, None),
    "handling": (1, 20, False, None),
    "armor": (1, 20, False, None),
    "special_power": (1, 20, False, None),
    "mass": (1, 20, False, None),
    "launch": (0, 20, False, 0),
    "special_ammo_cap": (1, 9, False, 1),
    "special_recharge_seconds": (1.0, 300.0, True, 12.0),
    "whip_scale": (0.5, 2.0, True, 1.0),
    "side_slide_bonus": (1.0, 3.0, True, 1.5),
}


def _fold_car(c, row):
    """Fold one export row into one roster character. Returns changed props."""
    changed = []
    for prop, (lo, hi, is_float, default) in FOLD_PROPS.items():
        if prop not in row:
            continue
        v = float(row[prop]) if is_float else int(row[prop])
        if not lo <= v <= hi:
            sys.exit(f"fold: {c['id']}.{prop} = {v} outside [{lo}, {hi}]")
        in_stats = prop not in ("mass", "special_ammo_cap", "special_recharge_seconds",
                                "whip_scale", "side_slide_bonus")
        holder = c["stats"] if in_stats else c
        current = holder.get(prop, default)
        if is_float:
            if abs(float(current) - v) < 1e-6:
                continue
        elif int(current) == v:
            continue
        if prop == "launch" and v == 0:
            holder.pop(prop, None)  # 0 = mass-derived sentinel, authored by omission
        else:
            holder[prop] = v
        changed.append(prop)
    return changed


def fold(export_path, roster_path, run_import):
    export = json.loads(Path(export_path).read_text())
    if int(export.get("schema_version", 0)) != 2:
        sys.exit("fold: export is not schema_version 2")
    data = json.loads(roster_path.read_text())
    if data.get("schema_version") != 2:
        sys.exit("fold: roster is not schema_version 2")
    cars = {c["id"]: c for c in data["characters"]}
    total = 0
    for cid, row in export.get("cars", {}).items():
        if cid not in cars:
            sys.exit(f"fold: unknown car id '{cid}'")
        changed = _fold_car(cars[cid], row)
        if changed:
            total += len(changed)
            print(f"fold: {cid}: {', '.join(changed)}")
    if total == 0:
        print("fold: no changes — roster.json untouched")
        return
    roster_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"fold: wrote {roster_path} ({total} values)")
    if not run_import:
        print("fold: custom --roster — skipping the importer; run it yourself when ready")
        return
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") \
        or str(Path.home() / ".local/bin/godot")
    if not Path(godot).exists():
        print("fold: WARNING — no godot binary found (GODOT_BIN/PATH/~/.local/bin); "
              "run the importer yourself: godot --headless --path . -s res://tools/import_roster.gd")
        return
    print("fold: running the importer to regenerate data/vehicles/*.tres ...")
    result = subprocess.run(
        [godot, "--headless", "--path", str(roster_path.parent.parent.parent),
         "-s", "res://tools/import_roster.gd"])
    if result.returncode != 0:
        sys.exit(result.returncode)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--profiles-only", action="store_true")
    ap.add_argument("--car")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--fold", metavar="EXPORT_JSON")
    ap.add_argument("--roster", metavar="ROSTER_JSON")
    args = ap.parse_args()
    if args.car and not args.dry_run:
        sys.exit("migrate: --car is a preview filter; pair it with --dry-run")

    roster_path = Path(args.roster) if args.roster else ROSTER
    if args.fold:
        fold(args.fold, roster_path, run_import=args.roster is None)
        return

    data = json.loads(roster_path.read_text())
    if args.dry_run:
        preview(data, args.car)
        return

    changed = extract_profiles(data)
    if not args.profiles_only:
        changed = rescale(data) or changed
    if not changed:
        print("migrate: nothing to do (already applied)")
        return
    roster_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"migrate: wrote {roster_path}")


if __name__ == "__main__":
    main()
