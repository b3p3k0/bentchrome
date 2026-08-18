#!/usr/bin/env python3
"""Procedural SFX generator for Bent Chrome — the regeneration source for
every assets/sfx/*.ogg. Usage: python3 tools/synth_sfx.py (re-renders all).

Pure-numpy DSP -> wav (stdlib wave) -> ogg (ffmpeg, libvorbis), written
straight into assets/sfx/ where AudioDirector's drop-in loader finds them.
Direction: realistic-ish, not cartoony (reference-link workflow lives in
assets/sfx/refs.md). Needs: numpy, ffmpeg. No sampled sources — every sound
is synthesized; references are analysis-only.
"""
import os
import subprocess
import wave
import numpy as np


def _write_wav(path, sr, x_int16):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(x_int16.tobytes())

SR = 44100
SFX_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
    "..", "assets", "sfx"))

rng = np.random.default_rng(0xB3E7)  # deterministic renders


# ---- primitives ------------------------------------------------------------
def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(SR * dur))


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * t(dur) + phase)


def square(freq, dur, duty=0.5):
    ph = (freq * t(dur)) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def saw(freq, dur):
    ph = (freq * t(dur)) % 1.0
    return 2.0 * ph - 1.0


def sweep(f0, f1, dur, kind="lin"):
    tt = t(dur)
    if kind == "exp":
        f = f0 * (f1 / f0) ** (tt / dur)
    else:
        f = np.linspace(f0, f1, tt.size)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase)


def env_ad(dur, atk, dec, curve=2.0):
    """Attack/decay envelope, atk+dec in seconds (decay fills the rest)."""
    n = int(SR * dur)
    a = max(1, int(SR * atk))
    d = max(1, n - a)
    e = np.concatenate([
        np.linspace(0, 1, a),
        (1.0 - np.linspace(0, 1, d)) ** curve,
    ])
    return e[:n]


def env_exp(dur, tau):
    """Percussive exponential decay."""
    return np.exp(-t(dur) / tau)


def one_pole_lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def one_pole_hp(x, cutoff):
    return x - one_pole_lp(x, cutoff)


def biquad_bp(x, freq, q):
    """Band-pass (constant skirt) biquad."""
    w0 = 2 * np.pi * freq / SR
    alpha = np.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * np.cos(w0), 1 - alpha
    b = np.array([b0, b1, b2]) / a0
    a = np.array([a1, a2]) / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.size):
        xi = x[i]
        yi = b[0] * xi + b[1] * x1 + b[2] * x2 - a[0] * y1 - a[1] * y2
        x2, x1 = x1, xi
        y2, y1 = y1, yi
        y[i] = yi
    return y


def softclip(x, drive=2.0):
    return np.tanh(x * drive)


def fit(a, b):
    """Sum two signals of differing length (zero-pad shorter)."""
    n = max(a.size, b.size)
    out = np.zeros(n)
    out[:a.size] += a
    out[:b.size] += b
    return out


def normalize(x, peak=0.95):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def declick(x, ms=3.0):
    """Short fade in/out to kill boundary clicks."""
    n = int(SR * ms / 1000)
    n = min(n, x.size // 2)
    if n <= 0:
        return x
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name, x, peak=0.95, fade_ms=3.0):
    x = declick(normalize(x, peak), fade_ms)
    wav_path = f"/tmp/{name}.wav"
    ogg_path = f"{SFX_DIR}/{name}.ogg"
    _write_wav(wav_path, SR, (x * 32767).astype(np.int16))
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
         "-c:a", "libvorbis", "-q:a", "5", "-ac", "1", "-ar", str(SR), ogg_path],
        check=True,
    )
    dur = x.size / SR
    print(f"  wrote {ogg_path}  ({dur*1000:.0f}ms, peak {np.max(np.abs(x)):.2f})")


# ---- mg_fire ---------------------------------------------------------------
def friedlander(dur, T):
    """Blast overpressure model: p(t) = (1 - t/T) * exp(-t/T). Sharp rise,
    positive phase for t<T, negative undershoot after. T = positive-phase sec."""
    tt = t(dur)
    return (1.0 - tt / T) * np.exp(-tt / T)


def mg_fire():
    """7.62-ish MG report: impulsive muzzle blast (Friedlander), low thump,
    short crackle tail. No pitched oscillators — real gunshots have no pitch."""
    dur = 0.11
    # 1) muzzle blast crack: broadband noise shaped by a fast Friedlander +
    #    exp decay. Instant attack (the sample-zero onset IS the shockwave).
    blast_env = np.abs(friedlander(dur, 0.0011)) * env_exp(dur, 0.0045)
    crack = noise(dur) * blast_env
    crack = one_pole_hp(crack, 450.0)                 # keep it broadband, cut rumble
    # 2) low-frequency body thump: the pressure weight of a rifle round. Filtered
    #    noise band around ~110Hz with a fast decay, plus a short down-thump.
    thump_env = env_exp(dur, 0.016)
    thump = biquad_bp(noise(dur), 115.0, 1.2) * thump_env
    downthump = sweep(190, 70, dur, "exp") * env_exp(dur, 0.010)
    body = one_pole_lp(1.4 * thump + 0.8 * downthump, 900.0)
    # 3) crackle tail: brief mid/high noise ring-out (report bouncing off ground)
    tail = one_pole_hp(noise(dur), 1600.0) * env_exp(dur, 0.028) * 0.35
    # 4) mechanical bolt tick: tiny bright click at onset
    tick = one_pole_hp(noise(dur), 3500.0) * env_exp(dur, 0.0016) * 0.5
    x = fit(fit(1.5 * crack, 1.1 * body), fit(tail, tick))
    x = softclip(x, 2.2)                              # loud/compressed gunshot bite
    write("mg_fire", x, peak=0.97, fade_ms=1.5)


# ---- explosion voice (npc_death / player_death / hit_weapon share this) ----
def debris_crackle(dur, start, density, decay, hp=2500.0, seed=7):
    """Sparse random pops scattered through [start, dur] — the debris/fire tail."""
    r = np.random.default_rng(seed)
    n = int(SR * dur)
    out = np.zeros(n)
    i0 = int(SR * start)
    npop = int((dur - start) * density)
    for _ in range(npop):
        pos = r.integers(i0, n - 1)
        amp = r.uniform(0.2, 1.0)
        ln = min(int(SR * 0.02), n - pos)
        seg = r.uniform(-1, 1, ln) * np.exp(-np.arange(ln) / (SR * decay)) * amp
        out[pos:pos + ln] += seg
    return one_pole_hp(out, hp)


def explosion(dur, sub_f0, sub_f1, sub_tau, mid_tau, tail_tau, drive, seed=11):
    """Parametric explosion. Bigger sub_tau/tail_tau = bigger blast."""
    r = np.random.default_rng(seed)
    tt = t(dur)
    # 1) ignition blast: instant broadband crack
    blast = r.uniform(-1, 1, tt.size) * np.exp(-tt / 0.010)
    blast = one_pole_hp(blast, 300.0)
    # 2) sub boom: pitch-down tone + low-passed noise, the chest thump
    sub_tone = sweep(sub_f0, sub_f1, dur, "exp") * np.exp(-tt / sub_tau)
    sub_noise = one_pole_lp(r.uniform(-1, 1, tt.size), 140.0) * np.exp(-tt / (sub_tau * 0.8))
    sub = 1.3 * sub_tone + 1.1 * sub_noise
    # 3) mid rumble: fire/debris body
    mid = biquad_bp(r.uniform(-1, 1, tt.size), 320.0, 0.7) * np.exp(-tt / mid_tau)
    # 4) long rolling tail
    tail = one_pole_lp(r.uniform(-1, 1, tt.size), 1200.0) * np.exp(-tt / tail_tau) * 0.5
    # 5) debris crackle
    crackle = debris_crackle(dur, 0.06, 90, 0.006, seed=seed + 1) * 0.5
    early = softclip(1.6 * blast + 1.2 * sub + 0.9 * mid, drive)
    x = fit(early, fit(tail, crackle))
    return x


def npc_death():
    """~850ms rival explosion (positional). Mid-size blast + rolling tail."""
    x = explosion(0.85, sub_f0=120, sub_f1=38, sub_tau=0.16, mid_tau=0.13,
                  tail_tau=0.28, drive=1.8, seed=11)
    write("npc_death", x, peak=0.97, fade_ms=4.0)


def player_death():
    """~1.4s big send-off: main blast + delayed secondary detonation (fuel
    cooking off) + fire crackle. All noise-based — the swept-tone groan was
    the cartoon tell, gone."""
    dur = 1.4
    tt = t(dur)
    r = np.random.default_rng(25)
    main = explosion(dur, sub_f0=130, sub_f1=30, sub_tau=0.30, mid_tau=0.24,
                     tail_tau=0.55, drive=2.0, seed=23)
    # secondary detonation ~0.28s in
    sec = explosion(0.7, sub_f0=100, sub_f1=34, sub_tau=0.14, mid_tau=0.10,
                    tail_tau=0.22, drive=1.8, seed=24) * 0.6
    sec = np.concatenate([np.zeros(int(SR * 0.28)), sec])
    # burning-wreck settle: rough low band, zero pitch
    fire = biquad_bp(r.uniform(-1, 1, tt.size), 160.0, 0.6)
    rough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 30.0))
    fire = fire * (rough / (rough.max() + 1e-9)) * np.exp(-tt / 0.5) * 0.7
    crackle = debris_crackle(dur, 0.15, 120, 0.005, hp=2800.0, seed=26) * 0.45
    x = fit(fit(main, sec), fit(fire, crackle))
    write("player_death", x, peak=0.98, fade_ms=8.0)


