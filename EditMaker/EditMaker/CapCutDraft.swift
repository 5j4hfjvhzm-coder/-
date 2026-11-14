import AVFoundation
import AppKit
import Foundation
import ImageIO

/// 맥용 CapCut(해외판) 프로젝트 폴더를 직접 만들어요.
/// CapCut에 공식 API가 없어서, 데스크톱 앱이 쓰는 draft_content.json / draft_meta_info.json 형식을 따라 써요.
/// (비공식 형식이라 CapCut 업데이트 후 안 열리면 형식을 다시 맞춰야 할 수 있어요.)
enum CapCutDraft {
    enum DraftError: LocalizedError {
        case noFolder(String)
        var errorDescription: String? {
            switch self {
            case .noFolder(let p):
                return "CapCut 프로젝트 폴더를 찾지 못했어요 (\(p)). CapCut을 한 번 열어 아무 프로젝트나 만든 뒤 다시 시도하거나, 설정에서 폴더를 골라 주세요."
            }
        }
    }

    static let defaultRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Movies/CapCut/User Data/Projects/com.lveditor.draft")

    static var root: URL {
        if let p = UserDefaults.standard.string(forKey: "capcutRoot"), !p.isEmpty { return URL(fileURLWithPath: p) }
        return defaultRoot
    }

    static var isAvailable: Bool { FileManager.default.fileExists(atPath: root.path) }

