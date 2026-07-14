"""bgm_stadium_p1 — Goliath's Arena, trailered phase. Doom stomp at 90 under
stadium night air: the E/G/Bb progression rung out long, tom artillery,
distant crowd roar, bell-dark clanks. Heavy like ten axles.
"""
from .. import engine as E
from .. import voices as V
from . import stadium_common as C

SEED = 0x601A
BPM = 90
BARS = 54
MASTER = {"reverb_wet": 0.12, "room": 0.6}

KICK = "X.......x.x....."
SNARE = "........X......."
TOMS = "..........x.x.xx"


def build():
    song = E.Song(BPM, BARS, SEED)

    song.add("crowd", V.crowd_swell(song.total / E.SR, seed=SEED), 0, 0)
    for lo, hi in [(0, 8), (53, 55)]:
        song.add("drone", V.drone(E.hz("E1"), song.sec(hi - lo)), lo, 0)

    # INTRO 0-6: crowd + war toms
    for i, bar in enumerate(range(1, 6)):
        song.add("drums", V.tom(i % 3), bar, [0, 6, 8, 12, 14][i], 0.75)
    song.hits("drums", "X...............", (3, 6), lambda v: V.kick(v), vel=0.8,
        rotate=2)
    song.add("riser", V.riser(song.sec(1), seed=3), 5, 0)

    # A 6-18 / B 18-26 (toms + bass) / A2 26-38 / C 38-46 (8th push) / A3 46-54
    _doom(song, 6, 18)
    song.hits("drums", "........X.......", (9, 18), lambda v: V.clank(v),
        every=4, rotate=3)

    song.hits("drums", KICK, (18, 26), lambda v: V.kick(v), rotate=2)
    song.hits("drums", TOMS, (18, 26), lambda v: V.tom(v % 3), vel=0.85, rotate=3)
    song.notes("bass", C.DOOM_BASS, (18, 26), V.bass_render(1.3), every_bars=4)
    song.add("riser", V.riser(song.sec(1), seed=5), 25, 0)

    _doom(song, 26, 38)
    song.hits("drums", "........X.......", (29, 38), lambda v: V.clank(v),
        every=4, rotate=3)

    # C: the stomp doubles its steps — a hint of what phase 2 becomes
    song.add("drums", V.crash(0), 38, 0)
    song.hits("drums", "X...x...X...x...", (38, 46), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (38, 46), lambda v: V.snare(v), rotate=2)
    song.notes("gtrL", C.RAGE, (38, 46), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", C.RAGE, (38, 46), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", C.DOOM_BASS, (38, 46), V.bass_render(1.3), every_bars=4)

    song.add("drums", V.crash(1), 46, 0)
    _doom(song, 46, BARS)
    song.hits("drums", TOMS, (46, BARS), lambda v: V.tom(v % 3), vel=0.7,
        every=2, rotate=3)

    # loop wrap: toms hand back to the crowd
    song.add("drums", V.crash(2), BARS, 0)
    song.add("drums", V.tom(0), BARS, 0)
    song.add("drums", V.tom(1), BARS, 6, 0.8)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "crowd": 0.35, "riser": 0.1,
            "drone": 0.0, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -2.5, "gtrL": -2.5, "gtrR": -2.5, "crowd": -13.0,
            "drone": -9.0, "riser": -10.0})
    return x2, song


def _doom(song, lo, hi):
    song.hits("drums", KICK, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", "x...x...x...x...", (lo, hi), lambda v: V.hat(False, v),
        vel=0.5, rotate=2)
    song.notes("gtrL", C.DOOM, (lo, hi), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", C.DOOM, (lo, hi), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", C.DOOM_BASS, (lo, hi), V.bass_render(1.3), every_bars=4)
