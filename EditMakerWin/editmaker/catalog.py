"""자막 스타일, 전환, CC 프리셋, 무료 폰트 목록 (맥 앱과 같은 id를 써요)."""

STYLES = [
    {"id": "neon_glow", "name": "네온 글로우", "detail": "번쩍 켜지는 네온 + RGB 번짐", "font": "BlackHanSans-Regular"},
    {"id": "soft_blur", "name": "소프트 블러", "detail": "흐릿하게 번지다 또렷해지는 몽환 자막", "font": "GowunDodum-Regular"},
    {"id": "impact_pop", "name": "임팩트 팝", "detail": "크게 튀어나오는 강조 자막", "font": "GasoekOne-Regular"},
    {"id": "typewriter", "name": "타자기", "detail": "한 글자씩 써지는 자막", "font": "DoHyeon-Regular"},
    {"id": "cute_bounce", "name": "말랑 바운스", "detail": "통통 튀는 귀여운 자막", "font": "Jua-Regular"},
    {"id": "light_sweep", "name": "라이트 스윕", "detail": "빛이 쓱 지나가는 반짝 자막", "font": "Orbit-Regular"},
    {"id": "glitch", "name": "글리치", "detail": "지직거리는 RGB 분리", "font": "DoHyeon-Regular"},
    {"id": "minimal", "name": "미니멀", "detail": "얇고 깔끔한 페이드", "font": "GowunDodum-Regular"},
]

TRANSITIONS = [
    {"id": "none", "name": "컷", "detail": "그냥 바로 넘어가기"},
    {"id": "zoom_punch", "name": "줌 펀치", "detail": "비트에 맞춰 확 당겼다 놓기"},
    {"id": "flash", "name": "플래시", "detail": "하얗게 번쩍"},
    {"id": "blur_in", "name": "블러 인", "detail": "흐릿하게 시작해서 또렷하게"},
    {"id": "radial_blur", "name": "래디얼 블러", "detail": "빨려 들어가듯 확대"},
    {"id": "whip", "name": "휩 슬라이드", "detail": "옆에서 휙 밀려 들어오기"},
]

CC_PRESETS = [
    {"id": "dreamy_glow", "name": "몽환 글로우", "detail": "핑크빛 + 부드럽게 번지는 블룸"},
    {"id": "vivid_pop", "name": "쨍한 케이팝", "detail": "채도·대비 업, 선명하게"},
    {"id": "soft_film", "name": "소프트 필름", "detail": "따뜻한 색감 + 필름 노이즈"},
    {"id": "cool_night", "name": "쿨 나이트", "detail": "푸른 보랏빛 밤 감성"},
    {"id": "clean", "name": "클린", "detail": "살짝만 선명하게"},
]

_FONT_BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
FONTS = [
    {"id": "BlackHanSans-Regular", "name": "검은고딕", "path": "blackhansans/BlackHanSans-Regular.ttf"},
    {"id": "DoHyeon-Regular", "name": "도현", "path": "dohyeon/DoHyeon-Regular.ttf"},
    {"id": "Jua-Regular", "name": "주아", "path": "jua/Jua-Regular.ttf"},
    {"id": "Gaegu-Bold", "name": "개구쟁이", "path": "gaegu/Gaegu-Bold.ttf"},
    {"id": "Dongle-Bold", "name": "동글", "path": "dongle/Dongle-Bold.ttf"},
    {"id": "GowunDodum-Regular", "name": "고운돋움", "path": "gowundodum/GowunDodum-Regular.ttf"},
    {"id": "Orbit-Regular", "name": "오르빗", "path": "orbit/Orbit-Regular.ttf"},
    {"id": "GasoekOne-Regular", "name": "가석원", "path": "gasoekone/GasoekOne-Regular.ttf"},
]
for _f in FONTS:
    _f["file"] = _f["path"].split("/")[-1]
    _f["url"] = _FONT_BASE + _f["path"]

STYLE_IDS = {s["id"] for s in STYLES}
TRANSITION_IDS = {t["id"] for t in TRANSITIONS}
CC_IDS = {c["id"] for c in CC_PRESETS}


def style(sid):
    return next((s for s in STYLES if s["id"] == sid), STYLES[0])


def font_file(ps_name):
    f = next((f for f in FONTS if f["id"] == ps_name), None)
    return f["file"] if f else None
