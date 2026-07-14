"""Mastering: pedalboard glue chain + house loudness convention + loop bake.

One convention across every track — median 50ms-RMS at -18 dBFS, true peak
ceiling -1 dB — so the in-game MusicDirector needs no per-track trim. Reverb
is the baseline glue (a convolution IR would itself need synthesizing to stay
license-clean; keep that as an opt-in flavor, not the default).
"""
import numpy as np
from pedalboard import Pedalboard, HighpassFilter, Compressor, Reverb, Limiter
from . import engine as E

TARGET_RMS_DB = -18.0
PEAK_DB = -1.0


def _chain(reverb_wet=0.08, room=0.45):
    return Pedalboard([
        HighpassFilter(cutoff_frequency_hz=28.0),
        Compressor(threshold_db=-16.0, ratio=3.0, attack_ms=9.0,
            release_ms=170.0),
        Reverb(room_size=room, damping=0.6, wet_level=reverb_wet,
            dry_level=1.0 - reverb_wet, width=0.9),
    ])


def _median_rms_db(x2):
    mono = np.mean(x2, axis=0)
    win = int(E.SR * 0.050)
    n = mono.size // win
    frames = mono[:n * win].reshape(n, win)
    r = np.sqrt(np.mean(np.square(frames), axis=1))
    r = r[r > 10 ** (-60.0 / 20.0)]  # gate silence out of the median
    if r.size == 0:
        return -120.0
    return float(20.0 * np.log10(np.median(r)))


def finalize(name, x2, song, wav_only=False, reverb_wet=0.08, room=0.45):
    """Master -> loudness-normalize -> limit -> bake the loop seam -> write.
    x2 is the raw (2, N) mix including the +1 loop-tail bar."""
    x = _chain(reverb_wet, room)(x2.astype(np.float32), E.SR).astype(np.float64)
    gain_db = TARGET_RMS_DB - _median_rms_db(x)
    x *= 10.0 ** (gain_db / 20.0)
    x = Limiter(threshold_db=PEAK_DB, release_ms=120.0)(
        x.astype(np.float32), E.SR).astype(np.float64)
    x = E.bake_loop(x, song.bar_samples, song.bars)
    peak = float(np.max(np.abs(x)))
    ceiling = 10 ** (PEAK_DB / 20.0)
    if peak > ceiling:
        x *= ceiling / peak
    print("  %s: %.1fs loop, %d bars @ %d bpm, RMS %.1f dBFS, peak %.2f dBFS"
        % (name, x.shape[1] / E.SR, song.bars, song.bpm, _median_rms_db(x),
           20.0 * np.log10(max(peak, 1e-9))))
    return E.write_stereo(name, x, wav_only)
