"""bgm_ground_floor_gore — the construction site. Industrial metal at 135
(deep Ministry lane): 16th gallop kick, chromatic-descent riff, pile-driver
thuds, air-wrench rattle, machine room loud in the mix. The site equipment
is part of the band.
"""
from .. import engine as E
from .. import voices as V

SEED = 0x60E5
BPM = 135
BARS = 80

# 2-bar chromatic descent (32 steps): E..G / E..F#-F — the drill bites down
RIFF = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.75), (4, 2, "E2", 0.9), (6, 2, "E2", 0.75),
    (8, 2, "G2", 1.0), (10, 2, "G2", 0.8), (12, 4, "E2", 0.95),
    (16, 2, "E2", 1.0), (18, 2, "E2", 0.75), (20, 2, "E2", 0.9), (22, 2, "E2", 0.75),
    (24, 2, "F#2", 1.0), (26, 2, "F#2", 0.85), (28, 4, "F2", 1.0),
]
BASS = [(s, l, n, v) for s, l, n, v in RIFF]
# grinding half-time slab (4-bar tile)
SLAB = [
    (0, 12, "E2", 1.0), (16, 12, "G2", 1.0),
    (32, 12, "F#2", 1.0), (48, 12, "F2", 1.0),
]

GALLOP = "X..xX..xX..xX..x"
SNARE = "....X.......X..."
HATS = "x.xxx.xxx.xxx.xx"
PILE = "X..............."


def build():
    song = E.Song(BPM, BARS, SEED)

    # the machine room is LOUD here — it's the site's own backing track
    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED), 0, 0)
    for lo, hi in [(0, 10), (79, 81)]:
        song.add("drone", V.drone(E.hz("E1"), song.sec(hi - lo)), lo, 0)

    # INTRO 0-8: pile driver + air wrench set the tempo before the band does
    song.hits("machines", PILE, (0, 8), lambda v: V.pile_thud(v), rotate=2)
    for i, bar in enumerate(range(1, 8, 2)):
        song.add("machines", V.air_rattle(0.5, seed=i), bar, 8, 0.8)
    song.hits("drums", GALLOP, (6, 8), lambda v: V.kick(v), vel=0.8, rotate=2)
    song.add("riser", V.riser(song.sec(1), seed=3), 7, 0)

    # A 8-24 / B 24-32 (machines forward) / A2 32-48 / SLAB 48-56 / A3 56-72 / OUT 72-80
    _gallop(song, 8, 24)
    song.hits("drums", "........X.......", (11, 24), lambda v: V.clank(v),
        every=2, rotate=3)

    song.hits("machines", PILE, (24, 32), lambda v: V.pile_thud(v), rotate=2)
    song.hits("drums", GALLOP, (24, 32), lambda v: V.kick(v), rotate=2)
    song.notes("bass", BASS, (24, 32), V.bass_render(1.4), every_bars=2)
    for i, bar in enumerate(range(25, 32, 2)):
        song.add("machines", V.air_rattle(0.4, seed=10 + i), bar, 12, 0.9)
    song.add("riser", V.riser(song.sec(1), seed=5), 31, 0)

    _gallop(song, 32, 48)
    song.hits("drums", "........X.......", (35, 48), lambda v: V.clank(v),
        every=2, rotate=3)
    song.hits("machines", PILE, (36, 48), lambda v: V.pile_thud(v), every=4,
        rotate=2)

    song.add("drums", V.crash(0), 48, 0)
    song.hits("drums", "X.......x.......", (48, 56), lambda v: V.kick(v), rotate=2)
    song.hits("drums", "........X.......", (48, 56), lambda v: V.snare(v), rotate=2)
    song.hits("machines", PILE, (48, 56), lambda v: V.pile_thud(v), rotate=2)
    song.notes("gtrL", SLAB, (48, 56), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", SLAB, (48, 56), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", SLAB, (48, 56), V.bass_render(1.4), every_bars=4)

    song.add("drums", V.crash(1), 56, 0)
    _gallop(song, 56, 72)
    song.hits("drums", "........X.......", (57, 72), lambda v: V.clank(v),
        every=2, rotate=3)

    _gallop(song, 72, BARS)
    song.hits("machines", PILE, (72, BARS), lambda v: V.pile_thud(v), every=2,
        rotate=2)

    # loop wrap: the pile driver alone — the site never clocks out
    song.hits("machines", PILE, (BARS, BARS + 1), lambda v: V.pile_thud(v),
        rotate=2)
    song.add("drums", V.crash(2), BARS, 0)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "machines": 0.4, "texture": -0.45,
            "riser": 0.1, "drone": 0.0, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -2.0, "gtrL": -2.5, "gtrR": -2.5, "machines": -6.0,
            "texture": -11.0, "drone": -9.0, "riser": -9.0})
    return x2, song


def _gallop(song, lo, hi):
    song.hits("drums", GALLOP, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS, (lo, hi), lambda v: V.hat(False, v), vel=0.55,
        rotate=2)
    song.notes("gtrL", RIFF, (lo, hi), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", RIFF, (lo, hi), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", BASS, (lo, hi), V.bass_render(1.4), every_bars=2)
