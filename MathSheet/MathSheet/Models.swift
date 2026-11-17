import Foundation

/// 학년·학기 (2015 개정 교육과정 기준)
enum Course: String, Codable, CaseIterable, Identifiable {
    case e5b, e6a, e6b, m1, m2, m3

    var id: String { rawValue }

    var korean: String {
        switch self {
        case .e5b: return "초등 5학년 2학기"
        case .e6a: return "초등 6학년 1학기"
        case .e6b: return "초등 6학년 2학기"
        case .m1: return "중학교 1학년"
        case .m2: return "중학교 2학년"
        case .m3: return "중학교 3학년"
        }
    }

    var short: String {
        switch self {
        case .e5b: return "초5-2"
        case .e6a: return "초6-1"
        case .e6b: return "초6-2"
        case .m1: return "중1"
        case .m2: return "중2"
        case .m3: return "중3"
        }
    }

    var units: [MathUnit] { MathUnit.allCases.filter { $0.course == self } }
}

/// 단원
enum MathUnit: String, Codable, CaseIterable, Identifiable {
    // 초5-2
    case range, fractionMul, symmetry, decimalMul, cuboid, average
    // 초6-1
    case e61Frac, e61Prism, e61Dec, e61Ratio, e61Graph, e61Volume
    // 초6-2
    case e62Frac, e62Dec, e62Space, e62Proportion, e62Circle, e62Solids
    // 중1
    case m1Prime, m1Integer, m1Expr, m1Equation, m1Coord, m1Geometry, m1Stats
    // 중2
    case m2Repeating, m2Expr, m2Inequality, m2System, m2Linear, m2Shapes, m2Similar, m2Probability
    // 중3
    case m3Root, m3Factor, m3Quadratic, m3QFunc, m3Trig, m3Circle, m3Stats

    var id: String { rawValue }

    var course: Course {
        switch self {
        case .range, .fractionMul, .symmetry, .decimalMul, .cuboid, .average: return .e5b
        case .e61Frac, .e61Prism, .e61Dec, .e61Ratio, .e61Graph, .e61Volume: return .e6a
        case .e62Frac, .e62Dec, .e62Space, .e62Proportion, .e62Circle, .e62Solids: return .e6b
        case .m1Prime, .m1Integer, .m1Expr, .m1Equation, .m1Coord, .m1Geometry, .m1Stats: return .m1
        case .m2Repeating, .m2Expr, .m2Inequality, .m2System, .m2Linear, .m2Shapes, .m2Similar, .m2Probability: return .m2
        case .m3Root, .m3Factor, .m3Quadratic, .m3QFunc, .m3Trig, .m3Circle, .m3Stats: return .m3
        }
    }

    /// 학기 안에서 몇 단원인지
    var number: Int { (course.units.firstIndex(of: self) ?? 0) + 1 }

    /// 전체 순서 (정렬용)
    var order: Int { MathUnit.allCases.firstIndex(of: self) ?? 0 }

