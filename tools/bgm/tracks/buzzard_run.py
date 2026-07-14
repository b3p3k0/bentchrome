"""bgm_buzzard_run — Route 666 Roulette. Digital hardcore at 175 (the ATR
lane): overdriven four-floor kick, snare-roll fills, hoover-adjacent rave
stabs, square-wave bass hammering 8ths. Three minutes of horde in the
mirrors — no half-time, breathers are just the floor dropping out.
"""
from .. import engine as E
from .. import voices as V

SEED = 0x666
BPM = 175
BARS = 104

# square bass hammering (1-bar tile)
BASSLINE = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.85), (4, 2, "E2", 1.0), (6, 2, "E2", 0.85),
    (8, 2, "G2", 1.0), (10, 2, "G2", 0.85), (12, 2, "F2", 1.0), (14, 2, "F2", 0.85),
]
# rave stab shout (2-bar tile)
STABS = [
    (2, 2, "E4", 1.0), (6, 2, "E4", 0.85), (10, 3, "G4", 1.0),
    (18, 2, "E4", 0.9), (24, 4, "F4", 1.0),
]
# panic lead for the final act (2-bar tile)
PANIC = [
    (0, 2, "E5", 1.0), (4, 2, "D5", 0.9), (8, 2, "E5", 1.0), (12, 2, "G5", 0.95),
    (16, 2, "E5", 1.0), (20, 2, "F5", 0.95), (24, 4, "E5", 1.0),
]

KICK4 = "X...X...X...X..."
SNARE = "....X.......X..."
ROLL = "............xxxX"
HATS_OFF = "..x...x...x...x."


def build():
    song = E.Song(BPM, BARS, SEED)

    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED) * 0.7, 0, 0)

    # INTRO 0-8: kick + bass lock in, stabs tease
    song.hits("drums", KICK4, (0, 8), lambda v: V.hard_kick(v), rotate=2)
    song.notes("bass", BASSLINE, (4, 8), V.bass_render(1.6), every_bars=1)
    song.add("riser", V.riser(song.sec(1), seed=3), 7, 0)

    # A 8-32 / BREAK 32-40 / B 40-64 / BREAK2 64-72 / C 72-96 / FIN 96-104
    _slam(song, 8, 32)
    song.notes("stab", STABS, (16, 32), V.rave_stab, every_bars=2)

    _floor_out(song, 32, 40)

    _slam(song, 40, 64)
    song.notes("stab", STABS, (40, 64), V.rave_stab, every_bars=2)
    song.hits("drums", "..............xX", (40, 64), lambda v: V.snare(v),
        vel=0.8, every=4, rotate=2)

    _floor_out(song, 64, 72)

    _slam(song, 72, 96)
    song.notes("stab", STABS, (72, 96), V.rave_stab, every_bars=2)
    song.notes("lead", PANIC, (80, 96), V.stab, every_bars=2)

    song.add("drums", V.crash(0), 96, 0)
    _slam(song, 96, BARS)
    song.notes("stab", STABS, (96, BARS), V.rave_stab, every_bars=2)
    song.notes("lead", PANIC, (96, BARS), V.stab, every_bars=2)
    song.hits("drums", ROLL, (96, BARS), lambda v: V.snare(v), vel=0.9, rotate=2)

    # loop wrap: one bar of bare kick+bass — the chase never actually ends
    song.hits("drums", KICK4, (BARS, BARS + 1), lambda v: V.hard_kick(v), rotate=2)
    song.notes("bass", BASSLINE, (BARS, BARS + 1), V.bass_render(1.6), every_bars=1)

    x2 = song.mix(
        pans={"stab": 0.4, "lead": -0.4, "texture": -0.3, "riser": 0.1,
            "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -1.5, "stab": -6.5, "lead": -9.0, "texture": -16.0,
            "riser": -9.0})
    return x2, song


def _slam(song, lo, hi):
    song.hits("drums", KICK4, (lo, hi), lambda v: V.hard_kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS_OFF, (lo, hi), lambda v: V.hat(True, v), vel=0.6,
        rotate=2)
    song.hits("drums", ROLL, (lo, hi), lambda v: V.snare(v), vel=0.7, every=8,
        rotate=2)
    song.notes("bass", BASSLINE, (lo, hi), V.bass_render(1.6), every_bars=1)


def _floor_out(song, lo, hi):
    """Breather: kick gone, bass + offbeat hats keep the wheels turning."""
    song.notes("bass", BASSLINE, (lo, hi), V.bass_render(1.6), every_bars=1)
    song.hits("drums", HATS_OFF, (lo, hi), lambda v: V.hat(True, v), vel=0.5,
        rotate=2)
    song.notes("stab", STABS, (lo + 4, hi), V.rave_stab, every_bars=2, gain=0.7)
    song.add("riser", V.riser(song.sec(1), seed=lo), hi - 1, 0)
