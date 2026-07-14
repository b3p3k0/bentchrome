"""bgm_stadium_p2 — Goliath bobtail. The p1 progression enraged: 150 BPM
gallop on the same E/G/Bb changes, rave-stab bellows, snare-roll charges,
the crowd now a wall. Arrives mid-fight via MusicDirector.set_override from
goliath_boss.start_phase2().
"""
from .. import engine as E
from .. import voices as V
from . import stadium_common as C

SEED = 0x601B
BPM = 150
BARS = 90
MASTER = {"reverb_wet": 0.1, "room": 0.55}

# bellow stabs (2-bar tile) — the boss shouting back
BELLOW = [(0, 3, "E3", 1.0), (8, 3, "G3", 0.9), (16, 3, "E3", 1.0),
    (24, 4, "Bb3", 1.0)]

KICK = "X..xX..xX..xX..x"
SNARE = "....X.......X..."
HATS = "x.xxx.xxx.xxx.xx"
ROLL = "............xxxX"


def build():
    song = E.Song(BPM, BARS, SEED)

    song.add("crowd", V.crowd_swell(song.total / E.SR, seed=SEED) * 1.2, 0, 0)

    # INTRO 0-4: drums roll straight in — the cutscene already built the drop
    song.hits("drums", KICK, (0, 4), lambda v: V.kick(v), rotate=2)
    song.hits("drums", ROLL, (0, 4), lambda v: V.snare(v), vel=0.8, rotate=2)
    song.notes("bass", C.RAGE, (2, 4), V.bass_render(1.5), every_bars=2)

    # A 4-24 / B 24-32 (toms charge) / A2 32-52 / SLAM 52-64 / A3 64-84 / OUT 84-90
    _rage(song, 4, 24)
    song.notes("stab", BELLOW, (12, 24), V.rave_stab, every_bars=2)

    song.hits("drums", KICK, (24, 32), lambda v: V.kick(v), rotate=2)
    song.hits("drums", "..x...x...x...x.", (24, 32), lambda v: V.tom(v % 3),
        vel=0.85, rotate=3)
    song.notes("bass", C.RAGE, (24, 32), V.bass_render(1.5), every_bars=2)
    song.add("riser", V.riser(song.sec(1), seed=5), 31, 0)

    song.add("drums", V.crash(0), 32, 0)
    _rage(song, 32, 52)
    song.notes("stab", BELLOW, (32, 52), V.rave_stab, every_bars=2)
    song.hits("drums", "........X.......", (35, 52), lambda v: V.clank(v),
        every=2, rotate=3)

    # SLAM: half-time weight — the p1 doom gene resurfaces at speed
    song.add("drums", V.crash(1), 52, 0)
    song.hits("drums", "X.......x.......", (52, 64), lambda v: V.kick(v), rotate=2)
    song.hits("drums", "........X.......", (52, 64), lambda v: V.snare(v), rotate=2)
    song.notes("gtrL", C.DOOM, (52, 64), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", C.DOOM, (52, 64), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", C.DOOM_BASS, (52, 64), V.bass_render(1.5), every_bars=4)

    song.add("drums", V.crash(2), 64, 0)
    _rage(song, 64, 84)
    song.notes("stab", BELLOW, (64, 84), V.rave_stab, every_bars=2)
    song.hits("drums", ROLL, (64, 84), lambda v: V.snare(v), vel=0.8, every=4,
        rotate=2)

    _rage(song, 84, BARS)
    song.hits("drums", ROLL, (84, BARS), lambda v: V.snare(v), vel=0.9, rotate=2)

    # loop wrap: kick + roll — the rage doesn't wind down
    song.hits("drums", KICK, (BARS, BARS + 1), lambda v: V.kick(v), rotate=2)
    song.notes("bass", C.RAGE, (BARS, BARS + 1), V.bass_render(1.5), every_bars=2)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "stab": 0.35, "crowd": -0.35,
            "riser": 0.1, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -1.5, "gtrL": -2.5, "gtrR": -2.5, "stab": -8.5,
            "crowd": -14.0, "riser": -9.0})
    return x2, song


def _rage(song, lo, hi):
    song.hits("drums", KICK, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS, (lo, hi), lambda v: V.hat(False, v), vel=0.6,
        rotate=2)
    song.notes("gtrL", C.RAGE, (lo, hi), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", C.RAGE, (lo, hi), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", C.RAGE, (lo, hi), V.bass_render(1.5), every_bars=2)
