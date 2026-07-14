"""bgm_dock — Piers of Pain. Odd-groove heavy at 100 in 7/8 (the Soundgarden
lane): the missing 16th makes every bar lurch forward like a deck swell.
Riff leans D-F-G with the C natural; a clean-ish mid-section breathes salt
air before the wall comes back.
"""
from .. import engine as E
from .. import voices as V

SEED = 0xD0C7
BPM = 100
BARS = 68

# 2-bar 7/8 riff (28 steps) — the lurch lands the accent early every pass
RIFF = [
    (0, 2, "D2", 1.0), (2, 2, "D2", 0.75), (4, 2, "D2", 0.9), (6, 2, "F2", 1.0),
    (8, 2, "D2", 0.8), (10, 4, "G2", 1.0),
    (14, 2, "D2", 1.0), (16, 2, "D2", 0.75), (18, 2, "F2", 0.95),
    (20, 2, "G2", 1.0), (22, 2, "C3", 0.95), (24, 4, "D2", 1.0),
]
BASS = [
    (0, 2, "D2", 1.0), (2, 2, "D2", 0.8), (4, 2, "D2", 1.0), (6, 2, "F2", 1.0),
    (8, 2, "D2", 0.8), (10, 2, "G2", 1.0), (12, 2, "G2", 0.8),
    (14, 2, "D2", 1.0), (16, 2, "D2", 0.8), (18, 2, "F2", 1.0),
    (20, 2, "G2", 1.0), (22, 2, "C3", 0.95), (24, 2, "D2", 1.0), (26, 2, "D2", 0.8),
]
# clean drift for the mid-section (2-bar tile)
DRIFT = [
    (0, 6, "D3", 0.8), (7, 6, "F3", 0.7), (14, 6, "C3", 0.8), (21, 6, "G3", 0.7),
]

KICK = "X..x..X..x..x."
SNARE = "....X......X.."
HATS = "x.x.x.x.x.x.x."


def build():
    song = E.Song(BPM, BARS, SEED, beats_per_bar=3.5)  # 14 steps = 7/8

    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED) * 0.6, 0, 0)
    for lo, hi in [(0, 8), (67, 69)]:
        song.add("drone", V.drone(E.hz("D1"), song.sec(hi - lo)) * 0.9, lo, 0)

    # INTRO 0-8: bass finds the lurch, drums fall in at 4
    song.notes("bass", BASS, (0, 8), V.bass_render(1.2), every_bars=2)
    song.hits("drums", KICK, (4, 8), lambda v: V.kick(v), vel=0.85, rotate=2)
    song.hits("drums", HATS, (4, 8), lambda v: V.hat(False, v), vel=0.55, rotate=2)

    # A 8-24 / DRIFT 24-36 / A2 36-52 / DOUBLE 52-60 / A3 60-68
    _full(song, 8, 24)

    song.hits("drums", KICK, (24, 36), lambda v: V.kick(v), vel=0.75, rotate=2)
    song.hits("drums", SNARE, (28, 36), lambda v: V.snare(v), vel=0.7, rotate=2)
    song.hits("drums", HATS, (24, 36), lambda v: V.hat(False, v), vel=0.45,
        rotate=2)
    song.notes("gtrclean", DRIFT, (24, 36), V.gtr_lane_render_clean(6),
        every_bars=2)
    song.notes("bass", BASS, (24, 36), V.bass_render(1.0), every_bars=2, gain=0.8)
    song.add("riser", V.riser(song.sec(1), seed=5), 35, 0)

    song.add("drums", V.crash(0), 36, 0)
    _full(song, 36, 52)
    song.hits("drums", ".......X......", (39, 52), lambda v: V.clank(v),
        every=4, rotate=3)

    # DOUBLE 52-60: chug density doubles — the swell peaks
    song.add("drums", V.crash(1), 52, 0)
    _full(song, 52, 60)
    song.hits("drums", "x.x.x.x.x.x.x.", (52, 60), lambda v: V.tom(v % 3),
        vel=0.5, every=2, rotate=3)

    _full(song, 60, BARS)

    # loop wrap: bass lurch alone hands back to the drone
    song.notes("bass", BASS[:6], (BARS, BARS + 1), V.bass_render(1.2),
        every_bars=2)
    song.add("drums", V.crash(2), BARS, 0)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])
    song.lanes["gtrclean"] = V._gtr_amp_clean(song.lanes["gtrclean"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "gtrclean": 0.3, "texture": -0.35,
            "riser": 0.1, "drone": 0.0, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -2.5, "gtrL": -2.5, "gtrR": -2.5, "gtrclean": -6.5,
            "texture": -16.0, "drone": -10.0, "riser": -10.0})
    return x2, song


def _full(song, lo, hi):
    song.hits("drums", KICK, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS, (lo, hi), lambda v: V.hat(False, v), vel=0.6,
        rotate=2)
    song.notes("gtrL", RIFF, (lo, hi), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", RIFF, (lo, hi), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", BASS, (lo, hi), V.bass_render(1.2), every_bars=2)