def saw_sweep(f0, f1, dur):
    tt = t(dur)
    f = f0 * (f1 / f0) ** (tt / dur)
    ph = np.cumsum(f) / SR
    return 2.0 * (ph % 1.0) - 1.0


def metal_modes(dur, freqs, decays, amps, seed=3):
    """Inharmonic decaying sines struck at t=0 — a metal clang/ring."""
    tt = t(dur)
    r = np.random.default_rng(seed)
    out = np.zeros(tt.size)
    for f, d, a in zip(freqs, decays, amps):
        det = f * (1.0 + r.uniform(-0.01, 0.01))
        out += a * np.sin(2 * np.pi * det * tt) * np.exp(-tt / d)
    return out


def svf_bp(x, cutoff_arr, q):
    """State-variable band-pass with a per-sample cutoff array (for sweeps)."""
    cutoff_arr = np.clip(cutoff_arr, 20.0, SR * 0.45)
    f = 2.0 * np.sin(np.pi * cutoff_arr / SR)
    qc = 1.0 / q
    low = band = 0.0
    out = np.empty_like(x)
    for i in range(x.size):
        high = x[i] - low - qc * band
        band = band + f[i] * high
        low = low + f[i] * band
        out[i] = band
    return out


def granular_crunch(dur, band, q, decay, rough_hz, seed):
    """Grinding/crunching deformation: filtered noise chopped by a rough
    amplitude envelope (rectified low-passed noise). NOT a smooth swoosh."""
    r = np.random.default_rng(seed)
    tt = t(dur)
    x = biquad_bp(r.uniform(-1, 1, tt.size), band, q)
    amp = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), rough_hz))
    amp = amp / (amp.max() + 1e-9)
    return x * amp * np.exp(-tt / decay)


def crash_soft():
    """~380ms fender-bender: pitch-drop thud + granular metal crunch + glass
    tinkle + scattering tail. Deformation/grit, not a ringing bell."""
    dur = 0.38
    tt = t(dur)
    r = np.random.default_rng(31)
    # 1) mass thud: fast pitch drop = weight (per crash sound-design trick)
    thud = sweep(220, 52, dur, "exp") * np.exp(-tt / 0.032) * 1.3
    thud += one_pole_lp(r.uniform(-1, 1, tt.size), 120.0) * np.exp(-tt / 0.028)
    # 2) crunch core: two rough-modulated noise bands (low grind + high grit)
    grind = granular_crunch(dur, 620.0, 0.8, 0.11, 240.0, seed=32)
    grit = granular_crunch(dur, 2000.0, 0.7, 0.075, 400.0, seed=33)
    crunch = 1.1 * grind + 0.8 * grit
    # 3) glass tinkle: bright sparse shards, quick decay
    glass = debris_crackle(dur, 0.0, 140, 0.003, hp=4000.0, seed=34) * 0.55
    # 4) scatter tail: parts skittering across pavement
    scatter = debris_crackle(dur, 0.05, 70, 0.006, hp=1500.0, seed=35) * 0.4
    # 5) heavily-damped metallic grit (short — a hint, never a ring)
    metal = metal_modes(dur, [370, 810, 1490], [0.03, 0.022, 0.016],
                        [0.5, 0.35, 0.25], seed=36)
    metal = one_pole_hp(metal * (0.5 + 0.5 * np.abs(r.uniform(-1, 1, tt.size))), 300.0) * 0.4
    x = fit(fit(1.3 * thud, crunch), fit(glass, fit(scatter, metal)))
    x = softclip(x, 1.7)
    write("crash_soft", x, peak=0.96, fade_ms=3.0)


def missile_fire():
    """~0.9s pop-THWoop, matched to Kevin's TOW-style ref (2s window @1.5s):
    sharp launch pop, beat of air, then the breathy mid whoosh of the round
    leaving. Ref bands: .3-1k 32% / 1-4k 32%, little sub — mid-forward, not
    the sub-heavy roar of v2."""
    dur = 0.9
    tt = t(dur)
    r = np.random.default_rng(51)
    # the POP: broadband mid crack, fast decay
    pop = biquad_bp(r.uniform(-1, 1, tt.size), 700.0, 0.5) * np.exp(-tt / 0.02) * 1.6
    pop += one_pole_hp(r.uniform(-1, 1, tt.size), 1800.0) * np.exp(-tt / 0.012) * 0.8
    # the THWOOP: breathy band-swept whoosh arriving ~0.15s after the pop
    n2 = int(SR * (dur - 0.15))
    t2 = np.linspace(0, dur - 0.15, n2, endpoint=False)
    cut = 450 + 1050 * np.clip(t2 / 0.10, 0, 1) - 900 * np.clip((t2 - 0.10) / 0.5, 0, 1)
    woo = svf_bp(r.uniform(-1, 1, n2), cut, 1.0)
    woo_env = np.minimum(t2 / 0.04, 1.0) * np.exp(-t2 / 0.20)
    woo = woo / (np.sqrt(np.mean(woo ** 2)) + 1e-9) * 0.30 * woo_env
    # mid body + restrained crackle riding the whoosh
    body = biquad_bp(r.uniform(-1, 1, n2), 380.0, 0.6)
    body = body / (np.sqrt(np.mean(body ** 2)) + 1e-9) * 0.22 * woo_env
    crk = debris_crackle(dur - 0.15, 0.0, 400, 0.0012, hp=2500.0, seed=52)
    crk = crk / (np.sqrt(np.mean(crk ** 2)) + 1e-9) * 0.10 * woo_env
    x = fit(pop, delay(softclip((woo + body) * 3.0, 1.6) + crk, 0.15))
    x = one_pole_lp(softclip(x, 1.3), 5200.0)
    write("missile_fire", x, peak=0.95, fade_ms=5.0)


def mine_drop():
    """~180ms mechanical clunk: release click + metal chunk + low ground-thud."""
    dur = 0.18
    tt = t(dur)
    r = np.random.default_rng(61)
    # release click (the arming mechanism)
    click = one_pole_hp(r.uniform(-1, 1, tt.size), 3500.0) * np.exp(-tt / 0.0018) * 0.7
    # metallic chunk: short damped band + one short mode
    chunk = biquad_bp(r.uniform(-1, 1, tt.size), 430.0, 1.0) * np.exp(-tt / 0.03)
    chunk += metal_modes(dur, [560, 940], [0.035, 0.025], [0.6, 0.35], seed=62) * 0.5
    chunk = one_pole_hp(chunk, 220.0)
    # low ground thud (weight settling)
    thud = sweep(170, 60, dur, "exp") * np.exp(-tt / 0.03) * 1.1
    thud += one_pole_lp(r.uniform(-1, 1, tt.size), 130.0) * np.exp(-tt / 0.025)
    x = fit(fit(click, 1.1 * chunk), thud)
    x = softclip(x, 1.6)
    write("mine_drop", x, peak=0.95, fade_ms=2.5)


def hit_weapon():
    """~300ms ordnance hit on YOUR hull: blast slap + deep thump + granular
    metal crunch. No ringing partials (crash-v2 rule: rough noise, not tones)."""
    dur = 0.30
    tt = t(dur)
    r = np.random.default_rng(41)
    blast = one_pole_hp(r.uniform(-1, 1, tt.size), 350.0) * np.exp(-tt / 0.009) * 1.4
    # deep thump: fast pitch-drop buried under noise = weight, not melody
    thump = sweep(160, 45, dur, "exp") * np.exp(-tt / 0.05) * 1.3
    thump += one_pole_lp(r.uniform(-1, 1, tt.size), 120.0) * np.exp(-tt / 0.05)
    # granular hull crunch (the crash-v2 texture, shorter)
    grind = granular_crunch(dur, 700.0, 0.8, 0.07, 260.0, seed=42)
    grit = granular_crunch(dur, 2100.0, 0.7, 0.05, 420.0, seed=43)
    debris = debris_crackle(dur, 0.03, 80, 0.004, hp=1800.0, seed=44) * 0.4
    x = fit(fit(blast, 1.2 * thump), fit(1.0 * grind + 0.7 * grit, debris))
    x = softclip(x, 2.0)
    write("hit_weapon", x, peak=0.97, fade_ms=3.0)


def hit_mg():
    """~70ms bullet tink on your hull: sharp strike + tiny damped rattle.
    Rapid repeats in-game (jittered), so short and dry."""
    dur = 0.07
    tt = t(dur)
    r = np.random.default_rng(71)
    strike = one_pole_hp(r.uniform(-1, 1, tt.size), 2500.0) * np.exp(-tt / 0.0025) * 1.2
    body = biquad_bp(r.uniform(-1, 1, tt.size), 950.0, 1.4) * np.exp(-tt / 0.012)
    low = one_pole_lp(r.uniform(-1, 1, tt.size), 200.0) * np.exp(-tt / 0.008) * 0.5
    x = fit(fit(strike, 0.9 * body), low)
    x = softclip(x, 1.5)
    write("hit_mg", x, peak=0.93, fade_ms=1.5)


