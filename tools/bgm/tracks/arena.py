"""bgm_arena — Downtown Derby. The style-lock exemplar: 122 BPM industrial
rock stomp (KMFDM / Ministry lane). E-minor riff with the b5 lean, palm-mute
chugs against backbeat clank, saturated 8th-note bass, machine-room bed.
72-bar loop (~2:22): INTRO 8 / RIFF-A 16 / BREAK 8 / RIFF-B 16 / HALF-TIME 8 /
RIFF-A2 16, tail bar = intro texture so the wrap lands on the build.
"""
from .. import engine as E
from .. import voices as V

SEED = 0xD3B1
BPM = 122
BARS = 72

# 2-bar main riff on the 16th grid (step, len_steps, note, vel).
RIFF = [
    (0, 2, "E2", 0.85), (2, 2, "E2", 0.7), (4, 2, "E2", 0.9), (6, 2, "G2", 1.0),
    (8, 2, "E2", 0.7), (10, 2, "E2", 0.7), (12, 4, "A2", 1.0),
    (16, 2, "E2", 0.85), (18, 2, "E2", 0.7), (20, 2, "E2", 0.9), (22, 2, "G2", 1.0),
    (24, 2, "Bb2", 1.0), (26, 2, "A2", 0.9), (28, 4, "E2", 1.0),
]

# Bass doubles the riff roots in straight 8ths (2-bar tile).
BASS = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.85), (4, 2, "E2", 1.0), (6, 2, "G2", 1.0),
    (8, 2, "E2", 0.85), (10, 2, "E2", 0.85), (12, 2, "A2", 1.0), (14, 2, "A2", 0.85),
    (16, 2, "E2", 1.0), (18, 2, "E2", 0.85), (20, 2, "E2", 1.0), (22, 2, "G2", 1.0),
    (24, 2, "Bb2", 1.0), (26, 2, "A2", 0.9), (28, 2, "E2", 1.0), (30, 2, "E2", 0.85),
]

# Half-time sludge: ringing whole/half chords over a 4-bar (64-step) tile.
SLUDGE = [
    (0, 16, "E2", 1.0), (16, 16, "G2", 1.0),
    (32, 16, "A2", 1.0), (48, 8, "Bb2", 1.0), (56, 8, "A2", 0.9),
]
SLUDGE_BASS = [
    (0, 14, "E2", 1.0), (16, 14, "G2", 1.0),
    (32, 14, "A2", 1.0), (48, 8, "Bb2", 1.0), (56, 8, "A2", 0.9),
]

# Sampler-stab motif (BREAK / RIFF-B garnish), 2-bar tile.
STAB = [
    (0, 3, "E4", 1.0), (6, 2, "E4", 0.7), (12, 3, "G4", 0.9),
    (16, 3, "E4", 1.0), (24, 4, "D4", 0.9),
]

KICK_A = "X...x..xX...x..."
KICK_B = "X..x.x..X..x..x."
SNARE = "....X.......X..."
HATS = "x.xxx.xxx.xxxxx."
HATS_OPEN = "..x...........x."


def build():
    song = E.Song(BPM, BARS, SEED)

    # -- beds run the full length INCLUDING the tail bar (they ARE the seam) --
    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED), 0, 0)
    for lo, hi in [(0, 8), (24, 32), (71, 73)]:
        song.add("drone", V.drone(E.hz("E1"), song.sec(hi - lo)), lo, 0)

    # -- INTRO 0-8: kick walks in at 4, hats at 6, riser into the drop --------
    song.hits("drums", "X...x...X...x...", (4, 8), lambda v: V.kick(v), rotate=2)
    song.hits("drums", HATS, (6, 8), lambda v: V.hat(False, v), vel=0.7, rotate=2)
    song.add("riser", V.riser(song.sec(1), seed=3), 7, 0)

    # -- RIFF-A 8-24 -----------------------------------------------------------
    _full_band(song, 8, 24, KICK_A)
    song.hits("drums", "........X.......", (11, 24), lambda v: V.clank(v),
        every=4, rotate=3)

    # -- BREAK 24-32: guitars out, stab motif in --------------------------------
    song.hits("drums", "X...x...X...x...", (24, 32), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (28, 32), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS, (24, 32), lambda v: V.hat(False, v), vel=0.6, rotate=2)
    song.notes("bass", BASS, (24, 32), V.bass_note, every_bars=2)
    song.notes("stab", STAB, (24, 32), V.stab, every_bars=2)
    song.add("riser", V.riser(song.sec(1), seed=5), 31, 0)

    # -- RIFF-B 32-48: denser kick, stabs stay ---------------------------------
    _full_band(song, 32, 48, KICK_B)
    song.notes("stab", STAB, (34, 48), V.stab, every_bars=4)
    song.hits("drums", "........X.......", (35, 48), lambda v: V.clank(v),
        every=4, rotate=3)

    # -- HALF-TIME 48-56: sludge chords, snare on 3 -----------------------------
    song.add("drums", V.crash(0), 48, 0)
    song.hits("drums", "X.......x.......", (48, 56), lambda v: V.kick(v), rotate=2)
    song.hits("drums", "........X.......", (48, 56), lambda v: V.snare(v), rotate=2)
    song.hits("drums", "x...x...x...x...", (48, 56), lambda v: V.hat(False, v),
        vel=0.55, rotate=2)
    song.notes("gtrL", SLUDGE, (48, 56), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", SLUDGE, (48, 56), V.gtr_lane_render(4), every_bars=4)
    song.notes("bass", SLUDGE_BASS, (48, 56), V.bass_note, every_bars=4)

    # -- RIFF-A2 56-72: everything on, clank doubled ----------------------------
    song.add("drums", V.crash(1), 56, 0)
    _full_band(song, 56, 72, KICK_A)
    song.hits("drums", "........X.......", (57, 72), lambda v: V.clank(v),
        every=2, rotate=3)
    song.notes("stab", STAB, (64, 72), V.stab, every_bars=4)

    # -- loop-wrap accent: lands on the seam every pass --------------------------
    song.add("drums", V.crash(2), BARS, 0)
    song.add("drums", V.kick(0), BARS, 0)

    # guitar lanes hit the amp ONCE, assembled (real amps see summed strings)
    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"gtrL": -0.85, "gtrR": 0.85, "stab": 0.3, "texture": -0.25,
            "riser": 0.15, "drone": 0.0, "bass": 0.0, "drums": 0.0},
        core=("drums",),
        offsets={"bass": -3.0, "gtrL": -2.5, "gtrR": -2.5, "stab": -11.0,
            "texture": -15.0, "drone": -9.0, "riser": -9.0})
    return x2, song


def _full_band(song, lo, hi, kick_pattern):
    song.hits("drums", kick_pattern, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", SNARE, (lo, hi), lambda v: V.snare(v), rotate=2)
    song.hits("drums", HATS, (lo, hi), lambda v: V.hat(False, v), vel=0.65,
        rotate=2)
    song.hits("drums", HATS_OPEN, (lo, hi), lambda v: V.hat(True, v), vel=0.5,
        every=2, rotate=2)
    song.notes("gtrL", RIFF, (lo, hi), V.gtr_lane_render(3), every_bars=2)
    song.notes("gtrR", RIFF, (lo, hi), V.gtr_lane_render(4), every_bars=2)
    song.notes("bass", BASS, (lo, hi), V.bass_note, every_bars=2)
