import Foundation

/// 5학년 2학기 단원
enum MathUnit: String, Codable, CaseIterable, Identifiable {
    case range, fractionMul, symmetry, decimalMul, cuboid, average

    var id: String { rawValue }

    var number: Int { (MathUnit.allCases.firstIndex(of: self) ?? 0) + 1 }

    var english: String {
        switch self {
        case .range: return "Range & Rounding"
        case .fractionMul: return "Multiplying Fractions"
        case .symmetry: return "Congruence & Symmetry"
        case .decimalMul: return "Multiplying Decimals"
        case .cuboid: return "Cuboids & Cubes"
        case .average: return "Average & Possibility"
        }
    }

    var korean: String {
        switch self {
        case .range: return "수의 범위와 어림하기"
        case .fractionMul: return "분수의 곱셈"
        case .symmetry: return "합동과 대칭"
        case .decimalMul: return "소수의 곱셈"
        case .cuboid: return "직육면체"
        case .average: return "평균과 가능성"
        }
    }
}

/// 분수(정수·소수 포함). 채점할 때 3/4, 0.75, 6/8 을 같은 값으로 봐요.
struct Frac: Equatable, Hashable {
    let n: Int
    let d: Int

    init(_ n: Int, _ d: Int = 1) {
        let g = Frac.gcd(abs(n), abs(d))
        let s = d < 0 ? -1 : 1
        self.n = s * n / max(g, 1)
        self.d = s * d / max(g, 1)
    }

    static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

    static func * (a: Frac, b: Frac) -> Frac { Frac(a.n * b.n, a.d * b.d) }

    var isWhole: Bool { d == 1 }

    /// 대분수: 7/2 → "3 1/2"
    var mixed: String {
        if d == 1 { return "\(n)" }
        let w = n / d
        let r = abs(n % d)
        return w == 0 ? "\(n)/\(d)" : "\(w) \(r)/\(d)"
    }

    /// 가분수: "7/2"
    var improper: String { d == 1 ? "\(n)" : "\(n)/\(d)" }

    /// "3", "3/4", "1 1/2", "0.75", "1,000", "12 cm" 를 읽어요.
    static func parse(_ raw: String) -> Frac? {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "⁄", with: "/")
        let s = String(cleaned.map { "0123456789./-".contains($0) ? $0 : " " })
        let parts = s.split(separator: " ").map(String.init)
        switch parts.count {
        case 1:
            return single(parts[0])
        case 2:
            // 대분수 "1 1/2"
            guard let w = Int(parts[0]), parts[1].contains("/"),
                  let f = single(parts[1]), f.n >= 0 else { return nil }
            return Frac(w * f.d + (w < 0 ? -f.n : f.n), f.d)
        default:
            return nil
        }
    }

    private static func single(_ s: String) -> Frac? {
        if s.contains("/") {
            let p = s.split(separator: "/", omittingEmptySubsequences: false)
            guard p.count == 2, let a = Int(p[0]), let b = Int(p[1]), b != 0 else { return nil }
            return Frac(a, b)
        }
        if s.contains(".") {
            let p = s.split(separator: ".", omittingEmptySubsequences: false)
            guard p.count == 2, p[1].count <= 9, p[1].allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            let neg = p[0].hasPrefix("-")
            let wholeText = p[0].replacingOccurrences(of: "-", with: "")
            guard let w = wholeText.isEmpty ? 0 : Int(wholeText) else { return nil }
            guard !(wholeText.isEmpty && p[1].isEmpty) else { return nil }
            let den = pow10(p[1].count)
            let f = p[1].isEmpty ? 0 : (Int(p[1]) ?? 0)
            let v = w * den + f
            return Frac(neg ? -v : v, den)
        }
        return Int(s).map { Frac($0) }
    }
}

func pow10(_ k: Int) -> Int { (0..<k).reduce(1) { r, _ in r * 10 } }