def skid():
    """~0.8s SEAMLESS tire-squeal loop (AudioDirector replays on finished).
    Real squeal = narrow resonant noise band ~1kHz wandering slowly + low
    rubber judder. Loop seam solved by wrap-crossfading tail into head;
    write with fade_ms=0 (a declick fade would dip every loop pass)."""
    body = 0.8
    xf = 0.06
    dur = body + xf
    tt = t(dur)
    r = np.random.default_rng(81)
    # squeal band: center freq random-walks 950-1350Hz (the wail)
    wander = one_pole_lp(r.uniform(-1, 1, tt.size), 3.0)
    wander = wander / (np.max(np.abs(wander)) + 1e-9)
    centers = 1150.0 + 200.0 * wander
    squeal = svf_bp(r.uniform(-1, 1, tt.size), centers, 4.0)
    # slow amplitude wobble so it breathes instead of buzzing
    wob = one_pole_lp(r.uniform(-1, 1, tt.size), 6.0)
    wob = 0.75 + 0.25 * wob / (np.max(np.abs(wob)) + 1e-9)
    squeal = squeal * wob
    # rubber judder underneath
    judder = biquad_bp(r.uniform(-1, 1, tt.size), 320.0, 1.0)
    rough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 45.0))
    judder = judder * (rough / (rough.max() + 1e-9)) * 0.6
    x = softclip(1.4 * squeal + judder, 1.6)
    # wrap-crossfade: blend the tail over the head, trim to body length
    n = int(SR * body)
    k = int(SR * xf)
    w = np.linspace(0.0, 1.0, k)
    out = x[:n].copy()
    out[:k] = x[n:n + k] * (1.0 - w) + out[:k] * w
    write("skid", out, peak=0.9, fade_ms=0.0)


def spawn():
    """~1.15s V8 start matched to a measured ref ('68 Road Runner @4.0-5.5s):
    quiet low crank chugs -> catch cough -> rev spike -> settle to LOPING low
    idle. Engine = explicit harmonic stack (energy 60-300Hz like the ref, sub
    modest), steep-filtered — v3's naive pulse train sprayed comb lines to
    20kHz on the spectrogram, which was the 'sproingy' read."""
    dur = 1.15
    tt = t(dur)
    r = np.random.default_rng(91)
    n = tt.size
    # crank: 9Hz chugs of LOW knock (no broadband click), faint starter tick
    crank_env = np.interp(tt, [0, 0.02, 0.26, 0.30], [0, 1, 1, 0]) * 0.16
    chug = np.maximum(np.sin(2 * np.pi * 9.0 * tt - 1.2), 0.0) ** 2
    knock = biquad_bp(r.uniform(-1, 1, n), 140.0, 1.2) + 0.8 * one_pole_lp(r.uniform(-1, 1, n), 90.0)
    knock = one_pole_lp(one_pole_lp(knock, 300.0), 300.0)
    tick = one_pole_hp(r.uniform(-1, 1, n), 2000.0) * 0.05
    crank = (knock + tick) * chug * crank_env * 8.0
    # engine: harmonic stack; f0 arc catch->rev->settle-to-idle, slight wander
    f0 = np.interp(tt, [0, 0.30, 0.33, 0.42, 0.60, 0.80, dur], [45, 45, 60, 95, 55, 45, 44])
    wob = one_pole_lp(r.uniform(-1, 1, n), 4.0)
    f0 = f0 * (1.0 + 0.03 * wob / (np.max(np.abs(wob)) + 1e-9))
    ph = np.cumsum(f0) / SR
    eng = np.zeros(n)
    for k, a in enumerate([1.0, 1.0, 0.6, 0.35, 0.2, 0.12, 0.07], start=1):
        eng += a * np.sin(2 * np.pi * k * ph)
    # combustion unevenness + the muscle-car idle lope
    grit = np.abs(one_pole_lp(r.uniform(-1, 1, n), 55.0))
    grit = 0.75 + 0.25 * grit / (grit.max() + 1e-9)
    lope = 0.88 + 0.12 * np.sin(2 * np.pi * 10.5 * tt + 0.7)
    # ref envelope shape: spike at catch, fast settle, pulsing idle, end low
    eng_env = np.interp(tt, [0, 0.29, 0.305, 0.33, 0.55, 0.80, 1.02, dur],
                        [0, 0, 0.3, 1.0, 0.45, 0.20, 0.18, 0.0])
    eng = softclip(eng * grit * lope, 1.4)
    eng = one_pole_lp(one_pole_lp(eng, 400.0), 400.0) * eng_env * 1.6
    # per-cycle exhaust chuff (the ref's 300-1k presence)
    chuff = biquad_bp(r.uniform(-1, 1, n), 600.0, 0.8)
    gate = np.clip(np.sin(2 * np.pi * ph), 0.0, 1.0) ** 2
    chuff = chuff * gate * eng_env
    chuff = chuff / (np.sqrt(np.mean(chuff ** 2)) + 1e-9) * np.sqrt(np.mean(eng ** 2)) * 0.26
    # broadband air so it isn't vacuum-sealed (ref has soft haze to ~13k)
    air = one_pole_hp(one_pole_lp(r.uniform(-1, 1, n), 5000.0), 700.0) * eng_env
    air = air / (np.sqrt(np.mean(air ** 2)) + 1e-9) * np.sqrt(np.mean(eng ** 2)) * 0.20
    # catch cough: one dark burst right at ignition
    cough = one_pole_lp(r.uniform(-1, 1, n), 1500.0) \
        * np.exp(-np.maximum(tt - 0.30, 0) / 0.03) * (tt >= 0.30) * 0.5
    x = crank + eng + chuff + air + cough
    write("spawn", x, peak=0.95, fade_ms=10.0)


def ram_warn():
    """~0.95s Goliath charge tell: dual-tone truck air horn (horns ARE tonal —
    realistic here) over a revving diesel. Positional in-game."""
    dur = 0.95
    tt = t(dur)
    r = np.random.default_rng(101)
    # dual-tone horn: two brassy notes, slight detune roughness
    horn = np.zeros(tt.size)
    for f, a in [(335.0, 1.0), (422.0, 0.9)]:
        horn += a * (saw(f, dur) + 0.5 * saw(f * 2.01, dur))
    hrough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 35.0))
    horn = horn * (0.88 + 0.12 * hrough / (hrough.max() + 1e-9))
    horn = one_pole_lp(one_pole_hp(horn, 240.0), 2400.0)
    horn_env = np.minimum(tt / 0.03, 1.0) * (1.0 - np.clip((tt - 0.72) / 0.23, 0, 1))
    horn = softclip(horn * horn_env, 2.6)
    # diesel rev underneath: rising rough pulse train
    f0 = 55.0 + 40.0 * np.clip(tt / 0.7, 0, 1)
    ph = np.cumsum(f0) / SR
    diesel = one_pole_lp(np.where((ph % 1.0) < 0.3, 1.0, -0.4), 220.0)
    drough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 60.0))
    diesel = diesel * (0.6 + 0.4 * drough / (drough.max() + 1e-9)) * horn_env
    x = fit(1.2 * horn, softclip(diesel, 1.8) * 0.8)
    write("ram_warn", x, peak=0.96, fade_ms=6.0)


# ---- expansion batch (2026-07-13): terrain/death/brake/crash-split/UI/MP ----
def delay(x, sec):
    """Prefix silence — for placing a layer at an offset inside fit()."""
    return np.concatenate([np.zeros(int(SR * sec)), x])


def crash_hard():
    """~550ms totaled: everything in crash_soft but heavier — deeper thud,
    denser glass, longer scatter, extra low boom."""
    dur = 0.55
    tt = t(dur)
    r = np.random.default_rng(37)
    thud = sweep(200, 45, dur, "exp") * np.exp(-tt / 0.045) * 1.6
    thud += one_pole_lp(r.uniform(-1, 1, tt.size), 110.0) * np.exp(-tt / 0.06)
    grind = granular_crunch(dur, 560.0, 0.8, 0.16, 220.0, seed=38)
    grit = granular_crunch(dur, 1900.0, 0.7, 0.11, 380.0, seed=39)
    glass = debris_crackle(dur, 0.0, 260, 0.003, hp=4000.0, seed=40) * 0.6
    scatter = debris_crackle(dur, 0.07, 130, 0.006, hp=1400.0, seed=45) * 0.45
    boom = one_pole_lp(r.uniform(-1, 1, tt.size), 70.0) * np.exp(-tt / 0.10) * 0.9
    x = fit(fit(1.4 * thud, 1.2 * grind + 0.85 * grit), fit(glass, fit(scatter, boom)))
    x = softclip(x, 2.0)
    write("crash_hard", x, peak=0.97, fade_ms=4.0)


def splash():
    """~420ms shallow-water hit at speed: noise burst body + spray + droplets."""
    dur = 0.42
    tt = t(dur)
    r = np.random.default_rng(111)
    burst = biquad_bp(r.uniform(-1, 1, tt.size), 900.0, 0.6) * np.exp(-tt / 0.06)
    spray = one_pole_hp(r.uniform(-1, 1, tt.size), 2500.0) * np.exp(-tt / 0.12) * 0.6
    body = one_pole_lp(r.uniform(-1, 1, tt.size), 400.0) * np.exp(-tt / 0.09)
    drops = debris_crackle(dur, 0.08, 160, 0.004, hp=3000.0, seed=112) * 0.5
    x = fit(fit(1.4 * burst, body), fit(spray, drops))
    x = softclip(x, 1.6)
    write("splash", x, peak=0.95, fade_ms=4.0)


