"""BGM sequencing engine — the song-scale sibling of tools/synth_sfx.py.

Same house rules (pure synthesis, deterministic seeds, refs analysis-only)
but vectorized: SFX primitives loop per-sample, which is fine for a one-second
gunshot and hours-slow for a three-minute track, so filters here ride
scipy.signal.lfilter and Karplus-Strong runs block-wise. Mono lanes are
sequenced on a 16th-note grid, RMS-matched against the drum core (the
"unity-gain layers steamroll attenuated layers" law made structural), then
panned into stereo for mastering.
"""
import os
import subprocess
import wave
import numpy as np
from scipy import signal

SR = 44100
BGM_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "assets", "bgm"))


# ---- vectorized DSP ----------------------------------------------------------
def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * t(dur) + phase)


def saw(freq, dur, phase=0.0):
    ph = (freq * t(dur) + phase) % 1.0
    return 2.0 * ph - 1.0


def square(freq, dur, duty=0.5):
    ph = (freq * t(dur)) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def sweep(f0, f1, dur, kind="exp"):
    tt = t(dur)
    if kind == "exp":
        f = f0 * (f1 / f0) ** (tt / dur)
    else:
        f = np.linspace(f0, f1, tt.size)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def env_exp(dur, tau):
    return np.exp(-t(dur) / tau)


def env_ad(dur, atk, dec_curve=2.0):
    n = int(SR * dur)
    a = max(1, int(SR * atk))
    d = max(1, n - a)
    e = np.concatenate([np.linspace(0, 1, a),
        (1.0 - np.linspace(0, 1, d)) ** dec_curve])
    return e[:n]


def lp(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, cutoff, order=2):
    b, a = signal.butter(order, max(cutoff / (SR / 2), 1e-4), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [max(lo / (SR / 2), 1e-4),
        min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def one_pole_lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    return signal.lfilter([1 - a], [1, -a], x)


def softclip(x, drive=2.0):
    return np.tanh(x * drive)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)))) if x.size else 0.0


def rms_match(layer, core_rms, offset_db=0.0):
    """Scale a lane so its RMS sits offset_db relative to the core's RMS."""
    r = rms(layer)
    if r <= 0.0 or core_rms <= 0.0:
        return layer
    return layer * (core_rms / r) * (10.0 ** (offset_db / 20.0))


def karplus(freq, dur, damp=0.996, bright=0.5, seed=0):
    """Karplus-Strong plucked/struck string, block-wise (fast at song scale).
    damp < 1 shortens sustain (palm mute ~0.980, ring ~0.998); bright blends
    the averaging filter (lower = darker decay)."""
    n = int(SR * dur)
    D = max(2, int(round(SR / freq)))
    rng = np.random.default_rng(seed)
    out = np.empty(max(n, D) + D)
    out[:D] = rng.uniform(-1.0, 1.0, D)
    filled = D
    while filled < out.size:
        prev = out[filled - D:filled]
        lagged = np.concatenate(([out[filled - D - 1] if filled > D else prev[0]],
            prev[:-1]))
        block = damp * (bright * prev + (1.0 - bright) * lagged)
        m = min(D, out.size - filled)
        out[filled:filled + m] = block[:m]
        filled += m
    return out[:n]


# ---- note helpers --------------------------------------------------------------
A4 = 440.0
_NOTE = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5,
    "F": -4, "F#": -3, "Gb": -3, "G": -2, "G#": -1, "Ab": -1, "A": 0,
    "A#": 1, "Bb": 1, "B": 2}


def hz(name):
    """"E2" / "Bb3" -> Hz."""
    pitch, octave = name[:-1], int(name[-1])
    return A4 * 2.0 ** ((_NOTE[pitch] + (octave - 4) * 12) / 12.0)


