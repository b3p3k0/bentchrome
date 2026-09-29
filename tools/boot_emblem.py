#!/usr/bin/env python3
"""FanStation emblem builder for Bent Chrome — the regeneration source for
assets/boot/source/card_fanstation_src.png. Runs on the repo venv (numpy) and
needs ImageMagick's `magick` on PATH:

    ./venv312/bin/python tools/boot_emblem.py                 # the shipped look
    ./venv312/bin/python tools/boot_emblem.py stroke=90 slot=24
    ./venv312/bin/python tools/boot_emblem.py out=/tmp/try.png half=120

The flat S under the F is drawn here as EXACT GEOMETRY, not generated: image
models kept closing its loops into a pretzel. It is a ribbon of three
parallel strokes joined by two round caps (top stroke -> left cap -> middle
stroke -> right cap -> bottom stroke), laid on the ground in a parallel
projection and given a thin plate edge. The red F and the lettering come from
the donor card (the first generated card); the F is cut out by color and set
back on top.

The F stands on the S's FRONT terminal, the way the reference's letter does:
its foot covers the bottom stroke's end and its stem hides the top stroke's
end, so only the two loops show. Every knob is a `key=value` argument; the
defaults below are what ships. Then run the card recipe in
assets/boot/README.md to cut the 640x360 card.
"""
import math
import os
import subprocess
import sys
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SOURCE_DIR = os.path.join(ROOT, "assets", "boot", "source")
DONOR = os.path.join(SOURCE_DIR, "card_fanstation_donor.png")
OUT = os.path.join(SOURCE_DIR, "card_fanstation_src.png")

W, H = 1536, 1024
SS = 4                                  # supersampling per axis
REGION = (380, 60, 1160, 604)           # emblem area: cleared, then redrawn
F_BOX = (640, 90, 960, 500)             # where the donor's F lives
F_FOOT = (746.75, 457.5)                # centre of the F's footprint in the donor

CFG = dict(
    stroke=82.0,      # ribbon width
    slot=28.0,        # gap between neighbouring strokes
    half=100.0,       # the cap centres sit at +-half along the strokes
    thick=14.0,       # plate edge, screen px
    ext=8.0,          # how far each terminal runs on under / behind the F
    scale=1.15,       # scales every S length above
    fscale=1.15,      # F scale, about its own foot
    foot=(764.0, 548.0),   # where the F's foot lands on the card
    ang_d=21.0,       # stroke axis: degrees above horizontal, up-right
    ang_w=19.0,       # across axis: degrees below horizontal, down-right
    bands=(-0.34, 0.34),   # color band edges, as a fraction of the S's reach
)
TUPLES = ("foot", "bands")

YELLOW = (232, 200, 40)
TEAL = (26, 153, 130)
BLUE = (50, 87, 187)


def shade(color, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in color)


