"""레퍼런스 분석 + 내 클립 → edit 설계도(plan). 설계도 형식은 맥 앱과 같아요."""
import colorsys
import os
import random

from . import catalog


def r3(v):
    return round(float(v), 3)


def hex_hsb(h, s, b):
    r, g, bl = colorsys.hsv_to_rgb(h % 1, max(0, min(s, 1)), max(0, min(b, 1)))
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(bl * 255))


def hex_rgb(hexs):
    h = str(hexs).lstrip("#")
    if len(h) != 6:
        return None
    try:
        v = int(h, 16)
    except ValueError:
        return None
    return ((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255


def dimensions(aspect, ref):
    if aspect == "horizontal":
        return 1920, 1080
    if aspect == "square":
        return 1080, 1080
    if aspect == "match":
        scale = 1920 / max(ref["width"], ref["height"])
        even = lambda v: max(2, round(v * scale / 2) * 2)
        return even(ref["width"]), even(ref["height"])
    return 1080, 1920


def snap(t, beats):
    if not beats:
        return t
    b = min(beats, key=lambda x: abs(x - t))
    return b if abs(b - t) < 0.09 else t


def cut_points(ref, duration, mode):
    ref_cuts = [snap(c, ref["beats"]) for c in ref["cuts"] if 0.15 < c < duration - 0.15]
    step = (1 if ref["energy"] > 0.7 else 2) if ref["bpm"] >= 110 else 1
    beat_cuts = [b for i, b in enumerate(ref["beats"]) if i % step == 0 and 0.15 < b < duration - 0.15]
    if mode == "reference":
        pts = ref_cuts if len(ref_cuts) >= max(3, int(duration / 4)) else ref_cuts + beat_cuts
    elif mode == "beats":
        pts = beat_cuts
    else:
        pts = ref_cuts + beat_cuts[::2]
    pts.sort()
    out = [0.0]
    for p in pts:
        if p - out[-1] >= 0.3:
            out.append(p)
    if duration - out[-1] < 0.25 and len(out) > 1:
        out.pop()
    out.append(duration)
    return out


def beat_strength(t, ref):
    if not ref["beats"]:
        return 0.3
    i = min(range(len(ref["beats"])), key=lambda k: abs(ref["beats"][k] - t))
    if abs(ref["beats"][i] - t) < 0.1 and i < len(ref["beatStrength"]):
        return ref["beatStrength"][i]
    return 0.3


def auto_style(text, ref, index):
    t = text.strip()
    if "!" in t or (len(t) <= 4 and ref["energy"] > 0.4):
        return "impact_pop"
    if any(c in t for c in ["?", "~", "ㅋ", "ㅎ", "♡", "♥", "💕", "🩷"]):
        return "cute_bounce"
    if len(t) >= 16:
        return "typewriter"
    if ref["saturation"] < 0.22 or ref["brightness"] < 0.3:
        opts = ["soft_blur", "minimal", "light_sweep"]
    elif ref["hue"] > 0.75 or ref["hue"] < 0.05:
        opts = ["neon_glow", "light_sweep", "soft_blur"]
    elif ref["energy"] > 0.6:
        opts = ["glitch", "neon_glow", "impact_pop"]
    else:
        opts = ["neon_glow", "soft_blur", "light_sweep"]
    return opts[index % len(opts)]


def auto_cc(ref):
    if ref["saturation"] < 0.2:
        return "soft_film"
    if ref["brightness"] < 0.38 and 0.5 < ref["hue"] < 0.78:
        return "cool_night"
    if ref["hue"] > 0.75 or ref["hue"] < 0.04:
        return "dreamy_glow"
    if ref["saturation"] > 0.5:
        return "vivid_pop"
    return "dreamy_glow"


def wrap(s):
    if len(s) <= 11 or "\n" in s:
        return s
    mid = len(s) // 2
    spaces = [i for i, c in enumerate(s) if c == " "]
    if not spaces:
        return s
    cut = min(spaces, key=lambda i: abs(i - mid))
    return s[:cut] + "\n" + s[cut + 1:]


def make_subtitle(sid, text, start, end, style, ref, width):
    hue = ref["hue"] if ref["saturation"] > 0.15 else 0.9
    fill, acc = hex_hsb(hue, 0.1, 1), hex_hsb(hue, 0.8, 1)
    size, y = width * 0.078, 0.55
    if style == "impact_pop":
        fill, acc, size, y = "#FFFFFF", hex_hsb(hue, 0.85, 0.95), size * 1.3, 0.5
    elif style == "minimal":
        fill, acc, size, y = "#FFFFFF", "#000000", size * 0.72, 0.8
    elif style == "cute_bounce":
        fill, acc = "#FFFFFF", hex_hsb(hue, 0.5, 1)
    elif style == "typewriter":
        size, y = size * 0.82, 0.72
    elif style == "soft_blur":
        fill = "#FFFFFF"
    return {"id": sid, "text": wrap(text), "start": r3(start), "end": r3(end), "style": style,
            "font": catalog.style(style)["font"], "size": round(size), "color": fill, "accent": acc, "x": 0.5, "y": y}


def make(ref, ref_path, music_path, clips, o):
    """o: aspect, cutMode, maxLength, ccPreset, subtitleStyle, effectAmount, bloom, subtitleLines, userPresets, seed"""
    rng = random.Random(o.get("seed", 7))
    w, h = dimensions(o.get("aspect", "vertical"), ref)
    duration = min(o["maxLength"], ref["duration"]) if o.get("maxLength") else ref["duration"]
    effect = float(o.get("effectAmount", 0.6))
    bounds = cut_points(ref, duration, o.get("cutMode", "mix"))

    order = list(clips)
    rng.shuffle(order)
    cursor = {}
    segments = []
    for i in range(len(bounds) - 1):
        if not order:
            break
        start, end = bounds[i], bounds[i + 1]
        length = end - start
        clip = order[i % len(order)]
        if i % len(order) == len(order) - 1 and len(order) > 2:
            rng.shuffle(order)
        speed = 0.75 if ref["energy"] < 0.4 and length > 1.2 and not clip["isStill"] else 1.0
        clip_in = 0.0
        if not clip["isStill"]:
            need = length * speed
            if clip["duration"] >= need:
                c = cursor.get(clip["path"], rng.random())
                clip_in = (clip["duration"] - need) * c
                cursor[clip["path"]] = (c + 0.618) % 1
            else:
                speed = max(0.25, clip["duration"] / length * 0.98)
        strength = beat_strength(start, ref)
        trans, shake = "none", False
        if i == 0:
            trans = "blur_in"
        elif i % 8 == 0 and effect > 0.3:
            trans = "flash"
        elif strength > 0.7 and rng.random() < effect:
            r = rng.random()
            trans = "zoom_punch" if r < 0.6 else ("radial_blur" if r < 0.8 else "flash")
            shake = strength > 0.85 and rng.random() < effect * 0.5
        elif rng.random() < effect * 0.45:
            trans = rng.choice(["whip", "zoom_punch", "blur_in"])
        push = (0.04 + 0.08 * rng.random()) * (0.5 + effect) if length > 0.8 else 0
        segments.append({"id": i + 1, "clip": clip["path"], "clipIn": r3(clip_in), "start": r3(start), "end": r3(end),
                         "speed": r3(speed), "transition": trans, "shake": shake, "push": r3(push)})

    lines = [l.strip() for l in o.get("subtitleLines", []) if l.strip()]
    subtitles = []
    if lines:
        slot = duration / len(lines)
        for k, line in enumerate(lines):
            desired = k * slot + min(0.3, slot * 0.1)
            start = min(bounds[:-1], key=lambda b: abs(b - desired))
            dur = min(max(len(line) * 0.13 + 0.8, 1.0), max(slot * 0.95, 0.8), 3.5)
            st = o.get("subtitleStyle", "auto")
            style = auto_style(line, ref, k) if st == "auto" else st
            subtitles.append(make_subtitle(k + 1, line, start, min(start + dur, duration), style, ref, w))

    cc_id = auto_cc(ref) if o.get("ccPreset", "auto") == "auto" else o["ccPreset"]
    music = music_path or (ref_path if ref.get("hasAudio") else None)
    return {
        "width": w, "height": h, "fps": 30, "duration": r3(duration),
        "music": {"path": music, "offset": 0} if music else None,
        "cc": {"preset": cc_id, "intensity": 0.7, "bloom": float(o.get("bloom", 0.5)),
               "grain": 0.4 if cc_id == "soft_film" else 0.15, "vignette": 0.3, "userPresets": o.get("userPresets", [])},
        "segments": segments, "subtitles": subtitles,
        "beats": [r3(b) for b in ref["beats"] if b < duration],
    }


def clamp(v, lo, hi):
    try:
        v = float(v)
    except (TypeError, ValueError):
        v = lo
    return min(max(v, lo), hi)


def sanitize(plan, clips):
    """범위를 맞추고, 클립 길이를 넘는 구간을 고쳐요. (AI가 고친 결과에도 써요)"""
    p = dict(plan)
    p["width"] = int(clamp(p.get("width", 1080), 360, 3840))
    p["height"] = int(clamp(p.get("height", 1920), 360, 3840))
    p["fps"] = min([24, 25, 29.97, 30, 50, 60], key=lambda f: abs(f - float(p.get("fps", 30))))
    p["duration"] = clamp(p.get("duration", 10), 1, 600)
    cc = dict(p.get("cc") or {})
    cc["preset"] = cc.get("preset") if cc.get("preset") in catalog.CC_IDS else "dreamy_glow"
    for k, d in (("intensity", 0.7), ("bloom", 0.5), ("grain", 0.2), ("vignette", 0.3)):
        cc[k] = clamp(cc.get(k, d), 0, 1)
    cc["userPresets"] = list(cc.get("userPresets") or [])
    p["cc"] = cc

    by_path = {c["path"]: c for c in clips}
    fallback = clips[0]["path"] if clips else ""
    segs = []
    for s in sorted(p.get("segments") or [], key=lambda s: float(s.get("start", 0))):
        s = dict(s)
        s["start"], s["end"] = float(s.get("start", 0)), min(float(s.get("end", 0)), p["duration"])
        if s["end"] <= s["start"] or s["start"] >= p["duration"]:
            continue
        if by_path and s.get("clip") not in by_path:
            s["clip"] = fallback
        s["clipIn"] = max(0.0, float(s.get("clipIn", 0)))
        s["speed"] = clamp(s.get("speed", 1), 0.1, 4)
        s["push"] = clamp(s.get("push", 0), 0, 0.4)
        s["shake"] = bool(s.get("shake", False))
        if s.get("transition") not in catalog.TRANSITION_IDS:
            s["transition"] = "none"
        c = by_path.get(s["clip"])
        if c and not c["isStill"]:
            length = s["end"] - s["start"]
            if length * s["speed"] > c["duration"]:
                s["speed"] = max(0.1, c["duration"] / length * 0.98)
            need = length * s["speed"]
            if s["clipIn"] + need > c["duration"]:
                s["clipIn"] = max(0.0, c["duration"] - need - 0.01)
        segs.append(s)
    for i, s in enumerate(segs):
        s["id"] = i + 1
    p["segments"] = segs

    subs = []
    for s in sorted(p.get("subtitles") or [], key=lambda s: float(s.get("start", 0))):
        s = dict(s)
        if not str(s.get("text", "")).strip():
            continue
        s["start"] = max(0.0, float(s.get("start", 0)))
        s["end"] = min(float(s.get("end", 0)), p["duration"])
        if s["end"] <= s["start"]:
            continue
        if s.get("style") not in catalog.STYLE_IDS:
            s["style"] = "neon_glow"
        s.setdefault("font", catalog.style(s["style"])["font"])
        s["size"] = clamp(s.get("size", 84), 20, 400)
        s["x"] = clamp(s.get("x", 0.5), 0.05, 0.95)
        s["y"] = clamp(s.get("y", 0.5), 0.05, 0.95)
        if not hex_rgb(s.get("color", "")):
            s["color"] = "#FFFFFF"
        if not hex_rgb(s.get("accent", "")):
            s["accent"] = "#FF3CAC"
        subs.append(s)
    for i, s in enumerate(subs):
        s["id"] = i + 1
    p["subtitles"] = subs
    p["beats"] = list(p.get("beats") or [])
    return p