def sink():
    """~0.85s deep plunge, matched to Kevin's ref (single concentrated deep
    'bloomp' — 60-120Hz 44%, little spray): soft-attack pitch-drop bloop +
    low noise body, restrained spray, small bubble settle."""
    dur = 0.85
    tt = t(dur)
    r = np.random.default_rng(121)
    # the bloomp: pitched drop with a SOFT attack (water swallows, not slaps)
    atk = np.minimum(tt / 0.03, 1.0)
    bloop = sweep(115, 52, dur, "exp") * atk * np.exp(-tt / 0.14) * 1.5
    body = one_pole_lp(r.uniform(-1, 1, tt.size), 140.0) * atk * np.exp(-tt / 0.12)
    # restrained splash edge (ref keeps highs modest)
    edge = biquad_bp(r.uniform(-1, 1, tt.size), 700.0, 0.6)
    edge = edge / (np.sqrt(np.mean(edge ** 2)) + 1e-9) * 0.35 * np.exp(-tt / 0.06)
    spray = one_pole_hp(one_pole_lp(r.uniform(-1, 1, tt.size), 6000.0), 1500.0) \
        * np.exp(-tt / 0.06) * 0.18
    # a couple of settle glugs
    glug = np.zeros(tt.size)
    for i, at in enumerate([0.42, 0.62]):
        ln = int(SR * 0.06)
        seg = biquad_bp(r.uniform(-1, 1, ln), 240.0 - i * 30.0, 2.2) \
            * np.exp(-np.arange(ln) / (SR * 0.018))
        glug[int(SR * at):int(SR * at) + ln] += seg * (0.55 - i * 0.15)
    x = fit(fit(1.4 * bloop, body), fit(edge, fit(spray, glug)))
    x = softclip(x, 1.6)
    write("sink", x, peak=0.96, fade_ms=6.0)


def pit_fall():
    """~750ms falling away: receding wind band darkening as it drops, faint
    distant thud at the bottom. Noise-based — no slide-whistle pitch."""
    dur = 0.75
    tt = t(dur)
    r = np.random.default_rng(131)
    centers = 1400.0 - 1050.0 * np.clip(tt / 0.6, 0, 1)
    wind = svf_bp(r.uniform(-1, 1, tt.size), centers, 1.2)
    env = np.minimum(tt / 0.04, 1.0) * (1.0 - np.clip((tt - 0.08) / 0.55, 0, 0.97))
    wind = wind * env * 1.4
    thud = delay(one_pole_lp(r.uniform(-1, 1, int(SR * 0.12)), 200.0)
        * np.exp(-np.arange(int(SR * 0.12)) / (SR * 0.03)), 0.60) * 0.5
    x = fit(wind, thud)
    x = softclip(x, 1.4)
    write("pit_fall", x, peak=0.93, fade_ms=6.0)


def brake():
    """~0.45s one-shot brake bite (Kevin: no loop — play once quickly when
    hard braking starts): crunchy grind burst + low judder, fast decay."""
    dur = 0.45
    tt = t(dur)
    r = np.random.default_rng(141)
    grind = granular_crunch(dur, 480.0, 0.9, 0.14, 220.0, seed=142)
    judder = biquad_bp(r.uniform(-1, 1, tt.size), 190.0, 1.0)
    rough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 30.0))
    judder = judder * (rough / (rough.max() + 1e-9)) * np.exp(-tt / 0.12) * 0.8
    edge = biquad_bp(r.uniform(-1, 1, tt.size), 1900.0, 3.0) * np.exp(-tt / 0.10) * 0.3
    bite = one_pole_hp(r.uniform(-1, 1, tt.size), 1200.0) * np.exp(-tt / 0.008) * 0.6
    x = softclip(1.3 * grind + judder + edge + bite, 1.7)
    write("brake", x, peak=0.9, fade_ms=4.0)


def jump_pad():
    """~300ms launch whump: compressed air thump + damped mechanical clank."""
    dur = 0.3
    tt = t(dur)
    r = np.random.default_rng(151)
    whump = sweep(150, 55, dur, "exp") * np.exp(-tt / 0.05) * 1.4
    whump += one_pole_lp(r.uniform(-1, 1, tt.size), 120.0) * np.exp(-tt / 0.06)
    clank = metal_modes(dur, [420, 760], [0.025, 0.018], [0.6, 0.4], seed=152)
    clank = clank * (0.5 + 0.5 * np.abs(r.uniform(-1, 1, tt.size))) * 0.45
    air = one_pole_hp(r.uniform(-1, 1, tt.size), 900.0) * np.exp(-tt / 0.08) * 0.4
    x = fit(fit(1.3 * whump, clank), air)
    x = softclip(x, 1.8)
    write("jump_pad", x, peak=0.95, fade_ms=3.0)


def pickup():
    """~160ms collect cue: latch click + short bright shimmer. Low-key."""
    dur = 0.16
    tt = t(dur)
    r = np.random.default_rng(161)
    click = one_pole_hp(r.uniform(-1, 1, tt.size), 2000.0) * np.exp(-tt / 0.004)
    body = biquad_bp(r.uniform(-1, 1, tt.size), 850.0, 2.0) * np.exp(-tt / 0.03) * 0.8
    shimmer = biquad_bp(r.uniform(-1, 1, tt.size), 3200.0, 3.0) * np.exp(-tt / 0.05) * 0.35
    x = fit(fit(click, body), shimmer)
    x = softclip(x, 1.3)
    write("pickup", x, peak=0.9, fade_ms=2.0)


def overheat():
    """~650ms MG lockout: metallic lock click, then venting steam hiss."""
    dur = 0.65
    tt = t(dur)
    r = np.random.default_rng(171)
    click = one_pole_hp(r.uniform(-1, 1, tt.size), 1500.0) * np.exp(-tt / 0.003) * 1.2
    hiss = one_pole_hp(r.uniform(-1, 1, tt.size), 3000.0) \
        * np.minimum(tt / 0.03, 1.0) * np.exp(-tt / 0.22)
    steam = biquad_bp(r.uniform(-1, 1, tt.size), 1200.0, 0.7) \
        * np.minimum(tt / 0.05, 1.0) * np.exp(-tt / 0.3) * 0.5
    x = fit(click, 1.1 * hiss + steam)
    x = softclip(x, 1.2)
    write("overheat", x, peak=0.9, fade_ms=5.0)


def win_sting():
    """~1.1s triumphant hit: two big percussive booms (low then higher) with a
    bright accent — drums, not melody; stays in the gritty house voice."""
    dur = 1.1
    tt = t(dur)
    r = np.random.default_rng(181)
    hit1 = sweep(180, 60, dur, "exp") * np.exp(-tt / 0.12) * 1.4
    hit1 += one_pole_lp(r.uniform(-1, 1, tt.size), 300.0) * np.exp(-tt / 0.10)
    n2 = int(SR * (dur - 0.28))
    t2 = np.linspace(0, dur - 0.28, n2, endpoint=False)
    hit2 = np.sin(2 * np.pi * np.cumsum(260.0 - 150.0 * np.clip(t2 / 0.3, 0, 1)) / SR) \
        * np.exp(-t2 / 0.10) * 0.9
    accent = biquad_bp(r.uniform(-1, 1, n2), 2400.0, 2.0) * np.exp(-t2 / 0.3) * 0.35
    tail = one_pole_lp(r.uniform(-1, 1, tt.size), 250.0) * np.exp(-tt / 0.5) * 0.4
    x = fit(fit(softclip(hit1, 2.2), delay(hit2 + accent, 0.28)), tail)
    write("win_sting", x, peak=0.96, fade_ms=8.0)


def lose_sting():
    """~1.2s deflated: dull thud + dark detuned drone sagging downward."""
    dur = 1.2
    tt = t(dur)
    r = np.random.default_rng(191)
    thud = sweep(120, 45, dur, "exp") * np.exp(-tt / 0.08) * 1.2
    f = 80.0 - 22.0 * np.clip(tt / 0.9, 0, 1)  # the sag
    ph = np.cumsum(f) / SR
    drone = np.sin(2 * np.pi * ph) + 0.6 * np.sin(2 * np.pi * ph * 1.031) \
        + 0.4 * np.sin(2 * np.pi * ph * 2.02)
    env = np.minimum(tt / 0.05, 1.0) * np.exp(-tt / 0.55)
    grit = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 25.0))
    drone = one_pole_lp(drone, 350.0) * env * (0.7 + 0.3 * grit / (grit.max() + 1e-9))
    x = fit(softclip(thud, 1.8), softclip(drone, 1.6) * 0.9)
    write("lose_sting", x, peak=0.94, fade_ms=10.0)


def ui_move():
    """~45ms tiny tick — selection moved."""
    dur = 0.045
    r = np.random.default_rng(201)
    x = biquad_bp(r.uniform(-1, 1, int(SR * dur)), 2200.0, 3.0) \
        * np.exp(-t(dur) / 0.008)
    write("ui_move", x, peak=0.85, fade_ms=1.5)


def ui_select():
    """~90ms confirm click — a touch more body than the move tick."""
    dur = 0.09
    tt = t(dur)
    r = np.random.default_rng(202)
    click = one_pole_hp(r.uniform(-1, 1, tt.size), 1800.0) * np.exp(-tt / 0.004)
    body = biquad_bp(r.uniform(-1, 1, tt.size), 900.0, 2.0) * np.exp(-tt / 0.025) * 0.9
    x = softclip(fit(click, body), 1.3)
    write("ui_select", x, peak=0.88, fade_ms=1.5)


def ui_back():
    """~70ms darker tick — stepping back down a level."""
    dur = 0.07
    tt = t(dur)
    r = np.random.default_rng(203)
    x = biquad_bp(r.uniform(-1, 1, tt.size), 620.0, 2.0) * np.exp(-tt / 0.02)
    x += one_pole_hp(r.uniform(-1, 1, tt.size), 1500.0) * np.exp(-tt / 0.003) * 0.5
    write("ui_back", x, peak=0.85, fade_ms=1.5)


def _two_tick(name, f1, f2, seed):
    """MP presence cues: two ticks — second one brighter (join) or darker
    (leave). Percussive direction cue, not a melody."""
    dur = 0.2
    r = np.random.default_rng(seed)
    ln = int(SR * 0.08)
    e = np.exp(-np.arange(ln) / (SR * 0.015))
    t1 = biquad_bp(r.uniform(-1, 1, ln), f1, 2.5) * e
    t2 = biquad_bp(r.uniform(-1, 1, ln), f2, 2.5) * e
    x = fit(np.concatenate([t1, np.zeros(int(SR * dur) - ln)]), delay(t2, 0.09))
    write(name, softclip(x, 1.3), peak=0.88, fade_ms=2.0)


