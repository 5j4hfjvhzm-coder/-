"""CapCut(해외판) 데스크톱 프로젝트 폴더를 직접 만들어요.
CapCut에 공식 API가 없어서 데스크톱 앱이 쓰는 draft_content.json / draft_meta_info.json 형식을 따라 써요.
(비공식 형식이라 CapCut 업데이트 후 안 열리면 형식을 다시 맞춰야 할 수 있어요.)"""
import json
import os
import shutil
import subprocess
import sys
import time
import uuid

from . import catalog, fonts, media, planner


def default_root():
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), "AppData", "Local")
        return os.path.join(base, "CapCut", "User Data", "Projects", "com.lveditor.draft")
    return os.path.join(os.path.expanduser("~"), "Movies", "CapCut", "User Data", "Projects", "com.lveditor.draft")


def root():
    from . import config
    return config.get("capcutRoot") or default_root()


def is_available():
    return os.path.isdir(root())


def open_capcut():
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA", "")
        for p in [os.path.join(base, "CapCut", "Apps", "CapCut.exe"),
                  r"C:\Program Files\CapCut\CapCut.exe", r"C:\Program Files (x86)\CapCut\CapCut.exe"]:
            if os.path.exists(p):
                subprocess.Popen([p], creationflags=0x08000000)
                return True
        return False
    subprocess.Popen(["open", "-a", "CapCut"])
    return True


def us(s):
    return int(round(float(s) * 1_000_000))


def nid():
    return str(uuid.uuid4()).upper()


MATERIAL_CATEGORIES = [
    "ai_translates", "audio_balances", "audio_effects", "audio_fades", "audio_track_indexes", "audios", "beats",
    "canvases", "chromas", "color_curves", "digital_humans", "drafts", "effects", "flowers", "green_screens",
    "handwrites", "hsl", "images", "log_color_wheels", "loudnesses", "manual_deformations", "masks",
    "material_animations", "material_colors", "multi_language_refs", "placeholders", "plugin_effects",
    "primary_color_wheels", "realtime_denoises", "shapes", "smart_crops", "smart_relights",
    "sound_channel_mappings", "speeds", "stickers", "tail_leaders", "text_templates", "texts", "time_marks",
    "transitions", "video_effects", "video_trackings", "videos", "vocal_beautifys", "vocal_separations",
]

TIMELINE_CONFIG = {
    "adjust_max_index": 1, "attachment_info": [], "combination_max_index": 1, "export_range": None,
    "extract_audio_last_index": 1, "lyrics_recognition_id": "", "lyrics_sync": True, "lyrics_taskinfo": [],
    "maintrack_adsorb": True, "material_save_mode": 0, "multi_language_current": "none", "multi_language_list": [],
    "multi_language_main": "none", "multi_language_mode": "none", "original_sound_last_index": 1,
    "record_audio_last_index": 1, "sticker_max_index": 1, "subtitle_recognition_id": "", "subtitle_sync": True,
    "subtitle_taskinfo": [], "system_font_list": [], "video_mute": False, "zoom_info_params": None,
}


def seed_info():
    """CapCut이 직접 만든 프로젝트가 있으면 그 버전 정보를 빌려와요. (버전 불일치로 거부되는 걸 줄여요)"""
    seed = {
        "platform": {"app_id": 359289, "app_source": "cc", "app_version": "5.9.0", "device_id": "", "hard_disk_id": "",
                     "mac_address": "", "os": "windows" if sys.platform == "win32" else "mac", "os_version": "10.0"},
        "new_version": "110.0.0", "version": 360000, "meta_version": "110.0.0",
    }
    r = root()
    try:
        dirs = sorted((os.path.join(r, d) for d in os.listdir(r)), key=lambda d: os.path.getmtime(d), reverse=True)
    except OSError:
        return seed
    for d in dirs:
        if os.path.basename(d).startswith("에딧메이커"):
            continue
        try:
            with open(os.path.join(d, "draft_content.json"), encoding="utf-8") as f:
                obj = json.load(f)
        except Exception:
            continue
        if isinstance(obj.get("platform"), dict):
            seed["platform"] = obj["platform"]
        if obj.get("new_version"):
            seed["new_version"] = obj["new_version"]
        if "version" in obj:
            seed["version"] = obj["version"]
        try:
            with open(os.path.join(d, "draft_meta_info.json"), encoding="utf-8") as f:
                mv = json.load(f).get("version")
            if isinstance(mv, str):
                seed["meta_version"] = mv
        except Exception:
            pass
        break
    return seed


