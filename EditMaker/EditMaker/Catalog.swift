import Foundation

struct SubtitleStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let font: String
    let symbol: String
}

struct NamedOption: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
}

struct FontAsset: Identifiable, Hashable {
    /// AE에서 쓰는 PostScript 이름
    let id: String
    let name: String
    let file: String
    let url: URL
}

/// 앱이 아는 자막 스타일, 전환 효과, 색보정(CC) 프리셋, 무료 폰트 목록.
/// JSX 템플릿(Templates.swift)과 id가 같아야 해요.
enum Catalog {
    static let styles: [SubtitleStyle] = [
        .init(id: "neon_glow", name: "네온 글로우", detail: "번쩍 켜지는 네온 + RGB 번짐 (레퍼런스 핑크 자막 느낌)", font: "BlackHanSans-Regular", symbol: "lightbulb.max.fill"),
        .init(id: "soft_blur", name: "소프트 블러", detail: "흐릿하게 번지다 또렷해지는 몽환 자막", font: "GowunDodum-Regular", symbol: "aqi.medium"),
        .init(id: "impact_pop", name: "임팩트 팝", detail: "크게 튀어나오는 강조 자막 + 방사 블러", font: "GasoekOne-Regular", symbol: "burst.fill"),
        .init(id: "typewriter", name: "타자기", detail: "한 글자씩 써지는 자막", font: "DoHyeon-Regular", symbol: "keyboard"),
        .init(id: "cute_bounce", name: "말랑 바운스", detail: "통통 튀는 귀여운 손글씨", font: "Jua-Regular", symbol: "heart.fill"),
        .init(id: "light_sweep", name: "라이트 스윕", detail: "빛이 쓱 지나가는 반짝 자막 (CC Light Sweep)", font: "Orbit-Regular", symbol: "sparkles"),
        .init(id: "glitch", name: "글리치", detail: "지직거리는 RGB 분리", font: "DoHyeon-Regular", symbol: "waveform.path.ecg"),
        .init(id: "minimal", name: "미니멀", detail: "얇고 깔끔한 페이드", font: "GowunDodum-Regular", symbol: "textformat"),
    ]

    static let transitions: [NamedOption] = [
        .init(id: "none", name: "컷", detail: "그냥 바로 넘어가기", symbol: "scissors"),
        .init(id: "zoom_punch", name: "줌 펀치", detail: "비트에 맞춰 확 당겼다 놓기", symbol: "plus.magnifyingglass"),
        .init(id: "flash", name: "플래시", detail: "하얗게 번쩍", symbol: "bolt.fill"),
        .init(id: "blur_in", name: "블러 인", detail: "흐릿하게 시작해서 또렷하게", symbol: "camera.aperture"),
        .init(id: "radial_blur", name: "래디얼 블러", detail: "CC Radial Fast Blur로 빨려 들어가기", symbol: "circle.dotted"),
        .init(id: "whip", name: "휩 슬라이드", detail: "옆에서 휙 밀려 들어오기", symbol: "arrow.right.to.line"),
    ]

    static let ccPresets: [NamedOption] = [
        .init(id: "dreamy_glow", name: "몽환 글로우", detail: "핑크빛 + 부드럽게 번지는 블룸", symbol: "moon.stars.fill"),
        .init(id: "vivid_pop", name: "쨍한 케이팝", detail: "채도·대비 업, 선명하게", symbol: "sun.max.fill"),
        .init(id: "soft_film", name: "소프트 필름", detail: "따뜻한 색감 + 필름 노이즈", symbol: "film"),
        .init(id: "cool_night", name: "쿨 나이트", detail: "푸른 보랏빛 밤 감성", symbol: "sparkles.tv"),
        .init(id: "clean", name: "클린", detail: "살짝만 선명하게", symbol: "drop"),
    ]

    private static let fontBase = "https://raw.githubusercontent.com/google/fonts/main/ofl/"

    /// Google Fonts의 무료(OFL) 한글 폰트. 처음 만들 때 자동으로 받아서 설치해요.
    static let fonts: [FontAsset] = [
        font("BlackHanSans-Regular", "검은고딕", "blackhansans/BlackHanSans-Regular.ttf"),
        font("DoHyeon-Regular", "도현", "dohyeon/DoHyeon-Regular.ttf"),
        font("Jua-Regular", "주아", "jua/Jua-Regular.ttf"),
        font("Gaegu-Bold", "개구쟁이", "gaegu/Gaegu-Bold.ttf"),
        font("Dongle-Bold", "동글", "dongle/Dongle-Bold.ttf"),
        font("GowunDodum-Regular", "고운돋움", "gowundodum/GowunDodum-Regular.ttf"),
        font("Orbit-Regular", "오르빗", "orbit/Orbit-Regular.ttf"),
        font("GasoekOne-Regular", "가석원", "gasoekone/GasoekOne-Regular.ttf"),
    ]

    private static func font(_ ps: String, _ name: String, _ path: String) -> FontAsset {
        FontAsset(id: ps, name: name, file: (path as NSString).lastPathComponent, url: URL(string: fontBase + path)!)
    }

    static func style(_ id: String) -> SubtitleStyle { styles.first { $0.id == id } ?? styles[0] }
    static func transition(_ id: String) -> NamedOption { transitions.first { $0.id == id } ?? transitions[0] }
    static func cc(_ id: String) -> NamedOption { ccPresets.first { $0.id == id } ?? ccPresets[0] }
    static func fontName(_ ps: String) -> String { fonts.first { $0.id == ps }?.name ?? ps }
}

enum AspectOption: String, CaseIterable, Identifiable {
    case vertical, matchReference, square, horizontal
    var id: String { rawValue }
    var name: String {
        switch self {
        case .vertical: return "9:16 세로"
        case .matchReference: return "레퍼런스와 같게"
        case .square: return "1:1"
        case .horizontal: return "16:9 가로"
        }
    }
}

enum CutMode: String, CaseIterable, Identifiable {
    case reference, beats, mix
    var id: String { rawValue }
    var name: String {
        switch self {
        case .reference: return "레퍼런스 컷 따라하기"
        case .beats: return "음악 비트에 맞추기"
        case .mix: return "둘 다 섞기"
        }
    }
}
