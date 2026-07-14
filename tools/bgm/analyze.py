"""Analysis half of the closed loop (see assets/sfx/refs.md workflow): band
power, RMS envelope, loop-seam continuity, spectrogram PNG. References pulled
with yt-dlp are ANALYSIS-ONLY — numbers get matched, audio never sampled.
"""
import os
import subprocess
import wave
import numpy as np
from . import engine as E

BANDS = [(0, 60), (60, 120), (120, 300), (300, 1000), (1000, 4000),
    (4000, 22050)]


def load_wav(path):
    with wave.open(path, "r") as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
        ch = w.getnchannels()
        sr = w.getframerate()
    x = raw.astype(np.float64) / 32768.0
    if ch == 2:
        x = 0.5 * (x[0::2] + x[1::2])
    return x, sr


def band_split_db(x, sr):
    spec = np.abs(np.fft.rfft(x)) ** 2
    freqs = np.fft.rfftfreq(x.size, 1.0 / sr)
    total = np.sum(spec)
    out = []
    for lo, hi in BANDS:
        p = np.sum(spec[(freqs >= lo) & (freqs < hi)])
        out.append(10.0 * np.log10(max(p / max(total, 1e-12), 1e-12)))
    return out


def rms_envelope_db(x, sr, win_ms=50.0):
    win = int(sr * win_ms / 1000.0)
    n = x.size // win
    frames = x[:n * win].reshape(n, win)
    r = np.sqrt(np.mean(np.square(frames), axis=1))
    return 20.0 * np.log10(np.maximum(r, 1e-9))


def seam_check(x, sr, window_s=0.5):
    """Loop-seam continuity: RMS and band balance of the last window vs the
    first. A seamless loop keeps both deltas small."""
    n = int(sr * window_s)
    head, tail = x[:n], x[-n:]
    rms_delta = 20.0 * np.log10(max(E.rms(tail), 1e-9) / max(E.rms(head), 1e-9))
    bands_h = band_split_db(head, sr)
    bands_t = band_split_db(tail, sr)
    band_delta = max(abs(a - b) for a, b in zip(bands_h, bands_t))
    return rms_delta, band_delta


def spectrogram(wav_path, out_png):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
        "-lavfi", "showspectrumpic=s=1600x720:legend=1", out_png], check=True)
    return out_png


def report(wav_path, png_dir="/tmp"):
    x, sr = load_wav(wav_path)
    name = os.path.splitext(os.path.basename(wav_path))[0]
    env = rms_envelope_db(x, sr)
    rms_delta, band_delta = seam_check(x, sr)
    print("  analyze %s: %.1fs" % (name, x.size / sr))
    print("    bands (dB rel total): " + "  ".join(
        "%d-%d:%.1f" % (lo, hi, v) for (lo, hi), v in zip(BANDS,
            band_split_db(x, sr))))
    print("    RMS env: median %.1f dB, p95 %.1f dB, floor %.1f dB"
        % (np.median(env), np.percentile(env, 95), np.min(env)))
    print("    loop seam: RMS delta %.1f dB, worst band delta %.1f dB"
        % (rms_delta, band_delta))
    png = spectrogram(wav_path, os.path.join(png_dir, name + "_spec.png"))
    print("    spectrogram: " + png)
