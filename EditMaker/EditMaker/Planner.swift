import Foundation

struct PlanOptions {
    var aspect: AspectOption = .vertical
    var cutMode: CutMode = .mix
    /// 0이면 레퍼런스 길이 그대로
    var maxLength: Double = 0
    /// "auto" 또는 CC 프리셋 id
    var ccPreset: String = "auto"
    /// "auto" 또는 자막 스타일 id
    var subtitleStyle: String = "auto"
    /// 효과 양 0~1
    var effectAmount: Double = 0.6
    var bloom: Double = 0.5
    var subtitleLines: [String] = []
    var userPresets: [String] = []
    var seed: UInt64 = 7
}

/// 같은 seed면 항상 같은 결과가 나오는 난수
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// 레퍼런스 분석 + 내 클립 → 첫 번째 edit 설계도 (규칙 기반. AI 키가 있으면 AI가 한 번 더 다듬어요)
enum Planner {
    static func make(reference ref: ReferenceAnalysis, referenceURL: URL, referenceHasAudio: Bool,
                     musicURL: URL?, clips: [MediaItem], options o: PlanOptions) -> EditPlan {
        var rng = SeededRNG(seed: o.seed)
        let (w, h) = dimensions(o.aspect, ref)
        let duration = o.maxLength > 0 ? min(o.maxLength, ref.duration) : ref.duration

        // 1) 컷 위치
        let boundaries = cutPoints(ref: ref, duration: duration, mode: o.cutMode)

        // 2) 클립 배치
        var segments: [EditPlan.Segment] = []
        var order = clips.shuffled(using: &rng)
        if order.isEmpty { order = [] }
        var cursor: [URL: Double] = [:]
        for i in 0..<(boundaries.count - 1) {
            let start = boundaries[i], end = boundaries[i + 1]
            let len = end - start
            guard !order.isEmpty else { break }
            let clip = order[i % order.count]
            if i % order.count == order.count - 1 && order.count > 2 {
                // 한 바퀴 돌면 순서를 살짝 섞어서 같은 패턴이 반복되지 않게
                order = order.shuffled(using: &rng)
            }
            var speed = 1.0
            if ref.energy < 0.4 && len > 1.2 && !clip.isStill { speed = 0.75 }
            var clipIn = 0.0
            if !clip.isStill {
                let need = len * speed
                if clip.duration >= need {
                    let c = cursor[clip.url] ?? rng.unit()
                    clipIn = (clip.duration - need) * c
                    cursor[clip.url] = (c + 0.618).truncatingRemainder(dividingBy: 1)
                } else {
                    speed = max(0.25, clip.duration / len * 0.98)
                }
            }

            let strength = beatStrength(at: start, ref: ref)
            var transition = "none"
            var shake = false
            if i == 0 {
                transition = "blur_in"
            } else if i % 8 == 0 && o.effectAmount > 0.3 {
                transition = "flash"
            } else if strength > 0.7 && rng.unit() < o.effectAmount {
                let r = rng.unit()
                transition = r < 0.6 ? "zoom_punch" : (r < 0.8 ? "radial_blur" : "flash")
                shake = strength > 0.85 && rng.unit() < o.effectAmount * 0.5
            } else if rng.unit() < o.effectAmount * 0.45 {
                transition = ["whip", "zoom_punch", "blur_in"][Int(rng.unit() * 3) % 3]
            }
            let push = len > 0.8 ? (0.04 + 0.08 * rng.unit()) * (0.5 + o.effectAmount) : 0

            segments.append(.init(id: i + 1, clip: clip.url.path, clipIn: round3(clipIn), start: round3(start), end: round3(end),
                                  speed: round3(speed), transition: transition, shake: shake, push: round3(push)))
        }

        // 3) 자막
        let lines = o.subtitleLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var subtitles: [EditPlan.Subtitle] = []
        if !lines.isEmpty {
            let slot = duration / Double(lines.count)
            for (k, line) in lines.enumerated() {
                let desired = Double(k) * slot + min(0.3, slot * 0.1)
                let start = boundaries.dropLast().min(by: { abs($0 - desired) < abs($1 - desired) }) ?? desired
                let chars = Double(line.count)
                let dur = min(max(chars * 0.13 + 0.8, 1.0), max(slot * 0.95, 0.8), 3.5)
                let style = o.subtitleStyle == "auto" ? autoStyle(line, ref: ref, index: k) : o.subtitleStyle
                subtitles.append(subtitle(id: k + 1, text: line, start: start, end: min(start + dur, duration),
                                          style: style, ref: ref, width: Double(w)))
            }
        }

        // 4) 색보정(CC)
        let cc = EditPlan.CCSettings(
            preset: o.ccPreset == "auto" ? autoCC(ref) : o.ccPreset,
            intensity: 0.7,
            bloom: o.bloom,
            grain: (o.ccPreset == "soft_film" || (o.ccPreset == "auto" && autoCC(ref) == "soft_film")) ? 0.4 : 0.15,
            vignette: 0.3,
            userPresets: o.userPresets
        )

        let musicPath = musicURL?.path ?? (referenceHasAudio ? referenceURL.path : nil)
        return EditPlan(
            width: w, height: h, fps: 30, duration: round3(duration),
            music: musicPath.map { .init(path: $0, offset: 0) },
            cc: cc,
            segments: segments,
            subtitles: subtitles,
            beats: ref.beats.filter { $0 < duration }.map(round3)
        )
    }

