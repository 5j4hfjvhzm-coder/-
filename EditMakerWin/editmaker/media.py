"""ffmpeg로 영상을 읽고 레퍼런스 영상의 컷·비트·색감을 분석해요."""
import math
import os
import re
import subprocess
import sys

import numpy as np

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".heic", ".tif", ".tiff", ".gif", ".webp", ".bmp"}
AUDIO_EXTS = {".mp3", ".m4a", ".wav", ".aac", ".aif", ".aiff", ".flac", ".ogg"}
VIDEO_EXTS = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}

_NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0  # 윈도우에서 까만 창이 뜨지 않게


def ffmpeg_exe():
    """설치 파일에 같이 들어 있는 ffmpeg(imageio-ffmpeg) → 없으면 PATH의 ffmpeg."""
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


def run(args, input_bytes=None, check=True):
    p = subprocess.run([ffmpeg_exe()] + args, input=input_bytes, capture_output=True, creationflags=_NO_WINDOW)
    if check and p.returncode != 0:
        raise RuntimeError(p.stderr.decode("utf-8", "replace")[-600:])
    return p


def probe(path):
    """길이, 크기, 사진 여부, 소리 유무"""
    ext = os.path.splitext(path)[1].lower()
    name = os.path.basename(path)
    if ext in IMAGE_EXTS:
        try:
            from PIL import Image
            with Image.open(path) as im:
                w, h = im.size
        except Exception:
            w, h = 1080, 1920
        return {"path": path, "name": name, "duration": 0.0, "width": w, "height": h, "isStill": True, "hasAudio": False}
    p = run(["-hide_banner", "-i", path], check=False)
    err = p.stderr.decode("utf-8", "replace")
    m = re.search(r"Duration: (\d+):(\d+):(\d+\.?\d*)", err)
    if not m:
        raise RuntimeError(f"{name} 파일을 읽을 수 없어요. 영상(mp4, mov)이나 이미지인지 확인해 주세요.")
    dur = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    w = h = 0
    vm = re.search(r"Stream #.*Video:.*?(\d{2,5})x(\d{2,5})", err)
    if vm:
        w, h = int(vm.group(1)), int(vm.group(2))
        rot = re.search(r"rotation of (-?\d+\.?\d*)", err) or re.search(r"rotate\s*:\s*(-?\d+)", err)
        if rot and abs(abs(float(rot.group(1))) - 90) < 1:
            w, h = h, w
    has_audio = bool(re.search(r"Stream #.*Audio:", err))
    return {"path": path, "name": name, "duration": dur, "width": w, "height": h, "isStill": False, "hasAudio": has_audio}


def frame_jpeg(path, t, width=360):
    """t초 장면 한 장을 JPEG로"""
    ext = os.path.splitext(path)[1].lower()
    args = ["-hide_banner", "-loglevel", "error"]
    if ext not in IMAGE_EXTS:
        args += ["-ss", f"{max(t, 0):.3f}"]
    args += ["-i", path, "-frames:v", "1", "-vf", f"scale={width}:-2", "-q:v", "4", "-f", "image2pipe", "-vcodec", "mjpeg", "-"]
    p = run(args, check=False)
    return p.stdout if p.returncode == 0 and p.stdout else None


