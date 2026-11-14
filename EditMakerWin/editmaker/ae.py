"""After Effects(윈도우/맥) 찾기, JSX 스크립트 실행, aerender 렌더링"""
import glob
import json
import os
import re
import subprocess
import sys
import time

_NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0
TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ae_template.jsx")


def installed():
    """[{name, exe, aerender}] 최신 버전 먼저"""
    out = []
    if sys.platform == "win32":
        for pf in {os.environ.get("ProgramFiles", r"C:\Program Files"), r"C:\Program Files"}:
            for d in glob.glob(os.path.join(pf, "Adobe", "Adobe After Effects*")):
                exe = os.path.join(d, "Support Files", "AfterFX.exe")
                if os.path.exists(exe):
                    out.append({"name": os.path.basename(d), "exe": exe,
                                "aerender": os.path.join(d, "Support Files", "aerender.exe")})
    elif sys.platform == "darwin":
        for d in glob.glob("/Applications/Adobe After Effects*"):
            app = os.path.join(d, os.path.basename(d) + ".app")
            if os.path.exists(app):
                out.append({"name": os.path.basename(d), "exe": app, "aerender": os.path.join(d, "aerender")})
    return sorted(out, key=lambda a: a["name"], reverse=True)


def ascii_escape(s):
    """ExtendScript가 인코딩을 잘못 읽어도 한글이 깨지지 않게 \\uXXXX 로 바꿔요."""
    out = []
    for ch in s:
        if ord(ch) < 128:
            out.append(ch)
        else:
            b = ch.encode("utf-16-be")
            for i in range(0, len(b), 2):
                out.append("\\u%04x" % int.from_bytes(b[i:i + 2], "big"))
    return "".join(out)


def build_jsx(plan, aep, render_base, done):
    with open(TEMPLATE, encoding="utf-8") as f:
        tpl = f.read()
    out = {"aep": aep.replace("\\", "/"), "renderBase": render_base.replace("\\", "/"), "done": done.replace("\\", "/")}
    plan = json.loads(json.dumps(plan))
    # ExtendScript File()은 / 경로도 잘 읽어요
    for s in plan["segments"]:
        s["clip"] = s["clip"].replace("\\", "/")
    if plan.get("music"):
        plan["music"]["path"] = plan["music"]["path"].replace("\\", "/")
    plan["cc"]["userPresets"] = [p.replace("\\", "/") for p in plan["cc"].get("userPresets", [])]
    s = tpl.replace("__PLAN__", json.dumps(plan, ensure_ascii=False)).replace("__OUT__", json.dumps(out))
    return ascii_escape(s)


def run_script(app, jsx_path, done_path, timeout=3600):
    if os.path.exists(done_path):
        os.remove(done_path)
    if sys.platform == "win32":
        subprocess.Popen([app["exe"], "-r", jsx_path], creationflags=_NO_WINDOW)
    else:
        js = "$.evalFile(new File('%s'));" % jsx_path.replace("\\", "\\\\").replace("'", "\\'")
        name = os.path.splitext(os.path.basename(app["exe"]))[0]
        script = ('with timeout of 3600 seconds\ntell application "%s"\nactivate\nDoScript "%s"\nend tell\nend timeout'
                  % (name, js.replace("\\", "\\\\").replace('"', '\\"')))
        subprocess.Popen(["osascript", "-e", script])
    t0 = time.time()
    while time.time() - t0 < timeout:
        if os.path.exists(done_path):
            time.sleep(0.3)
            try:
                with open(done_path, encoding="utf-8") as f:
                    r = json.load(f)
            except Exception:
                continue
            if not r.get("ok"):
                raise RuntimeError("After Effects 스크립트 실패: " + r.get("message", ""))
            return r
        time.sleep(0.5)
    raise RuntimeError("After Effects가 결과를 남기지 않았어요. AE 환경 설정 › 스크립팅 및 표현식 › "
                       "'스크립트가 파일을 쓰고 네트워크에 액세스하도록 허용'을 켜 주세요.")


def render(app, project, total_frames, progress=lambda p: None):
    if not os.path.exists(app["aerender"]):
        raise RuntimeError("aerender를 찾지 못했어요: " + app["aerender"])
    p = subprocess.Popen([app["aerender"], "-project", project], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         creationflags=_NO_WINDOW)
    tail = []
    for raw in p.stdout:
        line = raw.decode("utf-8", "replace")
        tail = (tail + [line])[-5:]
        m = re.search(r"PROGRESS:.*\((\d+)\)", line)
        if m:
            progress(min(int(m.group(1)) / max(total_frames, 1), 1))
    if p.wait() != 0:
        raise RuntimeError("미리보기 렌더링 실패: " + "".join(tail))


def open_project(app, project):
    if sys.platform == "win32":
        subprocess.Popen([app["exe"], project] if app else ["cmd", "/c", "start", "", project], creationflags=_NO_WINDOW)
    else:
        subprocess.Popen(["open", "-a", app["exe"], project] if app else ["open", project])