def _kf_list(prop, keys, length=None):
    if not keys:
        return None
    return {
        "id": nid(),
        "keyframe_list": [{
            "curveType": "Line", "graphID": "", "id": nid(),
            "left_control": {"x": 0.0, "y": 0.0}, "right_control": {"x": 0.0, "y": 0.0},
            "time_offset": us(max(0, min(t, length)) if length is not None else max(0, t)), "values": [float(v)],
        } for t, v in keys],
        "material_id": "", "property_type": prop,
    }


CC_ADJUST = {  # 채도, 대비, 밝기 (-1~1)
    "vivid_pop": (0.3, 0.2, 0.02), "soft_film": (-0.15, -0.15, 0.06), "cool_night": (0.05, 0.15, -0.05),
    "clean": (0.1, 0.05, 0.02), "dreamy_glow": (0.12, -0.08, 0.06),
}


def motion_keyframes(seg, base, cc):
    length = seg["end"] - seg["start"]
    t_in = min(0.25, length * 0.5)
    end_scale = base * (1 + seg["push"])
    scale, pos_x, pos_y, rot, alpha, bright = [], [], [], [], [], []
    tr = seg["transition"]
    if tr == "zoom_punch":
        t1 = min(0.22, length * 0.6)
        scale = [(0, base * 1.22), (t1, base * 1.02), (length, end_scale)]
    elif tr == "radial_blur":
        scale = [(0, base * 1.35), (t_in, base), (length, end_scale)]
        rot = [(0, -6), (t_in, 0)]
    elif tr == "whip":
        pos_x = [(0, 0.7), (t_in, 0)]
    elif tr == "blur_in":
        alpha = [(0, 0.2), (t_in, 1)]
    elif tr == "flash":
        bright = [(0, 1), (min(0.16, length * 0.5), 0)]
    if not scale and seg["push"] > 0:
        scale = [(0, base), (length, end_scale)]
    if seg["shake"]:
        end = min(length, 0.5)
        xs, ys, t, i = [], [], 0.0, 0
        while t < end:
            k = 1 - t / end
            xs.append((t, (1 if i % 2 == 0 else -1) * 0.04 * k))
            ys.append((t, (-1 if i % 3 == 0 else 1) * 0.03 * k))
            t += 1 / 24
            i += 1
        xs.append((end, 0))
        ys.append((end, 0))
        pos_x = pos_x or xs
        pos_y = ys
    sat, con, bri = CC_ADJUST.get(cc["preset"], CC_ADJUST["dreamy_glow"])
    k = cc["intensity"]
    lists = [
        _kf_list("KFTypeScaleX", scale, length), _kf_list("KFTypeScaleY", scale, length),
        _kf_list("KFTypePositionX", pos_x, length), _kf_list("KFTypePositionY", pos_y, length),
        _kf_list("KFTypeRotation", rot, length), _kf_list("KFTypeAlpha", alpha, length),
        _kf_list("KFTypeSaturation", [(0, sat * k)], length), _kf_list("KFTypeContrast", [(0, con * k)], length),
        _kf_list("KFTypeBrightness", [(t, v + bri * k) for t, v in bright] if bright else [(0, bri * k)], length),
    ]
    return [l for l in lists if l]


def text_keyframes(sub):
    length = sub["end"] - sub["start"]
    x, y = (sub["x"] - 0.5) * 2, (0.5 - sub["y"]) * 2
    e = lambda t: min(t, length)
    scale, pos_x, pos_y, rot = [], [], [], []
    st = sub["style"]
    if st == "impact_pop":
        scale = [(0, 0.01), (e(0.12), 1.24), (e(0.22), 1)]
    elif st == "neon_glow":
        scale = [(0, 0.92), (e(0.05), 1.04), (e(0.09), 0.97), (e(0.2), 1)]
    elif st == "soft_blur":
        scale = [(0, 1.15), (e(0.4), 1)]
    elif st == "cute_bounce":
        pos_y = [(0, y - 0.07), (e(0.15), y + 0.02), (e(0.26), y - 0.006), (e(0.34), y)]
        scale = [(0, 0.7), (e(0.15), 1.06), (e(0.26), 1)]
        rot = [(0, -6), (e(0.15), 3), (e(0.3), 0)]
    elif st == "glitch":
        t, i = 0.0, 0
        while t < min(0.45, length):
            pos_x.append((t, x + (0.04 if i % 2 == 0 else -0.035)))
            t += 1 / 14
            i += 1
        pos_x.append((min(0.45, length), x))
    elif st in ("minimal", "light_sweep", "typewriter"):
        pos_y = [(0, y - 0.025), (e(0.35), y)]
        scale = [(0, 0.96), (e(0.35), 1)]
    lists = [_kf_list("KFTypeScaleX", scale), _kf_list("KFTypeScaleY", scale), _kf_list("KFTypePositionX", pos_x),
             _kf_list("KFTypePositionY", pos_y), _kf_list("KFTypeRotation", rot)]
    return [l for l in lists if l]