def mp_join():
    _two_tick("mp_join", 900.0, 1500.0, 211)


def mp_leave():
    _two_tick("mp_leave", 1400.0, 680.0, 212)


# ---- per-car specials (2026-07-14): sp_<def basename>, ref-matched ---------
def loopify(x, body, xf=0.06):
    """Wrap-crossfade the tail over the head and trim to body seconds — the
    skid-loop seam technique, shared by the sustained specials."""
    n = int(SR * body)
    k = int(SR * xf)
    w = np.linspace(0.0, 1.0, k)
    out = x[:n].copy()
    out[:k] = x[n:n + k] * (1.0 - w) + out[:k] * w
    return out


def sp_blunt_blaze():
    """~1s SEAMLESS flamethrower loop (ref: sub-heavy roar 53% + breathy hiss):
    deep rough rumble under a gas hiss. Loops while the flame is on."""
    body = 1.0
    dur = body + 0.06
    tt = t(dur)
    r = np.random.default_rng(301)
    rumble = one_pole_lp(r.uniform(-1, 1, tt.size), 130.0)
    rough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 22.0))
    rumble = rumble * (0.55 + 0.45 * rough / (rough.max() + 1e-9))
    rumble = rumble / (np.sqrt(np.mean(rumble ** 2)) + 1e-9)
    sub = one_pole_lp(r.uniform(-1, 1, tt.size), 55.0)
    sub = sub / (np.sqrt(np.mean(sub ** 2)) + 1e-9) * 0.9
    hiss = one_pole_hp(r.uniform(-1, 1, tt.size), 3500.0)
    hiss = hiss / (np.sqrt(np.mean(hiss ** 2)) + 1e-9) * 0.22
    mid = biquad_bp(r.uniform(-1, 1, tt.size), 420.0, 0.6)
    mid = mid / (np.sqrt(np.mean(mid ** 2)) + 1e-9) * 0.30
    x = softclip((rumble + sub + hiss + mid) * 1.2, 1.8)
    write("sp_blunt_blaze", loopify(x, body), peak=0.92, fade_ms=0.0)


def sp_taser():
    """~0.9s SEAMLESS electric-arc loop (ref: >4k 67% — bright dense crackle)."""
    body = 0.9
    dur = body + 0.06
    tt = t(dur)
    r = np.random.default_rng(311)
    # dense sharp arc snaps
    snaps = debris_crackle(dur, 0.0, 1400, 0.0008, hp=4500.0, seed=312)
    snaps = snaps / (np.sqrt(np.mean(snaps ** 2)) + 1e-9)
    sizzle = biquad_bp(r.uniform(-1, 1, tt.size), 1900.0, 0.8)
    rough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 90.0))
    sizzle = sizzle * (0.4 + 0.6 * rough / (rough.max() + 1e-9))
    sizzle = sizzle / (np.sqrt(np.mean(sizzle ** 2)) + 1e-9) * 0.75
    x = softclip((snaps + sizzle) * 0.8, 1.5)
    write("sp_taser", loopify(x, body), peak=0.9, fade_ms=0.0)


def sp_leap():
    """~0.85s dash lunge (ref: dirt racer accelerating — 60-300Hz engine roar
    ramp): rough rising rev burst that cuts off as the car leaves."""
    dur = 0.85
    tt = t(dur)
    r = np.random.default_rng(321)
    f0 = 55.0 + 65.0 * np.clip(tt / 0.5, 0, 1)
    ph = np.cumsum(f0) / SR
    eng = np.zeros(tt.size)
    for k, a in enumerate([0.9, 1.0, 0.7, 0.45, 0.28, 0.16], start=1):
        eng += a * np.sin(2 * np.pi * k * ph)
    grit = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 60.0))
    eng = eng * (0.7 + 0.3 * grit / (grit.max() + 1e-9))
    env = np.minimum(tt / 0.05, 1.0) * (1.0 - np.clip((tt - 0.62) / 0.20, 0, 1))
    eng = softclip(eng * env * 1.8, 2.2)
    eng = one_pole_lp(eng, 1500.0)
    dirt = biquad_bp(r.uniform(-1, 1, tt.size), 900.0, 0.7)
    dirt = dirt / (np.sqrt(np.mean(dirt ** 2)) + 1e-9) * 0.30 * env
    x = fit(eng, dirt)
    write("sp_leap", x, peak=0.94, fade_ms=5.0)


def sp_tornado_alley():
    """~3s whirlwind matching the spin duration (ref: real tornado — broadband
    roar 120Hz-1k with slow undulation, real sub): fade in fast, churn, die."""
    dur = 3.0
    tt = t(dur)
    r = np.random.default_rng(331)
    roar = biquad_bp(r.uniform(-1, 1, tt.size), 240.0, 0.5)
    roar = roar / (np.sqrt(np.mean(roar ** 2)) + 1e-9)
    midr = biquad_bp(r.uniform(-1, 1, tt.size), 550.0, 0.7)
    midr = midr / (np.sqrt(np.mean(midr ** 2)) + 1e-9) * 0.8
    low = one_pole_lp(r.uniform(-1, 1, tt.size), 110.0)
    low = low / (np.sqrt(np.mean(low ** 2)) + 1e-9) * 0.75
    sub = one_pole_lp(r.uniform(-1, 1, tt.size), 50.0)
    sub = sub / (np.sqrt(np.mean(sub ** 2)) + 1e-9) * 0.65
    und = one_pole_lp(r.uniform(-1, 1, tt.size), 1.8)
    und = 0.65 + 0.35 * und / (np.max(np.abs(und)) + 1e-9)
    env = np.minimum(tt / 0.25, 1.0) * (1.0 - np.clip((tt - 2.45) / 0.55, 0, 1))
    x = one_pole_lp(softclip((roar + midr + low + sub) * und * 0.7, 1.9), 1600.0) * env
    write("sp_tornado_alley", x, peak=0.94, fade_ms=8.0)


def sp_toe_jam():
    """~1.1s trap-landed stab: an ORIGINAL distorted power-chord hit in the
    ref riff's character (chug-chug-STAB rhythm, 120-300 body + 1-4k edge) —
    vibe-alike, not the song's melody."""
    dur = 1.1
    r = np.random.default_rng(341)
    def chord(dur_c, f, drive, seed):
        tc = t(dur_c)
        rr = np.random.default_rng(seed)
        x = saw(f, dur_c) + saw(f * 1.5, dur_c) + 0.7 * saw(f * 2.0, dur_c) \
            + 0.4 * saw(f * 1.007, dur_c)  # detune grit
        x = softclip(x * drive, 3.0)
        x = one_pole_lp(x, 5200.0)
        sn = one_pole_hp(one_pole_lp(rr.uniform(-1, 1, tc.size), 6000.0), 2500.0)
        x += sn * 0.4  # string/pick noise
        return x
    # two palm-muted chugs then the open stab
    chug1 = chord(0.14, 82.0, 2.5, 342) * env_exp(0.14, 0.05)
    chug2 = chord(0.14, 82.0, 2.5, 343) * env_exp(0.14, 0.05)
    stab = chord(0.75, 110.0, 2.2, 344) * env_exp(0.75, 0.28)
    x = fit(fit(chug1, delay(chug2, 0.17)), delay(stab, 0.34))
    write("sp_toe_jam", x, peak=0.94, fade_ms=6.0)


def sp_molotov():
    """~1.2s glass smash + fire whump (ref: smash spike then 120-300Hz-heavy
    fire bloom, modest highs)."""
    dur = 1.2
    tt = t(dur)
    r = np.random.default_rng(351)
    glass = debris_crackle(dur, 0.0, 300, 0.0025, hp=3800.0, seed=352)
    glass = glass / (np.sqrt(np.mean(glass ** 2)) + 1e-9) * 0.18 * np.exp(-tt / 0.09)
    # fire whump blooming just after the smash
    n2 = int(SR * (dur - 0.08))
    t2 = np.linspace(0, dur - 0.08, n2, endpoint=False)
    r2 = np.random.default_rng(353)
    whump = biquad_bp(r2.uniform(-1, 1, n2), 200.0, 0.5)
    whump = whump / (np.sqrt(np.mean(whump ** 2)) + 1e-9) * 1.7 \
        * np.minimum(t2 / 0.06, 1.0) * np.exp(-t2 / 0.30)
    lowb = one_pole_lp(r2.uniform(-1, 1, n2), 110.0)
    lowb = lowb / (np.sqrt(np.mean(lowb ** 2)) + 1e-9) * 0.45 * np.exp(-t2 / 0.18)
    firecrk = debris_crackle(dur - 0.08, 0.15, 90, 0.005, hp=2200.0, seed=354)
    firecrk = firecrk / (np.sqrt(np.mean(firecrk ** 2)) + 1e-9) * 0.12
    x = fit(glass, delay(softclip(whump + lowb, 1.7) + firecrk, 0.08))
    write("sp_molotov", x, peak=0.95, fade_ms=6.0)