class Emblem:
    def __init__(self, cfg):
        self.cfg = cfg
        self.pitch = cfg["stroke"] + cfg["slot"]
        a_d, a_w = math.radians(cfg["ang_d"]), math.radians(cfg["ang_w"])
        self.ax_d = np.array([math.cos(a_d), -math.sin(a_d)])
        self.ax_w = np.array([math.cos(a_w), math.sin(a_w)])
        # Two pitches further back lands at the same screen x this far along
        # the strokes: the front terminal sits under the foot at -tuck, the
        # back terminal hides behind the stem at +tuck.
        self.tuck = self.pitch * math.cos(a_w) / math.cos(a_d)
        foot = np.array(cfg["foot"])
        self.origin = foot - (-self.tuck * self.ax_d + self.pitch * self.ax_w) \
            - np.array([0.0, cfg["thick"]])

    def screen(self, pt, z=0.0):
        s = self.origin + pt[0] * self.ax_d - pt[1] * self.ax_w
        return np.array([s[0], s[1] - z])

    def centerline(self, n_arc=56, n_line=24):
        p, half = self.pitch, self.cfg["half"]
        xt = self.tuck + self.cfg["ext"]
        pts = [(xt + (-half - xt) * i / n_line, p) for i in range(n_line + 1)]
        for i in range(1, n_arc + 1):  # left cap: top stroke round to the middle
            a = math.radians(90 + 180 * i / n_arc)
            pts.append((-half + p / 2 * math.cos(a), p / 2 + p / 2 * math.sin(a)))
        pts += [(-half + 2 * half * i / n_line, 0.0) for i in range(1, n_line + 1)]
        for i in range(1, n_arc + 1):  # right cap: middle round to the bottom
            a = math.radians(90 - 180 * i / n_arc)
            pts.append((half + p / 2 * math.cos(a), -p / 2 + p / 2 * math.sin(a)))
        pts += [(half + (-xt - half) * i / n_line, -p) for i in range(1, n_line + 1)]
        return np.array(pts), half + p / 2 + self.cfg["stroke"] / 2

    def band(self, x, reach):
        f = x / reach
        lo, hi = self.cfg["bands"]
        return YELLOW if f < lo else (TEAL if f < hi else BLUE)

    def faces(self):
        """(top quads, edge quads far-to-near), each as (screen quad, color)."""
        cl, reach = self.centerline()
        tang = np.zeros_like(cl)
        tang[1:-1] = cl[2:] - cl[:-2]
        tang[0], tang[-1] = cl[1] - cl[0], cl[-1] - cl[-2]
        tang /= np.linalg.norm(tang, axis=1)[:, None]
        norm = np.stack([-tang[:, 1], tang[:, 0]], axis=1)
        half_w, t = self.cfg["stroke"] / 2, self.cfg["thick"]
        left, right = cl + norm * half_w, cl - norm * half_w
        tops, edges = [], []

        def edge(a, b, outward, color):
            v = outward[0] * self.ax_d - outward[1] * self.ax_w
            if v[1] <= 0.02:  # faces away from the viewer
                return
            k = 0.60 + 0.16 * v[0] / (abs(v[0]) + abs(v[1]) + 1e-9)
            quad = [self.screen(a, t), self.screen(b, t), self.screen(b), self.screen(a)]
            edges.append((max(q[1] for q in quad), quad, shade(color, k)))

        for i in range(len(cl) - 1):
            color = self.band((cl[i][0] + cl[i + 1][0]) / 2, reach)
            tops.append(([self.screen(left[i], t), self.screen(left[i + 1], t),
                self.screen(right[i + 1], t), self.screen(right[i], t)], color))
            mid = (norm[i] + norm[i + 1]) / 2
            edge(left[i], left[i + 1], mid, color)
            edge(right[i], right[i + 1], -mid, color)
        for idx, sign in ((0, -1.0), (len(cl) - 1, 1.0)):  # the two terminals
            edge(left[idx], right[idx], tang[idx] * sign, self.band(cl[idx][0], reach))
        edges.sort(key=lambda e: e[0])
        return tops, [(q, c) for _, q, c in edges]


def fill_quad(buf, cover, quad, color):
    """Fill one convex quad into the supersampled emblem buffer."""
    x0, y0 = REGION[0], REGION[1]
    pts = np.array([[(p[0] - x0) * SS, (p[1] - y0) * SS] for p in quad])
    lo = np.maximum(np.floor(pts.min(axis=0)).astype(int) - 1, 0)
    hi = np.minimum(np.ceil(pts.max(axis=0)).astype(int) + 1,
        [buf.shape[1] - 1, buf.shape[0] - 1])
    if hi[0] < lo[0] or hi[1] < lo[1]:
        return
    gx, gy = np.meshgrid(np.arange(lo[0], hi[0] + 1) + 0.5, np.arange(lo[1], hi[1] + 1) + 0.5)
    pos = np.ones(gx.shape, dtype=bool)
    neg = np.ones(gx.shape, dtype=bool)
    for i in range(4):
        (ax, ay), (bx, by) = pts[i], pts[(i + 1) % 4]
        cross = (bx - ax) * (gy - ay) - (by - ay) * (gx - ax)
        pos &= cross >= -0.75  # a hair of overlap: no seams between quads
        neg &= cross <= 0.75
    inside = pos | neg
    buf[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1][inside] = color
    cover[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1][inside] = 1.0


