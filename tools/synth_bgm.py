#!/usr/bin/env python3
"""Procedural BGM generator for Bent Chrome — the regeneration source for
every assets/bgm/*.ogg. Runs on the repo venv (pedalboard + scipy + numpy):

    ./venv312/bin/python tools/synth_bgm.py               # render all tracks
    ./venv312/bin/python tools/synth_bgm.py bgm_arena     # just one
    ./venv312/bin/python tools/synth_bgm.py bgm_arena --analyze
    ./venv312/bin/python tools/synth_bgm.py --wav-only    # audition in /tmp

Unlike synth_sfx.py, renders here are 2-4 minute stereo seamless loops:
compose bars+1, master, wrap-crossfade the tail bar over the head, write with
no declick fade. Deterministic seeds per track. Engine/voices/mastering live
in tools/bgm/; references are analysis-only (assets/bgm/refs.md), never
sampled. Only the rendered oggs ship — the game contains zero synthesis code.
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bgm import master, analyze
from bgm.tracks import TRACKS


def main(argv):
    wav_only = "--wav-only" in argv
    do_analyze = "--analyze" in argv
    names = [a for a in argv if not a.startswith("--")]
    if not names:
        names = list(TRACKS)
    unknown = [n for n in names if n not in TRACKS]
    if unknown:
        print("unknown tracks: %s\nknown: %s" % (", ".join(unknown),
            ", ".join(TRACKS)))
        return 1
    for name in names:
        print("== %s" % name)
        x2, song = TRACKS[name].build()
        wav_path = master.finalize(name, x2, song, wav_only)
        if do_analyze:
            analyze.report(wav_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
