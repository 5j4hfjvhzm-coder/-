import Foundation

/// 초6 ~ 중3 문제 공통 도우미와 단원 연결
extension Generator {
    /// 숫자 답 문제 (영어, 한국어, 답, 풀이 영어/한국어)
    static func q(_ u: MathUnit, _ en: String, _ ko: String, ans: String, unit: String? = nil, expr: String? = nil,
                  why: String, kwhy: String) -> Problem {
        num(u, en, ko: ko, expr: expr, answer: ans, unit: unit, why: why, whyKo: kwhy)
    }

    /// 객관식 문제
    static func qc(_ u: MathUnit, _ en: String, _ ko: String, ans: String, wrong: [String], d: Dice,
                   why: String, kwhy: String) -> Problem {
        choice(u, en, ko: ko, answer: ans, wrong: wrong, d: d, why: why, whyKo: kwhy)
    }

    /// "12/3 = 4" (약분이 필요 없으면 "2/3"만)
    static func simp(_ n: Int, _ d: Int) -> String {
        let raw = "\(n)/\(d)"
        let f = Frac(n, d)
        return raw == f.mixed ? raw : "\(raw) = \(f.mixed)"
    }

    /// 위 첨자: 2 → "²"
    static func sup(_ n: Int) -> String {
        let map: [Character: String] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵",
                                        "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
        return String(n).map { map[$0] ?? "" }.joined()
    }

    /// 음수는 괄호로: -3 → "(-3)"
    static func par(_ n: Int) -> String { n < 0 ? "(\(n))" : "\(n)" }

    /// 부호를 붙인 정수: 3 → "(+3)", -3 → "(-3)"
    static func sgn(_ n: Int) -> String { n < 0 ? "(\(n))" : "(+\(n))" }

    /// 일차식: lin(3, -2) → "3x - 2", lin(1, 0) → "x", lin(-1, 5) → "-x + 5"
    static func lin(_ a: Int, _ b: Int, _ v: String = "x") -> String {
        var s: String
        switch a {
        case 0: s = ""
        case 1: s = v
        case -1: s = "-\(v)"
        default: s = "\(a)\(v)"
        }
        if b != 0 {
            if s.isEmpty { s = "\(b)" } else { s += b > 0 ? " + \(b)" : " - \(-b)" }
        }
        return s.isEmpty ? "0" : s
    }

    /// 이차식: quad(1, -5, 6) → "x² - 5x + 6"
    static func quad(_ a: Int, _ b: Int, _ c: Int) -> String {
        var s = a == 1 ? "x²" : a == -1 ? "-x²" : "\(a)x²"
        if b != 0 { s += b > 0 ? " + " : " - "; s += abs(b) == 1 ? "x" : "\(abs(b))x" }
        if c != 0 { s += c > 0 ? " + \(c)" : " - \(-c)" }
        return s
    }

    /// 0이 아닌 정수
    static func nonzero(_ d: Dice, _ r: ClosedRange<Int>) -> Int {
        var v = d.int(r)
        while v == 0 { v = d.int(r) }
        return v
    }

    static func extra(_ unit: MathUnit, _ d: Dice, hard: Bool) -> Problem {
        switch unit {
        case .e61Frac: return e61Frac(d, hard)
        case .e61Prism: return e61Prism(d, hard)
        case .e61Dec: return e61Dec(d, hard)
        case .e61Ratio: return e61Ratio(d, hard)
        case .e61Graph: return e61Graph(d, hard)
        case .e61Volume: return e61Volume(d, hard)
        case .e62Frac: return e62Frac(d, hard)
        case .e62Dec: return e62Dec(d, hard)
        case .e62Space: return e62Space(d, hard)
        case .e62Proportion: return e62Proportion(d, hard)
        case .e62Circle: return e62Circle(d, hard)
        case .e62Solids: return e62Solids(d, hard)
        case .m1Prime: return m1Prime(d, hard)
        case .m1Integer: return m1Integer(d, hard)
        case .m1Expr: return m1Expr(d, hard)
        case .m1Equation: return m1Equation(d, hard)
        case .m1Coord: return m1Coord(d, hard)
        case .m1Geometry: return m1Geometry(d, hard)
        case .m1Stats: return m1Stats(d, hard)
        case .m2Repeating: return m2Repeating(d, hard)
        case .m2Expr: return m2Expr(d, hard)
        case .m2Inequality: return m2Inequality(d, hard)
        case .m2System: return m2System(d, hard)
        case .m2Linear: return m2Linear(d, hard)
        case .m2Shapes: return m2Shapes(d, hard)
        case .m2Similar: return m2Similar(d, hard)
        case .m2Probability: return m2Probability(d, hard)
        case .m3Root: return m3Root(d, hard)
        case .m3Factor: return m3Factor(d, hard)
        case .m3Quadratic: return m3Quadratic(d, hard)
        case .m3QFunc: return m3QFunc(d, hard)
        case .m3Trig: return m3Trig(d, hard)
        case .m3Circle: return m3Circle(d, hard)
        case .m3Stats: return m3Stats(d, hard)
        case .range, .fractionMul, .symmetry, .decimalMul, .cuboid, .average:
            return hard ? challenge(unit, d) : make(unit, d)
        }
    }
}
