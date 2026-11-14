"""AI 감독: 레퍼런스를 보고 자막·효과를 고르고, 수정 요청을 설계도에 반영해요. (Claude 또는 Gemini)"""
import base64
import json
import urllib.error
import urllib.request

from . import catalog, config, media, planner, scenes

CLAUDE_MODEL = "claude-opus-5-5"
GEMINI_MODEL = "gemini-flash-latest"


class AIError(Exception):
    pass


def current_client():
    pref = config.get("aiProvider", "claude")
    for p in [pref] + [x for x in ("claude", "gemini") if x != pref]:
        k = config.get_key(p)
        if k:
            return p, k
    return None


def _post(url, headers, body, timeout=300):
    req = urllib.request.Request(url, data=json.dumps(body).encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            msg = json.loads(e.read().decode("utf-8")).get("error", {}).get("message", "")
        except Exception:
            msg = ""
        if e.code in (401, 403):
            raise AIError("API 키가 올바르지 않거나 권한이 없어요. 설정에서 확인해 주세요.")
        if e.code == 429:
            raise AIError("AI 사용 한도에 걸렸어요. 잠시 후 다시 시도해 주세요.")
        raise AIError(f"AI 응답 실패 ({e.code}) {msg}")
    except urllib.error.URLError as e:
        raise AIError(f"인터넷 연결을 확인해 주세요. ({e.reason})")


def complete(system, text, jpegs=(), client=None):
    client = client or current_client()
    if not client:
        raise AIError("AI를 쓰려면 설정에서 Claude 또는 Gemini API 키를 넣어 주세요.")
    provider, key = client
    if provider == "claude":
        content = [{"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
                                                 "data": base64.b64encode(j).decode()}} for j in jpegs]
        content.append({"type": "text", "text": text})
        obj = _post("https://api.anthropic.com/v1/messages", {
            "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01",
            "anthropic-beta": "server-side-fallback-2026-07-01",
        }, {"model": CLAUDE_MODEL, "max_tokens": 16000, "output_config": {"effort": "medium"}, "fallbacks": "default",
            "system": system, "messages": [{"role": "user", "content": content}]})
        if obj.get("stop_reason") == "refusal":
            raise AIError("AI가 이 요청에 답할 수 없어요.")
        out = "".join(b.get("text", "") for b in obj.get("content", []) if b.get("type") == "text")
    else:
        parts = [{"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(j).decode()}} for j in jpegs]
        parts.append({"text": text})
        obj = _post(f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent", {
            "content-type": "application/json", "x-goog-api-key": "".join(key.split()),
        }, {"systemInstruction": {"parts": [{"text": system}]}, "contents": [{"role": "user", "parts": parts}],
            "generationConfig": {"maxOutputTokens": 32000, "responseMimeType": "application/json"}})
        if obj.get("promptFeedback", {}).get("blockReason"):
            raise AIError("AI가 이 요청에 답할 수 없어요.")
        cands = obj.get("candidates") or [{}]
        ps = (cands[0].get("content") or {}).get("parts") or []
        out = "".join(p.get("text", "") for p in ps if not p.get("thought"))
    if not out:
        raise AIError("AI가 빈 답을 보냈어요. 다시 시도해 주세요.")
    return out


def system_prompt():
    styles = "\n".join(f"- {s['id']}: {s['name']} — {s['detail']} (기본 폰트 {s['font']})" for s in catalog.STYLES)
    trans = "\n".join(f"- {t['id']}: {t['name']} — {t['detail']}" for t in catalog.TRANSITIONS)
    ccs = "\n".join(f"- {c['id']}: {c['name']} — {c['detail']}" for c in catalog.CC_PRESETS)
    fonts = "\n".join(f"- {f['id']} ({f['name']})" for f in catalog.FONTS)
    fx = "\n".join(f"- {f['id']}: {f['name']} — {f['detail']}" for f in scenes.FX)
    return f"""너는 틱톡/릴스 "edit" 영상 전문 편집 감독이야. CapCut 또는 After Effects로 만들어질 edit의 설계도(JSON)를 다룬다.
edit 특유의 느낌: 비트에 딱딱 맞는 빠른 컷, 줌 펀치·플래시·흔들림·휩, 몽환적인 글로우 색보정(cc), 네온/번지는 자막.

설계도 필드:
- width, height, fps, duration(초)
- music: {{path, offset}} — 바꾸지 마.
- cc: {{preset, intensity 0~1, bloom 0~1(살짝 번지는 글로우), grain 0~1, vignette 0~1, userPresets[] — 바꾸지 마}}
- segments[]: {{id, clip(파일 경로, 주어진 클립 목록 안에서만), clipIn(클립의 몇 초부터), start, end, speed(1=원래, 0.5=슬로우), transition, shake(bool), push(0~0.3 천천히 줌인), effects[](장면 효과 id 목록), note(메모)}}
  · id는 사용자가 말하는 "N번 장면" 번호야. 사용자가 장면 번호나 초를 말하면 그 장면만 정확히 고쳐.
  · segments는 0초부터 duration까지 빈틈없이, 겹치지 않게 이어져야 해.
  · clipIn + (end-start)*speed 가 그 클립 길이를 넘으면 안 돼.
  · 컷 경계는 가능하면 beats 목록의 시각에 맞춰.
- subtitles[]: {{id, text(줄바꿈은 \\n), start, end, style, font, size(px), color(#RRGGBB 글자색), accent(#RRGGBB 테두리·글로우색), x, y(0~1, 0.5가 중앙)}}
- beats: 음악 비트 시각 — 참고만 하고 바꾸지 마.

자막 style:
{styles}

transition:
{trans}

장면 효과(effects):
{fx}

cc preset:
{ccs}

설치된 폰트(font 값):
{fonts}

규칙:
- 요청한 부분만 고치고 나머지는 최대한 그대로 둬.
- 자막 내용(text)은 사용자가 바꾸라고 할 때만 바꿔.
- 답은 반드시 JSON 하나만: {{"message": "무엇을 바꿨는지 한국어로 1~3문장", "plan": {{설계도 전체}}}}
- 코드블록이나 다른 설명 없이 JSON만 출력해."""


def clip_list(clips):
    return "\n".join(f"- {c['path']} (사진)" if c["isStill"] else f"- {c['path']} ({c['duration']:.2f}초)" for c in clips)


def _ask(text, jpegs, clips, original):
    raw = complete(system_prompt(), text, jpegs)
    a, b = raw.find("{"), raw.rfind("}")
    if a < 0 or b < a:
        raise AIError("AI 답을 이해하지 못했어요. 다시 시도해 주세요.")
    try:
        reply = json.loads(raw[a:b + 1])
        plan = reply["plan"]
    except Exception:
        raise AIError("AI 답의 설계도 형식이 이상해요. 다시 시도해 주세요.")
    plan["music"] = original.get("music")
    plan["beats"] = original.get("beats", [])
    plan.setdefault("cc", {})["userPresets"] = original["cc"].get("userPresets", [])
    return str(reply.get("message", "수정했어요.")), planner.sanitize(plan, clips)


def direct(plan, ref, clips, keyframes):
    text = f"""첨부 이미지는 레퍼런스 edit 영상의 장면들이야. 분석: {media.summary(ref)}

사용할 클립:
{clip_list(clips)}

아래 초안을 레퍼런스 느낌에 맞게 다듬어 줘.
- 자막마다 어울리는 style, font, 색(color/accent), 크기, 위치를 골라 (레퍼런스 자막 색감·분위기를 참고).
- 컷의 transition/shake/push 를 비트 세기와 분위기에 맞게 조절해.
- cc preset/bloom 도 레퍼런스 색감에 맞게.
- 컷 타이밍(start/end)과 clip 배치는 크게 바꾸지 마.

초안:
{json.dumps(plan, ensure_ascii=False)}"""
    return _ask(text, keyframes, clips, plan)


def revise(plan, request, history, ref, clips):
    recent = "\n".join(("사용자: " if h["role"] == "user" else "감독: ") + h["text"]
                       for h in history[-8:] if h["role"] in ("user", "assistant"))
    text = f"""{('레퍼런스 분석: ' + media.summary(ref)) if ref else ''}
사용할 클립:
{clip_list(clips)}

지금까지 대화:
{recent or '(없음)'}

현재 설계도:
{json.dumps(plan, ensure_ascii=False)}

사용자의 새 수정 요청: {request}"""
    return _ask(text, [], clips, plan)
