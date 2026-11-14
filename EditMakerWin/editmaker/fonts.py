"""Google Fonts 무료 한글 폰트를 받아서 내 계정용으로 설치해요. (관리자 권한 필요 없음)"""
import os
import sys
import urllib.request

from . import catalog


def folder():
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), "AppData", "Local")
        return os.path.join(base, "Microsoft", "Windows", "Fonts")
    if sys.platform == "darwin":
        return os.path.join(os.path.expanduser("~"), "Library", "Fonts")
    return os.path.join(os.path.expanduser("~"), ".local", "share", "fonts")


def installed_path(ps_name):
    fn = catalog.font_file(ps_name) if ps_name else None
    if not fn:
        return None
    p = os.path.join(folder(), fn)
    if os.path.exists(p):
        return p
    if sys.platform == "win32":
        sp = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", fn)
        if os.path.exists(sp):
            return sp
    return None


def missing():
    return [f for f in catalog.FONTS if not installed_path(f["id"])]


def _register_windows(path, family):
    """윈도우 10(1809)+ 사용자 폰트 등록 + 실행 중인 앱에 알림"""
    try:
        import winreg
        key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows NT\CurrentVersion\Fonts")
        winreg.SetValueEx(key, f"{family} (TrueType)", 0, winreg.REG_SZ, path)
        winreg.CloseKey(key)
        import ctypes
        ctypes.windll.gdi32.AddFontResourceW(path)
        ctypes.windll.user32.SendMessageTimeoutW(0xFFFF, 0x001D, 0, 0, 0x0002, 1000, None)  # WM_FONTCHANGE
    except Exception:
        pass


def install_missing(progress=lambda m: None):
    os.makedirs(folder(), exist_ok=True)
    n = 0
    for f in missing():
        progress(f"폰트 받는 중… {f['name']}")
        try:
            with urllib.request.urlopen(f["url"], timeout=60) as r:
                data = r.read()
        except Exception:
            continue
        dest = os.path.join(folder(), f["file"])
        with open(dest, "wb") as out:
            out.write(data)
        if sys.platform == "win32":
            _register_windows(dest, f["id"])
        n += 1
    return n
