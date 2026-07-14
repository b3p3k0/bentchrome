"""bgm_menu — title screen, every menu, MP lobby/scoreboard, Driver's Ed.
Slow doom-drone ambient (~72 BPM pulse): E drone bed, heartbeat kick, distant
metal, long dark chord rings, a cold high whisper mid-loop. Slower and 3 dB
under the combat loudness convention — the calm before the wreckage.
"""
from .. import engine as E
from .. import voices as V

SEED = 0x51EE7
BPM = 72
BARS = 42
MASTER = {"reverb_wet": 0.16, "room": 0.7, "rms_offset_db": -3.0}


def build():
    song = E.Song(BPM, BARS, SEED)

    # full-length beds (they ARE the loop seam)
    song.add("drone", V.drone(E.hz("E1"), song.total / E.SR), 0, 0)
    song.add("texture", V.machine_texture(song.total / E.SR, seed=SEED) * 0.7, 0, 0)

    # heartbeat pulse — lub-dub every other bar once the intro settles
    for bar in range(8, BARS, 2):
        song.add("drums", V.kick(0), bar, 0, 0.55)
        song.add("drums", V.kick(1), bar, 3, 0.35)

    # long dark chord rings (clean-stage guitar, one every 4 bars, low)
    ring = V.gtr_lane_render_clean(6)
    chords = ["E2", "E2", "G2", "E2", "D2", "E2", "Bb2", "E2"]
    for i, bar in enumerate(range(8, BARS - 2, 4)):
        dur = 12 * song.spb / E.SR
        song.add("gtr", ring(E.hz(chords[i % len(chords)]), dur, 0.8), bar, 0)

    # distant metal — sparse, echoing far left/right of the dash
    for i, bar in enumerate(range(10, BARS, 8)):
        song.add("metal", V.clank(i % 3), bar, int(song.rng.integers(4, 12)), 0.5)

    # a cold whisper drifts in for the middle stretch
    pad = V.icy_pad([E.hz("E4"), E.hz("B4"), E.hz("F#5")], song.sec(16), seed=9)
    song.add("pad", pad * E.env_ad(song.sec(16), 4.0, 1.0)[:pad.size], 20, 0)

    song.lanes["gtr"] = V._gtr_amp_clean(song.lanes["gtr"])

    x2 = song.mix(
        pans={"drone": 0.0, "texture": -0.3, "drums": 0.0, "gtr": 0.25,
            "metal": -0.6, "pad": 0.45},
        core=("drone",),
        offsets={"texture": -10.0, "drums": -2.0, "gtr": -7.0,
            "metal": -14.0, "pad": -12.0})
    return x2, song
