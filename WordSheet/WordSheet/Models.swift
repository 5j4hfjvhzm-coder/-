import SwiftUI

/// 형광펜 색
enum Marker: String, Codable, CaseIterable, Identifiable {
    case yellow, green, pink, blue, orange

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 1.00, green: 0.90, blue: 0.20)
        case .green: return Color(red: 0.50, green: 0.90, blue: 0.40)
        case .pink: return Color(red: 1.00, green: 0.55, blue: 0.75)
        case .blue: return Color(red: 0.45, green: 0.75, blue: 1.00)
        case .orange: return Color(red: 1.00, green: 0.68, blue: 0.30)
        }
    }

    var name: String {
        switch self {
        case .yellow: return "노랑"
        case .green: return "초록"
        case .pink: return "분홍"
        case .blue: return "파랑"
        case .orange: return "주황"
        }
    }
}

struct Detail: Identifiable, Hashable {
    let label: String
    let value: String
    var id: String { label }
}

/// 단어 하나 (CSV 한 줄)
struct Entry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var w = ""
    var m = ""
    /// 품사(POS)
    var pos = ""
    /// 발음(P)
    var pron = ""
    /// 성별(G)
    var g = ""
    /// 예문(E)
    var e = ""
    /// 파생어(DER)
    var der = ""
    /// 유의어(SIM)
    var sim = ""
    /// 동의어(S)
    var syn = ""
    /// 반의어(A)
    var ant = ""
    /// 설명(D)
    var d = ""
    var marker: Marker?

    /// 뜻 아래에 보여줄 정보 (값이 있는 것만)
    var meaningDetails: [Detail] {
        [Detail(label: "예문", value: e), Detail(label: "설명", value: d), Detail(label: "파생어", value: der),
         Detail(label: "유의어", value: sim), Detail(label: "동의어", value: syn), Detail(label: "반의어", value: ant)]
            .filter { !$0.value.isEmpty }
    }

    /// 단어 아래에 붙는 꼬리표 (품사, 성별)
    var wordTags: [String] {
        [pos, g].filter { !$0.isEmpty }
    }
}

struct Deck: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var entries: [Entry]

    var markedCount: Int { entries.filter { $0.marker != nil }.count }
}
