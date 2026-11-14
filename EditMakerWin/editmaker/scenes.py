"""장면(컷)별 효과: 효과 목록, 장면을 실제 재생 조각으로 펼치기, 한국어 요청 해석.

설계도의 segment 하나 = 사용자가 보는 "N번 장면".
segment["effects"] 에 아래 FX id 들이 들어가고, segment["note"] 에 메모를 남길 수 있어요.
"""
import hashlib
import os
import re

from . import media

FX = [
    {"id": "reverse", "name": "리버스", "detail": "거꾸로 재생"},
    {"id": "freeze", "name": "정지 화면", "detail": "장면 끝 40%를 멈춘 화면으로"},
    {"id": "velocity_montage", "name": "벨로시티 (느-빠-느)", "detail": "느리게 → 빠르게 → 느리게"},
    {"id": "velocity_hero", "name": "벨로시티 (빠-슬로)", "detail": "빠르게 → 슬로모션 → 원래 속도"},
    {"id": "memory", "name": "메모리", "detail": "바랜 색 + 살짝 흐림 + 느리게 (회상)"},
    {"id": "bw", "name": "흑백", "detail": "흑백으로"},
    {"id": "bw_to_color", "name": "흑백 → 컬러", "detail": "흑백에서 서서히 색이 돌아옴"},
    {"id": "rgb_split", "name": "글리치 (RGB)", "detail": "시작에 빨강·파랑이 갈라짐"},
    {"id": "strobe", "name": "깜빡임", "detail": "번쩍번쩍 스트로브"},
    {"id": "zoom_out", "name": "줌아웃", "detail": "크게 시작해서 원래 크기로"},
]
FX_IDS = {f["id"] for f in FX}
FX_NAME = {f["id"]: f["name"] for f in FX}
CONFLICTS = [{"velocity_montage", "velocity_hero"}, {"bw", "bw_to_color", "memory"}]

VELOCITY = {  # (구간 비율, 속도 배수)
    "velocity_montage": [(0.3, 0.6), (0.4, 2.0), (0.3, 0.6)],
    "velocity_hero": [(0.4, 2.0), (0.4, 0.4), (0.2, 1.0)],
}


def source_factor(effects):
    """효과 때문에 원본 클립이 얼마나 더 필요한지 (길이 × 속도 × 이 값)"""
    fx = set(effects or [])
    f = 0.7 if "memory" in fx else 1.0
    for k, parts in VELOCITY.items():
        if k in fx:
            f *= sum(a * b for a, b in parts)
            break
    if "freeze" in fx:
        f *= 0.6
    return f


def clean_effects(effects):
    out = []
    for e in effects or []:
        if e in FX_IDS and e not in out:
            for group in CONFLICTS:
                if e in group:
                    out = [x for x in out if x not in group]
            out.append(e)
    return out


# ---------------------------------------------------------------- 펼치기

def _asset(assets_dir, key, ext):
    h = hashlib.sha1(key.encode("utf-8")).hexdigest()[:16]
    return os.path.join(assets_dir, f"{h}{ext}")


def _make_reverse(path, start, dur, assets_dir):
    out = _asset(assets_dir, f"rev|{path}|{start:.3f}|{dur:.3f}", ".mp4")
    if not os.path.exists(out):
        media.run(["-hide_banner", "-loglevel", "error", "-y", "-ss", f"{start:.3f}", "-t", f"{dur:.3f}", "-i", path,
                   "-vf", "reverse", "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "16",
                   "-pix_fmt", "yuv420p", out])
    return out


def _make_frame(path, t, assets_dir):
    out = _asset(assets_dir, f"frame|{path}|{t:.3f}", ".jpg")
    if not os.path.exists(out):
        j = media.frame_jpeg(path, max(t, 0), 1920)
        if not j:
            raise RuntimeError("정지 화면을 만들지 못했어요")
        with open(out, "wb") as f:
            f.write(j)
    return out


