"""설정 저장 (%APPDATA%\\EditMaker\\config.json). API 키는 윈도우 자격 증명 관리자(keyring)에 저장해요."""
import json
import os
import sys


def app_dir():
    base = os.environ.get("APPDATA") or os.path.join(os.path.expanduser("~"), ".config")
    d = os.path.join(base, "EditMaker")
    os.makedirs(d, exist_ok=True)
    return d


def work_root():
    """결과물 저장 위치: 동영상(Videos)\\EditMaker"""
    home = os.path.expanduser("~")
    videos = os.path.join(home, "Videos")
    if not os.path.isdir(videos):
        videos = os.path.join(home, "Movies") if sys.platform == "darwin" else home
    d = os.path.join(videos, "EditMaker")
    os.makedirs(d, exist_ok=True)
    return d


_PATH = None


def _path():
    global _PATH
    if _PATH is None:
        _PATH = os.path.join(app_dir(), "config.json")
    return _PATH


def load():
    try:
        with open(_path(), encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def get(key, default=None):
    return load().get(key, default)


def set(key, value):
    data = load()
    if value is None:
        data.pop(key, None)
    else:
        data[key] = value
    with open(_path(), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def get_key(provider):
    try:
        import keyring
        v = keyring.get_password("EditMaker", provider)
        if v:
            return v
    except Exception:
        pass
    return load().get("key_" + provider)


def set_key(provider, value):
    value = (value or "").strip()
    try:
        import keyring
        if value:
            keyring.set_password("EditMaker", provider, value)
        else:
            try:
                keyring.delete_password("EditMaker", provider)
            except Exception:
                pass
        set("key_" + provider, None)
        return
    except Exception:
        pass
    set("key_" + provider, value or None)
