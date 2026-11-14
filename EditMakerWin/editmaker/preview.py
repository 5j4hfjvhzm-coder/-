"""ffmpeg로 미리보기 영상을 만들어요. (컷·속도·줌·블러·플래시·흔들림·색감·자막 + 음악)
CapCut/AE 결과와 100% 같지는 않지만 검토용으로 충분히 비슷하게 보여줘요."""
import os
import tempfile

from . import fonts, media, planner

CC_EQ = {  # 채도, 대비, 밝기, 감마
    "dreamy_glow": (1.12, 0.94, 0.04, 1.05), "vivid_pop": (1.35, 1.15, 0.01, 1.0), "soft_film": (0.85, 0.9, 0.05, 1.05),
    "cool_night": (1.05, 1.1, -0.03, 0.95), "clean": (1.1, 1.04, 0.01, 1.0),
}


def _esc(path):
    """ffmpeg 필터 안에서 쓸 경로 (윈도우 C: 처리)"""
    return path.replace("\\", "/").replace(":", "\\:").replace("'", "\\'")


def _seg_filter(i, seg, W, H, fps):
    """seg = scenes.expand() 가 만든 조각 하나"""
    length = seg["end"] - seg["start"]
    speed = 1.0 if seg["isStill"] else seg["speed"]
    fx = seg.get("fx") or {}
    f = [f"[{i}:v]setpts=(PTS-STARTPTS)/{speed:.4f}", f"fps={fps}",
         f"scale={W}:{H}:force_original_aspect_ratio=increase", f"crop={W}:{H}", "setsar=1"]
    # 줌: 줌 펀치 / 래디얼 / 천천히 줌인
    push = seg["push"]
    tr = seg["transition"]
    if fx.get("zoom_out"):
        f.append(f"zoompan=z='1.25-0.25*min(1,(on/{fps})/{length:.3f})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
                 f":d=1:s={W}x{H}:fps={fps}")
    elif fx.get("freeze"):
        # 멈춘 화면이 밋밋하지 않게 아주 살짝 줌인
        f.append(f"zoompan=z='1+0.06*(on/{fps})/{length:.3f}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
                 f":d=1:s={W}x{H}:fps={fps}")
    elif tr in ("zoom_punch", "radial_blur") or push > 0:
        k0 = 1.22 if tr == "zoom_punch" else (1.35 if tr == "radial_blur" else 1.0)
        p = min(0.22, length * 0.6) if k0 > 1 else 0
        z = (f"if(lt(on/{fps},{p:.3f}),{k0}-({k0}-1.02)*(on/{fps})/{max(p, 0.001):.3f},"
             f"1.02+{push:.3f}*(on/{fps})/{length:.3f})") if k0 > 1 else f"1+{push:.3f}*(on/{fps})/{length:.3f}"
        f.append(f"zoompan=z='{z}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={W}x{H}:fps={fps}")
    t_in = min(0.25, length * 0.5)
    if tr == "blur_in":
        f.append(f"gblur=sigma=30:enable='lt(t,{t_in:.3f})'")
    elif tr == "radial_blur":
        f.append(f"gblur=sigma=18:enable='lt(t,{t_in:.3f})'")
    elif tr == "whip":
        f.append(f"gblur=sigma=60:sigmaV=0:enable='lt(t,{t_in:.3f})'")
    if tr == "flash":
        d = min(0.08, length * 0.5)  # 플래시는 2~3프레임이 가장 깔끔해요
        f.append(f"eq=brightness='if(lt(t,{d:.3f}),0.85*(1-t/{d:.3f}),0)':eval=frame")
    if seg["shake"]:
        e = min(length, 0.5)
        f.append(f"crop=w=iw*0.92:h=ih*0.92:x='(iw-ow)/2+lt(t,{e:.3f})*(1-t/{e:.3f})*iw*0.035*sin(t*90)'"
                 f":y='(ih-oh)/2+lt(t,{e:.3f})*(1-t/{e:.3f})*ih*0.025*cos(t*70)'")
        f.append(f"scale={W}:{H}")
    # 장면 효과
    if fx.get("memory"):
        f.append("colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131")
        f.append("eq=saturation=0.75:contrast=0.92:brightness=0.04")
        f.append("gblur=sigma=1.6")
        f.append(f"fade=t=in:st=0:d={min(0.3, length * 0.5):.3f}:color=white")
    if fx.get("bw"):
        f.append("hue=s=0")
    if fx.get("bwc"):
        p0, p1 = fx["bwc"]
        f.append(f"hue=s='clip(({p0:.4f}+({p1 - p0:.4f})*t/{length:.4f}),0,1)'")
    if fx.get("rgb_split"):
        f.append(f"format=gbrp,rgbashift=rh=-{max(W // 60, 4)}:bh={max(W // 60, 4)}:enable='lt(t,0.2)'")
    if fx.get("strobe"):
        f.append("eq=brightness='if(lt(mod(t,0.2),0.07),0.55,0)':eval=frame")
    f.append(f"trim=duration={length:.4f}")
    f.append("setpts=PTS-STARTPTS,setsar=1,format=yuv420p")
    return ",".join(f) + f"[v{i}]"


def _hex(c):
    return "0x" + c.lstrip("#")


