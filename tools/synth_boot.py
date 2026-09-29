#!/usr/bin/env python3
"""Boot sting generator for Bent Chrome — the regeneration source for
assets/boot/boot_sting.ogg, the one sound under the FONY / FanStation startup
cards (ui/boot_splash.gd). Runs on the repo venv (pedalboard + scipy + numpy):

    ./venv312/bin/python tools/synth_boot.py              # render the sting
    ./venv312/bin/python tools/synth_boot.py --wav-only   # audition in /tmp
    ./venv312/bin/python tools/synth_boot.py --no-bend    # the straight take

An ORIGINAL homage to a mid-90s console power-on, built from the composer's
own public description of the form (quiet start, string swell on the
dominant, arrival on the tonic, twinkling fourths) — pure synthesis, nothing
sampled. One shot, not a loop: no wrap-crossfade, a real fade-out tail. The
cue points below mirror boot_splash.gd's TIMING; move them together.

The parody lives in the last chime: it sags flat like a knockoff console's
cheap DAC giving up. BEND is the knob.
"""
import sys
import os
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bgm import engine as E
from pedalboard import Pedalboard, HighpassFilter, Compressor, Reverb, Limiter

SR = E.SR
NAME = "boot_sting"
BOOT_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
    "..", "assets", "boot"))
SEED = 1994

# Cue points, seconds — the picture these land on (boot_splash.gd TIMING).
DUR = 14.5        # whole run; the last card is fully black again here
SWELL_TOP = 6.4   # publisher card at full brightness, strings at full bloom
ARRIVE = 7.4      # black between the cards ends; tonic lands
CHIMES = 7.6      # console card fading in; first bell
LAST_CHIME = 11.9
FADE_FROM = 13.2  # console card starts its fade-out

BEND = -1.6       # semitones the final chime sags; 0 = the straight take
PEAK_DB = -1.0


# ---- helpers ---------------------------------------------------------------------
def _n(dur):
    return int(SR * dur)


def ramp(t0, t1, shape=1.0):
    """0 before t0, 1 after t1, eased by `shape` in between — over the full run."""
    tt = E.t(DUR)
    return np.clip((tt - t0) / max(t1 - t0, 1e-6), 0.0, 1.0) ** shape


def pan2(x, pan):
    theta = (pan + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(theta), x * np.sin(theta)])


def place(mix, x2, at, gain=1.0):
    i = _n(at)
    m = min(x2.shape[1], mix.shape[1] - i)
    if m > 0:
        mix[:, i:i + m] += x2[:, :m] * gain


def morph_lp(x2, curve, lo=260.0, hi=6500.0, steps=7):
    """Time-varying lowpass without zipper seams: a bank of static filters,
    crossfaded per sample by `curve` (0 = darkest, 1 = brightest)."""
    cuts = lo * (hi / lo) ** (np.arange(steps) / (steps - 1.0))
    bank = [E.lp(x2, c) for c in cuts]
    pos = np.clip(curve, 0.0, 1.0) * (steps - 1.0)
    idx = np.minimum(pos.astype(int), steps - 2)
    frac = pos - idx
    out = np.zeros_like(x2)
    for k in range(steps - 1):
        sel = idx == k
        out[:, sel] = bank[k][:, sel] * (1.0 - frac[sel]) + bank[k + 1][:, sel] * frac[sel]
    return out


# ---- voices ----------------------------------------------------------------------
def strings(freqs, dur, rng, voices=6, cents=13.0):
    """Ensemble pad: detuned saws per note, each with its own slow vibrato and
    seat in the stereo field."""
    tt = E.t(dur)
    out = np.zeros((2, tt.size))
    for f in freqs:
        for _ in range(voices):
            det = 2.0 ** (rng.uniform(-cents, cents) / 1200.0)
            vib = 1.0 + 0.0028 * np.sin(2 * np.pi * rng.uniform(4.4, 5.9) * tt
                + rng.uniform(0, 6.28))
            ph = np.cumsum(f * det * vib) / SR + rng.uniform()
            out += pan2(2.0 * (ph % 1.0) - 1.0, rng.uniform(-0.85, 0.85))
    return out / (len(freqs) * voices)


