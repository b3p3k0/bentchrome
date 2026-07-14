"""bgm_suburbs — Suburban Slaughter. Drop-tuned grunge sludge at 95: the
quiet/loud trick — clean-ish arpeggiated verses over a lazy beat, then the
choruses drop the D5-F5-G5-Bb5 wall. Sabbath weight, flannel pacing.
"""
from .. import engine as E
from .. import voices as V

SEED = 0x5AB5
BPM = 95
BARS = 56

# clean verse arpeggio, 2-bar tile (Dm wash with the b6 lean)
VERSE = [
    (0, 4, "D3", 0.8), (4, 4, "F3", 0.7), (8, 4, "A3", 0.75), (12, 4, "F3", 0.65),
    (16, 4, "C3", 0.8), (20, 4, "E3", 0.7), (24, 4, "G3", 0.75), (28, 4, "E3", 0.65),
]
# chorus sludge wall, 4-bar tile (64 steps)
CHORUS = [
    (0, 12, "D2", 1.0), (12, 4, "D2", 0.8),
    (16, 12, "F2", 1.0), (28, 4, "F2", 0.8),
    (32, 12, "G2", 1.0), (44, 4, "G2", 0.8),
    (48, 8, "Bb2", 1.0), (56, 8, "A2", 0.95),
]
CHORUS_BASS = [
    (0, 6, "D2", 1.0), (8, 6, "D2", 0.85),
    (16, 6, "F2", 1.0), (24, 6, "F2", 0.85),
    (32, 6, "G2", 1.0), (40, 6, "G2", 0.85),
    (48, 8, "Bb2", 1.0), (56, 8, "A2", 0.9),
]
VERSE_BASS = [
    (0, 8, "D2", 0.8), (8, 8, "D2", 0.7), (16, 8, "C2", 0.8), (24, 8, "C2", 0.7),
]

KICK_V = "X.......x......."
SNARE_V = "....x.......x..."
KICK_C = "X..x....X.x....."
SNARE_C = "....X.......X..."
HATS_V = "x...x...x...x..."
HATS_C = "x.x.x.x.x.x.x.x."


def build():
    song = E.Song(BPM, BARS, SEED)
    clean = V.gtr_lane_render_clean(6)

    # INTRO 0-4: clean guitar alone in an empty room
    song.notes("gtrclean", VERSE, (0, 4), clean, every_bars=2)

    # V1 4-16 / CH1 16-28 / V2 28-36 / CH2 36-48 / SLUDGE OUT 48-56
    _verse(song, 4, 16, clean)
    _chorus(song, 16, 28)
    _verse(song, 28, 36, clean)
    _chorus(song, 36, 48)

    song.add("drums", V.crash(1), 48, 0)
    song.hits("drums", "X.......X.......", (48, 56), lambda v: V.kick(v), rotate=2)
    song.hits("drums", "........X.......", (48, 56), lambda v: V.snare(v), rotate=2)
    song.notes("gtrL", CHORUS, (48, 56), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", CHORUS, (48, 56), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", CHORUS_BASS, (48, 56), V.bass_render(1.3), every_bars=4)

    # loop tail: the clean intro figure returns (the wrap lands on it)
    song.notes("gtrclean", VERSE, (BARS, BARS + 1), clean, every_bars=2)
    song.add("drums", V.crash(2), BARS, 0)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])
    song.lanes["gtrclean"] = V._gtr_amp_clean(song.lanes["gtrclean"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "gtrclean": -0.3, "bass": 0.0,
            "drums": 0.0},
        core=("drums",),
        offsets={"bass": -3.0, "gtrL": -2.5, "gtrR": -2.5, "gtrclean": -6.0})
    return x2, song


def _verse(song, lo, hi, clean):
    song.hits("drums", KICK_V, (lo, hi), lambda v: V.kick(v), vel=0.8, rotate=2)
    song.hits("drums", SNARE_V, (lo, hi), lambda v: V.snare(v), vel=0.7, rotate=2)
    song.hits("drums", HATS_V, (lo, hi), lambda v: V.hat(False, v), vel=0.5,
        rotate=2)
    song.notes("gtrclean", VERSE, (lo, hi), clean, every_bars=2)
    song.notes("bass", VERSE_BASS, (lo, hi), V.bass_render(1.1), every_bars=2)


def _chorus(song, lo, hi):
    song.add("drums", V.crash(lo % 3), lo, 0)
    song.hits("drums", KICK_C, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE_C, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS_C, (lo, hi), lambda v: V.hat(False, v), vel=0.65,
        rotate=2)
    song.hits("drums", "..............x.", (lo, hi), lambda v: V.hat(True, v),
        vel=0.5, every=2, rotate=2)
    song.notes("gtrL", CHORUS, (lo, hi), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", CHORUS, (lo, hi), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", CHORUS_BASS, (lo, hi), V.bass_render(1.3), every_bars=4)