def s_layer(emblem):
    x0, y0, x1, y1 = REGION
    rw, rh = (x1 - x0) * SS, (y1 - y0) * SS
    buf = np.zeros((rh, rw, 3))
    cover = np.zeros((rh, rw))
    tops, edges = emblem.faces()
    for quad, color in edges + tops:  # edges first: top faces sit over them
        fill_quad(buf, cover, quad, color)
    small = buf.reshape(rh // SS, SS, rw // SS, SS, 3).mean(axis=(1, 3))
    alpha = cover.reshape(rh // SS, SS, rw // SS, SS).mean(axis=(1, 3))
    rgb = np.where(alpha[..., None] > 0, small / np.maximum(alpha[..., None], 1e-6), 0.0)
    layer = np.zeros((H, W, 4), dtype=np.uint8)
    layer[y0:y1, x0:x1, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    layer[y0:y1, x0:x1, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return layer


def f_layer(donor):
    """The donor's F, cut out by color: red, and nothing else up there is."""
    raw = subprocess.run(["magick", donor, "-alpha", "off", "-depth", "8", "rgb:-"],
        check=True, capture_output=True).stdout
    img = np.frombuffer(raw, dtype=np.uint8).reshape(H, W, 3).astype(np.float64)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    mask = np.zeros((H, W))
    x0, y0, x1, y1 = F_BOX
    mask[y0:y1, x0:x1] = ((r > 64) & (g < 0.46 * r) & (b < 0.52 * r))[y0:y1, x0:x1]
    for _ in range(2):  # soften, then pull the edge in a hair: no color fringe
        m = mask.copy()
        m[1:-1, 1:-1] = (mask[:-2, 1:-1] + mask[2:, 1:-1] + mask[1:-1, :-2]
            + mask[1:-1, 2:] + 4 * mask[1:-1, 1:-1]) / 8.0
        mask = m
    alpha = np.clip((mask - 0.45) / 0.35, 0.0, 1.0)
    return np.dstack([img, alpha * 255.0]).astype(np.uint8)


def write_rgba(layer, path):
    subprocess.run(["magick", "-size", "%dx%d" % (W, H), "-depth", "8", "rgba:-", path],
        input=layer.tobytes(), check=True)


def main(argv):
    cfg = dict(CFG)
    donor, out = DONOR, OUT
    for arg in argv:
        key, _, value = arg.partition("=")
        if key == "donor":
            donor = value
        elif key == "out":
            out = value
        elif key in TUPLES:
            cfg[key] = tuple(float(v) for v in value.split(","))
        elif key in cfg:
            cfg[key] = float(value)
        else:
            print("unknown knob: %s\nknobs: %s, donor, out" % (key, ", ".join(cfg)))
            return 1
    for key in ("stroke", "slot", "half", "thick", "ext"):
        cfg[key] *= cfg["scale"]
    tmp = os.path.dirname(os.path.abspath(out))
    s_png, f_png = os.path.join(tmp, "_emblem_s.png"), os.path.join(tmp, "_emblem_f.png")
    write_rgba(s_layer(Emblem(cfg)), s_png)
    write_rgba(f_layer(donor), f_png)
    subprocess.run(["magick", donor, "-alpha", "off", "-fill", "black",
        "-draw", "rectangle %d,%d %d,%d" % REGION, s_png, "-composite",
        "(", f_png, "-background", "none", "-virtual-pixel", "transparent",
        "-filter", "Lanczos", "-distort", "SRT", "%.2f,%.2f %.4f 0 %.2f,%.2f" % (
            F_FOOT[0], F_FOOT[1], cfg["fscale"], cfg["foot"][0], cfg["foot"][1]), ")",
        "-composite", "-background", "black", "-alpha", "remove", "-alpha", "off",
        "PNG24:" + out], check=True)
    os.remove(s_png)
    os.remove(f_png)
    print("wrote %s" % out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