def companions(add, video, speed):
    ids = []
    sp = nid()
    add("speeds", {"curve_speed": None, "id": sp, "mode": 0, "speed": speed, "type": "speed"})
    ids.append(sp)
    if video:
        cv = nid()
        add("canvases", {"album_image": "", "blur": 0, "color": "", "id": cv, "image": "", "image_id": "",
                         "image_name": "", "source_platform": 0, "team_id": "", "type": "canvas_color"})
        ids.append(cv)
    sc = nid()
    add("sound_channel_mappings", {"audio_channel_mapping": 0, "id": sc, "is_config_open": False, "type": ""})
    ids.append(sc)
    vs = nid()
    add("vocal_separations", {"choice": 0, "id": vs, "production_path": "", "removed_sounds": [],
                              "time_range": None, "type": "vocal_separation"})
    ids.append(vs)
    return ids


def clip_obj(scale, x, y):
    return {"alpha": 1, "flip": {"horizontal": False, "vertical": False}, "rotation": 0,
            "scale": {"x": scale, "y": scale}, "transform": {"x": x, "y": y}}


def base_segment(material_id, refs, start, length):
    return {
        "caption_info": None, "cartoon": False, "clip": None, "common_keyframes": [], "enable_adjust": False,
        "enable_color_correct_adjust": False, "enable_color_curves": True, "enable_color_match_adjust": False,
        "enable_color_wheels": True, "enable_hsl": False, "enable_lut": False, "enable_smart_color_adjust": False,
        "extra_material_refs": refs, "group_id": "", "hdr_settings": None, "id": nid(), "intensifies_audio": False,
        "is_placeholder": False, "is_tone_modify": False, "keyframe_refs": [], "last_nonzero_volume": 1,
        "material_id": material_id, "render_index": 0,
        "responsive_layout": {"enable": False, "horizontal_pos_layout": 0, "size_layout": 0, "target_follow": "",
                              "vertical_pos_layout": 0},
        "reverse": False, "source_timerange": None, "speed": 1,
        "target_timerange": {"start": us(start), "duration": us(length)},
        "template_id": "", "template_scene": "default", "track_attribute": 0, "track_render_index": 0,
        "uniform_scale": None, "visible": True, "volume": 1,
    }


def video_material(mid, c):
    return {
        "aigc_type": "none", "audio_fade": None, "cartoon_path": "", "category_id": "", "category_name": "local",
        "check_flag": 63487,
        "crop": {"lower_left_x": 0, "lower_left_y": 1, "lower_right_x": 1, "lower_right_y": 1,
                 "upper_left_x": 0, "upper_left_y": 0, "upper_right_x": 1, "upper_right_y": 0},
        "crop_ratio": "free", "crop_scale": 1, "duration": us(10800 if c["isStill"] else c["duration"]),
        "extra_type_option": 0, "formula_id": "", "freeze": None, "has_audio": c["hasAudio"], "height": int(c["height"]),
        "id": mid, "intensifies_audio_path": "", "intensifies_path": "", "is_ai_generate_content": False,
        "is_copyright": False, "is_text_edit_overdub": False, "is_unified_beauty_mode": False, "local_id": "",
        "local_material_id": "", "material_id": "", "material_name": c["name"], "material_url": "",
        "matting": {"flag": 0, "has_use_quick_brush": False, "has_use_quick_eraser": False, "interactiveTime": [],
                    "path": "", "strokes": []},
        "media_path": "", "object_locked": None, "origin_material_id": "", "path": c["path"], "picture_from": "none",
        "picture_set_category_id": "", "picture_set_category_name": "", "request_id": "",
        "reverse_intensifies_path": "", "reverse_path": "", "smart_motion": None, "source": 0, "source_platform": 0,
        "stable": {"matrix_path": "", "stable_level": 0, "time_range": {"duration": 0, "start": 0}},
        "team_id": "", "type": "photo" if c["isStill"] else "video",
        "video_algorithm": {"algorithms": [], "complement_frame_config": None, "deflicker": None,
                            "gameplay_configs": [], "motion_blur_config": None, "noise_reduction": None, "path": "",
                            "quality_enhance": None, "time_range": None},
        "width": int(c["width"]),
    }