# ---- the song grid --------------------------------------------------------------
class Song:
    """16th-note grid over a fixed bar count. Lanes are full-length mono
    buffers; voices scatter-add cached hits/notes onto them; mix() balances
    every lane against the drum core and returns stereo (2, N).

    Compose bars+1 bars: the extra bar is the loop tail that finalize() wraps
    over the head (so reverb/energy at the end folds into the start)."""

    def __init__(self, bpm, bars, seed, beats_per_bar=4):
        self.bpm = bpm
        self.bars = bars                       # loop length (tail bar excluded)
        self.rng = np.random.default_rng(seed)
        self.spb = int(round(SR * 60.0 / bpm / 4.0))   # samples per 16th step
        self.steps_per_bar = int(round(beats_per_bar * 4))  # 3.5 -> 7/8 lurch
        self.bar_samples = self.spb * self.steps_per_bar
        self.total = self.bar_samples * (bars + 1)     # +1 = loop-tail bar
        self.lanes = {}

    def lane(self, name):
        if name not in self.lanes:
            self.lanes[name] = np.zeros(self.total)
        return self.lanes[name]

    def sec(self, bars):
        return bars * self.bar_samples / SR

    def add(self, lane, sample, bar, step, gain=1.0):
        """Scatter-add one rendered hit at bar:step (clipped at song end)."""
        buf = self.lane(lane)
        i = bar * self.bar_samples + step * self.spb
        if i >= buf.size:
            return
        m = min(sample.size, buf.size - i)
        buf[i:i + m] += sample[:m] * gain

    def hits(self, lane, pattern, bar_range, render, vel=1.0, humanize=0.06,
             every=1, rotate=None):
        """pattern: 16-char-per-bar string, "x" hit / "X" accent / "." rest.
        render: fn(variant_index) -> mono sample (cache inside the voice).
        rotate: number of render variants to cycle through."""
        pat = pattern.replace(" ", "")
        for bar in range(*bar_range):
            if (bar - bar_range[0]) % every:
                continue
            for step, ch in enumerate(pat):
                if ch == ".":
                    continue
                g = vel * (1.25 if ch == "X" else 1.0)
                g *= 1.0 + self.rng.uniform(-humanize, humanize)
                variant = 0 if rotate is None else int(self.rng.integers(rotate))
                self.add(lane, render(variant), bar, step, g)

    def notes(self, lane, seq, bar_range, render, every_bars=1, gain=1.0):
        """seq: list of (step, len_steps, note_name, vel) tiled every
        every_bars bars across bar_range. render: fn(freq, dur_sec, vel)."""
        for bar in range(bar_range[0], bar_range[1], every_bars):
            for step, length, note, vel in seq:
                dur = length * self.spb / SR
                self.add(lane, render(hz(note), dur, vel), bar, step, gain)

    def mix(self, pans, core=("drums",), offsets=None):
        """pans: lane -> (-1..1). offsets: lane -> dB relative to the summed
        core lanes (core lanes mix at unity). Equal-power panning."""
        offsets = offsets or {}
        core_sum = np.zeros(self.total)
        for name in core:
            if name in self.lanes:
                core_sum += self.lanes[name]
        core_rms = rms(core_sum)
        left = np.zeros(self.total)
        right = np.zeros(self.total)
        for name, buf in self.lanes.items():
            x = buf if name in core else rms_match(buf, core_rms,
                offsets.get(name, 0.0))
            pan = pans.get(name, 0.0)
            theta = (pan + 1.0) * np.pi / 4.0
            left += x * np.cos(theta)
            right += x * np.sin(theta)
        return np.stack([left, right])


# ---- output ----------------------------------------------------------------------
def bake_loop(x2, bar_samples, bars):
    """Wrap-crossfade the composed tail bar over the head (equal-power) and
    trim to the exact loop length. Mastered audio goes in — the seam then
    carries the real end-of-song decay instead of a dry splice."""
    body = bar_samples * bars
    head = x2[:, :bar_samples].copy()
    tail = x2[:, body:body + bar_samples]
    if tail.shape[1] < bar_samples:  # defensive: short render
        pad = np.zeros((2, bar_samples - tail.shape[1]))
        tail = np.concatenate([tail, pad], axis=1)
    theta = np.linspace(0.0, np.pi / 2.0, bar_samples)
    out = x2[:, :body].copy()
    out[:, :bar_samples] = head * np.sin(theta) + tail * np.cos(theta)
    return out


def write_stereo(name, x2, wav_only=False):
    """(2, N) float -> stereo wav -> ogg into assets/bgm/. No declick fade —
    a fade would dip every loop pass; the wrap-crossfade owns the seam."""
    os.makedirs(BGM_DIR, exist_ok=True)
    peak = float(np.max(np.abs(x2)))
    if peak > 0.985:
        x2 = x2 * (0.985 / peak)
    inter = np.empty(x2.shape[1] * 2, dtype=np.int16)
    inter[0::2] = (x2[0] * 32767).astype(np.int16)
    inter[1::2] = (x2[1] * 32767).astype(np.int16)
    wav_path = f"/tmp/{name}.wav"
    with wave.open(wav_path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(inter.tobytes())
    if not wav_only:
        ogg_path = f"{BGM_DIR}/{name}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
            "-c:a", "libvorbis", "-q:a", "5", "-ac", "2", "-ar", str(SR),
            ogg_path], check=True)
        print("  wrote %s  (%.1fs, peak %.2f)" % (ogg_path, x2.shape[1] / SR,
            float(np.max(np.abs(x2)))))
    else:
        print("  wrote %s  (%.1fs)" % (wav_path, x2.shape[1] / SR))
    return wav_path
