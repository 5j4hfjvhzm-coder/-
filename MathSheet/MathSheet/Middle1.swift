import Foundation

/// 중학교 1학년 문제
extension Generator {
    /// 소인수분해 표기: [2: 3, 3: 1] → "2³ × 3"
    static func factorText(_ f: [(Int, Int)]) -> String {
        f.filter { $0.1 > 0 }.map { $0.1 == 1 ? "\($0.0)" : "\($0.0)\(sup($0.1))" }.joined(separator: " × ")
    }

    // MARK: - 소인수분해

    static func m1Prime(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Prime
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            var a = 0, b = 0, c = 0, n = 0
            repeat { a = d.int(1...4); b = d.int(0...2); c = d.int(0...1); n = ipow(2, a) * ipow(3, b) * ipow(5, c) } while n > 1000 || n < 12
            let cnt = (a + 1) * (b + 1) * (c + 1)
            let ft = factorText([(2, a), (3, b), (5, c)])
            let formula = [a, b, c].filter { $0 > 0 }.map { "(\($0) + 1)" }.joined(separator: " × ")
            return q(u, "How many divisors does \(n) have?", "\(n)의 약수는 모두 몇 개인가요?",
                     ans: "\(cnt)", unit: "divisors",
                     why: "\(n) = \(ft). Number of divisors = (each exponent + 1) multiplied: \(formula) = \(cnt).",
                     kwhy: "\(n) = \(ft). 약수의 개수 = (각 지수 + 1)의 곱: \(formula) = \(cnt)개")
        case 1:
            let a = d.int(1...5), b = d.int(1...3)
            let n = ipow(2, a) * ipow(3, b)
            return q(u, "Write \(n) as a product of prime factors: \(n) = 2^□ × 3^△. What is □ + △?",
                     "\(josa("\(n)", "을", "를")) 소인수분해하면 2^□ × 3^△이에요. □ + △의 값은?",
                     ans: "\(a + b)",
                     why: "Keep dividing by primes: \(n) = \(factorText([(2, a), (3, b)])). So □ = \(a), △ = \(b), and □ + △ = \(a + b).",
                     kwhy: "소수로 계속 나누면 \(n) = \(factorText([(2, a), (3, b)]))예요. □ = \(a), △ = \(b)이므로 □ + △ = \(a + b)")
        case 2, 3:
            var g = 0, p = 0, r = 0
            repeat { g = d.int(2...12); p = d.int(2...9); r = d.int(2...9) } while p == r || Frac.gcd(p, r) != 1
            let x = g * p, y = g * r
            if d.bool() {
                return q(u, "What is the greatest common factor (GCF) of \(x) and \(y)?", "\(josa("\(x)", "과", "와")) \(y)의 최대공약수를 구하세요.",
                         ans: "\(g)",
                         why: "\(x) = \(g) × \(p) and \(y) = \(g) × \(r), and \(p) and \(r) share no common factor. GCF = \(g).",
                         kwhy: "\(x) = \(g) × \(p), \(y) = \(g) × \(r)이고 \(josa("\(p)", "과", "와")) \(josa("\(r)", "은", "는")) 서로소예요. 최대공약수 = \(g)")
            } else {
                return q(u, "What is the least common multiple (LCM) of \(x) and \(y)?", "\(josa("\(x)", "과", "와")) \(y)의 최소공배수를 구하세요.",
                         ans: "\(g * p * r)",
                         why: "\(x) = \(g) × \(p), \(y) = \(g) × \(r). LCM = \(g) × \(p) × \(r) = \(g * p * r).",
                         kwhy: "\(x) = \(g) × \(p), \(y) = \(g) × \(r). 최소공배수 = \(g) × \(p) × \(r) = \(g * p * r)")
            }
        case 4:
            var a = 0, b = 0, c = 0, n = 0, m = 1
            repeat {
                a = d.int(1...4); b = d.int(0...3); c = d.int(0...2)
                n = ipow(2, a) * ipow(3, b) * ipow(5, c)
                m = (a % 2 == 1 ? 2 : 1) * (b % 2 == 1 ? 3 : 1) * (c % 2 == 1 ? 5 : 1)
            } while m == 1 || n > 5000
            return q(u, "What is the smallest natural number you can multiply by \(n) to make it the square of a natural number?",
                     "\(n)에 가능한 한 작은 자연수를 곱하여 어떤 자연수의 제곱이 되게 하려고 해요. 곱해야 하는 가장 작은 자연수는?",
                     ans: "\(m)",
                     why: "\(n) = \(factorText([(2, a), (3, b), (5, c)])). A perfect square has all even exponents, so multiply the primes with odd exponents: \(m).",
                     kwhy: "\(n) = \(factorText([(2, a), (3, b), (5, c)])). 제곱수는 모든 지수가 짝수여야 하므로, 지수가 홀수인 소인수를 곱해요: \(m)")
        default:
            var x = 0, y = 0
            repeat { x = d.pick([6, 8, 9, 10, 12, 15, 18, 20]); y = d.pick([6, 8, 9, 10, 12, 15, 18, 20]) } while x == y
            let l = x * y / Frac.gcd(x, y)
            return q(u, "Bus A leaves every \(x) minutes and bus B leaves every \(y) minutes. Both left at 9:00. In how many minutes will they next leave at the same time?",
                     "A 버스는 \(x)분마다, B 버스는 \(y)분마다 출발해요. 9시에 두 버스가 동시에 출발했다면, 다음에 동시에 출발하는 것은 몇 분 후인가요?",
                     ans: "\(l)", unit: "minutes",
                     why: "They leave together again after the least common multiple of \(x) and \(y): LCM = \(l) minutes.",
                     kwhy: "\(josa("\(x)", "과", "와")) \(y)의 최소공배수만큼 지나면 다시 동시에 출발해요: \(l)분 후")
        }
    }

    static func ipow(_ b: Int, _ e: Int) -> Int { (0..<max(e, 0)).reduce(1) { r, _ in r * b } }

    // MARK: - 정수와 유리수

    static func m1Integer(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Integer
        let calc = "Calculate."
        let calcKo = "계산하세요."
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = nonzero(d, -9...9), b = nonzero(d, -9...9), c = nonzero(d, -9...9)
            let ans = a + b - c
            return q(u, calc, calcKo, ans: "\(ans)", expr: "\(sgn(a)) + \(sgn(b)) - \(sgn(c))",
                     why: "Subtracting a number is the same as adding its opposite: \(sgn(a)) + \(sgn(b)) + \(sgn(-c)) = \(ans).",
                     kwhy: "빼기는 부호를 바꾼 수를 더하는 것과 같아요: \(sgn(a)) + \(sgn(b)) + \(sgn(-c)) = \(ans)")
        case 1:
            var a = 0, b = 0, c = 0
            repeat { a = nonzero(d, -9...9); b = nonzero(d, -9...9); c = nonzero(d, -6...6) } while (a * b) % c != 0
            let ans = a * b / c
            let negs = [a, b, c].filter { $0 < 0 }.count
            return q(u, calc, calcKo, ans: "\(ans)", expr: "\(sgn(a)) × \(sgn(b)) ÷ \(sgn(c))",
                     why: "There \(negs == 1 ? "is" : "are") \(negs) negative number\(negs == 1 ? "" : "s"), so the sign is \(negs % 2 == 0 ? "+" : "−"). \(abs(a)) × \(abs(b)) ÷ \(abs(c)) = \(abs(ans)). Answer: \(ans).",
                     kwhy: "음수가 \(negs)개이므로 부호는 \(negs % 2 == 0 ? "+" : "−")예요. \(abs(a)) × \(abs(b)) ÷ \(abs(c)) = \(abs(ans)). 답: \(ans)")
        case 2:
            let a = nonzero(d, -15...15), b = nonzero(d, -15...15)
            return q(u, calc, calcKo, ans: "\(abs(a) + abs(b))", expr: "|\(a)| + |\(b)|",
                     why: "The absolute value is the distance from 0, so it is never negative: |\(a)| = \(abs(a)), |\(b)| = \(abs(b)). \(abs(a)) + \(abs(b)) = \(abs(a) + abs(b)).",
                     kwhy: "절댓값은 0으로부터의 거리라서 항상 0 이상이에요: |\(a)| = \(abs(a)), |\(b)| = \(abs(b)). \(abs(a)) + \(abs(b)) = \(abs(a) + abs(b))")
        case 3:
            let lo = d.int(-9 ... -1), hi = d.int(1...9)
            return q(u, "How many integers x satisfy the condition below?", "다음을 만족하는 정수 x는 모두 몇 개인가요?",
                     ans: "\(hi - lo)", expr: "\(lo) < x ≤ \(hi)",
                     why: "x can be \(lo + 1), \(lo + 2), …, \(hi) (\(lo) is not included, \(hi) is). From \(lo + 1) to \(hi) there are \(hi - lo) integers.",
                     kwhy: "x는 \(lo + 1), \(lo + 2), …, \(hi)예요 (\(josa("\(lo)", "은", "는")) 포함하지 않고 \(josa("\(hi)", "은", "는")) 포함해요). 모두 \(hi - lo)개예요.")
        case 4:
            let b1 = d.int(-3 ... -2), e1 = d.int(2...3), k = d.int(2...4)
            let b2 = d.int(-4 ... -2), dv = d.pick([2, 4])
            let p1 = ipow(b1, e1), p2 = ipow(b2, 2)
            var ans = p1 * k
            let part2 = p2 / dv
            let exact = p2 % dv == 0
            if exact { ans -= part2 }
            let exprText = exact ? "(\(b1))\(sup(e1)) × \(k) - (\(b2))² ÷ \(dv)" : "(\(b1))\(sup(e1)) × \(k) - (\(b2))²"
            if !exact { ans = p1 * k - p2 }
            let second = exact ? "(\(b2))² ÷ \(dv) = \(p2) ÷ \(dv) = \(part2)" : "(\(b2))² = \(p2)"
            return q(u, calc, calcKo, ans: "\(ans)", expr: exprText,
                     why: "Powers first: (\(b1))\(sup(e1)) = \(p1) (an \(e1 % 2 == 0 ? "even" : "odd") power of a negative number is \(e1 % 2 == 0 ? "positive" : "negative")). \(p1) × \(k) = \(p1 * k). Then \(second). \(p1 * k) - \(exact ? part2 : p2) = \(ans).",
                     kwhy: "거듭제곱을 먼저 계산해요: (\(b1))\(sup(e1)) = \(p1) (음수를 \(e1 % 2 == 0 ? "짝수" : "홀수")번 곱하면 \(e1 % 2 == 0 ? "양수" : "음수")). \(p1) × \(k) = \(p1 * k). 다음으로 \(second). \(p1 * k) - \(exact ? part2 : p2) = \(ans)")
        default:
            var p = 0, r = 0
            repeat { p = d.int(-15 ... -1); r = d.int(1...15) } while (p + r) % 2 != 0
            let mid = (p + r) / 2
            return q(u, "On a number line, what number is exactly halfway between \(p) and \(r)?",
                     "수직선 위에서 \(josa("\(p)", "과", "와")) \(r)의 한가운데에 있는 수는 무엇인가요?",
                     ans: "\(mid)",
                     why: "The distance between them is \(r) - (\(p)) = \(r - p). Half of it is \((r - p) / 2). \(p) + \((r - p) / 2) = \(mid).",
                     kwhy: "두 수 사이의 거리는 \(r) - (\(p)) = \(r - p)예요. 그 절반은 \((r - p) / 2). \(p) + \((r - p) / 2) = \(mid)")
        }
    }

    // MARK: - 문자와 식

    static func m1Expr(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Expr
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = nonzero(d, -6...6), b = d.int(-9...9), v = nonzero(d, -5...5)
            return q(u, "Find the value of the expression when x = \(v).", "x = \(v)일 때, 다음 식의 값을 구하세요.",
                     ans: "\(a * v + b)", expr: lin(a, b),
                     why: "Put \(par(v)) in place of x: \(a) × \(par(v))\(b == 0 ? "" : b > 0 ? " + \(b)" : " - \(-b)") = \(a * v + b).",
                     kwhy: "x 대신 \(par(v)) 넣어요: \(a) × \(par(v))\(b == 0 ? "" : b > 0 ? " + \(b)" : " - \(-b)") = \(a * v + b)")
        case 1:
            let a1 = nonzero(d, -6...6), b1 = d.int(-9...9), a2 = nonzero(d, -6...6), b2 = d.int(-9...9)
            let askX = d.bool()
            let ans = askX ? a1 - a2 : b1 - b2
            return q(u, "Simplify the expression below. What is the \(askX ? "coefficient of x" : "constant term")?",
                     "다음 식을 간단히 했을 때, \(askX ? "x의 계수" : "상수항")를 구하세요.",
                     ans: "\(ans)", expr: "(\(lin(a1, b1))) - (\(lin(a2, b2)))",
                     why: "Change the signs inside the second bracket: \(lin(a1, b1)) \(lin(-a2, -b2).hasPrefix("-") ? "" : "+ ")\(lin(-a2, -b2)) = \(lin(a1 - a2, b1 - b2)).",
                     kwhy: "뒤 괄호 앞이 -이므로 괄호 안의 부호를 바꿔요: \(lin(a1 - a2, b1 - b2)). \(askX ? "x의 계수" : "상수항"): \(ans)")
        case 2:
            let k = nonzero(d, -5...5), a = nonzero(d, -5...5), b = d.int(-6...6)
            let m = nonzero(d, -5...5), c = nonzero(d, -5...5), e = d.int(-6...6)
            let askX = d.bool()
            let ans = askX ? k * a - m * c : k * b - m * e
            return q(u, "Simplify the expression below. What is the \(askX ? "coefficient of x" : "constant term")?",
                     "다음 식을 간단히 했을 때, \(askX ? "x의 계수" : "상수항")를 구하세요.",
                     ans: "\(ans)", expr: "\(k)(\(lin(a, b))) - \(par(m))(\(lin(c, e)))",
                     why: "Distribute: \(lin(k * a, k * b)) and \(lin(m * c, m * e)). Subtract: \(lin(k * a - m * c, k * b - m * e)).",
                     kwhy: "분배법칙으로 괄호를 풀면 앞의 식은 \(lin(k * a, k * b)), 뒤의 식은 \(lin(m * c, m * e)). 빼면 \(lin(k * a - m * c, k * b - m * e))예요.")
        case 3:
            let p = d.int(3...12) * 100, e = d.int(5...15) * 100, n = d.int(2...9)
            return q(u, "A pencil costs \(comma(p)) won and an eraser costs \(comma(e)) won. The total cost of x pencils and 1 eraser is (\(p)x + \(e)) won. What is the total when x = \(n)?",
                     "연필 한 자루는 \(comma(p))원, 지우개 한 개는 \(comma(e))원이에요. 연필 x자루와 지우개 1개의 값은 (\(p)x + \(e))원이에요. x = \(n)일 때 전체 값은 얼마인가요?",
                     ans: comma(p * n + e), unit: "won",
                     why: "\(p) × \(n) + \(e) = \(comma(p * n + e)) won",
                     kwhy: "\(p) × \(n) + \(e) = \(comma(p * n + e))원")
        case 4:
            let a = nonzero(d, -4...4), b = nonzero(d, -4...4), k = nonzero(d, -4...4)
            let ans = a * a + k * a * b - b * b
            let mid = k == 1 ? " + xy" : k == -1 ? " - xy" : k > 0 ? " + \(k)xy" : " - \(-k)xy"
            return q(u, "Find the value of the expression when x = \(a) and y = \(b).", "x = \(a), y = \(b)일 때, 다음 식의 값을 구하세요.",
                     ans: "\(ans)", expr: "x²\(mid) - y²",
                     why: "x² = \(par(a))² = \(a * a), \(k)xy = \(k) × \(par(a)) × \(par(b)) = \(k * a * b), y² = \(b * b). \(a * a) + \(par(k * a * b)) - \(b * b) = \(ans).",
                     kwhy: "x² = \(par(a))² = \(a * a), \(k)xy = \(k) × \(par(a)) × \(par(b)) = \(k * a * b), y² = \(b * b). \(a * a) + \(par(k * a * b)) - \(b * b) = \(ans)")
        default:
            let n = d.int(-10...30)
            let s = 3 * n
            return q(u, "The sum of three consecutive integers is \(s). What is the largest of the three?",
                     "연속하는 세 정수의 합이 \(s)예요. 세 정수 중 가장 큰 수는 무엇인가요?",
                     ans: "\(n + 1)",
                     why: "Call them n - 1, n, n + 1. Their sum is 3n = \(s), so n = \(n). The largest is \(n + 1).",
                     kwhy: "세 정수를 n - 1, n, n + 1이라 하면 합은 3n = \(s), n = \(n)이에요. 가장 큰 수는 \(n + 1)")
        }
    }

    // MARK: - 일차방정식

    static func m1Equation(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Equation
        let solve = "Solve for x."
        let solveKo = "다음 방정식의 해를 구하세요."
        let x = d.int(-10...10)
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = nonzero(d, -7...7), b = d.int(-12...12)
            let c = a * x + b
            return q(u, solve, solveKo, ans: "\(x)", expr: "\(lin(a, b)) = \(c)",
                     why: "Move \(b) to the other side: \(lin(a, 0)) = \(c) - \(par(b)) = \(c - b). Divide by \(a): x = \(x).",
                     kwhy: "\(josa("\(b)", "을", "를")) 이항하면 \(lin(a, 0)) = \(c) - \(par(b)) = \(c - b). 양변을 \(a)로 나누면 x = \(x)")
        case 1:
            var a = 0, c = 0
            repeat { a = nonzero(d, -7...7); c = nonzero(d, -7...7) } while a == c
            let b = d.int(-12...12)
            let e = (a - c) * x + b
            return q(u, solve, solveKo, ans: "\(x)", expr: "\(lin(a, b)) = \(lin(c, e))",
                     why: "Move x terms to the left and numbers to the right: \(lin(a - c, 0)) = \(e) - \(par(b)) = \(e - b). So x = \(e - b) ÷ \(par(a - c)) = \(x).",
                     kwhy: "x항은 왼쪽, 상수항은 오른쪽으로 이항해요: \(lin(a - c, 0)) = \(e) - \(par(b)) = \(e - b). x = \(e - b) ÷ \(par(a - c)) = \(x)")
        case 2:
            let k = nonzero(d, -6...6), m = nonzero(d, -8...8)
            let r = k * (x + m)
            return q(u, solve, solveKo, ans: "\(x)", expr: "\(k)(\(lin(1, m))) = \(r)",
                     why: "Divide both sides by \(k): \(lin(1, m)) = \(r / k). So x = \(r / k) - \(par(m)) = \(x).",
                     kwhy: "양변을 \(k)로 나누면 \(lin(1, m)) = \(r / k). x = \(r / k) - \(par(m)) = \(x)")
        case 3:
            let a = d.int(2...9), b = d.int(1...20), n = d.int(1...20)
            return q(u, "When a number is multiplied by \(a) and then \(b) is added, the result is \(a * n + b). What is the number?",
                     "어떤 수에 \(josa("\(a)", "을", "를")) 곱하고 \(josa("\(b)", "을", "를")) 더했더니 \(josa("\(a * n + b)", "이", "가")) 되었어요. 어떤 수는 무엇인가요?",
                     ans: "\(n)",
                     why: "Let the number be x: \(a)x + \(b) = \(a * n + b). \(a)x = \(a * n), x = \(n).",
                     kwhy: "어떤 수를 x라 하면 \(a)x + \(b) = \(a * n + b). \(a)x = \(a * n), x = \(n)")
        case 4:
            let (p, r) = d.pick([(2, 3), (3, 4), (2, 5), (4, 6), (3, 6), (2, 6)])
            let l = p * r / Frac.gcd(p, r)
            let xv = l * d.int(1...6)
            let k = xv / p + xv / r
            return q(u, solve, solveKo, ans: "\(xv)", expr: "x/\(p) + x/\(r) = \(k)",
                     why: "Multiply both sides by \(l) (LCM of \(p) and \(r)): \(l / p)x + \(l / r)x = \(k * l), so \(l / p + l / r)x = \(k * l) and x = \(xv).",
                     kwhy: "양변에 분모의 최소공배수 \(josa("\(l)", "을", "를")) 곱해요: \(l / p)x + \(l / r)x = \(k * l), \(l / p + l / r)x = \(k * l), x = \(xv)")
        default:
            let s = d.int(5...15), xv = d.int(1...15)
            let f = 2 * s + xv
            return q(u, "A father is \(f) years old and his son is \(s) years old. In how many years will the father be exactly twice as old as the son?",
                     "아버지는 \(f)살, 아들은 \(s)살이에요. 몇 년 후에 아버지의 나이가 아들의 나이의 2배가 되나요?",
                     ans: "\(xv)", unit: "years",
                     why: "In x years: \(f) + x = 2(\(s) + x). \(f) + x = \(2 * s) + 2x, so x = \(f) - \(2 * s) = \(xv).",
                     kwhy: "x년 후라 하면 \(f) + x = 2(\(s) + x). \(f) + x = \(2 * s) + 2x이므로 x = \(f) - \(2 * s) = \(xv)")
        }
    }

    // MARK: - 좌표평면과 그래프

    static func m1Coord(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Coord
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = nonzero(d, -5...5), x0 = d.int(1...6), x1 = nonzero(d, -6...8)
            return q(u, "y is directly proportional to x, and y = \(a * x0) when x = \(x0). What is y when x = \(x1)?",
                     "y가 x에 정비례하고, x = \(x0)일 때 y = \(a * x0)예요. x = \(x1)일 때 y의 값은?",
                     ans: "\(a * x1)",
                     why: "y = ax. \(a * x0) = a × \(x0), so a = \(a) and y = \(a)x. When x = \(x1): y = \(a) × \(par(x1)) = \(a * x1).",
                     kwhy: "y = ax에서 \(a * x0) = a × \(x0), a = \(a)이므로 y = \(a)x. x = \(x1)이면 y = \(a) × \(par(x1)) = \(a * x1)")
        case 1:
            let a = d.pick([12, 18, 24, 30, 36, 48, 60]) * (d.bool() ? 1 : -1)
            let divs = (1...abs(a)).filter { abs(a) % $0 == 0 && $0 <= 12 }
            let x0 = d.pick(divs)
            var x1 = d.pick(divs)
            while x1 == x0 { x1 = d.pick(divs) }
            return q(u, "y is inversely proportional to x, and y = \(a / x0) when x = \(x0). What is y when x = \(x1)?",
                     "y가 x에 반비례하고, x = \(x0)일 때 y = \(a / x0)예요. x = \(x1)일 때 y의 값은?",
                     ans: "\(a / x1)",
                     why: "y = a/x, so a = xy = \(x0) × \(par(a / x0)) = \(a). When x = \(x1): y = \(a) ÷ \(x1) = \(a / x1).",
                     kwhy: "y = a/x에서 a = xy = \(x0) × \(par(a / x0)) = \(a). x = \(x1)이면 y = \(a) ÷ \(x1) = \(a / x1)")
        case 2:
            let p = nonzero(d, -9...9), r = nonzero(d, -9...9)
            let quad = p > 0 ? (r > 0 ? 1 : 4) : (r > 0 ? 2 : 3)
            let names = ["Quadrant I", "Quadrant II", "Quadrant III", "Quadrant IV"]
            return qc(u, "In which quadrant is the point (\(p), \(r))?", "점 P(\(p), \(r))는 제몇 사분면 위의 점인가요?",
                      ans: names[quad - 1], wrong: names.filter { $0 != names[quad - 1] }, d: d,
                      why: "x is \(p > 0 ? "positive" : "negative") and y is \(r > 0 ? "positive" : "negative"), so the point is in \(names[quad - 1]). (I: +,+  II: −,+  III: −,−  IV: +,−)",
                      kwhy: "x좌표가 \(p > 0 ? "양수" : "음수"), y좌표가 \(r > 0 ? "양수" : "음수")이므로 제\(quad)사분면이에요. (제1: +,+  제2: −,+  제3: −,−  제4: +,−)")
        case 3:
            let p = nonzero(d, -9...9), r = nonzero(d, -9...9)
            switch d.int(0...2) {
            case 0:
                return q(u, "The point (\(p), \(r)) is reflected over the x-axis. What is the y-coordinate of the new point?",
                         "점 P(\(p), \(r))를 x축에 대하여 대칭이동한 점의 y좌표는?",
                         ans: "\(-r)",
                         why: "Reflecting over the x-axis changes the sign of y: (\(p), \(-r)).",
                         kwhy: "x축에 대하여 대칭이동하면 y좌표의 부호만 바뀌어요: (\(p), \(-r))")
            case 1:
                return q(u, "The point (\(p), \(r)) is reflected over the y-axis. What is the x-coordinate of the new point?",
                         "점 P(\(p), \(r))를 y축에 대하여 대칭이동한 점의 x좌표는?",
                         ans: "\(-p)",
                         why: "Reflecting over the y-axis changes the sign of x: (\(-p), \(r)).",
                         kwhy: "y축에 대하여 대칭이동하면 x좌표의 부호만 바뀌어요: (\(-p), \(r))")
            default:
                return q(u, "The point (\(p), \(r)) is reflected through the origin. What is the sum of the coordinates of the new point?",
                         "점 P(\(p), \(r))를 원점에 대하여 대칭이동한 점의 x좌표와 y좌표의 합은?",
                         ans: "\(-p - r)",
                         why: "Reflecting through the origin changes both signs: (\(-p), \(-r)). Sum: \(-p) + \(par(-r)) = \(-p - r).",
                         kwhy: "원점에 대하여 대칭이동하면 두 좌표의 부호가 모두 바뀌어요: (\(-p), \(-r)). 합: \(-p) + \(par(-r)) = \(-p - r)")
            }
        case 4:
            let p = d.int(2...10), r = d.int(-5...5), s = nonzero(d, -8...8)
            let area = Frac(abs(p * s), 2)
            return q(u, "What is the area of the triangle with vertices O(0, 0), A(\(p), 0), and B(\(r), \(s))?",
                     "세 점 O(0, 0), A(\(p), 0), B(\(r), \(s))를 꼭짓점으로 하는 삼각형의 넓이는?",
                     ans: area.mixed,
                     why: "Base OA = \(p) (on the x-axis). Height = distance from B to the x-axis = |\(s)| = \(abs(s)). Area = \(p) × \(abs(s)) ÷ 2 = \(area.mixed).",
                     kwhy: "밑변 OA = \(p) (x축 위). 높이는 점 B에서 x축까지의 거리 |\(s)| = \(abs(s)). 넓이 = \(p) × \(abs(s)) ÷ 2 = \(area.mixed)")
        default:
            let a = d.pick([6, 8, 12, 16, 18, 20, 24, 30, 36])
            let divs = (1...a).filter { a % $0 == 0 }
            return q(u, "On the graph of y = \(a)/x, how many points have both coordinates as natural numbers?",
                     "y = \(a)/x의 그래프 위의 점 중에서 x좌표와 y좌표가 모두 자연수인 점은 몇 개인가요?",
                     ans: "\(divs.count)", unit: "points",
                     why: "xy = \(a), so x must be a divisor of \(a): \(divs.map(String.init).joined(separator: ", ")). That is \(divs.count) points.",
                     kwhy: "xy = \(a)이므로 x는 \(a)의 약수여야 해요: \(divs.map(String.init).joined(separator: ", ")). 모두 \(divs.count)개예요.")
        }
    }

    // MARK: - 기본 도형과 평면도형

    static func m1Geometry(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Geometry
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let n = d.int(5...12)
            return q(u, "What is the sum of the interior angles of a polygon with \(n) sides?", "\(n)각형의 내각의 크기의 합은 몇 도인가요?",
                     ans: "\(180 * (n - 2))", unit: "°",
                     why: "Diagonals from one vertex split it into \(n) - 2 = \(n - 2) triangles: 180° × \(n - 2) = \(180 * (n - 2))°.",
                     kwhy: "한 꼭짓점에서 대각선을 그으면 삼각형 \(n) - 2 = \(n - 2)개로 나뉘어요: 180° × \(n - 2) = \(180 * (n - 2))°")
        case 1:
            let n = d.pick([3, 4, 5, 6, 8, 9, 10, 12])
            return q(u, "What is the size of each interior angle of a regular polygon with \(n) sides?", "정\(n)각형의 한 내각의 크기는 몇 도인가요?",
                     ans: "\(180 * (n - 2) / n)", unit: "°",
                     why: "Sum: 180° × \(n - 2) = \(180 * (n - 2))°. All \(n) angles are equal: \(180 * (n - 2)) ÷ \(n) = \(180 * (n - 2) / n)°.",
                     kwhy: "내각의 합은 180° × \(n - 2) = \(180 * (n - 2))°이고, 크기가 같은 내각이 \(n)개예요: \(180 * (n - 2)) ÷ \(n) = \(180 * (n - 2) / n)°")
        case 2:
            let n = d.int(4...12)
            return q(u, "How many diagonals does a polygon with \(n) sides have?", "\(n)각형의 대각선은 모두 몇 개인가요?",
                     ans: "\(n * (n - 3) / 2)", unit: "diagonals",
                     why: "From each vertex there are \(n) - 3 diagonals, and each diagonal is counted twice: \(n) × \(n - 3) ÷ 2 = \(n * (n - 3) / 2).",
                     kwhy: "한 꼭짓점에서 \(n) - 3개씩 그을 수 있고, 각 대각선을 두 번 세었으므로 \(n) × \(n - 3) ÷ 2 = \(n * (n - 3) / 2)개")
        case 3:
            let n = d.pick([3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 20])
            return q(u, "What is the size of each exterior angle of a regular polygon with \(n) sides?", "정\(n)각형의 한 외각의 크기는 몇 도인가요?",
                     ans: "\(360 / n)", unit: "°",
                     why: "The exterior angles of any polygon add up to 360°: 360 ÷ \(n) = \(360 / n)°.",
                     kwhy: "다각형의 외각의 합은 항상 360°예요: 360 ÷ \(n) = \(360 / n)°")
        case 4:
            let n = d.pick([5, 6, 8, 9, 10, 12, 15, 18, 20])
            let angle = 180 - 360 / n
            return q(u, "Each interior angle of a regular polygon is \(angle)°. How many sides does it have?",
                     "한 내각의 크기가 \(angle)°인 정다각형은 정몇각형인가요?",
                     ans: "\(n)", unit: "sides",
                     why: "Each exterior angle = 180 - \(angle) = \(360 / n)°. Exterior angles add up to 360°: 360 ÷ \(360 / n) = \(n).",
                     kwhy: "한 외각 = 180 - \(angle) = \(360 / n)°. 외각의 합은 360°이므로 360 ÷ \(360 / n) = \(n), 정\(n)각형이에요.")
        default:
            let n = d.int(5...15)
            let dg = n * (n - 3) / 2
            return q(u, "A polygon has \(dg) diagonals. How many sides does it have?", "대각선이 \(dg)개인 다각형은 몇 각형인가요?",
                     ans: "\(n)", unit: "sides",
                     why: "n(n - 3) ÷ 2 = \(dg), so n(n - 3) = \(2 * dg). Try numbers: \(n) × \(n - 3) = \(2 * dg). So n = \(n).",
                     kwhy: "n(n - 3) ÷ 2 = \(dg)이므로 n(n - 3) = \(2 * dg). \(n) × \(n - 3) = \(2 * dg)이므로 \(n)각형이에요.")
        }
    }

    // MARK: - 자료의 정리와 해석

    static func m1Stats(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m1Stats
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let n = d.pick([5, 7])
            let v = (0..<n).map { _ in d.int(1...50) }
            let s = v.sorted()
            return q(u, "Find the median of the data: \(v.map(String.init).joined(separator: ", ")).",
                     "다음 자료의 중앙값을 구하세요: \(v.map(String.init).joined(separator: ", "))",
                     ans: "\(s[n / 2])",
                     why: "Sort: \(s.map(String.init).joined(separator: ", ")). The middle (\(n / 2 + 1)th) value is \(s[n / 2]).",
                     kwhy: "작은 수부터 늘어놓으면 \(s.map(String.init).joined(separator: ", ")). 가운데(\(n / 2 + 1)번째) 값은 \(s[n / 2])예요.")
        case 1:
            let v = (0..<6).map { _ in d.int(1...50) }
            let s = v.sorted()
            let med = dec((s[2] + s[3]) * 5, 1)
            return q(u, "Find the median of the data: \(v.map(String.init).joined(separator: ", ")).",
                     "다음 자료의 중앙값을 구하세요: \(v.map(String.init).joined(separator: ", "))",
                     ans: med,
                     why: "Sort: \(s.map(String.init).joined(separator: ", ")). With 6 values, the median is the average of the 3rd and 4th: (\(s[2]) + \(s[3])) ÷ 2 = \(med).",
                     kwhy: "작은 수부터 늘어놓으면 \(s.map(String.init).joined(separator: ", ")). 자료가 6개이므로 3번째와 4번째 값의 평균: (\(s[2]) + \(s[3])) ÷ 2 = \(med)")
        case 2:
            let mode = d.int(1...20)
            var others: [Int] = []
            while others.count < 4 {
                let x = d.int(1...20)
                if x != mode && !others.contains(x) { others.append(x) }
            }
            let v = d.shuffle([mode, mode, mode] + others + [others[0]])
            return q(u, "Find the mode of the data: \(v.map(String.init).joined(separator: ", ")).",
                     "다음 자료의 최빈값을 구하세요: \(v.map(String.init).joined(separator: ", "))",
                     ans: "\(mode)",
                     why: "The mode is the value that appears most often. \(mode) appears 3 times.",
                     kwhy: "최빈값은 가장 많이 나타나는 값이에요. \(josa("\(mode)", "이", "가")) 3번으로 가장 많아요.")
        case 3:
            let n = d.int(4...6), m = d.int(10...40)
            var v = (0..<(n - 1)).map { _ in m + d.int(-8...8) }
            v.append(m * n - v.reduce(0, +))
            return q(u, "Find the mean of the data: \(v.map(String.init).joined(separator: ", ")).",
                     "다음 자료의 평균을 구하세요: \(v.map(String.init).joined(separator: ", "))",
                     ans: "\(m)",
                     why: "Mean = sum ÷ count = \(m * n) ÷ \(n) = \(m).",
                     kwhy: "평균 = (자료의 합) ÷ (자료의 수) = \(m * n) ÷ \(n) = \(m)")
        case 4:
            let t = d.pick([20, 25, 50]), c = d.int(1...(t / 2))
            let rf = dec(c * (100 / t), 2)
            return q(u, "In a frequency table of \(t) students, one class has a frequency of \(c). What is its relative frequency?",
                     "학생 \(t)명의 도수분포표에서 어떤 계급의 도수가 \(c)예요. 이 계급의 상대도수는?",
                     ans: rf,
                     why: "Relative frequency = frequency ÷ total = \(c) ÷ \(t) = \(rf).",
                     kwhy: "상대도수 = (그 계급의 도수) ÷ (도수의 총합) = \(c) ÷ \(t) = \(rf)")
        default:
            let total = d.pick([10, 20, 25])
            var f = [0, 0, 0, 0]
            repeat {
                f = [d.int(1...total), d.int(1...total), d.int(1...total), 0]
                f[3] = total - f[0] - f[1] - f[2]
            } while f[3] < 1
            let sum = f[0] * 1 + f[1] * 2 + f[2] * 3 + f[3] * 4
            let mean = dec(sum * (100 / total), 2)
            return q(u, "In a quiz, \(f[0]) students scored 1 point, \(f[1]) scored 2 points, \(f[2]) scored 3 points, and \(f[3]) scored 4 points. What is the mean score?",
                     "퀴즈에서 1점은 \(f[0])명, 2점은 \(f[1])명, 3점은 \(f[2])명, 4점은 \(f[3])명이 받았어요. 점수의 평균은 몇 점인가요?",
                     ans: mean, unit: "points",
                     why: "Total score: 1 × \(f[0]) + 2 × \(f[1]) + 3 × \(f[2]) + 4 × \(f[3]) = \(sum). Students: \(total). Mean = \(sum) ÷ \(total) = \(mean).",
                     kwhy: "점수의 합: 1 × \(f[0]) + 2 × \(f[1]) + 3 × \(f[2]) + 4 × \(f[3]) = \(sum)점. 학생 수 \(total)명. 평균 = \(sum) ÷ \(total) = \(mean)점")
        }
    }
}