def sub(freq, dur):
    """Felt more than heard: a sine with one soft octave over it."""
    x = E.sine(freq, dur) + 0.35 * E.lp(E.saw(freq * 2.0, dur), 220, order=4)
    return pan2(x, 0.0)


def thump(dur=1.4):
    """The arrival: a pitch-dropping sine, the floor moving."""
    return pan2(E.sweep(86.0, 36.0, dur) * E.env_exp(dur, 0.42), 0.0)


def whoosh(dur, rng):
    """Reverse-cymbal air into the arrival — decorrelated noise, rising."""
    n = _n(dur)
    rise = np.linspace(0.0, 1.0, n) ** 3.2
    left = E.hp(rng.uniform(-1, 1, n), 2600) * rise
    right = E.hp(rng.uniform(-1, 1, n), 2600) * rise
    return np.stack([left, right])


def bell(freq, dur, vel=1.0, bend=0.0):
    """Glassy FM chime. `bend` (semitones) sags the pitch across the decay,
    with a little wow on top — the knockoff tell."""
    tt = E.t(dur)
    glide = bend * (tt / dur) ** 1.4
    wow = 0.0 if bend == 0.0 else 0.22 * (tt / dur) * np.sin(2 * np.pi * 5.3 * tt)
    ph = 2 * np.pi * np.cumsum(freq * 2.0 ** ((glide + wow) / 12.0)) / SR
    index = 2.6 * np.exp(-tt / 0.22) + 0.35
    body = np.sin(ph + index * np.sin(ph * 3.5))
    glint = 0.3 * np.sin(ph * 2.0 + 1.6 * np.exp(-tt / 0.08) * np.sin(ph * 7.0))
    env = (1.0 - np.exp(-tt / 0.003)) * np.exp(-tt / (dur * 0.32))
    return (body + glint) * env * vel


# ---- the piece -------------------------------------------------------------------
def build(bend=BEND):
    rng = np.random.default_rng(SEED)
    hz = E.hz
    mix = np.zeros((2, _n(DUR)))

    # Dominant: quiet start, then the long bloom under the publisher card.
    gsus = strings([hz("G2"), hz("D3"), hz("G3"), hz("C4"), hz("D4"), hz("G4")],
        ARRIVE + 0.4, rng)
    n_a = gsus.shape[1]
    amp_a = ramp(0.2, SWELL_TOP, 1.9)[:n_a] * (1.0 - ramp(ARRIVE - 0.5, ARRIVE + 0.4)[:n_a])
    open_a = 0.04 + 0.96 * ramp(0.4, SWELL_TOP + 0.4, 1.4)[:n_a]
    place(mix, morph_lp(gsus, open_a) * amp_a, 0.0, 1.0)
    place(mix, sub(hz("G1"), ARRIVE + 0.2) * (ramp(0.0, 3.2, 1.5)
        * (1.0 - ramp(ARRIVE - 0.4, ARRIVE + 0.2)))[:_n(ARRIVE + 0.2)], 0.0, 0.55)

    # Air into the turn, then the tonic lands as the screen goes black.
    place(mix, whoosh(1.7, rng), ARRIVE - 1.7, 0.16)
    place(mix, thump(), ARRIVE, 0.6)
    tail = DUR - (ARRIVE - 0.5)
    cadd9 = strings([hz("C3"), hz("G3"), hz("D4"), hz("E4"), hz("G4")], tail, rng)
    n_b = cadd9.shape[1]
    tb = E.t(tail)
    amp_b = np.clip(tb / 0.9, 0.0, 1.0) * (0.32 + 0.68 * np.exp(-tb / 3.6))
    open_b = 0.82 - 0.5 * np.clip(tb / tail, 0.0, 1.0)
    place(mix, morph_lp(cadd9, open_b[:n_b]) * amp_b[:n_b], ARRIVE - 0.5, 0.8)
    sub_b = sub(hz("C2"), tail)
    place(mix, sub_b * (np.clip(tb / 0.6, 0.0, 1.0) * np.exp(-tb / 4.2))[:sub_b.shape[1]],
        ARRIVE - 0.5, 0.4)

    # The twinkles: fourths climbing, a strummed quartal chord, then sparkle.
    climb = [("G4", 0.00, 0.62), ("D5", 0.25, 0.7), ("G5", 0.50, 0.8), ("C6", 0.75, 0.9),
        ("E6", 1.12, 0.5), ("D6", 1.27, 0.45), ("G6", 1.42, 0.5)]
    for name, at, vel in climb:
        place(mix, pan2(bell(hz(name), 2.2, vel), rng.uniform(-0.5, 0.5)), CHIMES + at, 0.3)
    for k, name in enumerate(["D5", "G5", "C6"]):
        place(mix, pan2(bell(hz(name), 2.8, 0.85), -0.4 + 0.4 * k),
            CHIMES + 1.85 + 0.045 * k, 0.3)
    sparkle = ["C7", "G6", "D7", "E6", "G6", "C7", "D6", "G6", "E7"]
    at = CHIMES + 2.7
    for k, name in enumerate(sparkle):
        vel = 0.42 * (1.0 - 0.07 * k)
        place(mix, pan2(bell(hz(name), 1.5, vel), rng.uniform(-0.9, 0.9)), at, 0.3)
        at += rng.uniform(0.13, 0.22) + 0.03 * k
    # ...and the last one gives up.
    place(mix, pan2(bell(hz("G5"), DUR - LAST_CHIME, 0.95, bend), 0.0), LAST_CHIME, 0.34)
    return mix


