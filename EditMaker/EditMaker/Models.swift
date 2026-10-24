import Foundation

/// After Effects로 보낼 edit 설계도. 이 JSON이 그대로 JSX 스크립트에 들어가요.
/// AI 수정 요청도 이 구조를 고쳐서 돌려받는 방식이에요.
struct EditPlan: Codable, Equatable {
    var width: Int
    var height: Int
    var fps: Double
    var duration: Double
    var music: Music?
    var cc: CCSettings
    var segments: [Segment]
    var subtitles: [Subtitle]
    /// 음악 비트 시각(초). 타이밍 참고용이라 AI가 바꾸지 않아요.
    var beats: [Double]

    struct Music: Codable, Equatable {
        var path: String
        /// 음악 파일의 몇 초부터 쓸지
        var offset: Double
    }

    struct CCSettings: Codable, Equatable {
        var preset: String
        /// 색보정 세기 0~1
        var intensity: Double
        /// 살짝 번지는(글로우) 정도 0~1
        var bloom: Double
        /// 필름 노이즈 0~1
        var grain: Double
        /// 비네팅 0~1
        var vignette: Double
        /// 사용자가 넣은 .ffx 프리셋(자료) 경로
        var userPresets: [String]

        init(preset: String, intensity: Double, bloom: Double, grain: Double, vignette: Double, userPresets: [String]) {
            self.preset = preset
            self.intensity = intensity
            self.bloom = bloom
            self.grain = grain
            self.vignette = vignette
            self.userPresets = userPresets
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            preset = try c.decodeIfPresent(String.self, forKey: .preset) ?? "dreamy_glow"
            intensity = try c.decodeIfPresent(Double.self, forKey: .intensity) ?? 0.7
            bloom = try c.decodeIfPresent(Double.self, forKey: .bloom) ?? 0.5
            grain = try c.decodeIfPresent(Double.self, forKey: .grain) ?? 0.2
            vignette = try c.decodeIfPresent(Double.self, forKey: .vignette) ?? 0.3
            userPresets = try c.decodeIfPresent([String].self, forKey: .userPresets) ?? []
        }
    }

    struct Segment: Codable, Equatable, Identifiable {
        var id: Int
        var clip: String
        /// 클립의 몇 초부터 쓸지
        var clipIn: Double
        var start: Double
        var end: Double
        /// 1 = 원래 속도, 0.5 = 슬로모션
        var speed: Double
        var transition: String
        var shake: Bool
        /// 구간 동안 천천히 줌인하는 정도 (0 ~ 0.3)
        var push: Double

        var length: Double { end - start }

        init(id: Int, clip: String, clipIn: Double, start: Double, end: Double, speed: Double, transition: String, shake: Bool, push: Double) {
            self.id = id
            self.clip = clip
            self.clipIn = clipIn
            self.start = start
            self.end = end
            self.speed = speed
            self.transition = transition
            self.shake = shake
            self.push = push
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
            clip = try c.decode(String.self, forKey: .clip)
            clipIn = try c.decodeIfPresent(Double.self, forKey: .clipIn) ?? 0
            start = try c.decode(Double.self, forKey: .start)
            end = try c.decode(Double.self, forKey: .end)
            speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1
            transition = try c.decodeIfPresent(String.self, forKey: .transition) ?? "none"
            shake = try c.decodeIfPresent(Bool.self, forKey: .shake) ?? false
            push = try c.decodeIfPresent(Double.self, forKey: .push) ?? 0
        }
    }

    struct Subtitle: Codable, Equatable, Identifiable {
        var id: Int
        var text: String
        var start: Double
        var end: Double
        var style: String
        /// AE에서 쓰는 폰트 PostScript 이름
        var font: String
        var size: Double
        /// 글자색 #RRGGBB
        var color: String
        /// 테두리·글로우 색 #RRGGBB
        var accent: String
        /// 화면 안 위치(0~1). x=0.5, y=0.5 가 정중앙
        var x: Double
        var y: Double

        init(id: Int, text: String, start: Double, end: Double, style: String, font: String, size: Double, color: String, accent: String, x: Double, y: Double) {
            self.id = id
            self.text = text
            self.start = start
            self.end = end
            self.style = style
            self.font = font
            self.size = size
            self.color = color
            self.accent = accent
            self.x = x
            self.y = y
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
            text = try c.decode(String.self, forKey: .text)
            start = try c.decode(Double.self, forKey: .start)
            end = try c.decode(Double.self, forKey: .end)
            style = try c.decodeIfPresent(String.self, forKey: .style) ?? "neon_glow"
            let st = Catalog.style(style)
            font = try c.decodeIfPresent(String.self, forKey: .font) ?? st.font
            size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 84
            color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#FFFFFF"
            accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? "#FF3CAC"
            x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0.5
            y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0.5
        }
    }
}