def audio_material(mid, path, name, duration):
    return {
        "app_id": 0, "category_id": "", "category_name": "local", "check_flag": 1, "copyright_limit_type": "none",
        "duration": us(duration), "effect_id": "", "formula_id": "", "id": mid, "intensifies_path": "",
        "is_ai_clone_tone": False, "is_text_edit_overdub": False, "local_material_id": "", "music_id": nid(),
        "name": name, "path": path, "query": "", "request_id": "", "resource_id": "", "search_id": "",
        "source_from": "", "source_platform": 0, "team_id": "", "text_id": "", "tone_category_id": "",
        "tone_category_name": "", "tone_effect_id": "", "tone_effect_name": "", "tone_platform": "",
        "tone_second_category_id": "", "tone_second_category_name": "", "tone_speaker": "", "tone_type": "",
        "type": "extract_music", "video_id": "", "wave_points": [],
    }


def rgb(hexs):
    return list(planner.hex_rgb(hexs) or (1, 1, 1))


STROKE = {"impact_pop": 0.12, "cute_bounce": 0.1, "neon_glow": 0.05, "typewriter": 0.03, "light_sweep": 0.03}
GLOW = {"neon_glow", "soft_blur", "light_sweep", "glitch", "typewriter"}


def text_material(mid, sub, canvas_w):
    size = round(sub["size"] / canvas_w * 160, 1)
    sw = STROKE.get(sub["style"], 0)
    style = {
        "fill": {"alpha": 1.0, "content": {"render_type": "solid", "solid": {"alpha": 1.0, "color": rgb(sub["color"])}}},
        "range": [0, len(sub["text"].encode("utf-16-le")) // 2],
        "size": size, "bold": False, "italic": False, "underline": False,
        "strokes": [{"content": {"solid": {"alpha": 1.0, "color": rgb(sub["accent"])}}, "width": sw}] if sw else [],
    }
    font_path = fonts.installed_path(sub.get("font"))
    if font_path:
        style["font"] = {"id": "", "path": font_path}
    has_shadow = sub["style"] != "minimal"
    if has_shadow:
        glow = sub["style"] in GLOW
        style["shadows"] = [{"diffuse": 0.25 if glow else 0.05, "alpha": 0.9 if glow else 0.6,
                             "distance": 0.0 if glow else 5.0,
                             "content": {"solid": {"color": rgb(sub["accent"]) if glow else [0.0, 0.0, 0.0]}},
                             "angle": -45.0}]
    flag = 7 | (8 if sw else 0) | (32 if has_shadow else 0)
    return {
        "add_type": 0, "alignment": 1, "background_alpha": 1, "background_color": "", "background_height": 0.14,
        "background_horizontal_offset": 0, "background_round_radius": 0, "background_style": 0,
        "background_vertical_offset": 0, "background_width": 0.14, "base_content": "", "bold_width": 0,
        "border_alpha": 1, "border_color": sub["accent"] if sw else "", "border_width": sw, "check_flag": flag,
        "combo_info": {"text_templates": []},
        "content": json.dumps({"styles": [style], "text": sub["text"]}, ensure_ascii=False),
        "fixed_height": -1, "fixed_width": -1, "font_category_id": "", "font_category_name": "", "font_id": "",
        "font_name": "", "font_path": font_path or "", "font_resource_id": "", "font_size": size,
        "font_source_platform": 0, "font_team_id": "", "font_title": "none", "font_url": "", "fonts": [],
        "force_apply_line_max_width": False, "global_alpha": 1, "group_id": "", "has_shadow": has_shadow, "id": mid,
        "initial_scale": 1, "inner_padding": -1, "is_rich_text": False, "italic_degree": 0, "ktv_color": "",
        "language": "", "layer_weight": 1, "letter_spacing": 0.15 if sub["style"] == "minimal" else 0,
        "line_feed": 1, "line_max_width": 0.82, "line_spacing": 0.02, "multi_language_current": "none", "name": "",
        "original_size": [], "preset_category": "", "preset_category_id": "", "preset_has_set_alignment": False,
        "preset_id": "", "preset_index": 0, "preset_name": "", "recognize_task_id": "", "recognize_type": 0,
        "relevance_segment": [], "shadow_alpha": 0.9, "shadow_angle": -45,
        "shadow_color": sub["accent"] if has_shadow else "", "shadow_distance": 5,
        "shadow_point": {"x": 0.6363961030678928, "y": -0.6363961030678928}, "shadow_smoothing": 0.45,
        "shape_clip_x": False, "shape_clip_y": False, "style_name": "", "sub_type": 0, "subtitle_keywords": None,
        "text_alpha": 1, "text_color": sub["color"], "text_curve": None, "text_preset_resource_id": "",
        "text_size": 30, "text_to_audio_ids": [], "tts_auto_update": False, "type": "text", "typesetting": 0,
        "underline": False, "underline_offset": 0.22, "underline_width": 0.05, "use_effect_default_color": True,
        "words": {"end_time": [], "start_time": [], "text": []},
    }


def track(kind, segments):
    return {"attribute": 0, "flag": 0, "id": nid(), "is_default_name": True, "name": "", "segments": segments, "type": kind}


def write(plan, name, clips):
    r = root()
    if not os.path.isdir(r):
        raise RuntimeError(f"CapCut 프로젝트 폴더를 찾지 못했어요 ({r}). CapCut을 한 번 열어 아무 프로젝트나 만든 뒤 "
                           "다시 시도하거나, 설정에서 폴더를 골라 주세요.")
    folder = os.path.join(r, name)
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    seed = seed_info()
    materials = {k: [] for k in MATERIAL_CATEGORIES}
    add = lambda cat, m: materials.setdefault(cat, []).append(m)

    by_path = {c["path"]: c for c in clips}
    mids, media_entries = {}, []
    for path in sorted({s["clip"] for s in plan["segments"]}):
        c = by_path.get(path)
        if not c:
            continue
        mids[path] = nid()
        add("videos", video_material(mids[path], c))
        media_entries.append((path, c["name"], 10800 if c["isStill"] else c["duration"], c["width"], c["height"],
                              "photo" if c["isStill"] else "video"))

    W, H = float(plan["width"]), float(plan["height"])
    vsegs = []
    for seg in plan["segments"]:
        c = by_path.get(seg["clip"])
        if not c or seg["clip"] not in mids:
            continue
        speed = 1.0 if c["isStill"] else seg["speed"]
        length = seg["end"] - seg["start"]
        cw, ch = max(c["width"], 1), max(c["height"], 1)
        base = max(W / cw, H / ch) / min(W / cw, H / ch)
        s = base_segment(mids[seg["clip"]], companions(add, True, speed), seg["start"], length)
        s.update({"clip": clip_obj(base, 0, 0), "enable_adjust": True, "enable_lut": True,
                  "hdr_settings": {"intensity": 1, "mode": 1, "nits": 1000},
                  "source_timerange": {"start": us(0 if c["isStill"] else seg["clipIn"]), "duration": us(length * speed)},
                  "speed": speed, "uniform_scale": {"on": True, "value": 1}, "volume": 0, "last_nonzero_volume": 1})
        kf = motion_keyframes(seg, base, plan["cc"])
        if kf:
            s["common_keyframes"] = kf
            s["uniform_scale"] = {"on": False, "value": 1}
        vsegs.append(s)
    tracks = [track("video", vsegs)]

    m = plan.get("music")
    if m and m.get("path"):
        info = media.probe(m["path"])
        mid = nid()
        add("audios", audio_material(mid, m["path"], os.path.basename(m["path"]), info["duration"]))
        length = min(plan["duration"], max(info["duration"] - m["offset"], 0.1))
        a = base_segment(mid, companions(add, False, 1.0), 0, length)
        a["source_timerange"] = {"start": us(m["offset"]), "duration": us(length)}
        tracks.append(track("audio", [a]))
        if m["path"] not in by_path:
            media_entries.append((m["path"], os.path.basename(m["path"]), info["duration"], 0, 0, "music"))

    text_tracks, ends = [], []
    for k, sub in enumerate(plan["subtitles"]):
        mid = nid()
        add("texts", text_material(mid, sub, W))
        t = base_segment(mid, [], sub["start"], sub["end"] - sub["start"])
        t.update({"clip": clip_obj(1, (sub["x"] - 0.5) * 2, (0.5 - sub["y"]) * 2), "render_index": 15000 + k,
                  "uniform_scale": {"on": True, "value": 1}})
        kf = text_keyframes(sub)
        if kf:
            t["common_keyframes"] = kf
            t["uniform_scale"] = {"on": False, "value": 1}
        for i, e in enumerate(ends):
            if e <= sub["start"] + 1e-4:
                text_tracks[i].append(t)
                ends[i] = sub["end"]
                break
        else:
            text_tracks.append([t])
            ends.append(sub["end"])
    tracks += [track("text", segs) for segs in text_tracks]

    total = us(plan["duration"])
    content = {
        "canvas_config": {"width": plan["width"], "height": plan["height"], "ratio": "original"},
        "color_space": 0, "config": TIMELINE_CONFIG, "cover": None, "create_time": 0, "duration": total,
        "extra_info": None, "fps": plan["fps"], "free_render_index_mode_on": False, "group_container": None,
        "id": nid(), "keyframe_graph_list": [],
        "keyframes": {k: [] for k in ("adjusts", "audios", "effects", "filters", "handwrites", "stickers", "texts", "videos")},
        "last_modified_platform": seed["platform"], "materials": materials, "mutable_config": None, "name": "",
        "new_version": seed["new_version"], "platform": seed["platform"], "relationships": [],
        "render_index_track_mode_on": False, "retouch_cover": None, "source": "default", "static_cover_image_path": "",
        "time_marks": None, "tracks": tracks, "update_time": 0, "version": seed["version"],
    }
    now_us = int(time.time() * 1_000_000)
    now_s = now_us // 1_000_000
    entries = [{"create_time": now_s, "duration": us(d), "extra_info": n, "file_Path": p, "height": int(h),
                "id": nid(), "import_time": now_s, "import_time_ms": now_us, "item_source": 1, "md5": "",
                "metetype": kind, "roughcut_time_range": {"duration": us(d), "start": 0},
                "sub_time_range": {"duration": -1, "start": -1}, "type": 0, "width": int(w)}
               for p, n, d, w, h, kind in media_entries]
    meta = {
        "cloud_package_completed_time": "", "draft_cloud_capcut_purchase_info": "",
        "draft_cloud_last_action_download": False, "draft_cloud_materials": [], "draft_cloud_purchase_info": "",
        "draft_cloud_template_id": "", "draft_cloud_tutorial_info": "", "draft_cloud_videocut_purchase_info": "",
        "draft_cover": "draft_cover.jpg", "draft_deeplink_url": "",
        "draft_enterprise_info": {"draft_enterprise_extra": "", "draft_enterprise_id": "", "draft_enterprise_name": "",
                                  "enterprise_material": []},
        "draft_fold_path": folder, "draft_id": nid(), "draft_is_ai_packaging_used": False, "draft_is_ai_shorts": False,
        "draft_is_ai_translate": False, "draft_is_article_video_draft": False, "draft_is_from_deeplink": "false",
        "draft_is_invisible": False,
        "draft_materials": [{"type": t, "value": entries if t == 0 else []} for t in (0, 1, 2, 3, 6, 7, 8)],
        "draft_materials_copied_info": [], "draft_name": name, "draft_new_version": "",
        "draft_removable_storage_device": "", "draft_root_path": r, "draft_segment_extra_info": [],
        "draft_timeline_materials_size_": 0, "draft_type": "", "tm_draft_cloud_completed": "",
        "tm_draft_cloud_modified": 0, "tm_draft_create": now_us, "tm_draft_modified": now_us, "tm_duration": total,
        "version": seed["meta_version"],
    }
    with open(os.path.join(folder, "draft_content.json"), "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False)
    with open(os.path.join(folder, "draft_meta_info.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    if plan["segments"]:
        first = plan["segments"][0]
        cover = media.frame_jpeg(first["clip"], first["clipIn"] + 0.1, 540)
        if cover:
            with open(os.path.join(folder, "draft_cover.jpg"), "wb") as f:
                f.write(cover)
    return folder
