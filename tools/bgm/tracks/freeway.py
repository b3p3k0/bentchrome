"""bgm_freeway — Freeway Firefight. Motörhead-lane speed rock at 160: the
bass IS the riff (overdriven grit 1.8, straight 8ths), drums hammer, guitars
double the grind and jump the riff up a fourth for the B section. No
half-time anywhere — the ring road never slows down.
"""
from .. import engine as E
from .. import voices as V

SEED = 0xF3EE
BPM = 160
BARS = 96

# 2-bar grind (32 steps): E boogie with the G/A/D turnaround.
RIFF = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.75), (4, 2, "E2", 0.9), (6, 2, "E2", 0.75),
    (8, 2, "G2", 1.0), (10, 2, "G2", 0.8), (12, 2, "A2", 1.0), (14, 2, "A2", 0.8),
    (16, 2, "E2", 1.0), (18, 2, "E2", 0.75), (20, 2, "E2", 0.9), (22, 2, "E2", 0.75),
    (24, 2, "D3", 1.0), (26, 2, "C3", 0.9), (28, 2, "A2", 0.95), (30, 2, "G2", 0.9),
]
# B section: same shape up a fourth (single-pass map — no cascade)
_UP = {"E2": "A2", "G2": "C3", "A2": "D3", "D3": "G3", "C3": "F3"}
RIFF_UP = [(s, l, _UP[n], v) for s, l, n, v in RIFF]

# lead double-stops for the break (2-bar tile)
LEAD = [
    (0, 3, "E4", 1.0), (4, 3, "G4", 0.9), (8, 3, "A4", 1.0), (12, 4, "G4", 0.9),
    (16, 3, "E4", 1.0), (20, 3, "D4", 0.9), (24, 8, "E4", 1.0),
]

KICK = "X.....x.X.....x."
KICK_DRIVE = "X..x..x.X..x..x."
SNARE = "....X.......X..."
HATS8 = "x.x.x.x.x.x.x.x."


def build():
    song = E.Song(BPM, BARS, SEED)
    bass = V.bass_render(grit=1.8)

    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED) * 0.6, 0, 0)

    # INTRO 0-8: the bass alone kicks the door in, drums pile on at 4
    song.notes("bass", RIFF, (0, 8), bass, every_bars=2)
    song.hits("drums", KICK, (4, 8), lambda v: V.kick(v), rotate=2)
    song.hits("drums", HATS8, (4, 8), lambda v: V.hat(False, v), vel=0.7, rotate=2)
    song.add("riser", V.riser(song.sec(1), seed=3), 7, 0)

    # A 8-24 / B 24-40 (riff up) / BREAK 40-48 / A2 48-64 / B2 64-80 / OUT 80-96
    _full(song, 8, 24, RIFF, KICK, bass)
    _full(song, 24, 40, RIFF_UP, KICK_DRIVE, bass)

    song.add("drums", V.crash(0), 40, 0)
    song.hits("drums", KICK, (40, 48), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (40, 48), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS8, (40, 48), lambda v: V.hat(False, v), vel=0.6, rotate=2)
    song.notes("bass", RIFF, (40, 48), bass, every_bars=2)
    song.notes("lead", LEAD, (40, 48), V.stab, every_bars=2)
    song.add("riser", V.riser(song.sec(1), seed=5), 47, 0)

    _full(song, 48, 64, RIFF, KICK_DRIVE, bass)
    _full(song, 64, 80, RIFF_UP, KICK_DRIVE, bass)
    _full(song, 80, 96, RIFF, KICK_DRIVE, bass)
    song.notes("lead", LEAD, (88, 96), V.stab, every_bars=2)
    for bar in (48, 64, 80):
        song.add("drums", V.crash(bar % 3), bar, 0)

    # loop-wrap accent
    song.add("drums", V.crash(2), BARS, 0)
    song.add("drums", V.kick(0), BARS, 0)
    song.notes("bass", RIFF[:4], (BARS, BARS + 1), bass, every_bars=2)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "lead": 0.2, "texture": -0.3,
            "riser": 0.1, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -1.0, "gtrL": -3.5, "gtrR": -3.5, "lead": -9.0,
            "texture": -17.0, "riser": -10.0})
    return x2, song


def _full(song, lo, hi, riff, kick_pat, bass):
    song.hits("drums", kick_pat, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS8, (lo, hi), lambda v: V.hat(False, v), vel=0.7,
        rotate=2)
    song.hits("drums", "......x.......x.", (lo, hi), lambda v: V.hat(True, v),
        vel=0.5, every=2, rotate=2)
    song.notes("gtrL", riff, (lo, hi), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", riff, (lo, hi), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", riff, (lo, hi), bass, every_bars=2)
