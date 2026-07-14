"""BGM instrument voices. House aesthetic law applies (see synth_sfx.py):
clean pitched sweeps and ringing partials read cartoony — everything here is
rough-modulated, saturated, and dark-filtered. Hits are cached per variant so
a three-minute track renders in seconds; variation comes from velocity jitter
and variant rotation at the sequencer, not per-hit re-synthesis.
"""
import numpy as np
from . import engine as E

_cache = {}


def _cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


# ---- drums ---------------------------------------------------------------------
def kick(variant=0):
    def build():
        rng = np.random.default_rng(100 + variant)
        drop = E.sweep(150.0 - 6 * variant, 46.0, 0.30) * E.env_exp(0.30, 0.075)
        click = E.hp(rng.uniform(-1, 1, int(E.SR * 0.006)), 1800) * 0.8
        body = E.softclip(drop * 1.6 + np.concatenate([click,
            np.zeros(drop.size - click.size)]), 2.2)
        return body * 0.95
    return _cached(("kick", variant), build)


def snare(variant=0):
    def build():
        rng = np.random.default_rng(200 + variant)
        dur = 0.22
        body = E.sine(185.0, dur) * E.env_exp(dur, 0.045)
        rattle = E.bp(rng.uniform(-1, 1, int(E.SR * dur)), 1100, 4200)
        rattle = E.rms_match(rattle, E.rms(body), 2.0) * E.env_exp(dur, 0.075)
        return E.softclip(body + rattle, 2.6) * 0.9
    return _cached(("snare", variant), build)


def hat(open_=False, variant=0):
    def build():
        rng = np.random.default_rng(300 + variant + (50 if open_ else 0))
        dur = 0.14 if open_ else 0.035
        x = E.hp(rng.uniform(-1, 1, int(E.SR * dur)), 6500)
        ring = E.bp(rng.uniform(-1, 1, int(E.SR * dur)), 8200, 11000)
        x = x + E.rms_match(ring, E.rms(x), -4.0)
        return x * E.env_exp(dur, dur * 0.45) * 0.7
    return _cached(("hat", open_, variant), build)


def clank(variant=0):
    """Industrial anvil — inharmonic struck metal + crunch, the Ministry
    backbeat garnish. Rough modal decays, never clean bell partials."""
    def build():
        rng = np.random.default_rng(400 + variant)
        dur = 0.30
        n = int(E.SR * dur)
        x = np.zeros(n)
        for f, tau, amp in [(521, 0.05, 1.0), (833, 0.045, 0.8),
                (1279, 0.035, 0.7), (1968, 0.03, 0.55), (2841, 0.02, 0.4)]:
            f = f * (1.0 + 0.02 * variant)
            partial = E.sine(f, dur) * E.env_exp(dur, tau)
            partial *= 1.0 + 0.5 * rng.uniform(-1, 1, n)  # rough AM — no ring
            x += partial * amp
        crunch = E.bp(rng.uniform(-1, 1, n), 900, 5200) * E.env_exp(dur, 0.02)
        x = x + E.rms_match(crunch, E.rms(x), 1.0)
        thud = E.sine(120, dur) * E.env_exp(dur, 0.03)
        return E.softclip(x + thud * 0.8, 2.0) * 0.85
    return _cached(("clank", variant), build)


def crash(variant=0):
    """Section-marking noise wash (trash-crash flavor, not a clean cymbal)."""
    def build():
        rng = np.random.default_rng(500 + variant)
        dur = 1.4
        n = int(E.SR * dur)
        x = E.hp(rng.uniform(-1, 1, n), 3200) * E.env_exp(dur, 0.42)
        grit = E.bp(rng.uniform(-1, 1, n), 1400, 6400) * E.env_exp(dur, 0.2)
        x = x + E.rms_match(grit, E.rms(x), -2.0)
        return E.softclip(x, 1.6) * 0.55
    return _cached(("crash", variant), build)