extension EditPlan {
    /// 숫자 범위를 안전하게 맞추고, 순서·번호를 정리해요. (AI가 고친 결과에도 써요)
    func sanitized(allowedClips: Set<String>) -> EditPlan {
        var p = self
        p.width = min(max(p.width, 360), 3840)
        p.height = min(max(p.height, 360), 3840)
        p.fps = [24, 25, 29.97, 30, 50, 60].min(by: { abs($0 - p.fps) < abs($1 - p.fps) }) ?? 30
        p.duration = min(max(p.duration, 1), 600)

        p.cc.intensity = p.cc.intensity.clamped(0, 1)
        p.cc.bloom = p.cc.bloom.clamped(0, 1)
        p.cc.grain = p.cc.grain.clamped(0, 1)
        p.cc.vignette = p.cc.vignette.clamped(0, 1)
        if !Catalog.ccPresets.contains(where: { $0.id == p.cc.preset }) { p.cc.preset = "dreamy_glow" }

        let fallbackClip = allowedClips.sorted().first ?? ""
        p.segments = p.segments
            .filter { $0.end > $0.start && $0.start < p.duration }
            .sorted { $0.start < $1.start }
        for i in p.segments.indices {
            p.segments[i].id = i + 1
            if !allowedClips.isEmpty && !allowedClips.contains(p.segments[i].clip) { p.segments[i].clip = fallbackClip }
            p.segments[i].end = min(p.segments[i].end, p.duration)
            p.segments[i].clipIn = max(0, p.segments[i].clipIn)
            p.segments[i].speed = p.segments[i].speed.clamped(0.1, 4)
            p.segments[i].push = p.segments[i].push.clamped(0, 0.4)
            if !Catalog.transitions.contains(where: { $0.id == p.segments[i].transition }) { p.segments[i].transition = "none" }
        }

        p.subtitles = p.subtitles
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.end > $0.start }
            .sorted { $0.start < $1.start }
        for i in p.subtitles.indices {
            p.subtitles[i].id = i + 1
            if !Catalog.styles.contains(where: { $0.id == p.subtitles[i].style }) { p.subtitles[i].style = "neon_glow" }
            p.subtitles[i].start = max(0, p.subtitles[i].start)
            p.subtitles[i].end = min(p.subtitles[i].end, p.duration)
            p.subtitles[i].size = p.subtitles[i].size.clamped(20, 400)
            p.subtitles[i].x = p.subtitles[i].x.clamped(0.05, 0.95)
            p.subtitles[i].y = p.subtitles[i].y.clamped(0.05, 0.95)
            if HexColor.hex(p.subtitles[i].color) == nil { p.subtitles[i].color = "#FFFFFF" }
            if HexColor.hex(p.subtitles[i].accent) == nil { p.subtitles[i].accent = "#FF3CAC" }
        }
        return p
    }
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}

/// #RRGGBB 처리
enum HexColor {
    static func hex(_ s: String) -> (Double, Double, Double)? {
        var h = s.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    static func hex(r: Double, g: Double, b: Double) -> String {
        func c(_ v: Double) -> Int { Int((v.clamped(0, 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    /// HSB(0~1) → #RRGGBB
    static func hex(h: Double, s: Double, b: Double) -> String {
        let hh = (h - floor(h)) * 6
        let i = Int(hh) % 6
        let f = hh - floor(hh)
        let p = b * (1 - s), q = b * (1 - s * f), t = b * (1 - s * (1 - f))
        let c: (Double, Double, Double)
        switch i {
        case 0: c = (b, t, p)
        case 1: c = (q, b, p)
        case 2: c = (p, b, t)
        case 3: c = (p, q, b)
        case 4: c = (t, p, b)
        default: c = (b, p, q)
        }
        return hex(r: c.0, g: c.1, b: c.2)
    }
}

/// 넣은 영상 하나
struct MediaItem: Identifiable, Equatable {
    let id = UUID()
    var url: URL
    var duration: Double
    var width: Double
    var height: Double
    var isStill: Bool
    var hasAudio: Bool

    var name: String { url.lastPathComponent }
}

/// 레퍼런스 영상 분석 결과
struct ReferenceAnalysis: Equatable {
    var duration: Double
    var width: Double
    var height: Double
    /// 장면이 바뀌는 시각(초)
    var cuts: [Double]
    var beats: [Double]
    var bpm: Double
    /// 각 비트 근처의 소리 세기 (0~1)
    var beatStrength: [Double]
    /// 화면 평균 색 (HSB)
    var hue: Double
    var saturation: Double
    var brightness: Double
    /// 컷 빈도로 본 에너지 (0~1)
    var energy: Double

    var cutsPerSecond: Double { duration > 0 ? Double(cuts.count) / duration : 0 }

    var summary: String {
        String(format: "길이 %.1f초 · 컷 %d개(초당 %.1f) · %.0f BPM · 밝기 %.0f%% · 채도 %.0f%%",
               duration, cuts.count, cutsPerSecond, bpm, brightness * 100, saturation * 100)
    }
}

/// 만들어진 버전 하나 (검토·수정 기록)
struct EditVersion: Identifiable, Equatable {
    let id = UUID()
    var number: Int
    var plan: EditPlan
    var note: String
    var projectURL: URL?
    var renderURL: URL?
    var createdAt = Date()
}

struct ChatEntry: Identifiable, Equatable {
    enum Role { case user, assistant, system }
    let id = UUID()
    var role: Role
    var text: String
}
