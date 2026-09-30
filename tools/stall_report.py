#!/usr/bin/env python3
"""Summarize one or more stall-probe logs. This report never acts as a gate."""

from __future__ import annotations

import collections
import re
import sys
from pathlib import Path


FPS = 60.0
STALL_RE = re.compile(
    r"^\[stall\] seed=-?\d+ t=[\d.]+ car=\S+ secs=(?P<secs>[\d.]+) "
    r"pos=\([^)]*\) cell=\((?P<i>-?\d+),(?P<j>-?\d+)\) "
    r"mode=(?P<mode>[A-Z_]+) guard=(?P<guard>true|false)(?: open=true)?$"
)
FALL_RE = re.compile(r"^\[fall\].*\swhy=(?P<why>\S+)\s")
DONE_RE = re.compile(
    r"^\[done\] seed=-?\d+ frames=(?P<frames>\d+) car_frames=(?P<car_frames>\d+)$"
)


def load_report(path: Path) -> dict:
    report = {
        "matches": 0,
        "car_frames": 0,
        "falls": collections.Counter(),
        "stalls": [],
    }
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        print(f"stall_report: {path}: {error}", file=sys.stderr)
        return report

    for line in lines:
        done = DONE_RE.match(line)
        if done:
            report["matches"] += 1
            report["car_frames"] += int(done.group("car_frames"))
            continue
        fall = FALL_RE.match(line)
        if fall:
            report["falls"][fall.group("why")] += 1
            continue
        stall = STALL_RE.match(line)
        if stall:
            report["stalls"].append(
                {
                    "secs": float(stall.group("secs")),
                    "cell": (int(stall.group("i")), int(stall.group("j"))),
                    "mode": stall.group("mode"),
                    "guard": stall.group("guard") == "true",
                }
            )
    return report


def seconds(value: float) -> str:
    return f"{value:.1f}s"


def ranked_seconds(values: dict, formatter, limit: int | None = None) -> str:
    ranked = sorted(values.items(), key=lambda item: (-item[1], item[0]))
    if limit is not None:
        ranked = ranked[:limit]
    if not ranked:
        return "none"
    return ", ".join(f"{formatter(key)}={seconds(value)}" for key, value in ranked)


def format_cell(cell: tuple[int, int]) -> str:
    return f"({cell[0]},{cell[1]})"


def format_mode(key: tuple[str, bool]) -> str:
    return f"({key[0]},{str(key[1]).lower()})"


def print_report(label: str, report: dict) -> None:
    stalls = report["stalls"]
    stalled_seconds = sum(row["secs"] for row in stalls)
    car_seconds = report["car_frames"] / FPS
    share = 100.0 * stalled_seconds / car_seconds if car_seconds else 0.0
    longest = max((row["secs"] for row in stalls), default=0.0)

    cells = collections.defaultdict(float)
    modes = collections.defaultdict(float)
    for row in stalls:
        cells[row["cell"]] += row["secs"]
        modes[(row["mode"], row["guard"])] += row["secs"]

    falls = report["falls"]
    fall_total = sum(falls.values())
    fall_parts = ", ".join(
        f"{why}={falls[why]}" for why in ("after-air", "after-hit", "drove")
    )
    print(f"== {label} ==")
    print(f"matches: {report['matches']}")
    print(f"car-seconds observed: {seconds(car_seconds)}")
    print(f"falls: {fall_total} ({fall_parts})")
    print(f"stalls: {len(stalls)}")
    print(f"share of car-time stalled: {share:.1f}%")
    print(f"longest stall: {seconds(longest)}")
    print(f"ten worst cells: {ranked_seconds(cells, format_cell, 10)}")
    print(f"seconds per (mode, guard): {ranked_seconds(modes, format_mode)}")


def main(arguments: list[str]) -> int:
    if not arguments:
        print("usage: tools/stall_report.py label=path [label=path ...]", file=sys.stderr)
        return 0
    for argument in arguments:
        label, separator, raw_path = argument.partition("=")
        if not separator or not label or not raw_path:
            print(f"stall_report: expected label=path, got {argument!r}", file=sys.stderr)
            continue
        print_report(label, load_report(Path(raw_path)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