    static func dimensions(_ a: AspectOption, _ ref: ReferenceAnalysis) -> (Int, Int) {
        switch a {
        case .vertical: return (1080, 1920)
        case .horizontal: return (1920, 1080)
        case .square: return (1080, 1080)
        case .matchReference:
            let scale = 1920 / max(ref.width, ref.height)
            func even(_ v: Double) -> Int { max(2, Int((v * scale / 2).rounded()) * 2) }
            return (even(ref.width), even(ref.height))
        }
    }

    static func cutPoints(ref: ReferenceAnalysis, duration: Double, mode: CutMode) -> [Double] {
        let refCuts = ref.cuts.filter { $0 > 0.15 && $0 < duration - 0.15 }.map { snapToBeat($0, ref.beats) }
        let beatStep = ref.bpm >= 110 ? (ref.energy > 0.7 ? 1 : 2) : 1
        let beatCuts = ref.beats.enumerated()
            .filter { $0.offset % beatStep == 0 }
            .map { $0.element }
            .filter { $0 > 0.15 && $0 < duration - 0.15 }

        var points: [Double]
        switch mode {
        case .reference:
            points = refCuts.count >= max(3, Int(duration / 4)) ? refCuts : (refCuts + beatCuts)
        case .beats:
            points = beatCuts
        case .mix:
            points = refCuts + beatCuts.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        }
        points.sort()
        var cleaned: [Double] = [0]
        for p in points where p - cleaned.last! >= 0.3 { cleaned.append(p) }
        if duration - cleaned.last! < 0.25 && cleaned.count > 1 { cleaned.removeLast() }
        cleaned.append(duration)
        return cleaned
    }

    static func snapToBeat(_ t: Double, _ beats: [Double]) -> Double {
        guard let b = beats.min(by: { abs($0 - t) < abs($1 - t) }), abs(b - t) < 0.09 else { return t }
        return b
    }

    static func beatStrength(at t: Double, ref: ReferenceAnalysis) -> Double {
        guard let idx = ref.beats.indices.min(by: { abs(ref.beats[$0] - t) < abs(ref.beats[$1] - t) }),
              abs(ref.beats[idx] - t) < 0.1, idx < ref.beatStrength.count else { return 0.3 }
        return ref.beatStrength[idx]
    }

    // MARK: - 자막 스타일 고르기

    static func autoStyle(_ text: String, ref: ReferenceAnalysis, index: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespaces)
        let chars = t.count
        if t.contains("!") || (chars <= 4 && ref.energy > 0.4) { return "impact_pop" }
        if ["?", "~", "ㅋ", "ㅎ", "♡", "♥", "💕", "🩷"].contains(where: { t.contains($0) }) { return "cute_bounce" }
        if chars >= 16 { return "typewriter" }
        let options: [String]
        if ref.saturation < 0.22 || ref.brightness < 0.3 {
            options = ["soft_blur", "minimal", "light_sweep"]
        } else if ref.hue > 0.75 || ref.hue < 0.05 {
            options = ["neon_glow", "light_sweep", "soft_blur"]
        } else if ref.energy > 0.6 {
            options = ["glitch", "neon_glow", "impact_pop"]
        } else {
            options = ["neon_glow", "soft_blur", "light_sweep"]
        }
        return options[index % options.count]
    }

    static func subtitle(id: Int, text: String, start: Double, end: Double, style: String, ref: ReferenceAnalysis, width: Double) -> EditPlan.Subtitle {
        let hue = ref.saturation > 0.15 ? ref.hue : 0.9
        let accent = HexColor.hex(h: hue, s: 0.8, b: 1)
        var fill = HexColor.hex(h: hue, s: 0.1, b: 1)
        var acc = accent
        var size = width * 0.078
        var y = 0.55
        switch style {
        case "impact_pop": fill = "#FFFFFF"; acc = HexColor.hex(h: hue, s: 0.85, b: 0.95); size *= 1.3; y = 0.5
        case "minimal": fill = "#FFFFFF"; acc = "#000000"; size *= 0.72; y = 0.8
        case "cute_bounce": fill = "#FFFFFF"; acc = HexColor.hex(h: hue, s: 0.5, b: 1)
        case "typewriter": size *= 0.82; y = 0.72
        case "soft_blur": fill = "#FFFFFF"
        default: break
        }
        return .init(id: id, text: wrap(text), start: round3(start), end: round3(end), style: style,
                     font: Catalog.style(style).font, size: size.rounded(), color: fill, accent: acc, x: 0.5, y: y)
    }

    /// 긴 줄은 가운데 띄어쓰기에서 두 줄로 나눠요.
    static func wrap(_ s: String) -> String {
        guard s.count > 11, !s.contains("\n") else { return s }
        let chars = Array(s)
        let mid = chars.count / 2
        let spaces = chars.indices.filter { chars[$0] == " " }
        guard let cut = spaces.min(by: { abs($0 - mid) < abs($1 - mid) }) else { return s }
        return String(chars[..<cut]) + "\n" + String(chars[(cut + 1)...])
    }

    static func autoCC(_ ref: ReferenceAnalysis) -> String {
        if ref.saturation < 0.2 { return "soft_film" }
        if ref.brightness < 0.38 && ref.hue > 0.5 && ref.hue < 0.78 { return "cool_night" }
        if ref.hue > 0.75 || ref.hue < 0.04 { return "dreamy_glow" }
        if ref.saturation > 0.5 { return "vivid_pop" }
        return "dreamy_glow"
    }

    static func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
}