    var english: String {
        switch self {
        case .range: return "Range & Rounding"
        case .fractionMul: return "Multiplying Fractions"
        case .symmetry: return "Congruence & Symmetry"
        case .decimalMul: return "Multiplying Decimals"
        case .cuboid: return "Cuboids & Cubes"
        case .average: return "Average & Possibility"
        case .e61Frac: return "Dividing Fractions by Whole Numbers"
        case .e61Prism: return "Prisms & Pyramids"
        case .e61Dec: return "Dividing Decimals by Whole Numbers"
        case .e61Ratio: return "Ratios & Rates"
        case .e61Graph: return "Bar & Pie Graphs"
        case .e61Volume: return "Volume & Surface Area"
        case .e62Frac: return "Dividing Fractions"
        case .e62Dec: return "Dividing Decimals"
        case .e62Space: return "Space & Solid Figures"
        case .e62Proportion: return "Proportions"
        case .e62Circle: return "Area of a Circle"
        case .e62Solids: return "Cylinders, Cones & Spheres"
        case .m1Prime: return "Prime Factorization"
        case .m1Integer: return "Integers & Rational Numbers"
        case .m1Expr: return "Variables & Expressions"
        case .m1Equation: return "Linear Equations"
        case .m1Coord: return "Coordinates & Graphs"
        case .m1Geometry: return "Basic Figures & Polygons"
        case .m1Stats: return "Statistics (Representative Values)"
        case .m2Repeating: return "Repeating Decimals"
        case .m2Expr: return "Exponents & Polynomials"
        case .m2Inequality: return "Linear Inequalities"
        case .m2System: return "Systems of Equations"
        case .m2Linear: return "Linear Functions"
        case .m2Shapes: return "Properties of Triangles & Quadrilaterals"
        case .m2Similar: return "Similarity & Pythagorean Theorem"
        case .m2Probability: return "Counting & Probability"
        case .m3Root: return "Square Roots & Real Numbers"
        case .m3Factor: return "Expanding & Factoring"
        case .m3Quadratic: return "Quadratic Equations"
        case .m3QFunc: return "Quadratic Functions"
        case .m3Trig: return "Trigonometric Ratios"
        case .m3Circle: return "Properties of Circles"
        case .m3Stats: return "Statistics (Spread)"
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
        case .e61Frac: return "분수의 나눗셈"
        case .e61Prism: return "각기둥과 각뿔"
        case .e61Dec: return "소수의 나눗셈"
        case .e61Ratio: return "비와 비율"
        case .e61Graph: return "여러 가지 그래프"
        case .e61Volume: return "직육면체의 부피와 겉넓이"
        case .e62Frac: return "분수의 나눗셈"
        case .e62Dec: return "소수의 나눗셈"
        case .e62Space: return "공간과 입체"
        case .e62Proportion: return "비례식과 비례배분"
        case .e62Circle: return "원의 넓이"
        case .e62Solids: return "원기둥, 원뿔, 구"
        case .m1Prime: return "소인수분해"
        case .m1Integer: return "정수와 유리수"
        case .m1Expr: return "문자와 식"
        case .m1Equation: return "일차방정식"
        case .m1Coord: return "좌표평면과 그래프"
        case .m1Geometry: return "기본 도형과 평면도형"
        case .m1Stats: return "자료의 정리와 해석"
        case .m2Repeating: return "유리수와 순환소수"
        case .m2Expr: return "식의 계산"
        case .m2Inequality: return "일차부등식"
        case .m2System: return "연립일차방정식"
        case .m2Linear: return "일차함수"
        case .m2Shapes: return "삼각형과 사각형의 성질"
        case .m2Similar: return "도형의 닮음과 피타고라스 정리"
        case .m2Probability: return "경우의 수와 확률"
        case .m3Root: return "제곱근과 실수"
        case .m3Factor: return "다항식의 곱셈과 인수분해"
        case .m3Quadratic: return "이차방정식"
        case .m3QFunc: return "이차함수"
        case .m3Trig: return "삼각비"
        case .m3Circle: return "원의 성질"
        case .m3Stats: return "통계 (산포도)"
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
    /// 문제의 한국어 뜻
    var ko: String?
    /// 심화 문제인지
    var hard: Bool?
    /// 한국어 풀이 (심화 문제)
    var whyKo: String?

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
    /// "2026-10-28#3" (예전 학습지는 날짜만)
    var id: String
    var problems: [Problem]
    var submittedAt: Date?
    /// 학습지 날짜 "2026-10-28"
    var day: String?
    /// 그날의 몇 번째 장인지 (1부터). 단원별 연습은 그 단원의 몇 회째인지
    var number: Int?
    /// 단원별 연습 학습지면 그 단원 (매일 학습지가 아니라서 밀린 학습지에 쌓이지 않아요)
    var practiceUnit: MathUnit?

    var dayKey: String { day ?? id }
    var seq: Int { number ?? 1 }
    /// "11월 1일 (토) · 3장"
    var title: String {
        if let u = practiceUnit { return "\(u.korean) 연습 \(seq)회" }
        return "\(Day.label(dayKey)) · \(seq)장"
    }

    var isDone: Bool { submittedAt != nil }
    var score: Int { problems.filter { $0.correct == true }.count }
    var answeredCount: Int {
        problems.filter { !$0.userAnswer.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
}

enum StudyMode: String, Codable, Hashable {
    /// 한 단원을 정한 기간 동안 반복
    case chapter
    /// 여러 단원 섞기
    case mixed
}

struct Settings: Codable, Equatable {
    /// 학습지 1장의 문제 수
    var problemsPerDay = 10
    /// 하루에 나오는 학습지 장수
    var sheetsPerDay = 10
    var studyMode: StudyMode = .chapter
    /// 단원 집중 모드: chapterStart 날부터 공부하는 단원
    var chapterUnit: MathUnit = .fractionMul
    /// 한 단원을 공부하는 기간 (일)
    var chapterDays = 30
    var chapterStart: String?
    /// 공부하는 학년·학기
    var course: Course = .e5b
    /// 학습지에 나오는 단원 (지금 학년·학기 안에서)
    var units: [MathUnit] = Course.e5b.units
    var skipWeekends = false
    /// 매일 알림 (기본으로 켜요: 학습지가 매일 온다는 걸 알려줘요)
    var reminderOn = true
    /// 알림 시각 (자정부터 분)
    var reminderMinutes = 17 * 60
    /// 문제의 한국어 뜻을 처음부터 펼쳐 둘지
    var showKorean = false
    /// 학습지 1장에서 심화 문제 비율 (%)
    var challengePercent = 40
    /// 연습장에 손가락으로도 쓸지 (끄면 Apple Pencil로만 쓰고 손가락은 스크롤)
    var fingerDrawing = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Settings()
        problemsPerDay = (try? c.decode(Int.self, forKey: .problemsPerDay)) ?? base.problemsPerDay
        sheetsPerDay = (try? c.decode(Int.self, forKey: .sheetsPerDay)) ?? base.sheetsPerDay
        studyMode = (try? c.decode(StudyMode.self, forKey: .studyMode)) ?? base.studyMode
        chapterUnit = (try? c.decode(MathUnit.self, forKey: .chapterUnit)) ?? base.chapterUnit
        chapterDays = (try? c.decode(Int.self, forKey: .chapterDays)) ?? base.chapterDays
        chapterStart = try? c.decode(String.self, forKey: .chapterStart)
        course = (try? c.decode(Course.self, forKey: .course)) ?? base.course
        units = (try? c.decode([MathUnit].self, forKey: .units)) ?? base.units
        skipWeekends = (try? c.decode(Bool.self, forKey: .skipWeekends)) ?? base.skipWeekends
        reminderOn = (try? c.decode(Bool.self, forKey: .reminderOn)) ?? base.reminderOn
        reminderMinutes = (try? c.decode(Int.self, forKey: .reminderMinutes)) ?? base.reminderMinutes
        showKorean = (try? c.decode(Bool.self, forKey: .showKorean)) ?? base.showKorean
        fingerDrawing = (try? c.decode(Bool.self, forKey: .fingerDrawing)) ?? base.fingerDrawing
        challengePercent = (try? c.decode(Int.self, forKey: .challengePercent)) ?? base.challengePercent
    }
}

extension Settings {
    private var order: [MathUnit] {
        let us = units.filter { $0.course == course }
        return us.isEmpty ? course.units : us
    }

    /// 그날 공부할 단원 (단원 집중 모드). 기간이 끝나면 다음 단원, 마지막 다음엔 처음 단원으로 돌아가요.
    func unit(on day: String) -> MathUnit {
        let start = chapterStart ?? day
        let block = max(0, Day.days(from: start, to: day)) / max(chapterDays, 1)
        let first = order.firstIndex(of: chapterUnit) ?? 0
        return order[(first + block) % order.count]
    }

    /// 그날이 속한 단원 기간 (시작일, 마지막 날)
    func period(on day: String) -> (start: String, end: String) {
        let start = chapterStart ?? day
        let block = max(0, Day.days(from: start, to: day)) / max(chapterDays, 1)
        let s = Day.add(start, block * chapterDays)
        return (s, Day.add(s, chapterDays - 1))
    }

    /// 그날 학습지에 나올 단원들
    func units(on day: String) -> [MathUnit] {
        studyMode == .chapter ? [unit(on: day)] : order
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

    static func add(_ key: String, _ days: Int) -> String {
        guard let d = date(key), let n = calendar.date(byAdding: .day, value: days, to: d) else { return key }
        return Day.key(n)
    }

    /// from 부터 to 까지 며칠인지
    static func days(from: String, to: String) -> Int {
        guard let a = date(from), let b = date(to) else { return 0 }
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// "11월 1일"
    static func short(_ key: String) -> String {
        guard let d = date(key) else { return key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
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
