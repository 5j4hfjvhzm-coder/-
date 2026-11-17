import Foundation

/// 중학교 3학년 문제
extension Generator {
    /// y = a(x - p)² + q 표기
    static func vertexForm(_ a: Int, _ p: Int, _ qv: Int) -> String {
        let coef = a == 1 ? "" : a == -1 ? "-" : "\(a)"
        let inner = p == 0 ? "x²" : p > 0 ? "(x - \(p))²" : "(x + \(-p))²"
        let tail = qv == 0 ? "" : qv > 0 ? " + \(qv)" : " - \(-qv)"
        return "y = \(coef)\(inner)\(tail)"
    }

    // MARK: - 제곱근과 실수

    static func m3Root(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3Root
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let k = d.int(2...20)
            return q(u, "Calculate.", "계산하세요.", ans: "\(k)", expr: "√\(k * k)",
                     why: "\(k) × \(k) = \(k * k), so √\(k * k) = \(k).",
                     kwhy: "\(k) × \(k) = \(k * k)이므로 √\(k * k) = \(k)")
        case 1:
            let s = d.pick([2, 3, 5, 6, 7]), k1 = d.int(1...4), k2 = d.int(1...4)
            let a = s * k1 * k1, b = s * k2 * k2
            return q(u, "Calculate.", "계산하세요.", ans: "\(s * k1 * k2)", expr: "√\(a) × √\(b)",
                     why: "√\(a) × √\(b) = √\(a * b) = √(\(s * k1 * k2))² = \(s * k1 * k2).",
                     kwhy: "√\(a) × √\(b) = √\(a * b) = √(\(s * k1 * k2))² = \(s * k1 * k2)")
        case 2:
            let b = d.pick([2, 3, 5, 6, 7, 10]), a = d.int(2...6)
            let n = a * a * b
            return q(u, "Write √\(n) in the form a√b (b as small as possible). What is a + b?",
                     "√\(josa("\(n)", "을", "를")) a√b 꼴로 나타낼 때(b는 가장 작은 자연수), a + b의 값은?",
                     ans: "\(a + b)",
                     why: "\(n) = \(a * a) × \(b) = \(a)² × \(b), so √\(n) = \(a)√\(b). a + b = \(a + b).",
                     kwhy: "\(n) = \(a)² × \(b)이므로 √\(n) = \(a)√\(b). a + b = \(a + b)")
        case 3:
            let k = d.int(2...9)
            return q(u, "How many natural numbers x satisfy the inequality?", "다음을 만족하는 자연수 x는 모두 몇 개인가요?",
                     ans: "\(k * k - 1)", expr: "√x < \(k)",
                     why: "√x < \(k) means x < \(k)² = \(k * k). x = 1, 2, …, \(k * k - 1): \(k * k - 1) numbers.",
                     kwhy: "√x < \(k)이면 x < \(k)² = \(k * k). x = 1, 2, …, \(k * k - 1)로 \(k * k - 1)개예요.")
        case 4:
            let s = d.pick([2, 3, 5, 6, 7, 10, 14, 15]), m = d.int(2...5)
            let n = s * m * m
            return q(u, "√(\(n)x) is a natural number. What is the smallest natural number x?",
                     "√(\(n)x)가 자연수가 되도록 하는 가장 작은 자연수 x는?",
                     ans: "\(s)",
                     why: "\(n) = \(m)² × \(s). To make a perfect square, the leftover factor \(s) must be squared, so x = \(s). Then √(\(n * s)) = \(m * s).",
                     kwhy: "\(n) = \(m)² × \(s)예요. 제곱수가 되려면 남은 \(josa("\(s)", "을", "를")) 한 번 더 곱해야 하므로 x = \(s). 이때 √\(n * s) = \(m * s)")
        default:
            var n = d.int(2...200)
            while Int(Double(n).squareRoot()) * Int(Double(n).squareRoot()) == n { n = d.int(2...200) }
            let f = Int(Double(n).squareRoot())
            return q(u, "What is the integer part of √\(n)?", "√\(n)의 정수 부분은?",
                     ans: "\(f)",
                     why: "\(f)² = \(f * f) < \(n) < \((f + 1) * (f + 1)) = \(f + 1)², so \(f) < √\(n) < \(f + 1). The integer part is \(f).",
                     kwhy: "\(f)² = \(f * f) < \(n) < \((f + 1) * (f + 1)) = \(f + 1)²이므로 \(f) < √\(n) < \(f + 1). 정수 부분은 \(f)")
        }
    }

    // MARK: - 다항식의 곱셈과 인수분해

    static func m3Factor(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3Factor
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = nonzero(d, -9...9), b = nonzero(d, -9...9)
            let askX = d.bool()
            return q(u, "Expand the expression. What is the \(askX ? "coefficient of x" : "constant term")?",
                     "다음 식을 전개했을 때, \(askX ? "x의 계수" : "상수항")를 구하세요.",
                     ans: "\(askX ? a + b : a * b)", expr: "(\(lin(1, a)))(\(lin(1, b)))",
                     why: "(x + a)(x + b) = x² + (a + b)x + ab = \(quad(1, a + b, a * b)).",
                     kwhy: "(x + a)(x + b) = x² + (a + b)x + ab = \(quad(1, a + b, a * b))")
        case 1:
            let a = d.int(2...5), b = nonzero(d, -7...7)
            return q(u, "Expand the expression. What is the coefficient of x?", "다음 식을 전개했을 때, x의 계수를 구하세요.",
                     ans: "\(2 * a * b)", expr: "(\(lin(a, b)))²",
                     why: "(ax + b)² = a²x² + 2abx + b² = \(quad(a * a, 2 * a * b, b * b)). Coefficient of x: 2 × \(a) × \(par(b)) = \(2 * a * b).",
                     kwhy: "(ax + b)² = a²x² + 2abx + b² = \(quad(a * a, 2 * a * b, b * b)). x의 계수: 2 × \(a) × \(par(b)) = \(2 * a * b)")
        case 2:
            var a = 0, b = 0
            repeat { a = nonzero(d, -9...9); b = nonzero(d, -9...9) } while a >= b
            return q(u, "Factor the expression as (x + a)(x + b) with a < b. What is b?",
                     "다음 식을 (x + a)(x + b) (a < b) 꼴로 인수분해할 때, b의 값은?",
                     ans: "\(b)", expr: quad(1, a + b, a * b),
                     why: "Find two numbers with sum \(a + b) and product \(a * b): \(a) and \(b). So it is (\(lin(1, a)))(\(lin(1, b))), b = \(b).",
                     kwhy: "합이 \(a + b), 곱이 \(a * b)인 두 수는 \(a), \(b)예요. (\(lin(1, a)))(\(lin(1, b)))이므로 b = \(b)")
        case 3:
            let m = d.int(20...99), t = d.int(1...4)
            let n = m - t
            return q(u, "Use factoring to calculate.", "인수분해 공식을 이용하여 계산하세요.",
                     ans: "\((m + n) * t)", expr: "\(m)² - \(n)²",
                     why: "a² - b² = (a + b)(a - b): (\(m) + \(n))(\(m) - \(n)) = \(m + n) × \(t) = \((m + n) * t).",
                     kwhy: "a² - b² = (a + b)(a - b): (\(m) + \(n))(\(m) - \(n)) = \(m + n) × \(t) = \((m + n) * t)")
        case 4:
            let x = d.int(-6...9), y = d.int(-6...9)
            let s = x + y, p = x * y
            return q(u, "x + y = \(s) and xy = \(p). What is x² + y²?", "x + y = \(s), xy = \(p)일 때, x² + y²의 값은?",
                     ans: "\(s * s - 2 * p)",
                     why: "x² + y² = (x + y)² - 2xy = \(par(s))² - 2 × \(par(p)) = \(s * s) - \(par(2 * p)) = \(s * s - 2 * p).",
                     kwhy: "x² + y² = (x + y)² - 2xy = \(par(s))² - 2 × \(par(p)) = \(s * s - 2 * p)")
        default:
            let c = d.pick([20, 30, 50, 100]), k = d.int(1...4)
            return q(u, "Use a multiplication formula to calculate.", "곱셈 공식을 이용하여 계산하세요.",
                     ans: comma(c * c - k * k), expr: "\(c - k) × \(c + k)",
                     why: "(a - b)(a + b) = a² - b²: (\(c) - \(k))(\(c) + \(k)) = \(c)² - \(k)² = \(c * c) - \(k * k) = \(comma(c * c - k * k)).",
                     kwhy: "(a - b)(a + b) = a² - b²: (\(c) - \(k))(\(c) + \(k)) = \(c)² - \(k)² = \(c * c) - \(k * k) = \(comma(c * c - k * k))")
        }
    }

    // MARK: - 이차방정식

    static func m3Quadratic(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3Quadratic
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            var a = 0, b = 0
            repeat { a = d.int(-9...9); b = d.int(-9...9) } while a == b
            return q(u, "Solve the equation. What is the larger solution?", "다음 이차방정식의 두 해 중 큰 해는?",
                     ans: "\(max(a, b))", expr: "(\(lin(1, -a)))(\(lin(1, -b))) = 0",
                     why: "If a product is 0, one factor is 0: x = \(a) or x = \(b). The larger is \(max(a, b)).",
                     kwhy: "AB = 0이면 A = 0 또는 B = 0: x = \(a) 또는 x = \(b). 큰 해는 \(max(a, b))")
        case 1:
            var r1 = 0, r2 = 0
            repeat { r1 = d.int(-9...9); r2 = d.int(-9...9) } while r1 == r2
            let askSum = d.bool()
            return q(u, "Solve the equation. What is the \(askSum ? "sum of the two solutions" : "larger solution")?",
                     "다음 이차방정식을 풀 때, \(askSum ? "두 해의 합" : "두 해 중 큰 해")는?",
                     ans: "\(askSum ? r1 + r2 : max(r1, r2))", expr: "\(quad(1, -(r1 + r2), r1 * r2)) = 0",
                     why: "Factor: (\(lin(1, -r1)))(\(lin(1, -r2))) = 0, so x = \(r1) or x = \(r2).\(askSum ? " Sum: \(r1 + r2)." : " Larger: \(max(r1, r2)).")",
                     kwhy: "인수분해하면 (\(lin(1, -r1)))(\(lin(1, -r2))) = 0, x = \(r1) 또는 x = \(r2).\(askSum ? " 합: \(r1 + r2)" : " 큰 해: \(max(r1, r2))")")
        case 2:
            let k = d.int(2...15), a = d.int(1...3)
            return q(u, "What is the positive solution of the equation?", "다음 이차방정식의 양수인 해는?",
                     ans: "\(k)", expr: "\(a == 1 ? "" : "\(a)")x² = \(a * k * k)",
                     why: "x² = \(k * k), so x = ±\(k). The positive solution is \(k).",
                     kwhy: "x² = \(k * k)이므로 x = ±\(k). 양수인 해는 \(k)")
        case 3:
            var r = 0, s = 0
            repeat { r = nonzero(d, -8...8); s = nonzero(d, -8...8) } while r == s
            let c = r * s
            return q(u, "One solution of the equation is x = \(r). What is the number k?", "다음 이차방정식의 한 해가 x = \(r)일 때, k의 값은?",
                     ans: "\(-(r + s))", expr: "x² + kx \(c < 0 ? "-" : "+") \(abs(c)) = 0",
                     why: "Put x = \(r): \(r * r) + \(r)k + \(par(c)) = 0, so \(r)k = \(-(r * r + c)), k = \(-(r + s)).",
                     kwhy: "x = \(josa("\(r)", "을", "를")) 대입하면 \(r * r) + \(r)k + \(par(c)) = 0, \(r)k = \(-(r * r + c)), k = \(-(r + s))")
        case 4:
            let n = d.int(3...20)
            return q(u, "The product of two consecutive natural numbers is \(n * (n + 1)). What is the smaller number?",
                     "연속하는 두 자연수의 곱이 \(n * (n + 1))이에요. 두 수 중 작은 수는?",
                     ans: "\(n)",
                     why: "x(x + 1) = \(n * (n + 1)), x² + x - \(n * (n + 1)) = 0, (x - \(n))(x + \(n + 1)) = 0. x is natural, so x = \(n).",
                     kwhy: "x(x + 1) = \(n * (n + 1)), x² + x - \(n * (n + 1)) = 0, (x - \(n))(x + \(n + 1)) = 0. x는 자연수이므로 x = \(n)")
        default:
            let kind = d.int(0...2)
            var b = 0, c = 0
            switch kind {
            case 0:
                b = d.int(1...5) * 2 * (d.bool() ? 1 : -1); c = b * b / 4
            case 1:
                repeat { b = nonzero(d, -8...8); c = d.int(-10...10) } while b * b - 4 * c <= 0
            default:
                repeat { b = d.int(-6...6); c = d.int(1...20) } while b * b - 4 * c >= 0
            }
            let disc = b * b - 4 * c
            let ans = disc > 0 ? "2" : disc == 0 ? "1" : "0"
            return qc(u, "How many real solutions does \(quad(1, b, c)) = 0 have?",
                      "이차방정식 \(quad(1, b, c)) = 0의 서로 다른 실근의 개수는?",
                      ans: ans, wrong: ["0", "1", "2"].filter { $0 != ans }, d: d,
                      why: "Discriminant b² - 4ac = \(par(b))² - 4 × 1 × \(par(c)) = \(disc). \(disc > 0 ? "Positive: 2 solutions." : disc == 0 ? "Zero: 1 (double) solution." : "Negative: no real solutions.")",
                      kwhy: "판별식 b² - 4ac = \(par(b))² - 4 × 1 × \(par(c)) = \(disc). \(disc > 0 ? "양수이므로 2개" : disc == 0 ? "0이므로 1개(중근)" : "음수이므로 0개")")
        }
    }

    // MARK: - 이차함수

    static func m3QFunc(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3QFunc
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = nonzero(d, -3...3), p = d.int(-6...6), qv = d.int(-9...9)
            let askX = d.bool()
            return q(u, "What is the \(askX ? "x" : "y")-coordinate of the vertex of the graph of \(vertexForm(a, p, qv))?",
                     "\(vertexForm(a, p, qv))의 그래프의 꼭짓점의 \(askX ? "x" : "y")좌표는?",
                     ans: "\(askX ? p : qv)",
                     why: "The graph of y = a(x - p)² + q has its vertex at (p, q) = (\(p), \(qv)).",
                     kwhy: "y = a(x - p)² + q의 꼭짓점은 (p, q)예요: (\(p), \(qv))")
        case 1:
            let p = d.int(-5...5), c = d.int(-10...10)
            let b = -2 * p
            let vy = c - p * p
            return q(u, "What is the y-coordinate of the vertex of the graph of y = \(quad(1, b, c))?",
                     "y = \(quad(1, b, c))의 그래프의 꼭짓점의 y좌표는?",
                     ans: "\(vy)",
                     why: "Complete the square: y = (x \(p < 0 ? "+ \(-p)" : "- \(p)"))² - \(p * p) + \(par(c)) = (x \(p < 0 ? "+ \(-p)" : "- \(p)"))² + \(par(vy)). The vertex is (\(p), \(vy)).",
                     kwhy: "완전제곱식으로 고치면 y = (x \(p < 0 ? "+ \(-p)" : "- \(p)"))² - \(p * p) + \(par(c)) = (x \(p < 0 ? "+ \(-p)" : "- \(p)"))² + \(par(vy)). 꼭짓점은 (\(p), \(vy))")
        case 2:
            let a = nonzero(d, -3...3), b = d.int(-6...6), c = d.int(-9...9), v = d.int(-4...4)
            return q(u, "For y = \(quad(a, b, c)), what is y when x = \(v)?", "y = \(quad(a, b, c))에서 x = \(v)일 때 y의 값은?",
                     ans: "\(a * v * v + b * v + c)",
                     why: "y = \(a) × \(par(v))² + \(par(b)) × \(par(v)) + \(par(c)) = \(a * v * v) + \(par(b * v)) + \(par(c)) = \(a * v * v + b * v + c).",
                     kwhy: "y = \(a) × \(par(v))² + \(par(b)) × \(par(v)) + \(par(c)) = \(a * v * v + b * v + c)")
        case 3:
            let a = nonzero(d, -3...3), p = d.int(-5...5), qv = d.int(-9...9)
            return q(u, "What is the y-intercept of the graph of \(vertexForm(a, p, qv))?", "\(vertexForm(a, p, qv))의 그래프의 y절편은?",
                     ans: "\(a * p * p + qv)",
                     why: "Put x = 0: y = \(a) × \(par(-p))² + \(par(qv)) = \(a * p * p) + \(par(qv)) = \(a * p * p + qv).",
                     kwhy: "x = 0을 넣으면 y = \(a) × \(par(-p))² + \(par(qv)) = \(a * p * p + qv)")
        case 4:
            let p = d.int(-5...5), c = d.int(-10...10)
            let b = 2 * p
            let mx = c + p * p
            return q(u, "What is the maximum value of y = \(quad(-1, b, c))?", "y = \(quad(-1, b, c))의 최댓값은?",
                     ans: "\(mx)",
                     why: "y = -(x² \(b < 0 ? "+ \(-b)" : "- \(b)")x) + \(par(c)) = -(x \(p < 0 ? "+ \(-p)" : "- \(p)"))² + \(p * p) + \(par(c)) = -(x \(p < 0 ? "+ \(-p)" : "- \(p)"))² + \(par(mx)). The graph opens down, so the maximum is \(mx) (at x = \(p)).",
                     kwhy: "y = -(x \(p < 0 ? "+ \(-p)" : "- \(p)"))² + \(par(mx))로 고칠 수 있어요. 위로 볼록한 그래프이므로 x = \(p)일 때 최댓값 \(mx)")
        default:
            let a = nonzero(d, -3...3), k = d.int(1...3) * (d.bool() ? 1 : -1)
            var m = d.int(-4...4)
            while m == k || m == 0 { m = d.int(-4...4) }
            return q(u, "The graph of y = ax² passes through the point (\(k), \(a * k * k)). What is y when x = \(m)?",
                     "y = ax²의 그래프가 점 (\(k), \(a * k * k))를 지날 때, x = \(m)에서 y의 값은?",
                     ans: "\(a * m * m)",
                     why: "\(a * k * k) = a × \(par(k))² = \(k * k)a, so a = \(a). y = \(a) × \(par(m))² = \(a * m * m).",
                     kwhy: "\(a * k * k) = a × \(par(k))² = \(k * k)a이므로 a = \(a). y = \(a) × \(par(m))² = \(a * m * m)")
        }
    }

    // MARK: - 삼각비

    static func m3Trig(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3Trig
        let (a, b, c) = d.pick(triples)
        let setup = "In right triangle ABC, angle C = 90°, BC = \(a), CA = \(b), and AB = \(c)."
        let setupKo = "∠C = 90°인 직각삼각형 ABC에서 BC = \(a), CA = \(b), AB = \(c)예요."
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            return q(u, setup + " What is sin A?", setupKo + " sin A의 값은?", ans: Frac(a, c).mixed,
                     why: "sin A = (opposite side) ÷ (hypotenuse) = BC ÷ AB = \(simp(a, c)).",
                     kwhy: "sin A = (높이) ÷ (빗변) = BC ÷ AB = \(simp(a, c))")
        case 1:
            return q(u, setup + " What is cos A?", setupKo + " cos A의 값은?", ans: Frac(b, c).mixed,
                     why: "cos A = (adjacent side) ÷ (hypotenuse) = CA ÷ AB = \(simp(b, c)).",
                     kwhy: "cos A = (밑변) ÷ (빗변) = CA ÷ AB = \(simp(b, c))")
        case 2:
            return q(u, setup + " What is tan A?", setupKo + " tan A의 값은?", ans: Frac(a, b).mixed,
                     why: "tan A = (opposite side) ÷ (adjacent side) = BC ÷ CA = \(simp(a, b)).",
                     kwhy: "tan A = (높이) ÷ (밑변) = BC ÷ CA = \(simp(a, b))")
        case 3:
            let vals: [(String, Frac)] = [("sin 30°", Frac(1, 2)), ("cos 60°", Frac(1, 2)), ("tan 45°", Frac(1)), ("sin 90°", Frac(1)), ("cos 0°", Frac(1))]
            let x = d.pick(vals), y = d.pick(vals)
            let plus = d.bool()
            let ans = plus ? Frac(x.1.n * y.1.d + y.1.n * x.1.d, x.1.d * y.1.d) : x.1 * y.1
            return q(u, "Calculate.", "계산하세요.", ans: ans.mixed, expr: "\(x.0) \(plus ? "+" : "×") \(y.0)",
                     why: "\(x.0) = \(x.1.mixed), \(y.0) = \(y.1.mixed). \(x.1.mixed) \(plus ? "+" : "×") \(y.1.mixed) = \(ans.mixed).",
                     kwhy: "\(x.0) = \(x.1.mixed), \(y.0) = \(y.1.mixed)이므로 \(x.1.mixed) \(plus ? "+" : "×") \(y.1.mixed) = \(ans.mixed)")
        case 4:
            let l = d.int(2...10) * 2
            return q(u, "A ladder \(l) m long leans against a wall and makes a 30° angle with the ground. How high up the wall does it reach?",
                     "길이가 \(l) m인 사다리가 벽에 기대어 땅과 30°를 이루고 있어요. 사다리가 닿는 벽의 높이는 몇 m인가요?",
                     ans: "\(l / 2)", unit: "m",
                     why: "Height = \(l) × sin 30° = \(l) × 1/2 = \(l / 2) m.",
                     kwhy: "높이 = \(l) × sin 30° = \(l) × 1/2 = \(l / 2) m")
        default:
            let m = d.int(1...3)
            return q(u, "In a right triangle with angle C = 90°, tan A = \(simp(a, b).components(separatedBy: " = ").last!) and the hypotenuse AB = \(c * m). What is the area of the triangle?",
                     "∠C = 90°인 직각삼각형 ABC에서 tan A = \(simp(a, b).components(separatedBy: " = ").last!)이고 빗변 AB = \(c * m)일 때, 삼각형의 넓이는?",
                     ans: Frac(a * b * m * m, 2).mixed,
                     why: "tan A = BC : CA = \(a) : \(b). With hypotenuse \(c * m), the sides are BC = \(a * m), CA = \(b * m) (a \(a)-\(b)-\(c) triangle × \(m)). Area = \(a * m) × \(b * m) ÷ 2 = \(Frac(a * b * m * m, 2).mixed).",
                     kwhy: "tan A = BC : CA = \(a) : \(b)이고 빗변이 \(c * m)이므로 BC = \(a * m), CA = \(b * m)이에요. 넓이 = \(a * m) × \(b * m) ÷ 2 = \(Frac(a * b * m * m, 2).mixed)")
        }
    }

    // MARK: - 원의 성질

    static func m3Circle(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3Circle
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let c = d.int(20...80) * 2
            return q(u, "In circle O, the central angle AOB is \(c)°. What is the inscribed angle ACB on the same arc AB?",
                     "원 O에서 호 AB에 대한 중심각 ∠AOB가 \(c)°일 때, 같은 호에 대한 원주각 ∠ACB의 크기는?",
                     ans: "\(c / 2)", unit: "°",
                     why: "An inscribed angle is half the central angle on the same arc: \(c) ÷ 2 = \(c / 2)°.",
                     kwhy: "원주각의 크기는 같은 호에 대한 중심각의 1/2이에요: \(c) ÷ 2 = \(c / 2)°")
        case 1:
            let a = d.int(15...75)
            return q(u, "AB is a diameter of a circle and C is a point on the circle. Angle CAB is \(a)°. What is angle CBA?",
                     "AB가 원의 지름이고 점 C는 원 위의 점이에요. ∠CAB = \(a)°일 때, ∠CBA의 크기는?",
                     ans: "\(90 - a)", unit: "°",
                     why: "An angle in a semicircle is 90°, so angle ACB = 90°. Angle CBA = 180 - 90 - \(a) = \(90 - a)°.",
                     kwhy: "반원에 대한 원주각은 90°이므로 ∠ACB = 90°. ∠CBA = 180° - 90° - \(a)° = \(90 - a)°")
        case 2:
            let (r, dist, half) = d.pick([(5, 3, 4), (10, 6, 8), (13, 5, 12), (17, 8, 15), (25, 7, 24), (15, 9, 12), (10, 8, 6)])
            return q(u, "A circle has a radius of \(r) cm. A chord is \(dist) cm away from the center. How long is the chord?",
                     "반지름이 \(r) cm인 원에서 중심으로부터 \(dist) cm 떨어진 현의 길이는 몇 cm인가요?",
                     ans: "\(2 * half)", unit: "cm",
                     why: "The perpendicular from the center cuts the chord in half. Half = √(\(r)² - \(dist)²) = √\(r * r - dist * dist) = \(half). Chord = \(half) × 2 = \(2 * half) cm.",
                     kwhy: "원의 중심에서 현에 내린 수선은 현을 이등분해요. 현의 절반 = √(\(r)² - \(dist)²) = √\(r * r - dist * dist) = \(half). 현 = \(half) × 2 = \(2 * half) cm")
        case 3:
            let a = d.int(50...130)
            return q(u, "Quadrilateral ABCD is inscribed in a circle. Angle A is \(a)°. What is angle C?",
                     "원에 내접하는 사각형 ABCD에서 ∠A = \(a)°일 때, ∠C의 크기는?",
                     ans: "\(180 - a)", unit: "°",
                     why: "Opposite angles of a quadrilateral inscribed in a circle add up to 180°: 180 - \(a) = \(180 - a)°.",
                     kwhy: "원에 내접하는 사각형의 마주 보는 두 각의 합은 180°예요: 180° - \(a)° = \(180 - a)°")
        case 4:
            let p = d.int(20...140)
            return q(u, "From a point P outside circle O, two tangent lines touch the circle at A and B. Angle APB is \(p)°. What is angle AOB?",
                     "원 O 밖의 점 P에서 그은 두 접선이 원과 점 A, B에서 만나요. ∠APB = \(p)°일 때, ∠AOB의 크기는?",
                     ans: "\(180 - p)", unit: "°",
                     why: "A tangent is perpendicular to the radius, so angle OAP = angle OBP = 90°. In quadrilateral OAPB: 360 - 90 - 90 - \(p) = \(180 - p)°.",
                     kwhy: "접선은 반지름과 수직이므로 ∠OAP = ∠OBP = 90°. 사각형 OAPB에서 360° - 90° - 90° - \(p)° = \(180 - p)°")
        default:
            let (m, n) = d.pick([(1, 2), (2, 3), (1, 3), (3, 4), (2, 5)])
            let unit = d.int(5...20)
            let a = m * unit
            return q(u, "In a circle, arc AB : arc CD = \(m) : \(n). The inscribed angle on arc AB is \(a)°. What is the inscribed angle on arc CD?",
                     "한 원에서 호 AB와 호 CD의 길이의 비가 \(m) : \(n)이에요. 호 AB에 대한 원주각이 \(a)°일 때, 호 CD에 대한 원주각은?",
                     ans: "\(n * unit)", unit: "°",
                     why: "Inscribed angles are proportional to their arcs: \(a) × \(n)/\(m) = \(n * unit)°.",
                     kwhy: "원주각의 크기는 호의 길이에 정비례해요: \(a) × \(n)/\(m) = \(n * unit)°")
        }
    }

    // MARK: - 통계 (산포도)

    /// 편차 5개 (합 0, 분산이 정수)
    private static func deviations(_ d: Dice, square: Bool) -> [Int] {
        while true {
            var v = (0..<4).map { _ in d.int(-4...4) }
            v.append(-v.reduce(0, +))
            let ss = v.map { $0 * $0 }.reduce(0, +)
            guard abs(v[4]) <= 6, ss % 5 == 0, ss > 0 else { continue }
            let variance = ss / 5
            if !square || [1, 4, 9, 16].contains(variance) { return v }
        }
    }

    static func m3Stats(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m3Stats
        let mean = d.int(10...80)
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let x = mean + nonzero(d, -15...15)
            return q(u, "The mean of a data set is \(mean). What is the deviation of the value \(x)?",
                     "어떤 자료의 평균이 \(mean)일 때, 변량 \(x)의 편차는?",
                     ans: "\(x - mean)",
                     why: "Deviation = value - mean = \(x) - \(mean) = \(x - mean).",
                     kwhy: "편차 = (변량) - (평균) = \(x) - \(mean) = \(x - mean)")
        case 1, 2:
            let sd = d.bool()
            let dev = deviations(d, square: sd)
            let data = dev.map { mean + $0 }
            let ss = dev.map { $0 * $0 }.reduce(0, +)
            let variance = ss / 5
            let s = Int(Double(variance).squareRoot())
            return q(u, "Find the \(sd ? "standard deviation" : "variance") of the data: \(data.map(String.init).joined(separator: ", ")).",
                     "다음 자료의 \(sd ? "표준편차" : "분산")를 구하세요: \(data.map(String.init).joined(separator: ", "))",
                     ans: "\(sd ? s : variance)",
                     why: "Mean = \(mean). Deviations: \(dev.map(String.init).joined(separator: ", ")). Variance = (sum of squared deviations) ÷ 5 = \(ss) ÷ 5 = \(variance).\(sd ? " Standard deviation = √\(variance) = \(s)." : "")",
                     kwhy: "평균 = \(mean). 편차: \(dev.map(String.init).joined(separator: ", ")). 분산 = (편차의 제곱의 합) ÷ 5 = \(ss) ÷ 5 = \(variance)\(sd ? ". 표준편차 = √\(variance) = \(s)" : "")")
        case 3:
            let dev = deviations(d, square: false)
            let shown = dev.prefix(4).map(String.init).joined(separator: ", ")
            return q(u, "Five values have deviations \(shown), and x. What is x?", "변량 5개의 편차가 각각 \(shown), x일 때, x의 값은?",
                     ans: "\(dev[4])",
                     why: "The sum of all deviations is always 0: x = -(\(dev.prefix(4).map(String.init).joined(separator: " + "))) = \(dev[4]).",
                     kwhy: "편차의 합은 항상 0이에요: x = -(\(dev.prefix(4).map(String.init).joined(separator: " + "))) = \(dev[4])")
        case 4:
            let dev = deviations(d, square: false)
            let ss = dev.map { $0 * $0 }.reduce(0, +)
            let shown = dev.prefix(4).map(String.init).joined(separator: ", ")
            return q(u, "Five values have deviations \(shown), and x. What is the variance?", "변량 5개의 편차가 각각 \(shown), x일 때, 분산은?",
                     ans: "\(ss / 5)",
                     why: "Deviations add up to 0, so x = \(dev[4]). Variance = (\(dev.map { "\(par($0))²" }.joined(separator: " + "))) ÷ 5 = \(ss) ÷ 5 = \(ss / 5).",
                     kwhy: "편차의 합은 0이므로 x = \(dev[4]). 분산 = (\(dev.map { "\(par($0))²" }.joined(separator: " + "))) ÷ 5 = \(ss) ÷ 5 = \(ss / 5)")
        default:
            let v = d.int(2...30), add = d.int(2...10)
            return q(u, "A data set has a variance of \(v). If \(add) is added to every value, what is the new variance?",
                     "분산이 \(v)인 자료의 모든 변량에 \(josa("\(add)", "을", "를")) 더하면 새 자료의 분산은?",
                     ans: "\(v)",
                     why: "Adding the same number moves the mean by \(add) too, so every deviation stays the same. The variance stays \(v).",
                     kwhy: "모든 변량에 같은 수를 더하면 평균도 \(add)만큼 커져서 편차는 그대로예요. 그래서 분산도 \(v) 그대로예요.")
        }
    }
}
