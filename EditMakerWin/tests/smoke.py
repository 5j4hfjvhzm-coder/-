"""설치 파일을 만들기 전에 실제 윈도우에서 핵심 기능을 확인해요. (CI에서 실행)"""
import json
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from editmaker import ae, capcut, config, fonts, media, planner, preview, scenes  # noqa: E402

tmp = tempfile.mkdtemp(prefix="em smoke ")  # 공백 들어간 경로도 확인
ff = media.ffmpeg_exe()
print("ffmpeg:", ff)
ref = os.path.join(tmp, "레퍼런스.mp4")
subprocess.run([ff, "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=576x1024:rate=30:duration=8",
                "-f", "lavfi", "-i", "sine=frequency=60:beep_factor=8:duration=8", "-shortest",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", ref], check=True)
clips = []
for i in range(3):
    p = os.path.join(tmp, f"clip {i}.mp4")
    subprocess.run([ff, "-v", "error", "-y", "-f", "lavfi", "-i", f"testsrc=size=1280x720:rate=30:duration=3",
                    "-vf", f"hue=h={i * 90}", "-c:v", "libx264", "-pix_fmt", "yuv420p", p], check=True)
    clips.append(media.probe(p))
img = os.path.join(tmp, "photo.jpg")
subprocess.run([ff, "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=800x800", "-frames:v", "1", img], check=True)
clips.append(media.probe(img))

a, k = media.analyze_reference(ref, print)
print(media.summary(a), "keyframes:", len(k))
assert a["duration"] > 7 and k

print("fonts installed:", fonts.install_missing(print), "missing:", [f["id"] for f in fonts.missing()])
o = dict(aspect="vertical", cutMode="mix", maxLength=0, ccPreset="auto", subtitleStyle="auto", effectAmount=0.8,
         bloom=0.5, subtitleLines=["씨러!", "이거랑 같이 먹어야지", "오늘도 귀여움 ♡"], userPresets=[], seed=3)
plan = planner.sanitize(planner.make(a, ref, None, clips, o), clips)
print(len(plan["segments"]), "segments,", len(plan["subtitles"]), "subtitles")

# 장면 요청: "1번 메모리, 2번 리버스 ..." → 효과 펼치기
n = len(plan["segments"])
req = "1번 장면 메모리, 2번 리버스, 3번 정지 화면, 4번 벨로시티, 5번 흑백에서 컬러로, 마지막 장면 글리치 그리고 깜빡임"
new_plan, msg = scenes.apply_request(plan, req)
print(msg)
assert new_plan is not None
plan = planner.sanitize(new_plan, clips)
pieces, extra = scenes.expand(plan, clips, os.path.join(tmp, "assets"))
print(len(pieces), "pieces,", len(extra), "helper files")
assert len(pieces) > n

out = os.path.join(tmp, "preview.mp4")
preview.render(plan, pieces, out)
info = media.probe(out)
print("preview:", info)
assert info["duration"] > 7 and info["hasAudio"]

root = os.path.join(tmp, "capcut drafts")
os.makedirs(root)
config.set("capcutRoot", root)
folder = capcut.write(plan, "에딧메이커 smoke v1", pieces)
with open(os.path.join(folder, "draft_content.json"), encoding="utf-8") as f:
    d = json.load(f)
print("capcut tracks:", [t["type"] for t in d["tracks"]], "files:", sorted(os.listdir(folder)))
config.set("capcutRoot", None)

jsx = ae.build_jsx(dict(plan, segments=pieces), os.path.join(tmp, "a.aep"), os.path.join(tmp, "a"), os.path.join(tmp, "d.json"))
assert "__PLAN__" not in jsx and all(ord(c) < 128 for c in jsx)
print("AE apps:", ae.installed())
print("SMOKE OK")