/// 소수 표시: dec(345, 2) → "3.45", dec(120, 2) → "1.2"
func dec(_ v: Int, _ places: Int, trim: Bool = true) -> String {
    let neg = v < 0
    let a = abs(v)
    let p = pow10(places)
    var fs = ""
    if places > 0 {
        let s = String(a % p)
        fs = String(repeating: "0", count: places - s.count) + s
        if trim { while fs.hasSuffix("0") { fs.removeLast() } }
    }
    return (neg ? "-" : "") + "\(a / p)" + (fs.isEmpty ? "" : "." + fs)
}

/// 천 단위 쉼표: 12345 → "12,345"
func comma(_ n: Int) -> String {
    let s = String(abs(n))
    var out = ""
    for (i, ch) in s.enumerated() {
        if i > 0 && (s.count - i) % 3 == 0 { out.append(",") }
        out.append(ch)
    }
    return (n < 0 ? "-" : "") + out
}

struct Problem: Codable, Identifiable {
    enum Kind: String, Codable { case number, choice }

    var id: String
    var unit: MathUnit
    var kind: Kind
    /// 영어 문제
    var text: String
    /// 크게 보여줄 식 (예: "1 1/2 × 2/3"). 분수는 세로로 그려요.
    var expr: String?
    /// 정답 (숫자 문제는 보여줄 형태, 객관식은 보기 글자)
    var answer: String
    var choices: [String]?
    /// 답 옆 단위 (cm, °, L …)
    var unitLabel: String?
    /// 풀이 (영어)
    var explanation: String

    var userAnswer: String = ""
    var correct: Bool?

    func isCorrect(_ input: String) -> Bool {
        switch kind {
        case .choice:
            return input == answer
        case .number:
            guard let a = Frac.parse(answer), let b = Frac.parse(input) else { return false }
            return a == b
        }
    }
}

struct Worksheet: Codable, Identifiable {
    /// 날짜 "2026-10-28"
    var id: String
    var problems: [Problem]
    var submittedAt: Date?

    var isDone: Bool { submittedAt != nil }
    var score: Int { problems.filter { $0.correct == true }.count }
    var answeredCount: Int {
        problems.filter { !$0.userAnswer.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
}

struct Settings: Codable, Equatable {
    var problemsPerDay = 10
    var units: [MathUnit] = MathUnit.allCases
    var skipWeekends = false
    var reminderOn = false
    /// 알림 시각 (자정부터 분)
    var reminderMinutes = 17 * 60

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Settings()
        problemsPerDay = (try? c.decode(Int.self, forKey: .problemsPerDay)) ?? base.problemsPerDay
        units = (try? c.decode([MathUnit].self, forKey: .units)) ?? base.units
        skipWeekends = (try? c.decode(Bool.self, forKey: .skipWeekends)) ?? base.skipWeekends
        reminderOn = (try? c.decode(Bool.self, forKey: .reminderOn)) ?? base.reminderOn
        reminderMinutes = (try? c.decode(Int.self, forKey: .reminderMinutes)) ?? base.reminderMinutes
    }
}

/// 날짜를 "yyyy-MM-dd" 글자로 다뤄요 (기기 시간대 기준).
enum Day {
    static let calendar = Calendar(identifier: .gregorian)

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }
    static var today: String { key(Date()) }

    static func next(_ key: String) -> String {
        guard let d = date(key), let n = calendar.date(byAdding: .day, value: 1, to: d) else { return key }
        return Day.key(n)
    }

    static func previous(_ key: String) -> String {
        guard let d = date(key), let n = calendar.date(byAdding: .day, value: -1, to: d) else { return key }
        return Day.key(n)
    }

    static func isWeekend(_ key: String) -> Bool {
        guard let d = date(key) else { return false }
        return calendar.isDateInWeekend(d)
    }

    /// "10월 28일 (화)"
    static func label(_ key: String) -> String {
        guard let d = date(key) else { return key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: d)
    }

    /// 오늘로부터 며칠 전인지
    static func daysAgo(_ key: String) -> Int {
        guard let d = date(key), let t = date(today) else { return 0 }
        return calendar.dateComponents([.day], from: d, to: t).day ?? 0
    }
}