def master(x2):
    board = Pedalboard([
        HighpassFilter(cutoff_frequency_hz=28.0),
        Compressor(threshold_db=-18.0, ratio=2.2, attack_ms=20.0, release_ms=260.0),
        Reverb(room_size=0.86, damping=0.42, wet_level=0.3, dry_level=0.78, width=1.0),
    ])
    x = board(x2.astype(np.float32), SR).astype(np.float64)
    # One shot: declick the head, fade the tail to true silence.
    tt = E.t(DUR)[:x.shape[1]]
    x *= np.clip(tt / 0.01, 0.0, 1.0)
    x *= 0.5 * (1.0 + np.cos(np.pi * np.clip((tt - FADE_FROM) / (DUR - FADE_FROM), 0.0, 1.0)))
    x = Limiter(threshold_db=PEAK_DB, release_ms=160.0)(
        x.astype(np.float32), SR).astype(np.float64)
    ceiling = 10.0 ** (PEAK_DB / 20.0)
    x *= ceiling / max(float(np.max(np.abs(x))), 1e-9)
    return x


def report(x2):
    print("  %s: %.2fs, peak %.2f dBFS" % (NAME, x2.shape[1] / SR,
        20.0 * np.log10(max(float(np.max(np.abs(x2))), 1e-9))))
    mono = np.mean(x2, axis=0)
    for label, t0, t1 in [("quiet start", 0.0, 1.5), ("swell", 1.5, SWELL_TOP),
            ("bloom", SWELL_TOP, ARRIVE), ("chimes", CHIMES, LAST_CHIME),
            ("last chime", LAST_CHIME, FADE_FROM), ("tail", FADE_FROM, DUR)]:
        seg = mono[_n(t0):_n(t1)]
        print("    %-12s %5.1f-%4.1fs  RMS %6.1f dBFS" % (label, t0, t1,
            20.0 * np.log10(max(E.rms(seg), 1e-9))))


def main(argv):
    wav_only = "--wav-only" in argv
    bend = 0.0 if "--no-bend" in argv else BEND
    print("== %s (bend %.1f st)" % (NAME, bend))
    x2 = master(build(bend))
    report(x2)
    E.write_stereo(NAME, x2, wav_only, out_dir=BOOT_DIR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