def _hsb(rgb):
    mx = rgb.max(axis=1)
    mn = rgb.min(axis=1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    h[rm] = ((g[rm] - b[rm]) / d[rm]) % 6
    h[gm] = (b[gm] - r[gm]) / d[gm] + 2
    h[bm] = (r[bm] - g[bm]) / d[bm] + 4
    return h / 6, s, mx


def detect_cuts(diffs, times):
    if len(diffs) < 3:
        return []
    median = float(np.median(diffs))
    thr = max(0.11, median * 3.2)
    cuts = []
    for i, d in enumerate(diffs):
        if d <= thr:
            continue
        left = diffs[i - 1] if i > 0 else 0
        right = diffs[i + 1] if i + 1 < len(diffs) else 0
        if d < left or d < right:
            continue
        if cuts and times[i] - cuts[-1] < 0.2:
            continue
        cuts.append(round(times[i], 2))
    return cuts


def detect_beats(samples, sr=22050):
    """저음(킥) 위주로 소리가 세지는 순간 → BPM과 박자 위치"""
    hop, win = 512, 1024
    if len(samples) < win * 8:
        return [], 0.0, []
    env_rate = sr / hop
    # 150Hz 아래(킥 드럼)만 남긴 신호
    spec = np.fft.rfft(samples)
    spec[int(150 * len(samples) / sr):] = 0
    low = np.fft.irfft(spec, n=len(samples)).astype(np.float32)
    n = (len(samples) - win) // hop + 1
    idx = np.arange(win)[None, :] + hop * np.arange(n)[:, None]
    full_e = np.log1p(1000 * np.mean(samples[idx] ** 2, axis=1))
    low_e = np.log1p(1000 * np.mean(low[idx] ** 2, axis=1))
    onset = np.zeros(n)
    onset[1:] = 0.6 * np.maximum(0, np.diff(low_e)) + 0.4 * np.maximum(0, np.diff(full_e))
    c = onset - onset.mean()
    best_lag, best = 0, -1e18
    for lag in range(max(int(60 * env_rate / 180), 1), int(60 * env_rate / 70) + 1):
        s = float(np.dot(c[lag:], c[:-lag]))
        bpm = 60 * env_rate / lag
        s *= math.exp(-0.5 * (math.log2(bpm / 120) / 0.9) ** 2)
        if s > best:
            best, best_lag = s, lag
    if best_lag <= 0:
        return [], 0.0, []
    best_phase, best_sum = 0, -1e18
    for p in range(best_lag):
        s = float(onset[p::best_lag].sum())
        if s > best_sum:
            best_sum, best_phase = s, p
    peak = max(float(onset.max()), 1e-6)
    beats, strength = [], []
    for c_ in range(best_phase, n, best_lag):
        local = float(onset[max(0, c_ - 2):c_ + 3].max())
        beats.append(round(c_ / env_rate, 3))
        strength.append(min(local / peak * 1.5, 1.0))
    return beats, 60 * env_rate / best_lag, strength


def load_audio(path, sr=22050, max_seconds=180, offset=0.0):
    p = run(["-hide_banner", "-loglevel", "error", "-ss", f"{offset}", "-t", f"{max_seconds}", "-i", path,
             "-vn", "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"], check=False)
    if p.returncode != 0 or not p.stdout:
        return np.zeros(0, dtype=np.float32)
    return np.frombuffer(p.stdout, dtype=np.float32)


def analyze_reference(path, progress=lambda m: None):
    info = probe(path)
    dur = info["duration"]
    scan = min(dur, 180)

    progress("장면 전환 찾는 중…")
    side, fps = 24, 8
    p = run(["-hide_banner", "-loglevel", "error", "-t", f"{scan}", "-i", path, "-vf", f"fps={fps},scale={side}:{side}",
             "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], check=False)
    frames = np.frombuffer(p.stdout, dtype=np.uint8)
    nf = len(frames) // (side * side * 3)
    frames = frames[: nf * side * side * 3].reshape(nf, side * side, 3).astype(np.float32) / 255
    cuts, hue, sat, bri = [], 0.9, 0.4, 0.5
    if nf > 2:
        diffs = np.abs(np.diff(frames, axis=0)).mean(axis=(1, 2))
        times = [(i + 1) / fps - 0.5 / fps for i in range(len(diffs))]
        cuts = detect_cuts(list(diffs), times)
        h, s, b = _hsb(frames.reshape(-1, 3))
        sat, bri = float(s.mean()), float(b.mean())
        w = s * b
        hx, hy = float((np.cos(h * 2 * np.pi) * w).sum()), float((np.sin(h * 2 * np.pi) * w).sum())
        hue = (math.atan2(hy, hx) / (2 * math.pi)) % 1

    progress("음악 비트 찾는 중…")
    beats, bpm, strength = detect_beats(load_audio(path, max_seconds=scan)) if info["hasAudio"] else ([], 0.0, [])
    if not beats:
        bpm = 120.0
        beats = [round(x * 0.5, 3) for x in range(int(dur / 0.5))]
        strength = [0.5] * len(beats)

    progress("대표 장면 고르는 중…")
    keyframes = [j for j in (frame_jpeg(path, dur * f, 512) for f in (0.15, 0.4, 0.65, 0.9)) if j]

    cps = len(cuts) / max(dur, 1)
    energy = min(max(min(cps / 2.5, 1) * 0.65 + min(max((bpm - 80) / 80, 0), 1) * 0.35, 0), 1)
    return {
        "duration": dur, "width": info["width"] or 1080, "height": info["height"] or 1920,
        "cuts": cuts, "beats": beats, "bpm": bpm, "beatStrength": strength,
        "hue": hue, "saturation": sat, "brightness": bri, "energy": energy, "hasAudio": info["hasAudio"],
    }, keyframes


def summary(a):
    cps = len(a["cuts"]) / max(a["duration"], 1)
    return (f"길이 {a['duration']:.1f}초 · 컷 {len(a['cuts'])}개(초당 {cps:.1f}) · {a['bpm']:.0f} BPM · "
            f"밝기 {a['brightness'] * 100:.0f}% · 채도 {a['saturation'] * 100:.0f}%")