def render(plan, pieces, out_path, width=540, progress=lambda m: None):
    """pieces = scenes.expand(plan, ...)[0]"""
    W = width - width % 2
    H = int(round(plan["height"] * W / plan["width"] / 2)) * 2
    fps = 30
    k = W / plan["width"]
    args = ["-hide_banner", "-loglevel", "error", "-y"]
    filters, labels = [], []
    idx = 0
    for seg in pieces:
        length = seg["end"] - seg["start"]
        if seg["isStill"]:
            args += ["-loop", "1", "-t", f"{length + 0.1:.3f}", "-i", seg["clip"]]
        else:
            need = length * seg["speed"]
            args += ["-ss", f"{seg['clipIn']:.3f}", "-t", f"{need + 0.1:.3f}", "-i", seg["clip"]]
        filters.append(_seg_filter(idx, seg, W, H, fps))
        labels.append(f"[v{idx}]")
        idx += 1
    if not labels:
        raise RuntimeError("미리보기에 쓸 클립이 없어요.")
    filters.append("".join(labels) + f"concat=n={len(labels)}:v=1:a=0[cat]")

    # 색감 + 살짝 번지는 글로우
    sat, con, bri, gam = CC_EQ.get(plan["cc"]["preset"], CC_EQ["dreamy_glow"])
    ik = plan["cc"]["intensity"]
    lerp = lambda a, b: a + (b - a) * ik
    chain = f"[cat]eq=saturation={lerp(1, sat):.3f}:contrast={lerp(1, con):.3f}:brightness={bri * ik:.3f}:gamma={lerp(1, gam):.3f}"
    bloom = plan["cc"]["bloom"]
    if bloom > 0.02:
        filters.append(chain + "[ccb]")
        filters.append(f"[ccb]format=gbrp,split[g1][g2];[g2]gblur=sigma={8 + 30 * bloom:.1f}[g3];"
                       f"[g1][g3]blend=all_mode=screen:all_opacity={0.15 + 0.35 * bloom:.2f},format=yuv420p[cc]")
    else:
        filters.append(chain + "[cc]")
    last = "cc"
    if plan["cc"]["vignette"] > 0.02:
        filters.append(f"[{last}]vignette=angle={0.3 + 0.5 * plan['cc']['vignette']:.2f}[vg]")
        last = "vg"
    if plan["cc"]["grain"] > 0.02:
        filters.append(f"[{last}]noise=alls={int(plan['cc']['grain'] * 18)}:allf=t[gr]")
        last = "gr"

    # 자막
    tmp = tempfile.mkdtemp(prefix="editmaker_")
    for i, sub in enumerate(plan["subtitles"]):
        tf = os.path.join(tmp, f"sub{i}.txt")
        with open(tf, "w", encoding="utf-8") as f:
            f.write(sub["text"])
        font = fonts.installed_path(sub.get("font")) or fonts.installed_path("BlackHanSans-Regular")
        size = max(int(sub["size"] * k), 8)
        a, b = sub["start"], sub["end"]
        fade_in = 0.12 if sub["style"] in ("impact_pop", "glitch", "neon_glow") else 0.3
        alpha = f"if(lt(t,{a + fade_in:.3f}),(t-{a:.3f})/{fade_in},if(gt(t,{b - 0.15:.3f}),({b:.3f}-t)/0.15,1))"
        border = {"impact_pop": 5, "cute_bounce": 4, "neon_glow": 2, "typewriter": 1, "light_sweep": 1}.get(sub["style"], 0)
        base = (f"textfile='{_esc(tf)}':expansion=none:fontsize={size}:x=(w-text_w)/2+w*({sub['x']:.3f}-0.5)"
                f":y=h*{sub['y']:.3f}-text_h/2:enable='between(t,{a:.3f},{b:.3f})':alpha='{alpha}':text_align=C")
        if font:
            base = f"fontfile='{_esc(font)}':" + base
        parts = []
        if sub["style"] in ("neon_glow", "soft_blur", "light_sweep", "glitch", "typewriter"):
            # 네온 번짐: 색 글자를 흐리게 깔고 위에 또렷한 글자
            parts.append(f"[{last}]format=gbrp,split[s{i}a][s{i}b];[s{i}b]drawbox=c=black:t=fill,"
                         f"drawtext={base}:fontcolor={_hex(sub['accent'])}:borderw={max(border, 3)}:bordercolor={_hex(sub['accent'])},"
                         f"gblur=sigma={max(size / 7, 3):.1f}[s{i}g];[s{i}a][s{i}g]blend=all_mode=screen,format=yuv420p[s{i}c]")
            src = f"s{i}c"
        else:
            src = last
        shadow = ":shadowcolor=black@0.6:shadowx=3:shadowy=3" if sub["style"] != "minimal" else ""
        stroke = f":borderw={border}:bordercolor={_hex(sub['accent'])}" if border else ""
        parts.append(f"[{src}]drawtext={base}:fontcolor={_hex(sub['color'])}{stroke}{shadow}[t{i}]")
        filters.append(";".join(parts))
        last = f"t{i}"

    music = plan.get("music")
    if music and music.get("path"):
        args += ["-ss", f"{music['offset']:.3f}", "-t", f"{plan['duration']:.3f}", "-i", music["path"]]
        audio_map = ["-map", f"{idx}:a?"]
    else:
        audio_map = []
    script = os.path.join(tmp, "graph.txt")
    with open(script, "w", encoding="utf-8") as f:
        f.write(";\n".join(filters))
    progress("미리보기 영상 만드는 중…")
    tail = ["-map", f"[{last}]"] + audio_map + [
        "-t", f"{plan['duration']:.3f}", "-c:v", "libx264", "-preset", "veryfast", "-crf", "24", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out_path]
    # ffmpeg 7+ 은 "-/filter_complex 파일", 예전 버전은 "-filter_complex_script 파일"
    try:
        media.run(args + ["-/filter_complex", script] + tail)
    except RuntimeError as e:
        if "filter_complex" not in str(e) and "Unrecognized option" not in str(e):
            raise
        media.run(args + ["-filter_complex_script", script] + tail)
    return out_path