def tom(pitch=0, variant=0):
    """Floor/rack tom family — pitch 0 low .. 2 high. Doom/boss artillery."""
    def build():
        rng = np.random.default_rng(600 + pitch * 10 + variant)
        dur = 0.4
        f0 = [190.0, 240.0, 300.0][pitch]
        body = E.sweep(f0, f0 * 0.55, dur) * E.env_exp(dur, 0.12)
        skin = E.bp(rng.uniform(-1, 1, int(E.SR * dur)), 400, 1800)
        skin = E.rms_match(skin, E.rms(body), -6.0) * E.env_exp(dur, 0.03)
        return E.softclip(body * 1.5 + skin, 2.0) * 0.9
    return _cached(("tom", pitch, variant), build)


def clap(variant=0):
    """Electro clap — three micro-bursts + band flam. The snowy/chase snare."""
    def build():
        rng = np.random.default_rng(700 + variant)
        dur = 0.20
        n = int(E.SR * dur)
        x = np.zeros(n)
        for k, at in enumerate([0.0, 0.011, 0.023]):
            i = int(E.SR * at)
            burst = E.bp(rng.uniform(-1, 1, n - i), 900, 3600)
            env = E.env_exp(dur - at, 0.008 if k < 2 else 0.05)
            m = min(burst.size, env.size)
            x[i:i + m] += burst[:m] * env[:m]
        return E.softclip(x * 1.6, 2.2) * 0.85
    return _cached(("clap", variant), build)


def hard_kick(variant=0):
    """Overdriven 909-style four-floor — the digital-hardcore engine block."""
    def build():
        base = kick(variant)
        return E.softclip(base * 3.0, 2.5) * 0.95
    return _cached(("hard_kick", variant), build)


def pile_thud(variant=0):
    """Pile-driver hit — construction-yard sub thump with a metal lip."""
    def build():
        rng = np.random.default_rng(800 + variant)
        dur = 0.5
        sub = E.sweep(70.0, 38.0, dur) * E.env_exp(dur, 0.14)
        lip = E.bp(rng.uniform(-1, 1, int(E.SR * 0.08)), 1200, 3200) * 0.5
        x = sub * 1.8
        x[:lip.size] += lip * E.env_exp(0.08, 0.01)[:lip.size]
        return E.softclip(x, 2.0) * 0.95
    return _cached(("pile", variant), build)


# ---- bass ----------------------------------------------------------------------
def bass_note(freq, dur, vel=1.0, grit=1.0):
    """grit 1.0 = saturated house bass; ~1.8 = Lemmy-lane overdriven grind."""
    def build():
        n = int(E.SR * dur)
        x = E.saw(freq, dur) + 0.5 * E.square(freq * 0.5, dur, 0.48)
        x = E.lp(x, 620 + 500 * (grit - 1.0))
        x = E.softclip(x * 2.4 * grit, 1.8)   # first saturation stage
        x = E.softclip(x * 1.4, 1.5)          # second — "saturated", not fuzz
        env = E.env_ad(dur, 0.004, 1.6)
        gate = np.ones(n)
        rel = max(1, int(E.SR * 0.012))
        gate[-rel:] = np.linspace(1, 0, rel)  # tight release between 8ths
        return x[:n] * env * gate
    return _cached(("bass", round(freq, 2), round(dur, 4), grit), build) * vel


def bass_render(grit=1.0):
    """notes() renderer with a fixed grit (renderers take freq/dur/vel only)."""
    return lambda freq, dur, vel: bass_note(freq, dur, vel, grit)


# ---- guitar --------------------------------------------------------------------
def _gtr_amp(x):
    """Per-lane amp/cab: assembled lane goes through this ONCE (real amps see
    the summed strings). Cascaded soft clip + dark cab EQ + presence."""
    x = E.hp(x, 95)
    x = E.softclip(x * 5.5, 2.2)
    x = E.softclip(x * 1.7, 1.6)
    cab = E.lp(x, 4800, order=4)
    presence = E.bp(x, 1800, 3400) * 0.35
    return cab + presence