def sp_pulse_wave():
    """~1.4s expanding shockwave (ref: 60-120Hz 70% — a deep slow bloom):
    sub swell rising then rolling away, faint bright front edge."""
    dur = 1.4
    tt = t(dur)
    r = np.random.default_rng(361)
    f = 82.0 - 26.0 * np.clip(tt / 1.1, 0, 1)
    ph = np.cumsum(f) / SR
    swell = np.sin(2 * np.pi * ph) + 0.5 * np.sin(2 * np.pi * 2.0 * ph)
    env = np.minimum(tt / 0.22, 1.0) * (1.0 - np.clip((tt - 0.75) / 0.6, 0, 1))
    grit = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 18.0))
    swell = softclip(swell * (0.75 + 0.25 * grit / (grit.max() + 1e-9)) * env * 1.6, 1.8)
    lown = one_pole_lp(r.uniform(-1, 1, tt.size), 100.0) * env * 0.7
    edge = biquad_bp(r.uniform(-1, 1, tt.size), 2200.0, 1.5)
    edge = edge / (np.sqrt(np.mean(edge ** 2)) + 1e-9) * 0.16 * env
    mid = biquad_bp(r.uniform(-1, 1, tt.size), 500.0, 0.8)
    mid = mid / (np.sqrt(np.mean(mid ** 2)) + 1e-9) * 0.20 * env
    edge = edge + mid
    x = swell + lown + edge
    write("sp_pulse_wave", x, peak=0.95, fade_ms=8.0)


def sp_chill_out():
    """~0.6s 'beep!beep!' from a weak nasal horn (ref: 1-4k 86%) — the
    pacifist's love-tap."""
    r = np.random.default_rng(371)
    def beep(dur_b, seed):
        tb = t(dur_b)
        x = np.sin(2 * np.pi * 1240.0 * tb) + 0.9 * np.sin(2 * np.pi * 1860.0 * tb) \
            + 0.45 * np.sin(2 * np.pi * 2480.0 * tb) + 0.25 * np.sin(2 * np.pi * 3720.0 * tb)
        x = softclip(x * 1.6, 2.0)  # nasal squawk, not a pure tone
        e = np.minimum(tb / 0.012, 1.0) * (1.0 - np.clip((tb - dur_b + 0.03) / 0.03, 0, 1))
        return x * e
    x = fit(beep(0.16, 372), delay(beep(0.20, 373), 0.25))
    write("sp_chill_out", x, peak=0.9, fade_ms=3.0)


def sp_red_glare():
    """~0.7s single rocket leaving (plays once per volley rocket, x3): snappy
    bang + fast bright whoosh (ref: .3-1k 36% / 1-4k 41%, instant attack)."""
    dur = 0.7
    tt = t(dur)
    r = np.random.default_rng(381)
    bang = one_pole_hp(r.uniform(-1, 1, tt.size), 500.0) * np.exp(-tt / 0.012) * 1.4
    cut = 600 + 1300 * np.clip(tt / 0.06, 0, 1) - 1100 * np.clip((tt - 0.06) / 0.4, 0, 1)
    woo = svf_bp(r.uniform(-1, 1, tt.size), cut, 1.0)
    woo = woo / (np.sqrt(np.mean(woo ** 2)) + 1e-9) * 0.35 \
        * np.minimum(tt / 0.02, 1.0) * np.exp(-tt / 0.16)
    body = biquad_bp(r.uniform(-1, 1, tt.size), 420.0, 0.6)
    body = body / (np.sqrt(np.mean(body ** 2)) + 1e-9) * 0.18 * np.exp(-tt / 0.14)
    crk = debris_crackle(dur, 0.0, 500, 0.001, hp=2800.0, seed=382)
    crk = crk / (np.sqrt(np.mean(crk ** 2)) + 1e-9) * 0.10 * np.exp(-tt / 0.15)
    x = one_pole_lp(softclip(fit(bang * 0.7, (woo + body) * 3.0) + crk, 1.5), 5200.0)
    write("sp_red_glare", x, peak=0.94, fade_ms=4.0)


def boost():
    """~0.8s ignition roar morphing into a rising whoosh — the onset voice;
    boost_loop takes over for the duration. Engine bite = harmonic stack rev,
    no clean sweeps."""
    dur = 0.8
    tt = t(dur)
    r = np.random.default_rng(501)
    # rev bite: f0 kicks 70->130Hz fast, gritty
    f0 = 70.0 + 60.0 * np.clip(tt / 0.18, 0, 1)
    ph = np.cumsum(f0) / SR
    eng = np.zeros(tt.size)
    for k, a in enumerate([0.9, 1.0, 0.7, 0.45, 0.25, 0.14], start=1):
        eng += a * np.sin(2 * np.pi * k * ph)
    grit = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 70.0))
    eng = eng * (0.7 + 0.3 * grit / (grit.max() + 1e-9))
    eng_env = np.minimum(tt / 0.02, 1.0) * (1.0 - np.clip((tt - 0.30) / 0.35, 0, 1))
    eng = one_pole_lp(softclip(eng * eng_env * 2.0, 2.2), 1200.0)
    # whoosh rises as the roar hands off (crossfades toward the loop's voice)
    cut = 500 + 1300 * np.clip((tt - 0.15) / 0.45, 0, 1)
    woo = svf_bp(r.uniform(-1, 1, tt.size), cut, 1.0)
    woo_env = np.clip((tt - 0.15) / 0.25, 0, 1)
    woo = woo / (np.sqrt(np.mean(woo ** 2)) + 1e-9) * 0.30 * woo_env
    rumble = one_pole_lp(r.uniform(-1, 1, tt.size), 140.0)
    rumble = rumble / (np.sqrt(np.mean(rumble ** 2)) + 1e-9) * 0.35 * woo_env
    x = fit(eng, softclip((woo + rumble) * 2.0, 1.5))
    write("boost", x, peak=0.94, fade_ms=5.0)


def boost_loop():
    """~0.9s SEAMLESS whoosh loop riding the burn: airy band + low rumble,
    rough-modulated so it breathes. Same wrap-crossfade seam as skid."""
    body = 0.9
    dur = body + 0.06
    tt = t(dur)
    r = np.random.default_rng(511)
    air = biquad_bp(r.uniform(-1, 1, tt.size), 1500.0, 0.7)
    air = air / (np.sqrt(np.mean(air ** 2)) + 1e-9)
    wob = one_pole_lp(r.uniform(-1, 1, tt.size), 5.0)
    air = air * (0.75 + 0.25 * wob / (np.max(np.abs(wob)) + 1e-9))
    rumble = one_pole_lp(r.uniform(-1, 1, tt.size), 140.0)
    rumble = rumble / (np.sqrt(np.mean(rumble ** 2)) + 1e-9) * 0.8
    x = softclip((air + rumble) * 0.8, 1.6)
    write("boost_loop", loopify(x, body), peak=0.9, fade_ms=0.0)


def splat():
    """~0.28s wet verdict for a soft target: low thud + wet mid burst +
    irregular droplet spatter."""
    dur = 0.28
    tt = t(dur)
    r = np.random.default_rng(521)
    thud = sweep(150, 60, dur, "exp") * np.exp(-tt / 0.03) * 1.2
    wet = biquad_bp(r.uniform(-1, 1, tt.size), 650.0, 0.6)
    wet = wet / (np.sqrt(np.mean(wet ** 2)) + 1e-9) * 0.9 * np.exp(-tt / 0.045)
    spatter = debris_crackle(dur, 0.015, 220, 0.003, hp=1200.0, seed=522)
    spatter = spatter / (np.sqrt(np.mean(spatter ** 2)) + 1e-9) * 0.35 \
        * np.exp(-tt / 0.09)
    x = softclip(fit(thud, wet) + spatter, 1.7)
    write("splat", x, peak=0.93, fade_ms=3.0)


def crunch():
    """~0.25s dry verdict: granular crunch + discrete snaps + small thud."""
    dur = 0.25
    tt = t(dur)
    r = np.random.default_rng(531)
    grind = granular_crunch(dur, 750.0, 0.8, 0.05, 300.0, seed=532)
    grit = granular_crunch(dur, 2100.0, 0.7, 0.035, 450.0, seed=533)
    snaps = np.zeros(tt.size)
    for at in [0.004, 0.05, 0.11]:
        ln = int(SR * 0.015)
        seg = one_pole_hp(r.uniform(-1, 1, ln), 1800.0) \
            * np.exp(-np.arange(ln) / (SR * 0.003))
        snaps[int(SR * at):int(SR * at) + ln] += seg
    thud = sweep(140, 70, dur, "exp") * np.exp(-tt / 0.02) * 0.7
    x = softclip(1.1 * grind + 0.7 * grit + 0.8 * snaps + thud, 1.8)
    write("crunch", x, peak=0.93, fade_ms=3.0)


