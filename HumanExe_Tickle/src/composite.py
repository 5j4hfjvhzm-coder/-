"""Composite rendered 3D frames into the finished 1080x1920 Short.

Adds bloom, grading, transitions, impact FX, touch ripples, HUD labels,
on-screen headlines, word-synced subtitles and the Human.exe outro logo,
then pipes frames to ffmpeg.

Usage: python3 composite.py FRAMES_DIR BUILD_DIR OUT.mp4 [first last] [--png DIR]
"""
import json
import math
import os
import subprocess
import sys
from functools import lru_cache

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1080, 1920, 30
TOTAL = 825
SRC = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(SRC, "..", "assets")

BLUE = (30, 167, 255)
CYAN = (90, 225, 255)
MAGENTA = (255, 45, 143)
WHITE = (255, 255, 255)
F_BLACK = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
F_XBOLD = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
F_SEMI = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
F_MONO = "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-ExtraBold.ttf"

IMPACT_T = (528 - 1) / 30.0
CUTS = [1.5, 3.0, 5.0, 7.0, 9.0, 11.5, 13.5, 15.5, 17.3, 19.3, 21.5]
HEADLINES = [  # start, end, lines of (text, color)
    (0.05, 3.0, [[("YOUR", WHITE), ("BRAIN", WHITE), ("HAS", WHITE)], [("A", WHITE), ("SECRET!", BLUE)]]),
    (3.05, 9.0, [[("YOUR", WHITE), ("BRAIN", WHITE), ("PREDICTS", BLUE)], [("YOUR", WHITE), ("MOVEMENTS", WHITE)]]),
    (9.05, 15.5, [[("THE", WHITE), ("CEREBELLUM", BLUE)], [("PREDICTS", WHITE), ("SENSATIONS", WHITE)]]),
    (15.6, 21.45, [[("SOMEONE", WHITE), ("ELSE?", WHITE)], [("DIFFERENT", BLUE), ("STORY!", BLUE)]]),
]
KEYWORDS = {"brain", "tickling", "tickles", "predicts", "predict", "sensations", "movements",
            "cerebellum", "surprising", "someone", "else", "human.exe", "mind-blowing", "less",
            "secret", "touch"}


def t_of(f):
    return (f - 1) / FPS


def ease_out_back(x, s=1.9):
    x = min(max(x, 0.0), 1.0) - 1
    return 1 + (s + 1) * x ** 3 + s * x ** 2


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


# ------------------------------------------------------------ text sprites
@lru_cache(maxsize=512)
def font(path, size):
    return ImageFont.truetype(path, size)


@lru_cache(maxsize=1024)
def text_sprite(text, size, color, path=F_BLACK, stroke=7, glow=True, glow_col=None, track=0):
    """RGBA float sprite (premultiplied) with stroke + soft glow."""
    fnt = font(path, size)
    pad = int(size * 0.6)
    bbox = fnt.getbbox(text, stroke_width=stroke)
    tw = bbox[2] - bbox[0] + track * max(len(text) - 1, 0)
    th = bbox[3] - bbox[1]
    w, h = tw + 2 * pad, th + 2 * pad
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0 = pad - bbox[0], pad - bbox[1]
    if track:
        x = x0
        for ch in text:
            d.text((x, y0), ch, font=fnt, fill=color + (255,), stroke_width=stroke, stroke_fill=(3, 8, 20, 255))
            x += fnt.getlength(ch) + track
    else:
        d.text((x0, y0), text, font=fnt, fill=color + (255,), stroke_width=stroke, stroke_fill=(3, 8, 20, 255))
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    alpha = a[..., 3:4]
    if glow:
        gc = np.array(glow_col or color, np.float32) / 255.0
        g = cv2.GaussianBlur(alpha[..., 0], (0, 0), size * 0.22)[..., None]
        g = np.clip(g * 1.4, 0, 1)
        # glow goes under the text (screen-ish)
        rgb = rgb + gc * g * 0.55 * (1 - alpha)
        alpha = np.clip(alpha + g * 0.45 * (1 - alpha), 0, 1)
    return np.concatenate([rgb, alpha], axis=2)