def expand(plan, clips, assets_dir):
    """설계도 → 실제로 이어 붙일 조각 목록 + 새로 만든 파일 정보.
    리버스는 거꾸로 된 영상 파일을, 정지 화면은 사진 파일을 만들어서 CapCut·미리보기·AE 모두 같은 방식으로 써요."""
    os.makedirs(assets_dir, exist_ok=True)
    by_path = {c["path"]: c for c in clips}
    extra = {}
    out = []
    for seg in plan["segments"]:
        c = by_path.get(seg["clip"])
        if not c:
            continue
        fx = set(seg.get("effects") or [])
        length = seg["end"] - seg["start"]
        speed = seg["speed"] * (0.7 if "memory" in fx else 1.0)
        still = c["isStill"]
        path, clip_in = c["path"], seg["clipIn"]
        freeze_len = length * 0.4 if "freeze" in fx else 0.0
        moving = length - freeze_len
        parts = [(1.0, 1.0)] if still else next((VELOCITY[k] for k in VELOCITY if k in fx), [(1.0, 1.0)])
        need = sum(moving * a * speed * b for a, b in parts)

        if "reverse" in fx and not still:
            need = min(need, max(c["duration"] - clip_in, 0.1))
            path = _make_reverse(c["path"], clip_in, need, assets_dir)
            clip_in = 0.0
            if path not in extra:
                extra[path] = media.probe(path)

        def info_of(p):
            return extra.get(p) or by_path.get(p) or c

        t, src, k = seg["start"], clip_in, 0
        for a, b in parts:
            dur = moving * a
            sp = 1.0 if still else speed * b
            out.append(_piece(seg, path, info_of(path), still, src, t, t + dur, sp, k, (t - seg["start"]) / length,
                              (t + dur - seg["start"]) / length, fx, dur / length))
            t += dur
            src += 0 if still else dur * sp
            k += 1
        if freeze_len > 0:
            if still:
                fpath = path
            else:
                fpath = _make_frame(path, max(src - 0.05, 0), assets_dir)
                if fpath not in extra:
                    extra[fpath] = media.probe(fpath)
            out.append(_piece(seg, fpath, info_of(fpath), True, 0.0, t, seg["end"], 1.0, k,
                              (t - seg["start"]) / length, 1.0, fx, freeze_len / length))
    return out, list(extra.values())


def _piece(seg, path, info, still, clip_in, start, end, speed, index, p0, p1, fx, share):
    first = index == 0
    return {
        "scene": seg["id"], "clip": path, "isStill": still, "width": info["width"], "height": info["height"],
        "duration": info["duration"], "name": info["name"], "hasAudio": info.get("hasAudio", False),
        "clipIn": round(clip_in, 4), "start": round(start, 4), "end": round(end, 4), "speed": round(speed, 4),
        "transition": seg["transition"] if first else "none",
        "shake": bool(seg.get("shake")) and first,
        "push": 0.0 if "zoom_out" in fx else seg.get("push", 0) * share,
        "fx": {
            "bw": "bw" in fx, "memory": "memory" in fx,
            "bwc": [round(p0, 4), round(p1, 4)] if "bw_to_color" in fx else None,
            "rgb_split": "rgb_split" in fx and first, "strobe": "strobe" in fx,
            "zoom_out": "zoom_out" in fx and first, "freeze": still and "freeze" in fx and not first,
        },
    }


def todo_list(plan):
    """CapCut 프로젝트 파일에 직접 못 넣어서 사용자가 CapCut에서 넣어야 하는 것"""
    items = []
    for s in plan["segments"]:
        fx = set(s.get("effects") or [])
        if "rgb_split" in fx:
            items.append(f"{s['id']}번 장면 ({s['start']:.2f}초~{min(s['start'] + 0.25, s['end']):.2f}초): "
                         "효과 → 비디오 효과에서 'RGB' 또는 '글리치' 검색해서 짧게 넣기")
        if s.get("note"):
            items.append(f"{s['id']}번 장면 메모: {s['note']}")
    return items


# ---------------------------------------------------------------- 한국어 요청 해석

ACTIONS = [  # (정규식, 종류, 값)  — 먼저 나온 것이 우선
    (r"흑백\s*(에서|→|->|에서부터)?\s*(컬러|칼라|색)", "fx", "bw_to_color"),
    (r"(메모리|회상|플래시백|추억)", "fx", "memory"),
    (r"(리버스|거꾸로|역재생|되감)", "fx", "reverse"),
    (r"(정지\s*화면|정지|멈춰|멈추|프리즈|freeze)", "fx", "freeze"),
    (r"(히어로|hero)", "fx", "velocity_hero"),
    (r"(벨로시티|velocity|속도\s*변화)", "fx", "velocity_montage"),
    (r"흑백", "fx", "bw"),
    (r"(글리치|rgb|RGB|색\s*분리)", "fx", "rgb_split"),
    (r"(깜빡|스트로브|strobe|플리커)", "fx", "strobe"),
    (r"(줌\s*아웃|zoom\s*out)", "fx", "zoom_out"),
    (r"(줌\s*펀치|줌\s*인|확대|zoom)", "transition", "zoom_punch"),
    (r"(플래시|번쩍|flash)", "transition", "flash"),
    (r"(래디얼|빨려)", "transition", "radial_blur"),
    (r"(블러|흐리게|흐릿)", "transition", "blur_in"),
    (r"(휩|휙|슬라이드|whip)", "transition", "whip"),
    (r"(흔들|쉐이크|셰이크|shake)", "shake", True),
    (r"(슬로\s*모션|슬로모|슬로우|느리게|천천히)", "speed", 0.5),
    (r"(빠르게|빨리)", "speed", 1.6),
    (r"(원래\s*속도|정상\s*속도)", "speed", 1.0),
]
TRANSITION_NAME = {"zoom_punch": "줌 펀치", "flash": "플래시", "radial_blur": "래디얼 블러", "blur_in": "블러", "whip": "휩"}