def sp_placeholder():
    """~1.15s 'WHERE'S THE BEEF?' — hand-rolled FORMANT SYNTHESIS (no TTS on
    the box; Kevin chose delightfully robotic). Glottal harmonic buzz through
    three keyframed formant resonators (svf_bp with per-sample tracks) +
    consonant noise bursts; prosody matched to the ref's indignant ~320Hz
    shout; finished through a wasteland-radio band + bitcrush. Plays whenever
    a special fires without its own sp_* asset."""
    dur = 1.15
    tt = t(dur)
    n = tt.size
    r = np.random.default_rng(401)
    # prosody keyframes: WHERE'S(0-0.38) the(0.40-0.52) [b]BEEF!(0.58-1.08)
    kt = [0.00, 0.06, 0.26, 0.32, 0.38, 0.40, 0.44, 0.52, 0.58, 0.62, 0.80, 0.95, 1.00, 1.15]
    f0 = np.interp(tt, kt, [240, 255, 250, 235, 230, 225, 220, 220, 320, 335, 320, 290, 270, 250])
    jig = one_pole_lp(r.uniform(-1, 1, n), 9.0)
    f0 = f0 * (1.0 + 0.012 * jig / (np.max(np.abs(jig)) + 1e-9))
    voiced = np.interp(tt,
        [0.00, 0.03, 0.30, 0.34, 0.385, 0.40, 0.42, 0.50, 0.52, 0.585, 0.60, 0.90, 0.945, 0.96, 1.15],
        [0.0, 0.55, 0.60, 0.40, 0.15, 0.0, 0.30, 0.35, 0.0, 0.0, 1.0, 0.95, 0.30, 0.0, 0.0])
    # glottal buzz: harmonic stack, gated by voicing
    ph = np.cumsum(f0) / SR
    src = np.zeros(n)
    for k in range(1, 15):
        src += np.sin(2 * np.pi * k * ph) / k
    src *= voiced
    # formant tracks: w -> EH(air) -> r(F3 dip) -> z | dh-uh | b -> EE -> f
    F1 = np.interp(tt, kt, [350, 650, 640, 560, 500, 480, 520, 520, 200, 320, 320, 320, 300, 300])
    F2 = np.interp(tt, kt, [700, 1900, 1850, 1500, 1500, 1450, 1500, 1500, 900, 2600, 2650, 2600, 2400, 2200])
    F3 = np.interp(tt, kt, [2300, 2800, 2750, 1800, 2400, 2500, 2600, 2600, 2500, 3200, 3200, 3150, 3000, 3000])
    v = svf_bp(src, F1, 6.0) + 0.6 * svf_bp(src, F2, 8.0) + 0.3 * svf_bp(src, F3, 8.0)
    v = v / (np.max(np.abs(v)) + 1e-9)
    # consonants: z, dh, b-burst, f
    def seg_env(a, b, atk=0.01):
        return np.clip((tt - a) / atk, 0, 1) * np.clip((b - tt) / atk, 0, 1)
    zz = one_pole_hp(r.uniform(-1, 1, n), 3500.0) * seg_env(0.32, 0.40) * 0.22
    dh = biquad_bp(r.uniform(-1, 1, n), 1400.0, 1.0)
    dh = dh / (np.sqrt(np.mean(dh ** 2)) + 1e-9) * 0.06 * seg_env(0.40, 0.45)
    bb = one_pole_lp(r.uniform(-1, 1, n), 400.0) * seg_env(0.58, 0.605, 0.004) * 0.8
    ff = one_pole_hp(r.uniform(-1, 1, n), 3000.0) * seg_env(0.95, 1.10) * 0.28
    x = v + zz + dh + bb + ff
    # wasteland radio: drive + crunchy quantize FIRST, band-limit last so the
    # quantization grit stays inside the radio band instead of hissing to 20k
    x = softclip(x * 2.2, 1.8)
    x = np.round(x * 28.0) / 28.0
    x = one_pole_hp(one_pole_lp(x, 3000.0), 250.0)
    write("sp_placeholder", x, peak=0.92, fade_ms=6.0)


# ---- final specials (2026-07-14 pm): the beef retires -----------------------
def sp_rusty_poon():
    """~0.7s harpoon launch (ref: mid-forward pneumatic crack, .3-1k 47%):
    gas crack + air release + brief cable whir. Impact stays in hit_weapon."""
    dur = 0.7
    tt = t(dur)
    r = np.random.default_rng(601)
    crack = biquad_bp(r.uniform(-1, 1, tt.size), 620.0, 0.5)
    crack = crack / (np.sqrt(np.mean(crack ** 2)) + 1e-9) * np.exp(-tt / 0.018) * 1.6
    click = one_pole_hp(r.uniform(-1, 1, tt.size), 3200.0) * np.exp(-tt / 0.005) * 0.35
    cut = 900 - 500 * np.clip(tt / 0.35, 0, 1)
    air = svf_bp(r.uniform(-1, 1, tt.size), cut, 1.0)
    air = air / (np.sqrt(np.mean(air ** 2)) + 1e-9) * 0.30 * \
        np.minimum(tt / 0.02, 1.0) * np.exp(-tt / 0.14)
    whir = biquad_bp(r.uniform(-1, 1, tt.size), 2500.0, 2.0)
    rough = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 120.0))
    whir = whir / (np.sqrt(np.mean(whir ** 2)) + 1e-9) * 0.15 \
        * (rough / (rough.max() + 1e-9)) * np.exp(-tt / 0.2)
    thunk = sweep(160, 80, dur, "exp") * np.exp(-tt / 0.03) * 0.6
    x = one_pole_lp(softclip(fit(crack + click, air + whir) + thunk, 1.6), 4500.0)
    write("sp_rusty_poon", x, peak=0.94, fade_ms=4.0)


def sp_chilblain():
    """~0.85s freeze snap (ref: bright icy crack, 1-4k 40 / >4k 37, faint low
    thud): crystalline crackle burst + glassy shimmer tail + cold air."""
    dur = 0.85
    tt = t(dur)
    r = np.random.default_rng(611)
    snap = debris_crackle(dur, 0.0, 500, 0.0015, hp=2800.0, seed=612)
    snap = snap / (np.sqrt(np.mean(snap ** 2)) + 1e-9) * np.exp(-tt / 0.05)
    shimmer = biquad_bp(r.uniform(-1, 1, tt.size), 4200.0, 2.5)
    shimmer = shimmer / (np.sqrt(np.mean(shimmer ** 2)) + 1e-9) * 0.35 \
        * np.minimum(tt / 0.03, 1.0) * np.exp(-tt / 0.28)
    mid = biquad_bp(r.uniform(-1, 1, tt.size), 2000.0, 1.0)
    mid = mid / (np.sqrt(np.mean(mid ** 2)) + 1e-9) * 1.0 * np.exp(-tt / 0.10)
    thud = one_pole_lp(r.uniform(-1, 1, tt.size), 80.0)
    thud = thud / (np.sqrt(np.mean(thud ** 2)) + 1e-9) * 0.45 * np.exp(-tt / 0.06)
    x = softclip(snap + shimmer + mid + thud, 1.5)
    write("sp_chilblain", x, peak=0.93, fade_ms=4.0)


def sp_phantom_phire():
    """~1.1s ghostly projectile (ref is bimodal: low moan 60-120 40% + airy
    1-4k 30%): wavering hollow moan under a breathy high band, departing."""
    dur = 1.1
    tt = t(dur)
    r = np.random.default_rng(621)
    f = 88.0 * (1.0 + 0.04 * np.sin(2 * np.pi * 3.2 * tt))
    ph = np.cumsum(f) / SR
    moan = np.sin(2 * np.pi * ph) + 0.5 * np.sin(2 * np.pi * ph * 1.02) \
        + 0.3 * np.sin(2 * np.pi * ph * 2.03)
    wav = 0.7 + 0.3 * np.sin(2 * np.pi * 2.1 * tt + 1.0)
    env = np.minimum(tt / 0.12, 1.0) * (1.0 - np.clip((tt - 0.6) / 0.5, 0, 1))
    moan = one_pole_lp(moan * wav, 250.0) * env
    moan = moan / (np.max(np.abs(moan)) + 1e-9)
    breath = biquad_bp(r.uniform(-1, 1, tt.size), 2000.0, 0.8)
    slow = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 4.0))
    breath = breath / (np.sqrt(np.mean(breath ** 2)) + 1e-9) * 0.62 \
        * (0.5 + 0.5 * slow / (slow.max() + 1e-9)) * env
    mid = biquad_bp(r.uniform(-1, 1, tt.size), 620.0, 1.0)
    mid = mid / (np.sqrt(np.mean(mid ** 2)) + 1e-9) * 0.32 * env
    breath = one_pole_lp(breath, 3200.0)
    x = softclip(moan * 0.9 + breath * 0.8 + mid, 1.5)
    write("sp_phantom_phire", x, peak=0.92, fade_ms=8.0)


def sp_scythe():
    """~0.95s twin shriek stabs — ORIGINAL dissonant string-cluster hits in
    the ref's character (~2.5kHz, two peaks), never the Psycho recording."""
    def stab(dur_s, base, seed):
        ts = t(dur_s)
        rr = np.random.default_rng(seed)
        x = np.zeros(ts.size)
        for det in [1.0, 1.028, 1.061]:  # tight dissonant cluster
            x += saw(base * det, dur_s)
        x = softclip(x * 2.2, 2.5)
        x = one_pole_hp(one_pole_lp(x, 6000.0), 900.0)
        bow = biquad_bp(rr.uniform(-1, 1, ts.size), 2600.0, 1.5)
        bow = bow / (np.sqrt(np.mean(bow ** 2)) + 1e-9) * 0.3
        return (x + bow) * np.minimum(ts / 0.008, 1.0) * np.exp(-ts / 0.16)
    x = fit(stab(0.5, 1240.0, 631), delay(stab(0.5, 1310.0, 632) * 1.1, 0.45))
    write("sp_scythe", x, peak=0.93, fade_ms=4.0)


# ---- stage-event alerts (once-per-level, global) -----------------------------
def env_siren():
    """~3.6s police wail (ref sweeps ~830-1450Hz): two dual-horn wail cycles
    with sirens' natural distortion, city slap, fading out."""
    dur = 3.6
    tt = t(dur)
    r = np.random.default_rng(641)
    f = 780.0 + 660.0 * (0.5 - 0.5 * np.cos(2 * np.pi * tt / 2.0))
    ph = np.cumsum(f) / SR
    tone = np.sin(2 * np.pi * ph) + 0.45 * np.sin(2 * np.pi * 2 * ph) \
        + 0.18 * np.sin(2 * np.pi * 3 * ph)
    tone = softclip(tone * 1.8, 2.0)  # horn-driver bark
    env = np.minimum(tt / 0.15, 1.0) * (1.0 - np.clip((tt - 2.9) / 0.7, 0, 1))
    x = tone * env
    out = np.zeros(x.size + int(SR * 0.3))
    out[:x.size] += x
    j = int(SR * 0.18)
    out[j:j + x.size] += x * 0.28  # street slap
    air = one_pole_hp(r.uniform(-1, 1, out.size), 3000.0) * 0.03
    write("env_siren", one_pole_hp(out + air, 300.0), peak=0.92, fade_ms=10.0)