def blit(canvas, spr, cx, cy, scale=1.0, opacity=1.0):
    """Composite premultiplied sprite centered at (cx, cy)."""
    if opacity <= 0.003 or scale <= 0.01:
        return
    if abs(scale - 1.0) > 1e-3:
        spr = cv2.resize(spr, None, fx=scale, fy=scale, interpolation=cv2.INTER_LINEAR)
    h, w = spr.shape[:2]
    x0 = int(round(cx - w / 2)); y0 = int(round(cy - h / 2))
    xa, ya = max(x0, 0), max(y0, 0)
    xb, yb = min(x0 + w, W), min(y0 + h, H)
    if xa >= xb or ya >= yb:
        return
    s = spr[ya - y0:yb - y0, xa - x0:xb - x0] * opacity
    region = canvas[ya:yb, xa:xb]
    region[:] = region * (1 - s[..., 3:4]) + s[..., :3]


# ------------------------------------------------------------ frame loading
def load_frame(fdir, f):
    def rd(i):
        p = os.path.join(fdir, f"f{i:04d}.png")
        if not os.path.exists(p):
            return None
        im = cv2.imread(p, cv2.IMREAD_UNCHANGED)
        im = im[..., :3][..., ::-1].astype(np.float32)
        return im / (65535.0 if im.max() > 255 else 255.0)

    im = rd(f)
    if im is None:  # outro rendered on even steps: blend neighbours
        a, b = rd(f - 1), rd(f + 1)
        if a is not None and b is not None:
            im = 0.5 * (a + b)
        else:
            im = a if a is not None else b
    if im is None:
        im = np.zeros((1280, 720, 3), np.float32)
    im = cv2.resize(im, (W, H), interpolation=cv2.INTER_CUBIC)
    blur = cv2.GaussianBlur(im, (0, 0), 1.2)
    return np.clip(im + 0.35 * (im - blur), 0, 1)