    static func capCutApp() -> URL? {
        let candidates = ["/Applications/CapCut.app", NSHomeDirectory() + "/Applications/CapCut.app"]
        if let p = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) { return URL(fileURLWithPath: p) }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.lemon.lvoverseas")
    }

    static func openCapCut() {
        if let app = capCutApp() {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func us(_ s: Double) -> Int { Int((s * 1_000_000).rounded()) }
    private static func newID() -> String { UUID().uuidString }

    // MARK: - 만들기

    /// 프로젝트 폴더를 만들고 경로를 돌려줘요.
    @discardableResult
    static func write(plan: EditPlan, name: String, clips: [MediaItem], musicDuration: Double?) throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { throw DraftError.noFolder(root.path) }
        let folder = root.appendingPathComponent(name)
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let seed = seedInfo()
        var materials: [String: [[String: Any]]] = [:]
        for key in materialCategories { materials[key] = [] }
        func add(_ cat: String, _ m: [String: Any]) { materials[cat, default: []].append(m) }

        let byPath = Dictionary(clips.map { ($0.url.path, $0) }, uniquingKeysWith: { a, _ in a })
        var videoMaterialID: [String: String] = [:]
        var media: [(path: String, name: String, dur: Double, w: Double, h: Double, kind: String)] = []

        // 영상 소재
        for path in Set(plan.segments.map(\.clip)).sorted() {
            guard let c = byPath[path] else { continue }
            let id = newID()
            videoMaterialID[path] = id
            add("videos", videoMaterial(id: id, item: c))
            media.append((path, c.name, c.isStill ? 10800 : c.duration, c.width, c.height, c.isStill ? "photo" : "video"))
        }

        // 영상 트랙
        let W = Double(plan.width), H = Double(plan.height)
        var videoSegments: [[String: Any]] = []
        for seg in plan.segments {
            guard let c = byPath[seg.clip], let mid = videoMaterialID[seg.clip] else { continue }
            let refs = companions(video: true, speed: c.isStill ? 1 : seg.speed, add: add)
            let len = seg.length
            let cw = max(c.width, 1), ch = max(c.height, 1)
            let contain = min(W / cw, H / ch), cover = max(W / cw, H / ch)
            let base = cover / contain
            var s = videoSegment(materialID: mid, refs: refs, start: seg.start, length: len,
                                 sourceStart: c.isStill ? 0 : seg.clipIn, speed: c.isStill ? 1 : seg.speed, scale: base)
            let kf = motionKeyframes(seg: seg, base: base, cc: plan.cc)
            if !kf.isEmpty {
                s["common_keyframes"] = kf
                s["uniform_scale"] = ["on": false, "value": 1]
            }
            videoSegments.append(s)
        }

        var tracks: [[String: Any]] = [track("video", videoSegments)]

        // 음악
        if let m = plan.music {
            let url = URL(fileURLWithPath: m.path)
            let dur = musicDuration ?? plan.duration + m.offset
            let id = newID()
            add("audios", audioMaterial(id: id, path: m.path, name: url.lastPathComponent, duration: dur))
            let refs = companions(video: false, speed: 1, add: add)
            let length = min(plan.duration, max(dur - m.offset, 0.1))
            var a = baseSegment(materialID: id, refs: refs, start: 0, length: length)
            a["source_timerange"] = ["start": us(m.offset), "duration": us(length)]
            tracks.append(track("audio", [a]))
            if !media.contains(where: { $0.path == m.path }) {
                media.append((m.path, url.lastPathComponent, dur, 0, 0, "music"))
            }
        }

        // 자막 (겹치면 다음 트랙으로)
        var textTracks: [[[String: Any]]] = []
        var textEnds: [Double] = []
        for (k, sub) in plan.subtitles.enumerated() {
            let id = newID()
            add("texts", textMaterial(id: id, sub: sub, canvasWidth: W))
            var t = baseSegment(materialID: id, refs: [], start: sub.start, length: sub.end - sub.start)
            t["clip"] = clip(scale: 1, x: (sub.x - 0.5) * 2, y: (0.5 - sub.y) * 2)
            t["render_index"] = 15000 + k
            t["uniform_scale"] = ["on": true, "value": 1]
            let kf = textKeyframes(sub)
            if !kf.isEmpty {
                t["common_keyframes"] = kf
                t["uniform_scale"] = ["on": false, "value": 1]
            }
            if let i = textEnds.firstIndex(where: { $0 <= sub.start + 0.0001 }) {
                textTracks[i].append(t); textEnds[i] = sub.end
            } else {
                textTracks.append([t]); textEnds.append(sub.end)
            }
        }
        for segs in textTracks { tracks.append(track("text", segs)) }

        let total = us(plan.duration)
        var content: [String: Any] = [
            "canvas_config": ["width": plan.width, "height": plan.height, "ratio": "original"],
            "color_space": 0,
            "config": timelineConfig,
            "cover": NSNull(),
            "create_time": 0,
            "duration": total,
            "extra_info": NSNull(),
            "fps": plan.fps,
            "free_render_index_mode_on": false,
            "group_container": NSNull(),
            "id": newID(),
            "keyframe_graph_list": [Any](),
            "keyframes": ["adjusts": [Any](), "audios": [Any](), "effects": [Any](), "filters": [Any](),
                          "handwrites": [Any](), "stickers": [Any](), "texts": [Any](), "videos": [Any]()],
            "last_modified_platform": seed.platform,
            "materials": materials,
            "mutable_config": NSNull(),
            "name": "",
            "new_version": seed.newVersion,
            "platform": seed.platform,
            "relationships": [Any](),
            "render_index_track_mode_on": false,
            "retouch_cover": NSNull(),
            "source": "default",
            "static_cover_image_path": "",
            "time_marks": NSNull(),
            "tracks": tracks,
            "update_time": 0,
            "version": seed.version,
        ]
        content["materials"] = materials

        try writeJSON(content, to: folder.appendingPathComponent("draft_content.json"))
        try writeJSON(metaInfo(name: name, folder: folder, duration: total, media: media, metaVersion: seed.metaVersion),
                      to: folder.appendingPathComponent("draft_meta_info.json"))
        writeCover(plan: plan, to: folder.appendingPathComponent("draft_cover.jpg"))
        return folder
    }

    // MARK: - 움직임 (키프레임)

    /// 컷 전환·흔들림·줌인을 CapCut 키프레임으로 바꿔요. 색보정(CC)은 채도·대비·밝기 키프레임으로 흉내 내요.
    private static func motionKeyframes(seg: EditPlan.Segment, base: Double, cc: EditPlan.CCSettings) -> [[String: Any]] {
        let len = seg.length
        let tIn = min(0.25, len * 0.5)
        let endScale = base * (1 + seg.push)
        var scale: [(Double, Double)] = []
        var posX: [(Double, Double)] = []
        var posY: [(Double, Double)] = []
        var rot: [(Double, Double)] = []
        var alpha: [(Double, Double)] = []
        var bright: [(Double, Double)] = []

        switch seg.transition {
        case "zoom_punch":
            let t1 = min(0.22, len * 0.6)
            scale = [(0, base * 1.22), (t1, base * 1.02), (len, endScale)]
        case "radial_blur":
            scale = [(0, base * 1.35), (tIn, base), (len, endScale)]
            rot = [(0, -6), (tIn, 0)]
        case "whip":
            posX = [(0, 0.7), (tIn, 0)]
        case "blur_in":
            alpha = [(0, 0.2), (tIn, 1)]
        case "flash":
            bright = [(0, 1), (min(0.16, len * 0.5), 0)]
        default:
            break
        }
        if scale.isEmpty && seg.push > 0 { scale = [(0, base), (len, endScale)] }
        if seg.shake {
            let end = min(len, 0.5)
            var t = 0.0, i = 0
            var xs: [(Double, Double)] = [], ys: [(Double, Double)] = []
            while t < end {
                let k = 1 - t / end
                let ox = (i % 2 == 0 ? 1.0 : -1.0) * 0.04 * k
                let oy = (i % 3 == 0 ? -1.0 : 1.0) * 0.03 * k
                xs.append((t, ox))
                ys.append((t, oy))
                t += 1.0 / 24; i += 1
            }
            xs.append((end, 0)); ys.append((end, 0))
            if posX.isEmpty { posX = xs }
            posY = ys
        }

        var out: [[String: Any]] = []
        func list(_ type: String, _ keys: [(Double, Double)]) {
            guard !keys.isEmpty else { return }
            out.append([
                "id": newID(),
                "keyframe_list": keys.map { k -> [String: Any] in
                    ["curveType": "Line", "graphID": "", "id": newID(),
                     "left_control": ["x": 0.0, "y": 0.0], "right_control": ["x": 0.0, "y": 0.0],
                     "time_offset": us(max(0, min(k.0, len))), "values": [k.1]]
                },
                "material_id": "",
                "property_type": type,
            ])
        }
        list("KFTypeScaleX", scale)
        list("KFTypeScaleY", scale)
        list("KFTypePositionX", posX)
        list("KFTypePositionY", posY)
        list("KFTypeRotation", rot)
        list("KFTypeAlpha", alpha)

        // 색보정: 프리셋별 채도·대비·밝기 (-1~1)
        let k = cc.intensity
        let (sat, con, bri): (Double, Double, Double) = {
            switch cc.preset {
            case "vivid_pop": return (0.3, 0.2, 0.02)
            case "soft_film": return (-0.15, -0.15, 0.06)
            case "cool_night": return (0.05, 0.15, -0.05)
            case "clean": return (0.1, 0.05, 0.02)
            default: return (0.12, -0.08, 0.06) // dreamy_glow
            }
        }()
        list("KFTypeSaturation", [(0, sat * k)])
        list("KFTypeContrast", [(0, con * k)])
        if bright.isEmpty {
            list("KFTypeBrightness", [(0, bri * k)])
        } else {
            list("KFTypeBrightness", bright.map { ($0.0, $0.1 + bri * k) })
        }
        return out
    }

    /// 자막 등장 애니메이션 (텍스트는 크기·위치·회전 키프레임만 써요)
    private static func textKeyframes(_ sub: EditPlan.Subtitle) -> [[String: Any]] {
        let len = sub.end - sub.start
        let x = (sub.x - 0.5) * 2, y = (0.5 - sub.y) * 2
        var scale: [(Double, Double)] = []
        var posX: [(Double, Double)] = []
        var posY: [(Double, Double)] = []
        var rot: [(Double, Double)] = []
        let end = { (t: Double) in min(t, len) }
        switch sub.style {
        case "impact_pop":
            scale = [(0, 0.01), (end(0.12), 1.24), (end(0.22), 1)]
        case "neon_glow":
            scale = [(0, 0.92), (end(0.05), 1.04), (end(0.09), 0.97), (end(0.2), 1)]
        case "soft_blur":
            scale = [(0, 1.15), (end(0.4), 1)]
        case "cute_bounce":
            posY = [(0, y - 0.07), (end(0.15), y + 0.02), (end(0.26), y - 0.006), (end(0.34), y)]
            scale = [(0, 0.7), (end(0.15), 1.06), (end(0.26), 1)]
            rot = [(0, -6), (end(0.15), 3), (end(0.3), 0)]
        case "glitch":
            var t = 0.0, i = 0
            while t < min(0.45, len) {
                posX.append((t, x + (i % 2 == 0 ? 0.04 : -0.035)))
                t += 1.0 / 14; i += 1
            }
            posX.append((min(0.45, len), x))
        case "minimal", "light_sweep", "typewriter":
            posY = [(0, y - 0.025), (end(0.35), y)]
            scale = [(0, 0.96), (end(0.35), 1)]
        default:
            break
        }
        var out: [[String: Any]] = []
        func list(_ type: String, _ keys: [(Double, Double)]) {
            guard !keys.isEmpty else { return }
            out.append([
                "id": newID(),
                "keyframe_list": keys.map { k -> [String: Any] in
                    ["curveType": "Line", "graphID": "", "id": newID(),
                     "left_control": ["x": 0.0, "y": 0.0], "right_control": ["x": 0.0, "y": 0.0],
                     "time_offset": us(k.0), "values": [k.1]]
                },
                "material_id": "",
                "property_type": type,
            ])
        }
        list("KFTypeScaleX", scale)
        list("KFTypeScaleY", scale)
        list("KFTypePositionX", posX)
        list("KFTypePositionY", posY)
        list("KFTypeRotation", rot)
        return out
    }

    // MARK: - 조각들

    private static func companions(video: Bool, speed: Double, add: (String, [String: Any]) -> Void) -> [String] {
        var ids: [String] = []
        let sp = newID()
        add("speeds", ["curve_speed": NSNull(), "id": sp, "mode": 0, "speed": speed, "type": "speed"])
        ids.append(sp)
        if video {
            let cv = newID()
            add("canvases", ["album_image": "", "blur": 0, "color": "", "id": cv, "image": "", "image_id": "",
                             "image_name": "", "source_platform": 0, "team_id": "", "type": "canvas_color"])
            ids.append(cv)
        }
        let sc = newID()
        add("sound_channel_mappings", ["audio_channel_mapping": 0, "id": sc, "is_config_open": false, "type": ""])
        ids.append(sc)
        let vs = newID()
        add("vocal_separations", ["choice": 0, "id": vs, "production_path": "", "removed_sounds": [Any](),
                                  "time_range": NSNull(), "type": "vocal_separation"])
        ids.append(vs)
        return ids
    }

    private static func clip(scale: Double, x: Double, y: Double) -> [String: Any] {
        ["alpha": 1, "flip": ["horizontal": false, "vertical": false], "rotation": 0,
         "scale": ["x": scale, "y": scale], "transform": ["x": x, "y": y]]
    }

    private static func baseSegment(materialID: String, refs: [String], start: Double, length: Double) -> [String: Any] {
        [
            "caption_info": NSNull(), "cartoon": false, "clip": NSNull(), "common_keyframes": [Any](),
            "enable_adjust": false, "enable_color_correct_adjust": false, "enable_color_curves": true,
            "enable_color_match_adjust": false, "enable_color_wheels": true, "enable_hsl": false, "enable_lut": false,
            "enable_smart_color_adjust": false, "extra_material_refs": refs, "group_id": "", "hdr_settings": NSNull(),
            "id": newID(), "intensifies_audio": false, "is_placeholder": false, "is_tone_modify": false,
            "keyframe_refs": [Any](), "last_nonzero_volume": 1, "material_id": materialID, "render_index": 0,
            "responsive_layout": ["enable": false, "horizontal_pos_layout": 0, "size_layout": 0, "target_follow": "", "vertical_pos_layout": 0],
            "reverse": false, "source_timerange": NSNull(), "speed": 1,
            "target_timerange": ["start": us(start), "duration": us(length)],
            "template_id": "", "template_scene": "default", "track_attribute": 0, "track_render_index": 0,
            "uniform_scale": NSNull(), "visible": true, "volume": 1,
        ]
    }

    private static func videoSegment(materialID: String, refs: [String], start: Double, length: Double,
                                     sourceStart: Double, speed: Double, scale: Double) -> [String: Any] {
        var s = baseSegment(materialID: materialID, refs: refs, start: start, length: length)
        s["clip"] = clip(scale: scale, x: 0, y: 0)
        s["enable_adjust"] = true
        s["enable_lut"] = true
        s["hdr_settings"] = ["intensity": 1, "mode": 1, "nits": 1000]
        s["source_timerange"] = ["start": us(sourceStart), "duration": us(length * speed)]
        s["speed"] = speed
        s["uniform_scale"] = ["on": true, "value": 1]
        s["volume"] = 0 // 음악만 들리게 클립 소리는 꺼요
        s["last_nonzero_volume"] = 1
        return s
    }

    private static func track(_ type: String, _ segments: [[String: Any]]) -> [String: Any] {
        ["attribute": 0, "flag": 0, "id": newID(), "is_default_name": true, "name": "", "segments": segments, "type": type]
    }

    private static func videoMaterial(id: String, item c: MediaItem) -> [String: Any] {
        [
            "aigc_type": "none", "audio_fade": NSNull(), "cartoon_path": "", "category_id": "", "category_name": "local",
            "check_flag": 63487,
            "crop": ["lower_left_x": 0, "lower_left_y": 1, "lower_right_x": 1, "lower_right_y": 1,
                     "upper_left_x": 0, "upper_left_y": 0, "upper_right_x": 1, "upper_right_y": 0],
            "crop_ratio": "free", "crop_scale": 1,
            "duration": us(c.isStill ? 10800 : c.duration),
            "extra_type_option": 0, "formula_id": "", "freeze": NSNull(), "has_audio": c.hasAudio,
            "height": Int(c.height), "id": id, "intensifies_audio_path": "", "intensifies_path": "",
            "is_ai_generate_content": false, "is_copyright": false, "is_text_edit_overdub": false,
            "is_unified_beauty_mode": false, "local_id": "", "local_material_id": "", "material_id": "",
            "material_name": c.name, "material_url": "",
            "matting": ["flag": 0, "has_use_quick_brush": false, "has_use_quick_eraser": false,
                        "interactiveTime": [Any](), "path": "", "strokes": [Any]()],
            "media_path": "", "object_locked": NSNull(), "origin_material_id": "", "path": c.url.path,
            "picture_from": "none", "picture_set_category_id": "", "picture_set_category_name": "",
            "request_id": "", "reverse_intensifies_path": "", "reverse_path": "", "smart_motion": NSNull(),
            "source": 0, "source_platform": 0,
            "stable": ["matrix_path": "", "stable_level": 0, "time_range": ["duration": 0, "start": 0]],
            "team_id": "", "type": c.isStill ? "photo" : "video",
            "video_algorithm": ["algorithms": [Any](), "complement_frame_config": NSNull(), "deflicker": NSNull(),
                                "gameplay_configs": [Any](), "motion_blur_config": NSNull(), "noise_reduction": NSNull(),
                                "path": "", "quality_enhance": NSNull(), "time_range": NSNull()],
            "width": Int(c.width),
        ]
    }

    private static func audioMaterial(id: String, path: String, name: String, duration: Double) -> [String: Any] {
        [
            "app_id": 0, "category_id": "", "category_name": "local", "check_flag": 1, "copyright_limit_type": "none",
            "duration": us(duration), "effect_id": "", "formula_id": "", "id": id, "intensifies_path": "",
            "is_ai_clone_tone": false, "is_text_edit_overdub": false, "local_material_id": "", "music_id": newID(),
            "name": name, "path": path, "query": "", "request_id": "", "resource_id": "", "search_id": "",
            "source_from": "", "source_platform": 0, "team_id": "", "text_id": "", "tone_category_id": "",
            "tone_category_name": "", "tone_effect_id": "", "tone_effect_name": "", "tone_platform": "",
            "tone_second_category_id": "", "tone_second_category_name": "", "tone_speaker": "", "tone_type": "",
            "type": "extract_music", "video_id": "", "wave_points": [Any](),
        ]
    }

    private static func rgb(_ hex: String) -> [Double] {
        let c = HexColor.hex(hex) ?? (1, 1, 1)
        return [c.0, c.1, c.2]
    }

    /// 자막: 글자색 + 테두리 + (네온 느낌의) 색 그림자
    private static func textMaterial(id: String, sub: EditPlan.Subtitle, canvasWidth: Double) -> [String: Any] {
        let size = (sub.size / canvasWidth * 160 * 10).rounded() / 10
        let strokeWidth: Double = ["impact_pop": 0.12, "cute_bounce": 0.1, "neon_glow": 0.05, "typewriter": 0.03, "light_sweep": 0.03][sub.style] ?? 0
        let glowStyles: Set<String> = ["neon_glow", "soft_blur", "light_sweep", "glitch", "typewriter"]
        var style: [String: Any] = [
            "fill": ["alpha": 1.0, "content": ["render_type": "solid", "solid": ["alpha": 1.0, "color": rgb(sub.color)]]],
            "range": [0, sub.text.utf16.count],
            "size": size,
            "bold": false, "italic": false, "underline": false,
            "strokes": strokeWidth > 0 ? [["content": ["solid": ["alpha": 1.0, "color": rgb(sub.accent)]], "width": strokeWidth]] : [Any](),
        ]
        // 받아 둔 한글 폰트 파일을 가리켜요. (CapCut이 무시하면 기본 폰트로 나와요)
        let fontFile = FontInstaller.folder.appendingPathComponent(Catalog.fonts.first { $0.id == sub.font }?.file ?? "")
        if FileManager.default.fileExists(atPath: fontFile.path) {
            style["font"] = ["id": "", "path": fontFile.path]
        }
        var hasShadow = false
        if glowStyles.contains(sub.style) {
            style["shadows"] = [["diffuse": 0.25, "alpha": 0.9, "distance": 0.0, "content": ["solid": ["color": rgb(sub.accent)]], "angle": -45.0]]
            hasShadow = true
        } else if sub.style != "minimal" {
            style["shadows"] = [["diffuse": 0.05, "alpha": 0.6, "distance": 5.0, "content": ["solid": ["color": [0.0, 0.0, 0.0]]], "angle": -45.0]]
            hasShadow = true
        }
        let contentObj: [String: Any] = ["styles": [style], "text": sub.text]
        let contentStr = (try? JSONSerialization.data(withJSONObject: contentObj)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        var flag = 7
        if strokeWidth > 0 { flag |= 8 }
        if hasShadow { flag |= 32 }
        return [
            "add_type": 0, "alignment": 1, "background_alpha": 1, "background_color": "", "background_height": 0.14,
            "background_horizontal_offset": 0, "background_round_radius": 0, "background_style": 0,
            "background_vertical_offset": 0, "background_width": 0.14, "base_content": "", "bold_width": 0,
            "border_alpha": 1, "border_color": strokeWidth > 0 ? sub.accent : "", "border_width": strokeWidth,
            "check_flag": flag, "combo_info": ["text_templates": [Any]()], "content": contentStr,
            "fixed_height": -1, "fixed_width": -1, "font_category_id": "", "font_category_name": "", "font_id": "",
            "font_name": "", "font_path": FileManager.default.fileExists(atPath: fontFile.path) ? fontFile.path : "",
            "font_resource_id": "", "font_size": size, "font_source_platform": 0, "font_team_id": "", "font_title": "none",
            "font_url": "", "fonts": [Any](), "force_apply_line_max_width": false, "global_alpha": 1, "group_id": "",
            "has_shadow": hasShadow, "id": id, "initial_scale": 1, "inner_padding": -1, "is_rich_text": false,
            "italic_degree": 0, "ktv_color": "", "language": "", "layer_weight": 1,
            "letter_spacing": sub.style == "minimal" ? 0.15 : 0, "line_feed": 1, "line_max_width": 0.82,
            "line_spacing": 0.02, "multi_language_current": "none", "name": "", "original_size": [Any](),
            "preset_category": "", "preset_category_id": "", "preset_has_set_alignment": false, "preset_id": "",
            "preset_index": 0, "preset_name": "", "recognize_task_id": "", "recognize_type": 0,
            "relevance_segment": [Any](), "shadow_alpha": 0.9, "shadow_angle": -45,
            "shadow_color": hasShadow ? sub.accent : "", "shadow_distance": 5,
            "shadow_point": ["x": 0.6363961030678928, "y": -0.6363961030678928], "shadow_smoothing": 0.45,
            "shape_clip_x": false, "shape_clip_y": false, "style_name": "", "sub_type": 0,
            "subtitle_keywords": NSNull(), "text_alpha": 1, "text_color": sub.color, "text_curve": NSNull(),
            "text_preset_resource_id": "", "text_size": 30, "text_to_audio_ids": [Any](), "tts_auto_update": false,
            "type": "text", "typesetting": 0, "underline": false, "underline_offset": 0.22, "underline_width": 0.05,
            "use_effect_default_color": true, "words": ["end_time": [Any](), "start_time": [Any](), "text": [Any]()],
        ]
    }

    private static func metaInfo(name: String, folder: URL, duration: Int, media: [(path: String, name: String, dur: Double, w: Double, h: Double, kind: String)], metaVersion: String) -> [String: Any] {
        let nowUs = Int(Date().timeIntervalSince1970 * 1_000_000)
        let nowS = nowUs / 1_000_000
        let entries: [[String: Any]] = media.map { m in
            ["create_time": nowS, "duration": us(m.dur), "extra_info": m.name, "file_Path": m.path,
             "height": Int(m.h), "id": newID(), "import_time": nowS, "import_time_ms": nowUs, "item_source": 1,
             "md5": "", "metetype": m.kind, "roughcut_time_range": ["duration": us(m.dur), "start": 0],
             "sub_time_range": ["duration": -1, "start": -1], "type": 0, "width": Int(m.w)]
        }
        let buckets: [[String: Any]] = [0, 1, 2, 3, 6, 7, 8].map { t in ["type": t, "value": t == 0 ? entries : []] }
        return [
            "cloud_package_completed_time": "", "draft_cloud_capcut_purchase_info": "",
            "draft_cloud_last_action_download": false, "draft_cloud_materials": [Any](), "draft_cloud_purchase_info": "",
            "draft_cloud_template_id": "", "draft_cloud_tutorial_info": "", "draft_cloud_videocut_purchase_info": "",
            "draft_cover": "draft_cover.jpg", "draft_deeplink_url": "",
            "draft_enterprise_info": ["draft_enterprise_extra": "", "draft_enterprise_id": "", "draft_enterprise_name": "", "enterprise_material": [Any]()],
            "draft_fold_path": folder.path, "draft_id": newID(), "draft_is_ai_packaging_used": false,
            "draft_is_ai_shorts": false, "draft_is_ai_translate": false, "draft_is_article_video_draft": false,
            "draft_is_from_deeplink": "false", "draft_is_invisible": false, "draft_materials": buckets,
            "draft_materials_copied_info": [Any](), "draft_name": name, "draft_new_version": "",
            "draft_removable_storage_device": "", "draft_root_path": root.path, "draft_segment_extra_info": [Any](),
            "draft_timeline_materials_size_": 0, "draft_type": "", "tm_draft_cloud_completed": "",
            "tm_draft_cloud_modified": 0, "tm_draft_create": nowUs, "tm_draft_modified": nowUs,
            "tm_duration": duration, "version": metaVersion,
        ]
    }

    private static let timelineConfig: [String: Any] = [
        "adjust_max_index": 1, "attachment_info": [Any](), "combination_max_index": 1, "export_range": NSNull(),
        "extract_audio_last_index": 1, "lyrics_recognition_id": "", "lyrics_sync": true, "lyrics_taskinfo": [Any](),
        "maintrack_adsorb": true, "material_save_mode": 0, "multi_language_current": "none",
        "multi_language_list": [Any](), "multi_language_main": "none", "multi_language_mode": "none",
        "original_sound_last_index": 1, "record_audio_last_index": 1, "sticker_max_index": 1,
        "subtitle_recognition_id": "", "subtitle_sync": true, "subtitle_taskinfo": [Any](),
        "system_font_list": [Any](), "video_mute": false, "zoom_info_params": NSNull(),
    ]

    private static let materialCategories = [
        "ai_translates", "audio_balances", "audio_effects", "audio_fades", "audio_track_indexes", "audios", "beats",
        "canvases", "chromas", "color_curves", "digital_humans", "drafts", "effects", "flowers", "green_screens",
        "handwrites", "hsl", "images", "log_color_wheels", "loudnesses", "manual_deformations", "masks",
        "material_animations", "material_colors", "multi_language_refs", "placeholders", "plugin_effects",
        "primary_color_wheels", "realtime_denoises", "shapes", "smart_crops", "smart_relights",
        "sound_channel_mappings", "speeds", "stickers", "tail_leaders", "text_templates", "texts", "time_marks",
        "transitions", "video_effects", "video_trackings", "videos", "vocal_beautifys", "vocal_separations",
    ]

    // MARK: - 설치된 CapCut 버전에 맞추기

    struct Seed {
        var platform: [String: Any]
        var newVersion: String
        var version: Any
        var metaVersion: String
    }

    /// CapCut이 직접 만든 프로젝트가 있으면 그 버전 정보를 그대로 빌려와요. (버전 불일치로 거부되는 걸 줄여요)
    static func seedInfo() -> Seed {
        var seed = Seed(
            platform: ["app_id": 359289, "app_source": "cc", "app_version": "5.9.0", "device_id": "",
                       "hard_disk_id": "", "mac_address": "", "os": "mac", "os_version": "14.0"],
            newVersion: "110.0.0", version: 360000, metaVersion: "110.0.0")
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return seed }
        let sorted = dirs.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for d in sorted where !d.lastPathComponent.hasPrefix("에딧메이커") {
            guard let data = try? Data(contentsOf: d.appendingPathComponent("draft_content.json")),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let p = obj["platform"] as? [String: Any] { seed.platform = p }
            if let nv = obj["new_version"] as? String, !nv.isEmpty { seed.newVersion = nv }
            if let v = obj["version"] { seed.version = v }
            if let md = try? Data(contentsOf: d.appendingPathComponent("draft_meta_info.json")),
               let mo = try? JSONSerialization.jsonObject(with: md) as? [String: Any],
               let mv = mo["version"] as? String { seed.metaVersion = mv }
            break
        }
        return seed
    }

    private static func writeJSON(_ obj: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }

    private static func writeCover(plan: EditPlan, to url: URL) {
        guard let first = plan.segments.first else { return }
        let src = URL(fileURLWithPath: first.clip)
        var cg: CGImage?
        if MediaAnalyzer.imageExts.contains(src.pathExtension.lowercased()) {
            if let s = CGImageSourceCreateWithURL(src as CFURL, nil) { cg = CGImageSourceCreateImageAtIndex(s, 0, nil) }
        } else {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: src))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 540, height: 960)
            cg = try? gen.copyCGImage(at: CMTime(seconds: first.clipIn + 0.1, preferredTimescale: 600), actualTime: nil)
        }
        guard let cg, let jpg = Director.jpeg(cg) else { return }
        try? jpg.write(to: url)
    }
}