def power_chord(freq, dur, vel=1.0, mute=False, seed=0):
    """Root + fifth + octave Karplus-Strong stack. mute = palm-mute chug
    (short, damped); open = ringing. seed splits the double-tracked takes."""
    def build():
        damp = 0.981 if mute else 0.9965
        bright = 0.42 if mute else 0.55
        x = None
        for k, (ratio, amp) in enumerate([(1.0, 1.0), (1.4983, 0.8),
                (2.0, 0.55)]):
            detune = 1.0 + 0.0015 * ((seed + k) % 3 - 1)
            s = E.karplus(freq * ratio * detune, dur, damp, bright,
                seed=seed * 17 + k)
            x = s if x is None else x + s
        env = E.env_ad(dur, 0.002, 1.2 if mute else 0.6)
        return x * env
    return _cached(("pc", round(freq, 2), round(dur, 4), mute, seed), build) * vel


def gtr_lane_render(seed):
    """Returns a notes() renderer for one guitar take. len<=2 steps reads as a
    palm-mute chug, longer rings out."""
    def render(freq, dur, vel):
        mute = dur <= 0.26
        return power_chord(freq, dur * (1.35 if not mute else 1.0), vel,
            mute, seed)
    return render


def _gtr_amp_clean(x):
    """Low-gain 'clean-ish' stage for grunge verses — edge-of-breakup, dark."""
    x = E.hp(x, 110)
    x = E.softclip(x * 1.8, 1.4)
    return E.lp(x, 5200, order=2)


def gtr_lane_render_clean(seed):
    """Open-voiced, longer-ringing take for quiet grunge sections."""
    def render(freq, dur, vel):
        return power_chord(freq, dur * 1.5, vel * 0.8, False, seed + 10)
    return render


# ---- synth stab / textures ------------------------------------------------------
def stab(freq, dur, vel=1.0):
    """Dissonant minor-2nd cluster stab through a band sweep + slap echoes —
    the sampler-stab flavor, kept rough."""
    def build():
        n = int(E.SR * dur)
        x = E.saw(freq, dur) + E.saw(freq * 1.0595, dur, 0.3) \
            + 0.6 * E.saw(freq * 2.02, dur, 0.6)
        x = E.bp(x, 500, 2600)
        x = E.softclip(x * 2.0, 1.8) * E.env_exp(dur, 0.09)
        out = x.copy()
        for delay, g in [(0.14, 0.4), (0.28, 0.22)]:
            d = int(E.SR * delay)
            if d < n:
                out[d:] += x[:n - d] * g
        return out
    return _cached(("stab", round(freq, 2), round(dur, 3)), build) * vel


def machine_texture(dur, seed=7):
    """Machine-room bed: slow granular chug + hum, band-swept. Loopable-ish
    at section scale; sits far below the core."""
    rng = np.random.default_rng(seed)
    n = int(E.SR * dur)
    gate = (np.sin(2 * np.pi * 7.3 * E.t(dur)) > -0.2).astype(float)
    gate = E.one_pole_lp(gate, 60)
    x = E.bp(rng.uniform(-1, 1, n), 180, 900) * gate
    hum = E.sine(55.0, dur) * 0.25 * (1.0 + 0.3 * np.sin(2 * np.pi * 0.4 * E.t(dur)))
    wob = 1.0 + 0.35 * np.sin(2 * np.pi * 0.13 * E.t(dur))
    return E.softclip((x + hum) * wob, 1.4)


def drone(freq, dur):
    """Dark low drone — detuned saw pair under a heavy lowpass, slow swell."""
    x = E.saw(freq, dur) + E.saw(freq * 1.006, dur, 0.5) \
        + 0.7 * E.sine(freq * 0.5, dur)
    x = E.lp(x, 240, order=4)
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * 0.09 * E.t(dur) - np.pi / 2)
    return E.softclip(x * swell, 1.5)


