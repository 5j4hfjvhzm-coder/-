"""에딧 메이커 (Windows) — 레퍼런스 edit 영상 + 내 클립 → CapCut / After Effects 프로젝트 자동 생성.
화면은 ui/index.html (pywebview, 윈도우 기본 WebView2)로 그려요."""
import base64
import datetime
import json
import os
import random
import subprocess
import sys
import threading
import traceback
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

import webview

from editmaker import ae, capcut, catalog, config, director, fonts, media, planner, preview, scenes


def resource(*parts):
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, *parts)


# ---------- 미리보기 영상을 화면에 보내는 작은 서버 (탐색 가능하게 Range 지원) ----------
class MediaHandler(SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.isfile(path) or "Range" not in self.headers:
            return super().send_head()
        size = os.path.getsize(path)
        rng = self.headers["Range"].replace("bytes=", "").split("-")
        start = int(rng[0] or 0)
        end = int(rng[1]) if len(rng) > 1 and rng[1] else size - 1
        end = min(end, size - 1)
        f = open(path, "rb")
        f.seek(start)
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.end_headers()
        self._remaining = end - start + 1
        return f

    def copyfile(self, source, outputfile):
        remaining = getattr(self, "_remaining", None)
        if remaining is None:
            return super().copyfile(source, outputfile)
        while remaining > 0:
            chunk = source.read(min(65536, remaining))
            if not chunk:
                break
            try:
                outputfile.write(chunk)
            except (ConnectionError, OSError):
                break
            remaining -= len(chunk)


def start_media_server(root):
    handler = lambda *a, **k: MediaHandler(*a, directory=root, **k)
    srv = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv.server_address[1]


class Api:
    def __init__(self):
        self._window = None
        self._root = config.work_root()
        self._port = start_media_server(self._root)
        self._reference = None
        self._analysis = None
        self._keyframes = []
        self._clips = []
        self._music = None
        self._presets = []
        self._versions = []
        self._current = None
        self._chat = []
        self._workdir = None
        self._seed = 7
        self._busy = False

    # ---------- 화면으로 알림 ----------
    def _emit(self, kind, **data):
        if self._window:
            payload = json.dumps({"kind": kind, **data}, ensure_ascii=False)
            try:
                self._window.evaluate_js(f"window.onEvent({payload})")
            except Exception:
                pass

    def _status(self, text, progress=None):
        self._emit("status", text=text, progress=progress, busy=self._busy)

    def _log(self, text):
        self._emit("log", text=datetime.datetime.now().strftime("[%H:%M:%S] ") + text)

    def _error(self, e):
        msg = str(e) or e.__class__.__name__
        self._log("❌ " + msg)
        self._emit("error", text=msg)

    def _bg(self, fn, *args):
        def run():
            try:
                fn(*args)
            except Exception as e:
                traceback.print_exc()
                self._busy = False
                self._error(e)
                self._status("문제가 생겼어요")
        threading.Thread(target=run, daemon=True).start()

    # ---------- 상태 ----------
    def state(self):
        ai = director.current_client()
        return {
            "output": config.get("output", "capcut" if capcut.is_available() or not ae.installed() else "ae"),
            "capcutRoot": capcut.root(), "capcutOK": capcut.is_available(),
            "aeApps": [a["name"] for a in ae.installed()], "aeSelected": config.get("aeApp", ""),
            "ai": ai[0] if ai else None, "aiProvider": config.get("aiProvider", "claude"),
            "hasClaude": bool(config.get_key("claude")), "hasGemini": bool(config.get_key("gemini")),
            "fontsMissing": [f["name"] for f in fonts.missing()],
            "styles": catalog.STYLES, "transitions": catalog.TRANSITIONS, "ccPresets": catalog.CC_PRESETS,
            "sceneFx": scenes.FX,
            "fonts": [{"id": f["id"], "name": f["name"]} for f in catalog.FONTS],
            "workRoot": self._root,
        }

    def snapshot(self):
        return {
            "reference": self._reference, "analysis": self._analysis_view(), "clips": self._clips, "music": self._music,
            "presets": self._presets, "versions": [self._version_view(v) for v in self._versions],
            "current": self._current, "chat": self._chat, "busy": self._busy,
        }

    def _analysis_view(self):
        a = self._analysis
        if not a:
            return None
        return {"summary": media.summary(a), "duration": a["duration"], "cuts": len(a["cuts"]), "bpm": a["bpm"],
                "energy": a["energy"], "color": planner.hex_hsb(a["hue"], max(a["saturation"], 0.35), max(a["brightness"], 0.6)),
                "frames": ["data:image/jpeg;base64," + base64.b64encode(k).decode() for k in self._keyframes]}

    def _version_view(self, v):
        rel = os.path.relpath(v["preview"], self._root).replace("\\", "/") if v.get("preview") else None
        return {"number": v["number"], "note": v["note"], "plan": v["plan"], "project": v["project"],
                "kind": v["kind"], "previewUrl": f"http://127.0.0.1:{self._port}/{rel}" if rel else None}

    # ---------- 재료 ----------
    def _dialog(self, multiple, types):
        try:
            r = self._window.create_file_dialog(webview.OPEN_DIALOG, allow_multiple=multiple, file_types=types)
        except Exception:
            # 파일 종류 필터가 문제면 필터 없이라도 창을 열어요
            r = self._window.create_file_dialog(webview.OPEN_DIALOG, allow_multiple=multiple)
        return list(r) if r else []

    def pick_reference(self):
        paths = self._dialog(False, ("영상 (*.mp4;*.mov;*.m4v;*.avi;*.mkv;*.webm)", "모든 파일 (*.*)"))
        if paths:
            self.set_reference(paths[0])
        return bool(paths)

    def set_reference(self, path):
        self._reference = path
        self._analysis, self._keyframes = None, []
        self._emit("snapshot", data=self.snapshot())
        self._busy = True
        self._bg(self._analyze)

    def _analyze(self):
        self._status("레퍼런스 분석 중…")
        a, k = media.analyze_reference(self._reference, lambda m: self._status(m))
        self._analysis, self._keyframes = a, k
        self._busy = False
        self._log("레퍼런스 분석: " + media.summary(a))
        self._status("분석 완료 · " + media.summary(a))
        self._emit("snapshot", data=self.snapshot())

    def pick_clips(self):
        exts = ";".join("*" + e for e in sorted(media.VIDEO_EXTS | media.IMAGE_EXTS))
        self.add_paths(self._dialog(True, (f"영상 사진 ({exts})", "모든 파일 (*.*)")))

    def pick_music(self):
        exts = ";".join("*" + e for e in sorted(media.AUDIO_EXTS | {".mp4", ".mov"}))
        p = self._dialog(False, (f"음악 ({exts})", "모든 파일 (*.*)"))
        if p:
            self._music = p[0]
            self._emit("snapshot", data=self.snapshot())

    def clear_music(self):
        self._music = None
        self._emit("snapshot", data=self.snapshot())

    def pick_presets(self):
        self.add_paths(self._dialog(True, ("After Effects 프리셋 (*.ffx)",)))

    def add_paths(self, paths):
        for p in paths or []:
            ext = os.path.splitext(p)[1].lower()
            if ext == ".ffx":
                if p not in self._presets:
                    self._presets.append(p)
            elif ext in media.AUDIO_EXTS:
                self._music = p
            elif not any(c["path"] == p for c in self._clips):
                try:
                    self._clips.append(media.probe(p))
                except Exception as e:
                    self._error(e)
        self._emit("snapshot", data=self.snapshot())

    def remove_clip(self, path):
        self._clips = [c for c in self._clips if c["path"] != path]
        self._emit("snapshot", data=self.snapshot())

    def remove_preset(self, path):
        self._presets = [p for p in self._presets if p != path]
        self._emit("snapshot", data=self.snapshot())

    def thumb(self, path, t=0.5, width=240):
        j = media.frame_jpeg(path, t, width)
        return "data:image/jpeg;base64," + base64.b64encode(j).decode() if j else None

    # ---------- 만들기 ----------
    def generate(self, opts, reshuffle=False):
        if self._busy or not self._analysis or not self._clips:
            return False
        if reshuffle:
            self._seed = random.randint(1, 10 ** 9)
        self._busy = True
        self._bg(self._generate, opts)
        return True

    def _generate(self, opts):
        o = dict(opts)
        o["seed"] = self._seed
        o["subtitleLines"] = (opts.get("subtitles") or "").splitlines()
        o["userPresets"] = list(self._presets)
        plan = planner.sanitize(planner.make(self._analysis, self._reference, self._music, self._clips, o), self._clips)
        note = "첫 번째 버전"
        if opts.get("useAI") and director.current_client():
            self._status("AI가 레퍼런스를 보고 자막 스타일·효과를 고르는 중…")
            try:
                msg, plan = director.direct(plan, self._analysis, self._clips, self._keyframes)
                note = msg
                self._chat.append({"role": "assistant", "text": "🎬 " + msg})
                self._log("AI 감독: " + msg)
            except Exception as e:
                self._log("AI 감독을 건너뛰었어요: " + str(e))
        self._build(plan, note)

    def _ensure_workdir(self):
        if not self._workdir:
            self._workdir = os.path.join(self._root, "edit-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
            os.makedirs(self._workdir, exist_ok=True)
        return self._workdir

    def _build(self, plan, note):
        self._busy = True
        out = config.get("output", "capcut" if capcut.is_available() or not ae.installed() else "ae")
        if fonts.missing():
            self._status("자막 폰트 준비 중…")
            n = fonts.install_missing(lambda m: self._status(m))
            if n:
                self._log(f"폰트 {n}개 설치 완료")
        d = self._ensure_workdir()
        number = max([v["number"] for v in self._versions] or [0]) + 1
        base = os.path.join(d, f"edit_v{number}")
        with open(base + ".plan.json", "w", encoding="utf-8") as f:
            json.dump(plan, f, ensure_ascii=False, indent=1)

        # 장면 효과(리버스·정지 화면·벨로시티 등)를 실제 재생 조각으로 펼쳐요
        if any(s.get("effects") for s in plan["segments"]):
            self._status("장면 효과 준비 중… (리버스·정지 화면 파일 만들기)")
        pieces, _extra = scenes.expand(plan, self._clips, os.path.join(d, "assets"))

        if out == "ae":
            apps = ae.installed()
            app = next((a for a in apps if a["name"] == config.get("aeApp")), apps[0] if apps else None)
            if not app:
                raise RuntimeError("After Effects를 찾지 못했어요. 설정에서 'CapCut'으로 바꾸거나 AE를 설치해 주세요.")
            self._status(f"After Effects에서 v{number} 만드는 중… (AE 창이 움직여도 놀라지 마세요)")
            with open(base + ".jsx", "w", encoding="utf-8") as f:
                f.write(ae.build_jsx(dict(plan, segments=pieces), base + ".aep", base, base + ".done.json"))
            r = ae.run_script(app, base + ".jsx", base + ".done.json")
            for w in r.get("warnings", []):
                self._log("⚠️ " + w)
            project, kind = base + ".aep", "ae"
            self._log("AE 프로젝트 저장: " + os.path.basename(project))
        else:
            self._status(f"CapCut 프로젝트 v{number} 만드는 중…")
            name = f"에딧메이커 {os.path.basename(d).replace('edit-', '')} v{number}"
            project, kind = capcut.write(plan, name, pieces), "capcut"
            self._log("CapCut 프로젝트 저장: " + name)

        self._status("미리보기 영상 만드는 중… (1분 정도 걸릴 수 있어요)")
        prev = base + ".preview.mp4"
        try:
            preview.render(plan, pieces, prev)
        except Exception as e:
            self._log("⚠️ 미리보기를 못 만들었어요: " + str(e)[:300])
            prev = None
        self._versions.append({"number": number, "plan": plan, "note": note, "project": project, "kind": kind,
                              "preview": prev})
        self._current = number
        self._busy = False
        todo = scenes.todo_list(plan)
        if todo:
            self._chat.append({"role": "assistant", "text": "📝 CapCut에서 직접 넣어 주세요:\n" + "\n".join("• " + t for t in todo)})
        where = "CapCut 홈 화면에 프로젝트가 생겼어요" if kind == "capcut" else "AE 프로젝트를 저장했어요"
        self._status(f"v{number} 완성! {where}. 보고 고칠 부분을 말해 주세요.")
        self._emit("snapshot", data=self.snapshot())
        self._emit("built", number=number)

    # ---------- 검토 · 수정 ----------
    def revise(self, text, plan=None, auto=True):
        text = (text or "").strip()
        if not text or self._busy:
            return False
        v = self._version(self._current)
        base = plan or (v and v["plan"])
        if not base:
            return False
        self._chat.append({"role": "user", "text": text})
        # 1) "3번 장면 리버스" 같은 장면 요청은 AI 없이 바로 반영
        new_plan, msg = scenes.apply_request(base, text)
        if new_plan is not None:
            new_plan = planner.sanitize(new_plan, self._clips)
            self._chat.append({"role": "assistant", "text": "✅ " + msg})
            if auto:
                self._busy = True
                self._emit("snapshot", data=self.snapshot())
                self._bg(self._build, new_plan, text)
            else:
                self._emit("snapshot", data=self.snapshot())
                self._emit("draft", plan=new_plan)
            return True
        # 2) 그 밖의 요청은 AI가 처리
        if not director.current_client():
            hint = msg or ("이해한 장면 요청이 없어요. 예) \"3번 장면 리버스\", \"5~7번 흑백\", \"10초에 플래시\", "
                           "\"마지막 장면 정지 화면\". 자유로운 문장은 설정에서 AI 키를 넣으면 돼요.")
            self._chat.append({"role": "system", "text": hint})
            self._emit("snapshot", data=self.snapshot())
            return False
        self._busy = True
        self._emit("snapshot", data=self.snapshot())
        self._bg(self._revise, text, base, auto)
        return True

    def _revise(self, text, base, auto):
        self._status("AI가 수정 중…")
        try:
            msg, plan = director.revise(base, text, self._chat, self._analysis, self._clips)
        except Exception as e:
            self._busy = False
            self._chat.append({"role": "system", "text": str(e)})
            self._status("")
            self._emit("snapshot", data=self.snapshot())
            return
        self._chat.append({"role": "assistant", "text": msg})
        self._emit("snapshot", data=self.snapshot())
        if auto:
            self._build(plan, text)
        else:
            self._busy = False
            self._emit("draft", plan=plan)
            self._status("수정안 준비됨 · '바꾼 내용으로 다시 만들기'를 누르면 반영돼요")

    def rebuild(self, plan):
        if self._busy:
            return False
        self._busy = True
        self._bg(lambda: self._build(planner.sanitize(plan, self._clips), "직접 수정"))
        return True

    def select_version(self, number):
        self._current = number
        self._emit("snapshot", data=self.snapshot())

    def _version(self, number):
        return next((v for v in self._versions if v["number"] == number), None)

    def open_project(self, number):
        v = self._version(number)
        if not v:
            return
        if v["kind"] == "capcut":
            if not capcut.open_capcut():
                self._emit("error", text="CapCut을 찾지 못했어요. CapCut을 직접 열어 주세요.")
        else:
            apps = ae.installed()
            ae.open_project(apps[0] if apps else None, v["project"])

    def reveal(self, number):
        v = self._version(number)
        if not v:
            return
        target = v.get("preview") or v["project"]
        if sys.platform == "win32":
            subprocess.Popen(["explorer", "/select,", os.path.normpath(target)])
        elif sys.platform == "darwin":
            subprocess.Popen(["open", "-R", target])

    # ---------- 설정 ----------
    def save_settings(self, s):
        for k in ("output", "aeApp", "aiProvider"):
            if k in s:
                config.set(k, s[k])
        if "capcutRoot" in s:
            config.set("capcutRoot", s["capcutRoot"] or None)
        if s.get("claudeKey") is not None:
            config.set_key("claude", s["claudeKey"])
        if s.get("geminiKey") is not None:
            config.set_key("gemini", s["geminiKey"])
        return self.state()

    def pick_capcut_root(self):
        r = self._window.create_file_dialog(webview.FOLDER_DIALOG, directory=os.path.dirname(capcut.default_root()))
        if r:
            config.set("capcutRoot", r[0])
        return self.state()

    def test_ai(self):
        try:
            r = director.complete("짧게 답해.", "연결 테스트야. '연결 성공'이라고만 답해.")
            c = director.current_client()
            return {"ok": True, "text": f"✅ {'Claude' if c[0] == 'claude' else 'Gemini'}: {r[:40]}"}
        except Exception as e:
            return {"ok": False, "text": "❌ " + str(e)}

    def install_fonts(self):
        self._bg(lambda: (self._status("폰트 받는 중…"), self._status(f"폰트 {fonts.install_missing(self._status)}개 설치 완료")))


def main():
    # 창 모드 exe에서는 콘솔이 없어서 print가 실패하지 않게 막아요
    for name in ("stdout", "stderr"):
        if getattr(sys, name) is None:
            setattr(sys, name, open(os.devnull, "w", encoding="utf-8"))
    api = Api()
    w = webview.create_window("에딧 메이커", resource("ui", "index.html"), js_api=api, width=1320, height=860,
                              min_size=(1100, 720), background_color="#09060F")
    api._window = w
    webview.start(debug=os.environ.get("EDITMAKER_DEBUG") == "1")


if __name__ == "__main__":
    main()