def env_panic():
    """~3.2s crowd panic (ref: sustained 1-4k screams, no lows): a shaped
    crowd bed + a handful of swooping scream voices, rising then breaking."""
    dur = 3.2
    tt = t(dur)
    r = np.random.default_rng(651)
    bed = biquad_bp(r.uniform(-1, 1, tt.size), 1800.0, 0.5)
    churn = np.abs(one_pole_lp(r.uniform(-1, 1, tt.size), 7.0))
    bed = bed / (np.sqrt(np.mean(bed ** 2)) + 1e-9) \
        * (0.55 + 0.45 * churn / (churn.max() + 1e-9))
    screams = np.zeros(tt.size)
    for i in range(9):
        at = r.uniform(0.1, 2.4)
        ln = int(SR * r.uniform(0.25, 0.55))
        tv = np.linspace(0, ln / SR, ln, endpoint=False)
        f0 = r.uniform(700, 1200)
        fv = f0 * (1.0 + 0.6 * np.sin(np.pi * tv / tv[-1]))  # rise-fall swoop
        v = np.sin(2 * np.pi * np.cumsum(fv) / SR)
        v += 0.5 * np.sin(2 * np.pi * 2 * np.cumsum(fv) / SR)
        v = softclip(v * 2.0, 2.0) * np.sin(np.pi * tv / tv[-1]) ** 0.7
        j = int(SR * at)
        screams[j:j + ln] += v * r.uniform(0.25, 0.5)
    screams = one_pole_hp(one_pole_lp(one_pole_lp(screams, 3200.0), 3200.0), 700.0)
    env = np.minimum(tt / 0.3, 1.0) * (1.0 - np.clip((tt - 2.6) / 0.6, 0, 1))
    x = one_pole_lp(one_pole_lp(softclip((bed * 0.8 + screams) * env, 1.6), 3000.0), 3000.0)
    write("env_panic", x, peak=0.9, fade_ms=12.0)


def env_chopper():
    """~4.2s huey lifting off (ref: 10.8Hz two-blade slap, ~53Hz drone, heavy
    60-120): slap train quickening slightly + rotor drone + faint turbine."""
    dur = 4.2
    tt = t(dur)
    n = tt.size
    r = np.random.default_rng(661)
    # blade slaps: rate ramps 10.2 -> 11.4Hz (spooling up)
    rate = 10.2 + 1.2 * np.clip(tt / 3.0, 0, 1)
    ph = np.cumsum(rate) / SR
    slaps = np.zeros(n)
    prev = -1
    for i in range(n):
        k = int(ph[i])
        if k != prev:
            prev = k
            ln = min(int(SR * 0.045), n - i)
            burst = biquad_bp(r.uniform(-1, 1, ln), 105.0, 0.7) \
                * np.exp(-np.arange(ln) / (SR * 0.012))
            chuff = biquad_bp(r.uniform(-1, 1, ln), 320.0, 0.8) \
                * np.exp(-np.arange(ln) / (SR * 0.008))
            slaps[i:i + ln] += burst * 5.5 + chuff * 2.2
    # rotor/engine drone ~53Hz harmonics, rough
    phd = np.cumsum(53.0 * (1.0 + 0.02 * np.clip(tt / 3.0, 0, 1))) / SR
    drone = np.zeros(n)
    for k, a in enumerate([0.4, 1.0, 0.65, 0.35, 0.18], start=1):
        drone += a * np.sin(2 * np.pi * k * phd)
    grit = np.abs(one_pole_lp(r.uniform(-1, 1, n), 30.0))
    drone = one_pole_lp(drone * (0.7 + 0.3 * grit / (grit.max() + 1e-9)), 300.0)
    drone = drone / (np.max(np.abs(drone)) + 1e-9) * 0.6
    turbine = biquad_bp(r.uniform(-1, 1, n), 2600.0, 3.0)
    turbine = turbine / (np.sqrt(np.mean(turbine ** 2)) + 1e-9) * 0.06
    env = np.minimum(tt / 0.4, 1.0) * (1.0 - np.clip((tt - 3.4) / 0.8, 0, 1))
    x = softclip((slaps + drone + turbine) * env, 1.7)
    write("env_chopper", x, peak=0.93, fade_ms=15.0)


def env_genny():
    """~3s generator death (ref: deep muffled boom, sub 43% / 60-120 34%):
    distance-muffled double boom + electrical arc sizzle — the yard goes dark."""
    dur = 3.0
    tt = t(dur)
    r = np.random.default_rng(671)
    main = explosion(dur, sub_f0=70, sub_f1=24, sub_tau=0.32, mid_tau=0.18,
                     tail_tau=0.5, drive=1.8, seed=672)
    main = one_pole_lp(main, 650.0)  # heard through the arena — muffled
    subx = one_pole_lp(np.random.default_rng(675).uniform(-1, 1, tt.size), 42.0)
    subx = subx / (np.sqrt(np.mean(subx ** 2)) + 1e-9) * 1.8 * np.exp(-tt / 0.35)
    main = main + subx
    sec = explosion(1.2, sub_f0=80, sub_f1=30, sub_tau=0.14, mid_tau=0.10,
                    tail_tau=0.25, drive=1.6, seed=673) * 0.5
    sec = one_pole_lp(sec, 400.0)
    arcs = debris_crackle(dur, 0.3, 60, 0.004, hp=3000.0, seed=674)
    arcs = arcs / (np.sqrt(np.mean(arcs ** 2)) + 1e-9) * 0.10 * np.exp(-tt / 0.9)
    x = fit(main, delay(sec, 1.3)) + arcs
    write("env_genny", x, peak=0.95, fade_ms=15.0)


# ---- PA announcer (2026-07-14): baked speech, no runtime TTS ----------------
# Rendered on the dev box via espeak-ng (optional dep — section skips with a
# notice when absent; the .ogg files are committed, so other boxes never need
# it). Deep mechanical voice through a stadium-PA chain: horn-speaker band,
# drive, slap echoes, light flutter.
import shutil

ANNOUNCER_NAMES = {  # id -> spoken text (roster car_name)
    "bumper": "Bumper", "coldfront": "Coldfront", "cricket": "Cricket",
    "cyclone": "Cyclone", "ghost": "Ghost", "hammertoe": "Hammertoe",
    "hornet": "Hornet", "hubcap": "Hubcap", "kandykane": "Kandy Kane",
    "lovebug": "Lovebug", "mrghastly": "Mister Ghastly",
    "razorback": "Razorback", "smoky": "Smoky", "splatkat": "Splat Kat",
}


def _load_audio(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1",
         "-ar", str(SR), "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def _pa_chain(x, seed=7):
    """Stadium PA: horn-speaker band-limit + drive + slap echoes + flutter."""
    r = np.random.default_rng(seed)
    n = x.size
    # horn speakers have no lows and no air
    x = one_pole_hp(one_pole_lp(x, 4000.0), 350.0)
    # overdriven amp
    x = softclip(x * 2.6, 1.9)
    # light AM flutter (aging electronics)
    flut = one_pole_lp(r.uniform(-1, 1, n), 6.0)
    x = x * (0.92 + 0.08 * flut / (np.max(np.abs(flut)) + 1e-9))
    # stadium slap echoes
    out = np.zeros(n + int(SR * 0.4))
    out[:n] += x
    for dly, g in [(0.12, 0.45), (0.26, 0.25)]:
        j = int(SR * dly)
        out[j:j + n] += x * g
    return out


def announcer():
    espeak = shutil.which("espeak-ng")
    if espeak is None:
        print("  [announcer] espeak-ng not found — skipping (assets are committed)")
        return
    # wins ride a touch higher than the deflated loses (-p pitch)
    for verdict, phrase, pitch in [("wins", "%s wins!", "18"), ("loses", "%s loses!", "14")]:
        for car_id, spoken in ANNOUNCER_NAMES.items():
            tmp = f"/tmp/announcer_{car_id}_{verdict}.wav"
            subprocess.run([espeak, "-v", "en-us+m2", "-p", pitch, "-s", "135",
                "-a", "190", "-w", tmp, phrase % spoken], check=True)
            x = _load_audio(tmp)
            # trim espeak's lead/tail silence to a tight cue
            loud = np.where(np.abs(x) > 0.01)[0]
            if loud.size:
                x = x[max(0, loud[0] - int(SR * 0.02)):loud[-1] + int(SR * 0.05)]
            write("announcer_%s_%s" % (car_id, verdict), _pa_chain(x),
                peak=0.95, fade_ms=6.0)


if __name__ == "__main__":
    print("[synth] rendering...")
    mg_fire()
    npc_death()
    player_death()
    crash_soft()
    crash_hard()
    hit_weapon()
    missile_fire()
    mine_drop()
    hit_mg()
    skid()
    spawn()
    ram_warn()
    splash()
    sink()
    pit_fall()
    brake()
    jump_pad()
    pickup()
    overheat()
    win_sting()
    lose_sting()
    ui_move()
    ui_select()
    ui_back()
    mp_join()
    mp_leave()
    sp_blunt_blaze()
    sp_taser()
    sp_leap()
    sp_tornado_alley()
    sp_toe_jam()
    sp_molotov()
    sp_pulse_wave()
    sp_chill_out()
    sp_red_glare()
    sp_placeholder()
    boost()
    boost_loop()
    splat()
    crunch()
    sp_rusty_poon()
    sp_chilblain()
    sp_phantom_phire()
    sp_scythe()
    env_siren()
    env_panic()
    env_chopper()
    env_genny()
    announcer()
    print("[synth] done")