def arp_note(freq, dur, vel=1.0):
    """Cold synth pluck — the NIN-lane sequenced pulse. Dark square/saw blend
    with a fast filter bite, no ringing tail."""
    def build():
        n = int(E.SR * dur)
        x = 0.7 * E.square(freq, dur, 0.46) + 0.5 * E.saw(freq * 1.004, dur)
        x = E.lp(x, 1400)
        x = E.softclip(x * 1.8, 1.6)
        env = E.env_ad(dur, 0.002, 2.6)
        return x[:n] * env
    return _cached(("arp", round(freq, 2), round(dur, 4)), build) * vel


def rave_stab(freq, dur, vel=1.0):
    """Hoover-adjacent rave hit — thick detuned saw cluster, hard-clipped.
    The digital-hardcore shout; rough by construction."""
    def build():
        x = (E.saw(freq, dur) + E.saw(freq * 1.011, dur, 0.4)
            + E.saw(freq * 0.989, dur, 0.7) + 0.8 * E.saw(freq * 2.02, dur))
        x = E.bp(x, 300, 3200)
        x = E.softclip(x * 3.5, 2.4)
        return x * E.env_ad(dur, 0.004, 1.4)
    return _cached(("rave", round(freq, 2), round(dur, 3)), build) * vel


def icy_pad(freqs, dur, seed=21):
    """High glassy pad under shimmer noise — cold, slow-breathing. Detune and
    rough shimmer keep it off the clean-tone tell."""
    rng = np.random.default_rng(seed)
    n = int(E.SR * dur)
    x = np.zeros(n)
    for k, f in enumerate(freqs):
        x += E.sine(f * (1.0 + 0.0025 * ((k % 3) - 1)), dur, rng.uniform(0, 6.0))
    shimmer = E.hp(rng.uniform(-1, 1, n), 5200) * 0.12
    breathe = 0.7 + 0.3 * np.sin(2 * np.pi * 0.11 * E.t(dur) + 1.0)
    return E.softclip((x / max(len(freqs), 1) + shimmer) * breathe, 1.3)


def air_rattle(dur, seed=31):
    """Air-wrench / chain rattle burst — construction-yard garnish."""
    rng = np.random.default_rng(seed)
    n = int(E.SR * dur)
    gate = (np.sin(2 * np.pi * 33.0 * E.t(dur)) > 0.3).astype(float)
    x = E.bp(rng.uniform(-1, 1, n), 2200, 7800) * gate
    return x * E.env_ad(dur, 0.01, 1.2)


def crowd_swell(dur, seed=41):
    """Distant stadium roar — broad dark noise, slow surges, no voices."""
    rng = np.random.default_rng(seed)
    n = int(E.SR * dur)
    x = E.bp(rng.uniform(-1, 1, n), 300, 1600)
    surge = 0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * E.t(dur) + rng.uniform(0, 6))
    surge *= 1.0 + 0.15 * np.sin(2 * np.pi * 0.23 * E.t(dur))
    return E.one_pole_lp(x * surge, 1200)


def riser(dur, seed=11):
    """Noise riser into a section — band sweeping up, rough-modulated."""
    rng = np.random.default_rng(seed)
    n = int(E.SR * dur)
    x = rng.uniform(-1, 1, n)
    lo = np.linspace(300, 1800, n)
    # cheap time-varying band: chunked static filters
    chunks = []
    step = n // 16
    for i in range(0, n, step):
        seg = x[i:i + step]
        c = lo[min(i, n - 1)]
        chunks.append(E.bp(seg, c, c * 3.0))
    y = np.concatenate(chunks)[:n]
    return y * np.linspace(0.1, 1.0, n) ** 1.5
