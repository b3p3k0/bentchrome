"""bgm_snowy — Mountainside Mayhem. Cold synth-led industrial at 110 (the
NIN lane): sequenced 16th arp pulse, glassy pad, tight electronic drums with
a clap backbeat, guitar held back to sparse ringing chords on the peaks.
"""
from .. import engine as E
from .. import voices as V

SEED = 0x1CE5
BPM = 110
BARS = 64

# 1-bar arp cell (Em with the 9 — cold, circling)
ARP = [
    (0, 2, "E3", 0.9), (2, 2, "G3", 0.7), (4, 2, "B3", 0.8), (6, 2, "F#3", 0.7),
    (8, 2, "E3", 0.85), (10, 2, "B3", 0.7), (12, 2, "G3", 0.8), (14, 2, "F#3", 0.7),
]
ARP_LOW = [(s, l, n.replace("3", "2"), v) for s, l, n, v in ARP]
# sub bass, 2-bar tile
SUB = [
    (0, 6, "E1", 1.0), (8, 6, "E1", 0.85), (16, 6, "C2", 1.0), (24, 6, "D2", 0.9),
]
# sparse heavy rings for the C section (4-bar tile)
RINGS = [(0, 12, "E2", 1.0), (32, 12, "C2", 1.0), (48, 12, "D2", 0.9)]

KICK = "X...x...X...x..."
KICK_B = "X..x....X..x...."
CLAP = "....X.......X..."
TICKS = "x.x.x.xxx.x.x.x."


def build():
    song = E.Song(BPM, BARS, SEED)

    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED) * 0.5, 0, 0)
    for lo, hi in [(0, 10), (63, 65)]:
        song.add("drone", V.drone(E.hz("E1"), song.sec(hi - lo)) * 0.8, lo, 0)

    # INTRO 0-8: arp + pad breathe in the cold
    song.notes("arp", ARP, (0, 8), V.arp_note, every_bars=1)
    song.add("pad", V.icy_pad([E.hz("E4"), E.hz("B4"), E.hz("F#5")],
        song.sec(8), seed=9), 0, 0)

    # A 8-24: drums arrive, sub anchors
    _beat(song, 8, 24, KICK)
    song.notes("arp", ARP, (8, 24), V.arp_note, every_bars=1)
    song.notes("sub", SUB, (8, 24), V.bass_render(0.9), every_bars=2)

    # B 24-32: floor drops out — pad, arp low, sub
    song.notes("arp", ARP_LOW, (24, 32), V.arp_note, every_bars=1)
    song.notes("sub", SUB, (24, 32), V.bass_render(0.9), every_bars=2)
    song.add("pad", V.icy_pad([E.hz("G4"), E.hz("D5"), E.hz("A5")],
        song.sec(8), seed=11), 24, 0)
    song.add("riser", V.riser(song.sec(1), seed=5), 31, 0)

    # C 32-48: full — both arps, guitar rings on the peaks
    song.add("drums", V.crash(0), 32, 0)
    _beat(song, 32, 48, KICK_B)
    song.notes("arp", ARP, (32, 48), V.arp_note, every_bars=1)
    song.notes("arp2", ARP_LOW, (32, 48), V.arp_note, every_bars=1)
    song.notes("sub", SUB, (32, 48), V.bass_render(0.9), every_bars=2)
    song.notes("gtrL", RINGS, (32, 48), V.gtr_lane_render(3), every_bars=4)
    song.notes("gtrR", RINGS, (32, 48), V.gtr_lane_render(4), every_bars=4)
    song.add("pad", V.icy_pad([E.hz("E4"), E.hz("B4"), E.hz("F#5")],
        song.sec(16), seed=13), 32, 0)

    # D 48-56: strip back to ticks + arp
    song.hits("drums", TICKS, (48, 56), lambda v: V.hat(False, v), vel=0.55,
        rotate=2)
    song.hits("drums", KICK, (52, 56), lambda v: V.kick(v), vel=0.8, rotate=2)
    song.notes("arp", ARP, (48, 56), V.arp_note, every_bars=1)
    song.notes("sub", SUB, (48, 56), V.bass_render(0.9), every_bars=2)

    # A2 56-64: beat returns, cooling toward the wrap
    _beat(song, 56, 64, KICK)
    song.notes("arp", ARP, (56, 64), V.arp_note, every_bars=1)
    song.notes("sub", SUB, (56, 64), V.bass_render(0.9), every_bars=2)

    # loop tail: intro texture (arp + pad continue the circle)
    song.notes("arp", ARP, (BARS, BARS + 1), V.arp_note, every_bars=1)

    song.lanes["gtrL"] = V._gtr_amp(song.lanes["gtrL"])
    song.lanes["gtrR"] = V._gtr_amp(song.lanes["gtrR"])

    x2 = song.mix(
        pans={"arp": 0.35, "arp2": -0.35, "pad": 0.5, "sub": 0.0,
            "gtrL": -0.85, "gtrR": 0.85, "texture": -0.4, "drone": 0.0,
            "riser": 0.1, "drums": 0.0},
        core=("drums",),
        offsets={"arp": -6.0, "arp2": -8.0, "pad": -12.0, "sub": -3.0,
            "gtrL": -5.0, "gtrR": -5.0, "texture": -18.0, "drone": -10.0,
            "riser": -10.0})
    return x2, song


def _beat(song, lo, hi, kick_pat):
    song.hits("drums", kick_pat, (lo, hi), lambda v: V.kick(v), rotate=2)
    song.hits("drums", CLAP, (lo, hi), lambda v: V.clap(v), rotate=2)
    song.hits("drums", TICKS, (lo, hi), lambda v: V.hat(False, v), vel=0.6,
        rotate=2)
