"""bgm_depot — Lackey's Arena. Miniboss menace at 126: Phrygian riff (the F
and Bb leans against E), artillery toms, clank on the backbeat, dissonant
stabs circling overhead. Heavier air than the arena stomp — this yard has a
turret tracking you.
"""
from .. import engine as E
from .. import voices as V

SEED = 0xDE97
BPM = 126
BARS = 72

# 2-bar Phrygian grind (32 steps)
RIFF = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.75), (4, 2, "E2", 0.9), (6, 2, "F2", 1.0),
    (8, 2, "E2", 0.8), (10, 2, "E2", 0.75), (12, 4, "F2", 1.0),
    (16, 2, "E2", 1.0), (18, 2, "E2", 0.75), (20, 2, "E2", 0.9), (22, 2, "F2", 1.0),
    (24, 2, "Bb2", 1.0), (26, 2, "Bb2", 0.85), (28, 4, "A2", 1.0),
]
# half-time hammer for the C section (4-bar / 64-step tile)
HAMMER = [
    (0, 12, "E2", 1.0), (16, 12, "F2", 1.0),
    (32, 12, "E2", 1.0), (48, 8, "Bb2", 1.0), (56, 8, "A2", 0.9),
]
BASS = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.8), (4, 2, "E2", 1.0), (6, 2, "F2", 1.0),
    (8, 2, "E2", 0.8), (10, 2, "E2", 0.8), (12, 2, "F2", 1.0), (14, 2, "F2", 0.8),
    (16, 2, "E2", 1.0), (18, 2, "E2", 0.8), (20, 2, "E2", 1.0), (22, 2, "F2", 1.0),
    (24, 2, "Bb2", 1.0), (26, 2, "Bb2", 0.8), (28, 2, "A2", 1.0), (30, 2, "A2", 0.8),
]
# circling dissonant stab (2-bar tile)
MENACE = [
    (0, 3, "E4", 1.0), (5, 2, "F4", 0.85), (10, 3, "E4", 0.9), (16, 4, "Bb3", 1.0),
    (24, 4, "A3", 0.9),
]

KICK = "X..x..x.X...x..."
SNARE = "....X.......X..."
HATS = "x.xxx.xxx.xxx.xx"
TOMS = "........x.x.xx.."


def build():
    song = E.Song(BPM, BARS, SEED)

    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED) * 0.8, 0, 0)
    for lo, hi in [(0, 10), (71, 73)]:
        song.add("drone", V.drone(E.hz("E1"), song.sec(hi - lo)), lo, 0)

    # INTRO 0-8: drone + tom artillery walking closer
    for i, bar in enumerate(range(2, 8)):
        song.add("drums", V.tom(i % 3), bar, [0, 4, 8, 10, 12, 14][i], 0.7)
    song.hits("drums", "X.......X.......", (4, 8), lambda v: V.kick(v), vel=0.8,
        rotate=2)
    song.add("riser", V.riser(song.sec(1), seed=3), 7, 0)

    # A 8-24 / B(menace break) 24-32 / A2 32-48 / C(hammer) 48-56 / A3 56-72
    _full(song, 8, 24)
    song.hits("drums", "........X.......", (11, 24), lambda v: V.clank(v),
        every=4, rotate=3)

    song.hits("drums", KICK, (24, 32), lambda v: V.kick(v), rotate=2)
    song.hits("drums", TOMS, (24, 32), lambda v: V.tom(v % 3), vel=0.8, rotate=3)
    song.notes("bass", BASS, (24, 32), V.bass_render(1.2), every_bars=2)
    song.notes("stab", MENACE, (24, 32), V.stab, every_bars=2)
    song.add("riser", V.riser(song.sec(1), seed=5), 31, 0)

    _full(song, 32, 48)
    song.notes("stab", MENACE, (36, 48), V.stab, every_bars=4)
    song.hits("drums", "........X.......", (35, 48), lambda v: V.clank(v),
        every=4, rotate=3)

    song.add("drums", V.crash(0), 48, 0)
    song.hits("drums", "X.......x.......", (48, 56), lambda v: V.kick(v), rotate=2)
    song.hits("drums", "........X.......", (48, 56), lambda v: V.snare(v), rotate=2)
    song.hits("drums", TOMS, (48, 56), lambda v: V.tom(v % 3), vel=0.9, rotate=3)
    song.notes("gtrL", HAMMER, (48, 56), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", HAMMER, (48, 56), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", HAMMER, (48, 56), V.bass_render(1.2), every_bars=4)

    song.add("drums", V.crash(1), 56, 0)
    _full(song, 56, 72)
    song.hits("drums", "........X.......", (57, 72), lambda v: V.clank(v),
        every=2, rotate=3)
    song.notes("stab", MENACE, (64, 72), V.stab, every_bars=4)

    # loop wrap: a tom figure hands back to the intro drone
    song.add("drums", V.crash(2), BARS, 0)
    song.add("drums", V.tom(0), BARS, 0)
    song.add("drums", V.tom(1), BARS, 4, 0.8)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "stab": -0.3, "texture": 0.3,
            "riser": 0.1, "drone": 0.0, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -2.5, "gtrL": -2.5, "gtrR": -2.5, "stab": -10.0,
            "texture": -14.0, "drone": -9.0, "riser": -9.0})
    return x2, song


def _full(song, lo, hi):
    song.hits("drums", KICK, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS, (lo, hi), lambda v: V.hat(False, v), vel=0.6,
        rotate=2)
    song.notes("gtrL", RIFF, (lo, hi), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", RIFF, (lo, hi), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", BASS, (lo, hi), V.bass_render(1.2), every_bars=2)