# ------------------------------------------------------------ effects
def bloom(img):
    small = cv2.resize(img, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    lum = small.max(axis=2, keepdims=True)
    br = small * np.clip((lum - 0.45) / 0.55, 0, 1)
    acc = np.zeros_like(small)
    for s, w in ((3, 0.55), (9, 0.45), (24, 0.35)):
        acc += cv2.GaussianBlur(br, (0, 0), s) * w
    acc = cv2.resize(acc, (W, H), interpolation=cv2.INTER_LINEAR)
    return img + acc * np.array([0.75, 0.9, 1.1], np.float32)


_yy, _xx = np.mgrid[0:H, 0:W].astype(np.float32)
_r = np.sqrt(((_xx - W / 2) / (W * 0.75)) ** 2 + ((_yy - H * 0.45) / (H * 0.6)) ** 2)
VIGNETTE = np.clip(1.15 - 0.55 * _r ** 2, 0.35, 1.0)[..., None]
BG_GLOW = (np.exp(-(_r / 0.55) ** 2) * 0.05)[..., None] * np.array([0.05, 0.25, 0.7], np.float32)
GRAIN = np.random.default_rng(3).normal(0, 1, (8, H // 2, W // 2)).astype(np.float32)


def transform(img, scale=1.0, dx=0.0, dy=0.0, rot=0.0):
    if abs(scale - 1) < 1e-4 and abs(dx) < 0.05 and abs(dy) < 0.05 and abs(rot) < 1e-4:
        return img
    M = cv2.getRotationMatrix2D((W / 2, H / 2), rot, scale)
    M[0, 2] += dx; M[1, 2] += dy
    return cv2.warpAffine(img, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def zoom_blur(img, amt):
    acc = img.copy(); n = 6
    for i in range(1, n):
        s = 1 + amt * i / n
        acc += transform(img, s)
    return acc / n


def chroma(img, px):
    if px < 0.5:
        return img
    out = img.copy()
    M = np.float32([[1, 0, px], [0, 1, 0]])
    out[..., 0] = cv2.warpAffine(img[..., 0], M, (W, H), borderMode=cv2.BORDER_REFLECT)
    M = np.float32([[1, 0, -px], [0, 1, 0]])
    out[..., 2] = cv2.warpAffine(img[..., 2], M, (W, H), borderMode=cv2.BORDER_REFLECT)
    return out


def shake_at(t, events):
    dx = dy = rot = 0.0
    for te, amp, dur in events:
        k = t - te
        if 0 <= k < dur:
            a = amp * math.exp(-k / (dur * 0.35))
            dx += a * math.sin(k * 71.0) ; dy += a * math.sin(k * 53.0 + 1.3)
            rot += a * 0.02 * math.sin(k * 37.0)
    return dx, dy, rot


def ring(canvas, cx, cy, r, col, alpha, thick=4):
    if alpha <= 0.01 or r <= 0:
        return
    layer = np.zeros((H, W), np.float32)
    cv2.circle(layer, (int(cx), int(cy)), int(r), 1.0, int(thick), cv2.LINE_AA)
    layer = cv2.GaussianBlur(layer, (0, 0), 2.0) * 1.5 + layer
    canvas += layer[..., None] * np.array(col, np.float32) / 255.0 * alpha


def glow_dot(canvas, cx, cy, rad, col, alpha):
    if alpha <= 0.01:
        return
    x0, x1 = int(max(cx - rad * 3, 0)), int(min(cx + rad * 3, W))
    y0, y1 = int(max(cy - rad * 3, 0)), int(min(cy + rad * 3, H))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    g = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (rad * rad)))
    canvas[y0:y1, x0:x1] += g[..., None] * np.array(col, np.float32) / 255.0 * alpha


# ------------------------------------------------------------ HUD label
def hud_label(canvas, text, px, py, lx, ly, col, alpha):
    """Label at (lx, ly) with a leader line to the anatomy point (px, py)."""
    if alpha <= 0.01:
        return
    c = np.array(col, np.float32) / 255.0
    layer = np.zeros((H, W), np.float32)
    cv2.line(layer, (int(px), int(py)), (int(lx), int(ly)), 1.0, 3, cv2.LINE_AA)
    cv2.circle(layer, (int(px), int(py)), 9, 1.0, 3, cv2.LINE_AA)
    canvas[:] = canvas + (cv2.GaussianBlur(layer, (0, 0), 2) + layer)[..., None] * c * alpha * 0.9
    spr = text_sprite(text, 40, col, F_XBOLD, stroke=4, track=4)
    off = spr.shape[1] / 2 + 8
    cx = lx + (off if lx >= px else -off)
    half = spr.shape[1] / 2 - 30
    cx = min(max(cx, half + 10), W - half - 10)
    blit(canvas, spr, cx, ly, 1.0, alpha)


# ------------------------------------------------------------ headline + subtitles
def draw_headline(canvas, t):
    for t0, t1, lines in HEADLINES:
        if not (t0 - 0.01 <= t <= t1 + 0.01):
            continue
        out_k = smooth((t1 - t) / 0.18)
        y = 380
        size = 96 if max(len(" ".join(w for w, _ in ln)) for ln in lines) <= 16 else 84
        wi = 0
        for ln in lines:
            sprs = [text_sprite(w, size, c, F_BLACK, stroke=7) for w, c in ln]
            gap = -int(size * 0.93)
            widths = [s.shape[1] for s in sprs]
            total = sum(widths) + gap * (len(sprs) - 1)
            fit = min(1.0, 930 / max(total - size * 1.2, 1))
            x = W / 2 - total * fit / 2
            for s, wd in zip(sprs, widths):
                k = (t - t0 - wi * 0.06) / 0.28
                sc = (0.35 + 0.65 * ease_out_back(k) if k < 1 else 1.0) * fit
                op = smooth(k * 2.2) * out_k
                blit(canvas, s, x + wd * fit / 2, y, sc, op)
                x += (wd + gap) * fit
                wi += 1
            y += int(size * 1.08)


def subtitle_chunks(words):
    chunks, cur = [], []
    for w in words:
        cur.append(w)
        end_punct = w["word"][-1] in ",.!?"
        if len(cur) >= 3 or end_punct:
            chunks.append(cur); cur = []
    if cur:
        chunks.append(cur)
    out = []
    for i, ch in enumerate(chunks):
        start = ch[0]["start"] - 0.06
        nxt = chunks[i + 1][0]["start"] - 0.06 if i + 1 < len(chunks) else 1e9
        end = min(nxt, ch[-1]["end"] + 0.35)
        out.append((start, end, ch))
    return out


def draw_subs(canvas, t, chunks):
    for start, end, ch in chunks:
        if not (start <= t < end):
            continue
        size = 74
        y = 1390
        sprs = []
        for w in ch:
            word = w["word"].upper()
            key = w["word"].lower().strip(",.!?") in KEYWORDS
            spoken = t >= w["start"] - 0.03
            col = BLUE if key else WHITE
            if not spoken:
                col = tuple(int(c * 0.55) for c in col)
            sprs.append((text_sprite(word, size, col, F_BLACK, stroke=9, glow=key, glow_col=BLUE), w))
        gap = -int(size * 0.93)
        widths = [s.shape[1] for s, _ in sprs]
        total = sum(widths) + gap * (len(sprs) - 1)
        scale_all = min(1.0, 940 / max(total - size * 1.2, 1))
        x = W / 2 - total * scale_all / 2
        k_in = (t - start) / 0.12
        for (s, w), wd in zip(sprs, widths):
            active = w["start"] - 0.03 <= t < w["end"] + 0.05
            pop = 1.0
            if active:
                kk = (t - w["start"] + 0.03) / 0.16
                pop = 1.0 + 0.12 * math.sin(min(max(kk, 0), 1) * math.pi) + 0.04
            sc = scale_all * pop * (0.85 + 0.15 * smooth(k_in))
            blit(canvas, s, x + wd * scale_all / 2, y - (6 if active else 0), sc, smooth(k_in * 1.5))
            x += (wd + gap) * scale_all


# ------------------------------------------------------------ outro logo
def _sprite_from_pil(img, glow_col, size):
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    alpha = a[..., 3:4]
    gc = np.array(glow_col, np.float32) / 255.0
    g = np.clip(cv2.GaussianBlur(alpha[..., 0], (0, 0), size * 0.22)[..., None] * 1.4, 0, 1)
    rgb = rgb + gc * g * 0.6 * (1 - alpha)
    alpha = np.clip(alpha + g * 0.5 * (1 - alpha), 0, 1)
    return np.concatenate([rgb, alpha], axis=2)


@lru_cache(maxsize=4)
def logo_parts():
    size = 118
    fh, fm = font(F_BLACK, size), font(F_MONO, size)
    wh = fh.getlength("HUMAN"); we = fm.getlength(".exe"); wc = fm.getlength("_")
    pad = 90
    img = Image.new("RGBA", (int(wh + we + 8 + 2 * pad), int(size * 1.4 + 2 * pad)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = pad + size  # baseline
    d.text((pad, base), "HUMAN", font=fh, fill=WHITE + (255,), anchor="ls")
    d.text((pad + wh + 8, base), ".exe", font=fm, fill=BLUE + (255,), anchor="ls")
    logo = _sprite_from_pil(img, BLUE, size)
    cimg = Image.new("RGBA", (int(wc + 2 * pad), int(size * 1.4 + 2 * pad)), (0, 0, 0, 0))
    ImageDraw.Draw(cimg).text((pad, base), "_", font=fm, fill=CYAN + (255,), anchor="ls")
    cursor = _sprite_from_pil(cimg, CYAN, size)
    # follow pill content: text + emoji in one sprite
    fs = 64
    ff = font(F_BLACK, fs)
    tw = ff.getlength("FOLLOW FOR MORE")
    em = Image.open(os.path.join(ASSETS, "brain_emoji.png")).convert("RGBA").resize((82, 82), Image.LANCZOS)
    pad2 = 50
    fimg = Image.new("RGBA", (int(tw + 18 + 82 + 2 * pad2), int(110 + 2 * pad2)), (0, 0, 0, 0))
    d = ImageDraw.Draw(fimg)
    d.text((pad2, pad2 + 55), "FOLLOW FOR MORE", font=ff, fill=WHITE + (255,), anchor="lm",
           stroke_width=5, stroke_fill=(3, 8, 20, 255))
    follow = _sprite_from_pil(fimg, BLUE, fs)
    # paste emoji without glow
    e = np.asarray(em).astype(np.float32) / 255.0
    x0, y0 = int(pad2 + tw + 18), int(pad2 + 55 - 41)
    ea = e[..., 3:4]
    follow[y0:y0 + 82, x0:x0 + 82, :3] = follow[y0:y0 + 82, x0:x0 + 82, :3] * (1 - ea) + e[..., :3] * ea
    follow[y0:y0 + 82, x0:x0 + 82, 3:] = np.maximum(follow[y0:y0 + 82, x0:x0 + 82, 3:], ea)
    return logo, cursor, follow, (wh + we + 8), pad


def draw_logo(canvas, t, rng):
    t0 = 21.5
    if t < t0:
        return
    k = t - t0
    logo, cursor, follow, text_w, lpad = logo_parts()
    cy = 960
    total = text_w
    # dark plate behind the logo for legibility
    plate = smooth(k / 0.3) * 0.55
    canvas[cy - 210:cy + 330] *= (1 - plate * np.exp(-((np.arange(cy - 210, cy + 330) - (cy + 60)) / 260.0) ** 2))[:, None, None]
    op = smooth(k / 0.12)
    sc = 1.0 + 0.25 * math.exp(-k / 0.08)
    layer = np.zeros_like(canvas)
    blit(layer, logo, W / 2, cy, sc, op)
    if k > 0.6 and int(k * 2.2) % 2 == 0:
        blit(layer, cursor, W / 2 + total / 2 + cursor.shape[1] / 2 - lpad + 6, cy, 1.0, 1.0)
    if k < 0.45:
        for _ in range(7):
            y = int(rng.uniform(cy - 110, cy + 110)); hgt = int(rng.uniform(6, 26))
            layer[y:y + hgt] = np.roll(layer[y:y + hgt], int(rng.uniform(-60, 60)), axis=1)
        layer = chroma(layer, 10 * (1 - k / 0.45))
    # light sweep across the logo
    sw = (k - 0.7) / 0.9
    if 0 < sw < 1:
        xs = -200 + sw * (W + 400)
        band = np.exp(-((np.arange(W) - xs) / 70.0) ** 2)[None, :, None]
        layer = layer + layer * band * 1.2
    # pulsing glow
    layer *= 1.0 + 0.08 * math.sin(k * 5.0)
    canvas += layer - canvas * 0  # additive-ish over darkened plate
    # underline bar
    bw = (total - 40) * smooth((k - 0.25) / 0.4)
    if bw > 2:
        bar = np.zeros((H, W), np.float32)
        cv2.rectangle(bar, (int(W / 2 - bw / 2), cy + 112), (int(W / 2 + bw / 2), cy + 118), 1.0, -1)
        canvas += (cv2.GaussianBlur(bar, (0, 0), 6) * 1.5 + bar)[..., None] * np.array(BLUE, np.float32) / 255
    # FOLLOW FOR MORE + brain emoji (pill)
    kf = (t - 25.0) / 0.35
    if kf > 0:
        fy = cy + 250
        sc = ease_out_back(kf) if kf < 1 else 1.0 + 0.03 * math.sin((t - 25.35) * 6)
        fw = follow.shape[1] - 100
        pw, ph = (fw + 60) * sc, 124 * sc
        pill = np.zeros((H, W), np.float32)
        cv2.rectangle(pill, (int(W / 2 - pw / 2), int(fy - ph / 2)), (int(W / 2 + pw / 2), int(fy + ph / 2)), 1.0, 4, cv2.LINE_AA)
        a = smooth(kf * 2)
        canvas += (cv2.GaussianBlur(pill, (0, 0), 8) * 2 + pill)[..., None] * np.array(BLUE, np.float32) / 255 * a
        blit(canvas, follow, W / 2, fy, sc, a)


# ------------------------------------------------------------ main
def main():
    fdir, build, out = sys.argv[1], sys.argv[2], sys.argv[3]
    rest = sys.argv[4:]
    png_dir = None
    if "--png" in rest:
        png_dir = rest[rest.index("--png") + 1]
        rest = rest[:rest.index("--png")]
        os.makedirs(png_dir, exist_ok=True)
    first, last = (int(rest[0]), int(rest[1])) if len(rest) >= 2 else (1, TOTAL)
    proj = json.load(open(os.path.join(build, "scene_proj.json")))
    words = json.load(open(os.path.join(build, "words.json")))
    chunks = subtitle_chunks(words)
    rng = np.random.default_rng(11)
    shakes = [(0.0, 26, 0.45), (IMPACT_T, 34, 0.6), (19.3, 22, 0.5), (21.5, 14, 0.4), (8.25, 6, 0.3)]
    wm = text_sprite("HUMAN.EXE", 34, WHITE, F_MONO, stroke=0, glow=True, glow_col=BLUE)

    ff = None
    if out != "-":
        ff = subprocess.Popen([
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
            "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
            "-profile:v", "high", "-movflags", "+faststart", out], stdin=subprocess.PIPE)

    for f in range(first, last + 1):
        t = t_of(f)
        p = proj.get(str(f), {})
        shot = p.get("shot", "")
        img = load_frame(fdir, f)

        # grade: lift blacks to deep navy, teal-blue tone, vignette
        img = img * VIGNETTE + BG_GLOW
        img = bloom(img)

        # FX overlays that live "in" the scene (before camera shake)
        c = p.get("contact")
        if c and shot in ("S2a_touch", "S4a_self", "S4b_other"):
            who, cx, cy = c[0], c[1] * W, c[2] * H
            col = BLUE if who == "B" else MAGENTA
            period = 0.55 if who == "B" else 0.30
            for j in range(3):
                ph = ((t / period) + j / 3) % 1.0
                ring(img, cx, cy, 20 + ph * 150, col, (1 - ph) ** 1.5 * 0.9, thick=4)
            glow_dot(img, cx, cy, 26, col, 0.9)
        # HUD labels
        if shot in ("S3a_cereb_side", "S3b_cereb_close"):
            a0 = 9.6 if shot == "S3a_cereb_side" else 11.5
            al = smooth((t - a0) / 0.3) * smooth((15.45 - t) / 0.2)
            px, py = p["cereb"][0] * W, p["cereb"][1] * H
            if shot == "S3b_cereb_close":
                px, py = W * 0.52, H * 0.60
            lx = min(px + 150, W - 380) if px < W * 0.6 else px - 160
            hud_label(img, "CEREBELLUM", px, py, lx, min(py + 190, 1230) if py < 1000 else py - 190, CYAN, al)
        if shot == "S3c_predict":
            al = smooth((t - 13.65) / 0.25) * smooth((15.45 - t) / 0.2)
            ax, ay = p["arc"][0] * W, p["arc"][1] * H
            hud_label(img, "PREDICTION", ax, ay, ax + 130, ay + 260, (0, 255, 215), al)
            al2 = smooth((t - 14.55) / 0.2) * smooth((15.45 - t) / 0.2)
            sx, sy = p["spot"][0] * W, p["spot"][1] * H
            hud_label(img, "MATCH = WEAKER FEEL", sx, sy, min(max(sx - 60, 440), W - 440), max(sy - 170, 560), WHITE, al2)
        if shot == "S2b_nerve":
            al = smooth((t - 5.25) / 0.25) * smooth((6.95 - t) / 0.15)
            spr = text_sprite("SIGNAL  >>  TO THE BRAIN", 40, CYAN, F_XBOLD, stroke=4, track=3)
            blit(img, spr, W / 2, 1060, 1.0, al)
        if shot == "S4c_surprise":
            al = smooth((t - 19.45) / 0.15) * smooth((21.45 - t) / 0.15)
            sx, sy = p["spot"][0] * W, p["spot"][1] * H
            hud_label(img, "UNEXPECTED!", sx, sy, min(sx + 120, W - 330), sy - 170, MAGENTA, al)
            img *= np.array([1.0 + 0.25 * al, 0.92, 1.0], np.float32)  # magenta push

        # camera-ish moves: zoom punches on cuts + shakes
        sc = 1.0
        for cut in CUTS:
            k = t - cut
            if 0 <= k < 0.4:
                sc += 0.07 * math.exp(-k / 0.09)
        if 0 <= t < 0.5:
            sc += 0.10 * math.exp(-t / 0.12)
        dx, dy, rot = shake_at(t, shakes)
        img = transform(img, sc, dx, dy, rot)
        for cut in CUTS:
            k = t - cut
            if 0 <= k < 3 / FPS:
                img = zoom_blur(img, 0.10 * (1 - k * FPS / 3))
        # flashes + chromatic aberration
        flash = 0.0; ca = 0.0; fcol = np.array([0.75, 0.9, 1.0], np.float32)
        if t < 0.25:
            flash = 0.45 * (1 - t / 0.15) ** 2 if t < 0.15 else 0.0; ca = 10 * (1 - t / 0.25)
        k = t - IMPACT_T
        if 0 <= k < 0.35:
            flash = max(flash, 0.85 * (1 - k / 0.35) ** 2); ca = max(ca, 16 * (1 - k / 0.35))
            fcol = np.array([1.0, 0.55, 0.85], np.float32)
        k = t - 19.3
        if 0 <= k < 0.25:
            flash = max(flash, 0.6 * (1 - k / 0.25) ** 2); ca = max(ca, 10 * (1 - k / 0.25))
            fcol = np.array([1.0, 0.7, 0.95], np.float32)
        k = t - 21.5
        if 0 <= k < 0.2:
            flash = max(flash, 0.5 * (1 - k / 0.2) ** 2); ca = max(ca, 6)
        for cut in CUTS:
            k = t - cut
            if 0 <= k < 2 / FPS:
                flash = max(flash, 0.18)
        img = chroma(img, ca)
        img = img + flash * fcol

        # outro: dim 3D, logo
        if t >= 21.5:
            draw_logo(img, t, rng)

        # typography (screen space, unaffected by shake)
        draw_headline(img, t)
        draw_subs(img, t, chunks)
        if t < 21.4:
            blit(img, wm, 175, 150, 1.0, 0.75 * smooth(t / 0.4))

        # grain + output
        g = cv2.resize(GRAIN[f % 8], (W, H), interpolation=cv2.INTER_NEAREST)
        img = img + g[..., None] * 0.012
        img = np.clip(img, 0, 1)
        out8 = (img * 255 + 0.5).astype(np.uint8)
        if ff:
            ff.stdin.write(out8.tobytes())
        if png_dir:
            cv2.imwrite(os.path.join(png_dir, f"c{f:04d}.png"), out8[..., ::-1])
        if f % 50 == 0:
            print("composited", f, flush=True)
    if ff:
        ff.stdin.close(); ff.wait()


if __name__ == "__main__":
    main()