def _label(kind, val):
    if kind == "fx":
        return FX_NAME.get(val, val)
    if kind == "transition":
        return TRANSITION_NAME.get(val, val)
    if kind == "shake":
        return "흔들림"
    return f"속도 {val}x"


REMOVE = re.compile(r"(빼|없애|제거|지워|꺼|끄|취소|삭제|말고)")


def _targets(clause, segs, last):
    n = len(segs)
    ids = []
    for a, b in re.findall(r"(\d+)\s*(?:~|-|부터|에서)\s*(\d+)\s*번", clause):
        ids += list(range(int(a), int(b) + 1))
    clause2 = re.sub(r"(\d+)\s*(?:~|-|부터|에서)\s*(\d+)\s*번", "", clause)
    ids += [int(x) for x in re.findall(r"(\d+)\s*번", clause2)]
    for a, b in re.findall(r"(\d+(?:\.\d+)?)\s*초\s*(?:~|-|부터|에서)\s*(\d+(?:\.\d+)?)\s*초", clause):
        ids += [s["id"] for s in segs if s["end"] > float(a) and s["start"] < float(b)]
    clause3 = re.sub(r"(\d+(?:\.\d+)?)\s*초\s*(?:~|-|부터|에서)\s*(\d+(?:\.\d+)?)\s*초", "", clause)
    for t in re.findall(r"(\d+(?:\.\d+)?)\s*초", clause3):
        tt = float(t)
        ids += [s["id"] for s in segs if s["start"] <= tt < s["end"]] or ([segs[-1]["id"]] if segs else [])
    if re.search(r"(처음|첫\s*(번째)?\s*장면|맨\s*앞|시작)", clause):
        ids.append(1)
    if re.search(r"(마지막|맨\s*끝|끝\s*장면)", clause):
        ids.append(n)
    if re.search(r"(전부|모든|전체|다\s)", clause):
        ids += [s["id"] for s in segs]
    ids = [i for i in dict.fromkeys(ids) if 1 <= i <= n]
    return ids or last


def apply_request(plan, text):
    """'3번 장면 리버스, 5~7번 흑백' 같은 요청을 직접 반영.
    반환: (바뀐 plan, 설명 문장) — 이해 못 하면 (None, 이유)"""
    import copy
    p = copy.deepcopy(plan)
    segs = p["segments"]
    if not segs:
        return None, "장면이 없어요."
    clauses = [c.strip() for c in re.split(r"[,\n]|(?<!\d)\.|\.(?!\d)|그리고|하고\s|랑\s", text) if c.strip()]
    last, done, missing_target = [], [], False
    for cl in clauses:
        actions = []
        rest = cl
        for pat, kind, val in ACTIONS:
            if re.search(pat, rest):
                actions.append((kind, val))
                rest = re.sub(pat, " ", rest)
        if not actions:
            continue
        targets = _targets(cl, segs, last)
        if not targets:
            missing_target = True
            continue
        last = targets
        remove = bool(REMOVE.search(cl))
        names = []
        for kind, val in actions:
            for sid in targets:
                s = segs[sid - 1]
                if kind == "fx":
                    fx = list(s.get("effects") or [])
                    if remove:
                        fx = [x for x in fx if x != val]
                    else:
                        fx.append(val)
                    s["effects"] = clean_effects(fx)
                elif kind == "transition":
                    s["transition"] = "none" if remove else val
                elif kind == "shake":
                    s["shake"] = not remove
                elif kind == "speed":
                    s["speed"] = 1.0 if remove else val
            names.append(_label(kind, val))
        tl = ", ".join(f"{i}번" for i in targets) if len(targets) <= 6 else f"{targets[0]}~{targets[-1]}번"
        done.append(f"{tl} 장면: {' · '.join(names)} {'뺐어요' if remove else '넣었어요'}")
    if not done:
        if missing_target:
            return None, "몇 번 장면인지 알려 주세요. 예) \"3번 장면 리버스\", \"10초에 플래시\""
        return None, ""
    return p, "\n".join(done)
