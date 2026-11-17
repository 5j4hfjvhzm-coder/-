import Foundation

/// 중학교 2학년 문제
extension Generator {
    /// 영어 서수: 1 → "1st", 22 → "22nd"
    static func ord(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    /// x의 거듭제곱 표기: power("x", 1) → "x", power("x", 3) → "x³"
    static func power(_ v: String, _ e: Int) -> String { e == 0 ? "" : e == 1 ? v : v + sup(e) }

    // MARK: - 유리수와 순환소수

    static func m2Repeating(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Repeating
        let asFrac = "Write it as a fraction in simplest form."
        let asFracKo = "기약분수로 나타내세요."
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = d.int(1...8)
            return q(u, "0.\(a)\(a)\(a)… (the digit \(a) repeats forever). " + asFrac,
                     "0.\(a)\(a)\(a)… (\(josa("\(a)", "이", "가")) 끝없이 되풀이돼요). " + asFracKo,
                     ans: Frac(a, 9).mixed,
                     why: "Let x = 0.\(a)\(a)\(a)… Then 10x = \(a).\(a)\(a)… Subtract: 9x = \(a), so x = \(simp(a, 9)).",
                     kwhy: "x = 0.\(a)\(a)\(a)…라 하면 10x = \(a).\(a)\(a)…예요. 빼면 9x = \(a), x = \(simp(a, 9))")
        case 1:
            var a = 0, b = 0
            repeat { a = d.int(0...9); b = d.int(1...9) } while a == b
            let ab = 10 * a + b
            return q(u, "0.\(a)\(b)\(a)\(b)\(a)\(b)… (\"\(a)\(b)\" repeats forever). " + asFrac,
                     "0.\(a)\(b)\(a)\(b)\(a)\(b)… (\(josa("\(a)\(b)", "이", "가")) 끝없이 되풀이돼요). " + asFracKo,
                     ans: Frac(ab, 99).mixed,
                     why: "Let x = 0.\(a)\(b)\(a)\(b)… Then 100x = \(ab).\(a)\(b)… Subtract: 99x = \(ab), so x = \(simp(ab, 99)).",
                     kwhy: "x = 0.\(a)\(b)\(a)\(b)…라 하면 100x = \(ab).\(a)\(b)…예요. 빼면 99x = \(ab), x = \(simp(ab, 99))")
        case 2:
            var p = 0, r = 0
            repeat { p = d.int(1...9); r = d.int(1...9) } while p == r
            let num = 9 * p + r
            return q(u, "0.\(p)\(r)\(r)\(r)… (only the digit \(r) repeats). " + asFrac,
                     "0.\(p)\(r)\(r)\(r)… (\(r)만 끝없이 되풀이돼요). " + asFracKo,
                     ans: Frac(num, 90).mixed,
                     why: "Let x = 0.\(p)\(r)\(r)… Then 100x = \(p)\(r).\(r)\(r)… and 10x = \(p).\(r)\(r)… Subtract: 90x = \(10 * p + r) - \(p) = \(num), so x = \(simp(num, 90)).",
                     kwhy: "x = 0.\(p)\(r)\(r)…라 하면 100x = \(p)\(r).\(r)\(r)…, 10x = \(p).\(r)\(r)…예요. 빼면 90x = \(10 * p + r) - \(p) = \(num), x = \(simp(num, 90))")
        case 3:
            let goods = ["3/8", "7/20", "9/12", "21/30", "3/40", "11/25", "6/15"]
            let bads = ["1/3", "5/6", "2/7", "5/12", "4/15", "7/18", "3/14", "1/9"]
            let ans = d.pick(goods)
            return qc(u, "Which fraction can be written as a terminating decimal (a decimal that ends)?",
                      "다음 중 유한소수로 나타낼 수 있는 분수는 어느 것인가요?",
                      ans: ans, wrong: Array(d.shuffle(bads).prefix(3)), d: d,
                      why: "Simplify first. A fraction is a terminating decimal only if its denominator has no prime factors other than 2 and 5. \(ans) = \(Frac.parse(ans)!.improper), whose denominator has only 2s and 5s.",
                      kwhy: "먼저 기약분수로 고쳐요. 분모의 소인수가 2나 5뿐이면 유한소수예요. \(ans) = \(Frac.parse(ans)!.improper)이고, 분모의 소인수가 2와 5뿐이에요.")
        case 4:
            let n = d.int(20...100)
            let digit = Array("142857")[(n - 1) % 6]
            return q(u, "1/7 = 0.142857142857… What is the digit in the \(ord(n)) place after the decimal point?",
                     "1/7 = 0.142857142857…에서 소수점 아래 \(n)번째 자리의 숫자는 무엇인가요?",
                     ans: "\(digit)",
                     why: "The 6 digits 142857 repeat. \(n) ÷ 6 = \(n / 6) remainder \(n % 6), so it is the \(ord((n - 1) % 6 + 1)) digit of 142857: \(digit).",
                     kwhy: "142857의 6개 숫자가 되풀이돼요. \(n) ÷ 6 = \(n / 6) … \(n % 6)이므로 142857의 \((n - 1) % 6 + 1)번째 숫자인 \(digit)예요.")
        default:
            var a = 0, i = 0, j = 0, qq = 0, den = 0
            repeat {
                qq = d.pick([3, 7, 11]); i = d.int(0...2); j = d.int(0...2); a = d.int(1...20)
                den = ipow(2, i) * qq * ipow(5, j)
            } while a % qq == 0 || den > 300 || den == qq
            return q(u, "What is the smallest natural number you can multiply \(a)/\(den) by to make it a terminating decimal?",
                     "\(a)/\(den)에 어떤 자연수를 곱하여 유한소수가 되게 하려고 해요. 곱할 수 있는 가장 작은 자연수는?",
                     ans: "\(qq)",
                     why: "\(den) = \(factorText([(2, i), (qq, 1), (5, j)])). The prime \(qq) must cancel, and \(a) is not a multiple of \(qq), so multiply by \(qq).",
                     kwhy: "\(den) = \(factorText([(2, i), (qq, 1), (5, j)]))예요. 분모의 소인수 \(josa("\(qq)", "이", "가")) 약분되어야 하는데 분자 \(josa("\(a)", "은", "는")) \(qq)의 배수가 아니므로 \(josa("\(qq)", "을", "를")) 곱해야 해요.")
        }
    }

    // MARK: - 식의 계산

    static func m2Expr(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Expr
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = d.int(2...9), b = d.int(2...6)
            switch d.int(0...2) {
            case 0:
                return q(u, "Find the number that goes in the box.", "□ 안에 알맞은 수를 구하세요.",
                         ans: "\(a + b)", expr: "2\(sup(a)) × 2\(sup(b)) = 2^□",
                         why: "When multiplying the same base, add the exponents: \(a) + \(b) = \(a + b).",
                         kwhy: "밑이 같은 거듭제곱의 곱은 지수끼리 더해요: \(a) + \(b) = \(a + b)")
            case 1:
                return q(u, "Find the number that goes in the box.", "□ 안에 알맞은 수를 구하세요.",
                         ans: "\(a * b)", expr: "(x\(sup(a)))\(sup(b)) = x^□",
                         why: "A power of a power: multiply the exponents: \(a) × \(b) = \(a * b).",
                         kwhy: "거듭제곱의 거듭제곱은 지수끼리 곱해요: \(a) × \(b) = \(a * b)")
            default:
                return q(u, "Find the number that goes in the box.", "□ 안에 알맞은 수를 구하세요.",
                         ans: "\(a)", expr: "x\(sup(a + b)) ÷ x\(sup(b)) = x^□",
                         why: "When dividing the same base, subtract the exponents: \(a + b) - \(b) = \(a).",
                         kwhy: "밑이 같은 거듭제곱의 나눗셈은 지수끼리 빼요: \(a + b) - \(b) = \(a)")
            }
        case 1:
            let c1 = nonzero(d, -5...5), p = d.int(1...3), q1 = d.int(1...3)
            let c2 = nonzero(d, -5...5), r = d.int(1...3), s = d.int(1...3)
            let asks = ["the coefficient", "the exponent of x", "the exponent of y"]
            let asksKo = ["계수", "x의 지수", "y의 지수"]
            let k = d.int(0...2)
            let ans = [c1 * c2, p + r, q1 + s][k]
            let m1 = "\(c1)\(power("x", p))\(power("y", q1))", m2 = "\(c2)\(power("x", r))\(power("y", s))"
            return q(u, "Simplify (\(m1)) × (\(m2)). What is \(asks[k])?",
                     "(\(m1)) × (\(m2))를 간단히 했을 때, \(asksKo[k])를 구하세요.",
                     ans: "\(ans)",
                     why: "Multiply the numbers: \(c1) × \(par(c2)) = \(c1 * c2). Add the exponents of each letter: x\(sup(p + r)), y\(sup(q1 + s)). Result: \(c1 * c2)\(power("x", p + r))\(power("y", q1 + s)).",
                     kwhy: "계수끼리 곱하고(\(c1) × \(par(c2)) = \(c1 * c2)), 같은 문자는 지수끼리 더해요: \(c1 * c2)\(power("x", p + r))\(power("y", q1 + s))")
        case 2:
            let a1 = nonzero(d, -6...6), b1 = nonzero(d, -6...6), a2 = nonzero(d, -6...6), b2 = nonzero(d, -6...6)
            let pa = a1 - a2, pb = b1 - b2
            return q(u, "Simplify the expression to the form ax + by. What is a + b?",
                     "다음 식을 간단히 하여 ax + by 꼴로 나타낼 때, a + b의 값은?",
                     ans: "\(pa + pb)", expr: "(\(a1)x \(b1 < 0 ? "-" : "+") \(abs(b1))y) - (\(a2)x \(b2 < 0 ? "-" : "+") \(abs(b2))y)",
                     why: "Change the signs in the second bracket and combine like terms: (\(a1) - \(par(a2)))x + (\(b1) - \(par(b2)))y = \(pa)x + \(par(pb))y. a + b = \(pa + pb).",
                     kwhy: "뒤 괄호의 부호를 바꾸고 동류항끼리 계산해요: (\(a1) - \(par(a2)))x + (\(b1) - \(par(b2)))y = \(pa)x + \(par(pb))y. a + b = \(pa + pb)")
        case 3:
            let a = nonzero(d, -5...5), b = nonzero(d, -6...6), c = nonzero(d, -5...5), e = nonzero(d, -6...6)
            let pp = a - c, qq = b - c * e
            return q(u, "Simplify the expression to the form px² + qx. What is p + q?",
                     "다음 식을 간단히 하여 px² + qx 꼴로 나타낼 때, p + q의 값은?",
                     ans: "\(pp + qq)", expr: "x(\(lin(a, b))) - \(lin(c, 0))(\(lin(1, e)))",
                     why: "x(\(lin(a, b))) = \(quad(a, b, 0)). \(lin(c, 0))(\(lin(1, e))) = \(quad(c, c * e, 0)). Subtract: \(pp)x² + \(par(qq))x. p + q = \(pp + qq).",
                     kwhy: "x(\(lin(a, b))) = \(quad(a, b, 0)), \(lin(c, 0))(\(lin(1, e))) = \(quad(c, c * e, 0)). 빼면 \(pp)x² + \(par(qq))x. p + q = \(pp + qq)")
        case 4:
            if d.bool() {
                let e = d.int(3...8), k = d.int(1...2)
                return q(u, "Find x.", "x의 값을 구하세요.", ans: "\(e - k)", expr: "2^(x + \(k)) = \(ipow(2, e))",
                         why: "\(ipow(2, e)) = 2\(sup(e)). So x + \(k) = \(e), x = \(e - k).",
                         kwhy: "\(ipow(2, e)) = 2\(sup(e))이므로 x + \(k) = \(e), x = \(e - k)")
            } else {
                let base = d.pick([4, 8]), m = d.int(2...4)
                let t = base == 4 ? 2 : 3
                return q(u, "Find x.", "x의 값을 구하세요.", ans: "\(t * m)", expr: "\(base)\(sup(m)) = 2^x",
                         why: "\(base) = 2\(sup(t)), so \(base)\(sup(m)) = (2\(sup(t)))\(sup(m)) = 2\(sup(t * m)). x = \(t * m).",
                         kwhy: "\(base) = 2\(sup(t))이므로 \(base)\(sup(m)) = (2\(sup(t)))\(sup(m)) = 2\(sup(t * m)). x = \(t * m)")
            }
        default:
            let a = d.int(3...12), k = d.int(1...3)
            let b = a + k
            let five = ipow(5, k)
            return q(u, "How many digits does 2\(sup(a)) × 5\(sup(b)) have?",
                     "2\(sup(a)) × 5\(sup(b))는 몇 자리 자연수인가요?",
                     ans: "\(a + String(five).count)", unit: "digits",
                     why: "2\(sup(a)) × 5\(sup(b)) = 5\(sup(k)) × (2 × 5)\(sup(a)) = \(five) × 10\(sup(a)). That is \(five) followed by \(a) zeros: \(String(five).count) + \(a) = \(a + String(five).count) digits.",
                     kwhy: "2\(sup(a)) × 5\(sup(b)) = 5\(sup(k)) × (2 × 5)\(sup(a)) = \(five) × 10\(sup(a))예요. \(five) 뒤에 0이 \(a)개 붙으므로 \(String(five).count) + \(a) = \(a + String(five).count)자리예요.")
        }
    }

    // MARK: - 일차부등식

    static func m2Inequality(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Inequality
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = d.int(2...7), b = d.int(-10...10), t = d.int(-5...10)
            let c = a * t + b
            return q(u, "What is the largest integer x that satisfies the inequality?", "다음 부등식을 만족하는 가장 큰 정수 x는?",
                     ans: "\(t - 1)", expr: "\(lin(a, b)) < \(c)",
                     why: "\(lin(a, 0)) < \(c) - \(par(b)) = \(c - b), so x < \(t). The largest integer less than \(t) is \(t - 1).",
                     kwhy: "\(lin(a, 0)) < \(c) - \(par(b)) = \(c - b)이므로 x < \(t). \(t)보다 작은 가장 큰 정수는 \(t - 1)")
        case 1:
            let a = d.int(2...7), b = d.int(-10...10), t = d.int(-5...10)
            let c = a * t + b
            return q(u, "What is the smallest integer x that satisfies the inequality?", "다음 부등식을 만족하는 가장 작은 정수 x는?",
                     ans: "\(t)", expr: "\(lin(a, b)) ≥ \(c)",
                     why: "\(lin(a, 0)) ≥ \(c - b), so x ≥ \(t). The smallest integer is \(t) (\"≥\" includes \(t)).",
                     kwhy: "\(lin(a, 0)) ≥ \(c - b)이므로 x ≥ \(t). ≥는 \(t)도 포함하므로 가장 작은 정수는 \(t)")
        case 2:
            let a = d.int(2...6), b = d.int(1...10), t = d.int(3...12)
            let c = a * t + b
            return q(u, "How many natural numbers x satisfy the inequality?", "다음 부등식을 만족하는 자연수 x는 모두 몇 개인가요?",
                     ans: "\(t - 1)", expr: "\(lin(a, b)) < \(c)",
                     why: "\(a)x < \(c - b), so x < \(t). Natural numbers: 1, 2, …, \(t - 1). That is \(t - 1).",
                     kwhy: "\(a)x < \(c - b)이므로 x < \(t). 자연수는 1, 2, …, \(t - 1)로 \(t - 1)개예요.")
        case 3:
            let p = d.int(5...15) * 100, g = d.int(10...30) * 100, budget = d.int(50...150) * 100
            let n = (budget - g) / p
            return q(u, "A notebook costs \(comma(p)) won and a bag costs \(comma(g)) won. With \(comma(budget)) won, you buy 1 bag and some notebooks. At most how many notebooks can you buy?",
                     "공책 한 권은 \(comma(p))원, 가방은 \(comma(g))원이에요. \(comma(budget))원으로 가방 1개와 공책 몇 권을 사려면, 공책은 최대 몇 권 살 수 있나요?",
                     ans: "\(n)", unit: "notebooks",
                     why: "\(p)x + \(g) ≤ \(budget), so \(p)x ≤ \(budget - g), x ≤ \(Frac(budget - g, p).mixed). The largest whole number is \(n).",
                     kwhy: "\(p)x + \(g) ≤ \(budget), \(p)x ≤ \(budget - g), x ≤ \(Frac(budget - g, p).mixed). 가장 큰 자연수는 \(n)")
        case 4:
            let a = d.int(2...6), b = d.int(-10...10), t = d.int(-6...8)
            let c = -a * t + b
            return q(u, "What is the largest integer x that satisfies the inequality?", "다음 부등식을 만족하는 가장 큰 정수 x는?",
                     ans: "\(t - 1)", expr: "\(lin(-a, b)) > \(c)",
                     why: "\(lin(-a, 0)) > \(c - b). Dividing by a negative number (\(-a)) flips the sign: x < \(t). The largest integer is \(t - 1).",
                     kwhy: "\(lin(-a, 0)) > \(c - b). 양변을 음수 \(-a)로 나누면 부등호 방향이 바뀌어요: x < \(t). 가장 큰 정수는 \(t - 1)")
        default:
            var b1 = 0, b2 = 0, r1 = 0, r2 = 0
            repeat {
                b1 = d.int(5...15) * 1000; b2 = b1 + d.int(1...10) * 1000
                r1 = d.int(10...20) * 10; r2 = r1 - d.int(2...10) * 10
            } while r2 <= 0 || (b2 - b1) % (r1 - r2) != 0
            let t = (b2 - b1) / (r1 - r2)
            return q(u, "Phone plan A costs \(comma(b1)) won plus \(r1) won per minute. Plan B costs \(comma(b2)) won plus \(r2) won per minute. From how many minutes is plan B cheaper? (Give the smallest whole number of minutes.)",
                     "요금제 A는 기본 \(comma(b1))원에 1분마다 \(r1)원, 요금제 B는 기본 \(comma(b2))원에 1분마다 \(r2)원이에요. 몇 분 이상 통화하면 B가 더 싼가요? (가장 작은 자연수)",
                     ans: "\(t + 1)", unit: "minutes",
                     why: "B is cheaper when \(b2) + \(r2)x < \(b1) + \(r1)x, so \(r1 - r2)x > \(b2 - b1), x > \(t). The smallest whole number is \(t + 1).",
                     kwhy: "\(b2) + \(r2)x < \(b1) + \(r1)x일 때 B가 더 싸요. \(r1 - r2)x > \(b2 - b1), x > \(t). 가장 작은 자연수는 \(t + 1)")
        }
    }

    // MARK: - 연립일차방정식

    static func m2System(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2System
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let x = d.int(-8...12), y = d.int(-8...12)
            let askX = d.bool()
            return q(u, "Solve the system: x + y = \(x + y) and x - y = \(x - y). What is \(askX ? "x" : "y")?",
                     "연립방정식 x + y = \(x + y), x - y = \(josa("\(x - y)", "을", "를")) 풀 때, \(askX ? "x" : "y")의 값은?",
                     ans: "\(askX ? x : y)",
                     why: "Add the two equations: 2x = \(2 * x), so x = \(x). Then y = \(x + y) - \(par(x)) = \(y).",
                     kwhy: "두 식을 더하면 2x = \(2 * x), x = \(x). y = \(x + y) - \(par(x)) = \(y)")
        case 1:
            let x = d.int(-6...8), y = d.int(-6...8)
            var a = 0, b = 0
            repeat { a = nonzero(d, -5...5); b = nonzero(d, -5...5) } while a == b
            let c = a * x + b * y
            return q(u, "Solve the system: \(a)x + \(par(b))y = \(c) and x + y = \(x + y). What is x?",
                     "연립방정식 \(a)x + \(par(b))y = \(c), x + y = \(josa("\(x + y)", "을", "를")) 풀 때, x의 값은?",
                     ans: "\(x)",
                     why: "From x + y = \(x + y): y = \(x + y) - x. Substitute: \(a)x + \(par(b))(\(x + y) - x) = \(c), so \(a - b)x = \(c - b * (x + y)), x = \(x).",
                     kwhy: "x + y = \(x + y)에서 y = \(x + y) - x. 대입하면 \(a)x + \(par(b))(\(x + y) - x) = \(c), \(a - b)x = \(c - b * (x + y)), x = \(x)")
        case 2:
            let r = d.int(2...15), c = d.int(2...15)
            return q(u, "A farm has chickens and rabbits. There are \(r + c) heads and \(4 * r + 2 * c) legs in total. How many rabbits are there?",
                     "닭과 토끼가 모두 \(r + c)마리 있고, 다리 수의 합은 \(4 * r + 2 * c)개예요. 토끼는 몇 마리인가요?",
                     ans: "\(r)", unit: "rabbits",
                     why: "Let x = chickens, y = rabbits: x + y = \(r + c), 2x + 4y = \(4 * r + 2 * c). Subtract 2 × the first: 2y = \(2 * r), y = \(r).",
                     kwhy: "닭 x마리, 토끼 y마리: x + y = \(r + c), 2x + 4y = \(4 * r + 2 * c). 첫 식의 2배를 빼면 2y = \(2 * r), y = \(r)")
        case 3:
            let big = d.int(10...60), small = d.int(1...(big - 1))
            return q(u, "The sum of two numbers is \(big + small) and their difference is \(big - small). What is the larger number?",
                     "두 수의 합은 \(big + small), 차는 \(big - small)예요. 큰 수는 무엇인가요?",
                     ans: "\(big)",
                     why: "x + y = \(big + small), x - y = \(big - small). Add: 2x = \(2 * big), x = \(big).",
                     kwhy: "x + y = \(big + small), x - y = \(big - small). 더하면 2x = \(2 * big), x = \(big)")
        case 4:
            let a = d.int(2...15), b = d.int(2...15)
            let total = 100 * a + 500 * b
            return q(u, "\(a + b) coins are a mix of 100-won and 500-won coins. Together they are worth \(comma(total)) won. How many 500-won coins are there?",
                     "100원짜리와 500원짜리 동전이 모두 \(a + b)개 있고, 금액의 합은 \(comma(total))원이에요. 500원짜리 동전은 몇 개인가요?",
                     ans: "\(b)", unit: "coins",
                     why: "x + y = \(a + b) and 100x + 500y = \(total). Divide the second by 100: x + 5y = \(total / 100). Subtract the first: 4y = \(4 * b), y = \(b).",
                     kwhy: "x + y = \(a + b), 100x + 500y = \(total). 둘째 식을 100으로 나누면 x + 5y = \(total / 100). 첫 식을 빼면 4y = \(4 * b), y = \(b)")
        default:
            let tw = d.int(1...4), tr = d.int(1...3)
            let dist = 4 * tw + 8 * tr
            return q(u, "\(d.pick(people).0) walked at 4 km/h and then ran at 8 km/h. The whole trip was \(dist) km and took \(tw + tr) hours. How many km did they walk?",
                     "시속 4 km로 걷다가 시속 8 km로 달렸어요. 모두 \(dist) km를 가는 데 \(tw + tr)시간이 걸렸어요. 걸은 거리는 몇 km인가요?",
                     ans: "\(4 * tw)", unit: "km",
                     why: "Let x = hours walking, y = hours running: x + y = \(tw + tr), 4x + 8y = \(dist). Then 4y = \(dist) - 4 × \(tw + tr) = \(4 * tr), y = \(tr), x = \(tw). Walking distance: 4 × \(tw) = \(4 * tw) km.",
                     kwhy: "걸은 시간 x, 달린 시간 y: x + y = \(tw + tr), 4x + 8y = \(dist). 4y = \(dist) - 4 × \(tw + tr) = \(4 * tr), y = \(tr), x = \(tw). 걸은 거리: 4 × \(tw) = \(4 * tw) km")
        }
    }

    // MARK: - 일차함수

    static func m2Linear(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Linear
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let m = nonzero(d, -5...5), x1 = d.int(-5...5)
            var x2 = d.int(-5...5)
            while x2 == x1 { x2 = d.int(-5...5) }
            let y1 = d.int(-8...8), y2 = y1 + m * (x2 - x1)
            return q(u, "What is the slope of the line through (\(x1), \(y1)) and (\(x2), \(y2))?",
                     "두 점 (\(x1), \(y1)), (\(x2), \(y2))를 지나는 직선의 기울기는?",
                     ans: "\(m)",
                     why: "Slope = (change in y) ÷ (change in x) = (\(y2) - \(par(y1))) ÷ (\(x2) - \(par(x1))) = \(y2 - y1) ÷ \(par(x2 - x1)) = \(m).",
                     kwhy: "기울기 = (y의 값의 증가량) ÷ (x의 값의 증가량) = (\(y2) - \(par(y1))) ÷ (\(x2) - \(par(x1))) = \(m)")
        case 1:
            let a = nonzero(d, -6...6), b = d.int(-10...10), v = d.int(-6...6)
            return q(u, "For the linear function y = \(lin(a, b)), what is y when x = \(v)?",
                     "일차함수 y = \(lin(a, b))에서 x = \(v)일 때 y의 값은?",
                     ans: "\(a * v + b)",
                     why: "y = \(a) × \(par(v)) + \(par(b)) = \(a * v + b).",
                     kwhy: "y = \(a) × \(par(v)) + \(par(b)) = \(a * v + b)")
        case 2:
            let a = nonzero(d, -5...5), xi = nonzero(d, -8...8)
            let b = -a * xi
            return q(u, "What is the x-intercept of y = \(lin(a, b))?", "y = \(lin(a, b))의 그래프의 x절편은?",
                     ans: "\(xi)",
                     why: "Put y = 0: 0 = \(lin(a, b)), so x = \(xi).",
                     kwhy: "y = 0을 넣으면 0 = \(lin(a, b)), x = \(xi)")
        case 3:
            let m = nonzero(d, -4...4), x1 = d.int(-4...4), x2 = x1 + d.int(1...4), b = d.int(-8...8)
            let y1 = m * x1 + b, y2 = m * x2 + b
            return q(u, "What is the y-intercept of the line through (\(x1), \(y1)) and (\(x2), \(y2))?",
                     "두 점 (\(x1), \(y1)), (\(x2), \(y2))를 지나는 직선의 y절편은?",
                     ans: "\(b)",
                     why: "Slope = (\(y2) - \(par(y1))) ÷ (\(x2) - \(par(x1))) = \(m). y = \(m)x + b through (\(x1), \(y1)): \(y1) = \(m) × \(par(x1)) + b, b = \(b).",
                     kwhy: "기울기 = (\(y2) - \(par(y1))) ÷ (\(x2) - \(par(x1))) = \(m). y = \(m)x + b에 (\(x1), \(y1))을 넣으면 \(y1) = \(m) × \(par(x1)) + b, b = \(b)")
        case 4:
            let a = nonzero(d, -4...4), xi = nonzero(d, -6...6)
            let b = -a * xi
            let area = Frac(abs(xi * b), 2)
            return q(u, "What is the area of the triangle formed by the graph of y = \(lin(a, b)) and the x-axis and y-axis?",
                     "y = \(lin(a, b))의 그래프와 x축, y축으로 둘러싸인 삼각형의 넓이는?",
                     ans: area.mixed,
                     why: "x-intercept: \(xi), y-intercept: \(b). Area = |\(xi)| × |\(b)| ÷ 2 = \(area.mixed).",
                     kwhy: "x절편 \(xi), y절편 \(b). 넓이 = |\(xi)| × |\(b)| ÷ 2 = \(area.mixed)")
        default:
            let start = d.int(5...30), rate = d.int(2...8), t = d.int(3...20)
            return q(u, "A tank has \(start) L of water. Water is added at \(rate) L per minute. After how many minutes will it have \(start + rate * t) L?",
                     "물이 \(start) L 들어 있는 물통에 1분마다 \(rate) L씩 물을 넣어요. 물이 \(start + rate * t) L가 되는 것은 몇 분 후인가요?",
                     ans: "\(t)", unit: "minutes",
                     why: "y = \(rate)x + \(start). \(rate)x + \(start) = \(start + rate * t), \(rate)x = \(rate * t), x = \(t).",
                     kwhy: "y = \(rate)x + \(start). \(rate)x + \(start) = \(start + rate * t), \(rate)x = \(rate * t), x = \(t)")
        }
    }

    // MARK: - 삼각형과 사각형의 성질

    static func m2Shapes(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Shapes
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let v = d.int(10...70) * 2
            return q(u, "In isosceles triangle ABC with AB = AC, angle A is \(v)°. What is angle B?",
                     "AB = AC인 이등변삼각형 ABC에서 ∠A = \(v)°일 때, ∠B의 크기는?",
                     ans: "\((180 - v) / 2)", unit: "°",
                     why: "The base angles are equal: angle B = angle C = (180 - \(v)) ÷ 2 = \((180 - v) / 2)°.",
                     kwhy: "이등변삼각형의 두 밑각의 크기는 같아요: ∠B = ∠C = (180° - \(v)°) ÷ 2 = \((180 - v) / 2)°")
        case 1:
            let a = d.int(40...140)
            return q(u, "In parallelogram ABCD, angle A is \(a)°. What is angle B?", "평행사변형 ABCD에서 ∠A = \(a)°일 때, ∠B의 크기는?",
                     ans: "\(180 - a)", unit: "°",
                     why: "Neighboring angles of a parallelogram add up to 180°: 180 - \(a) = \(180 - a)°.",
                     kwhy: "평행사변형에서 이웃한 두 각의 합은 180°예요: 180° - \(a)° = \(180 - a)°")
        case 2:
            let b = d.int(20...80)
            return q(u, "In isosceles triangle ABC with AB = AC, angle B is \(b)°. What is angle A?",
                     "AB = AC인 이등변삼각형 ABC에서 ∠B = \(b)°일 때, ∠A의 크기는?",
                     ans: "\(180 - 2 * b)", unit: "°",
                     why: "Angle C = angle B = \(b)°. Angle A = 180 - \(b) - \(b) = \(180 - 2 * b)°.",
                     kwhy: "∠C = ∠B = \(b)°예요. ∠A = 180° - \(b)° - \(b)° = \(180 - 2 * b)°")
        case 3:
            let hyp = d.int(3...20) * 2
            return q(u, "In a right triangle, the hypotenuse is \(hyp) cm long. What is the radius of the circle that passes through all three vertices (the circumscribed circle)?",
                     "빗변의 길이가 \(hyp) cm인 직각삼각형의 외접원의 반지름은 몇 cm인가요?",
                     ans: "\(hyp / 2)", unit: "cm",
                     why: "The circumcenter of a right triangle is the midpoint of the hypotenuse, so the radius is \(hyp) ÷ 2 = \(hyp / 2) cm.",
                     kwhy: "직각삼각형의 외심은 빗변의 중점이므로 외접원의 반지름은 \(hyp) ÷ 2 = \(hyp / 2) cm")
        case 4:
            let a = d.int(15...65) * 2
            return q(u, "In triangle ABC, point I is the incenter (where the angle bisectors meet). Angle A is \(a)°. What is angle BIC?",
                     "삼각형 ABC의 내심을 I라 하고 ∠A = \(a)°일 때, ∠BIC의 크기는?",
                     ans: "\(90 + a / 2)", unit: "°",
                     why: "Angle B + angle C = 180 - \(a) = \(180 - a)°. Half of that is \((180 - a) / 2)°. Angle BIC = 180 - \((180 - a) / 2) = \(90 + a / 2)° (= 90° + A/2).",
                     kwhy: "∠B + ∠C = 180° - \(a)° = \(180 - a)°. 내심은 각의 이등분선의 교점이므로 ∠IBC + ∠ICB = \((180 - a) / 2)°. ∠BIC = 180° - \((180 - a) / 2)° = \(90 + a / 2)° (공식: 90° + ∠A/2)")
        default:
            let d1 = d.int(2...12) * 2, d2 = d.int(2...12)
            return q(u, "The diagonals of a rhombus are \(d1) cm and \(d2) cm long. What is its area?",
                     "두 대각선의 길이가 \(d1) cm, \(d2) cm인 마름모의 넓이는 몇 cm²인가요?",
                     ans: "\(d1 * d2 / 2)", unit: "cm²",
                     why: "Area of a rhombus = diagonal × diagonal ÷ 2 = \(d1) × \(d2) ÷ 2 = \(d1 * d2 / 2) cm².",
                     kwhy: "마름모의 넓이 = (한 대각선) × (다른 대각선) ÷ 2 = \(d1) × \(d2) ÷ 2 = \(d1 * d2 / 2) cm²")
        }
    }

    // MARK: - 도형의 닮음과 피타고라스 정리

    static let triples: [(Int, Int, Int)] = [(3, 4, 5), (5, 12, 13), (6, 8, 10), (8, 15, 17), (9, 12, 15), (7, 24, 25), (12, 16, 20)]

    static func m2Similar(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Similar
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let (p, r) = d.pick([(2, 3), (3, 4), (2, 5), (3, 5), (4, 5)])
            let t = d.int(1...4), s = d.int(1...5)
            return q(u, "Triangle ABC is similar to triangle DEF. AB = \(p * t) cm, DE = \(r * t) cm, and BC = \(p * s) cm. How long is EF?",
                     "△ABC ∽ △DEF이고 AB = \(p * t) cm, DE = \(r * t) cm, BC = \(p * s) cm일 때, EF의 길이는 몇 cm인가요?",
                     ans: "\(r * s)", unit: "cm",
                     why: "The similarity ratio is AB : DE = \(p * t) : \(r * t) = \(p) : \(r). So BC : EF = \(p) : \(r), EF = \(p * s) × \(r)/\(p) = \(r * s) cm.",
                     kwhy: "닮음비 AB : DE = \(p * t) : \(r * t) = \(p) : \(r). BC : EF = \(p) : \(r)이므로 EF = \(p * s) × \(r)/\(p) = \(r * s) cm")
        case 1:
            let (p, r) = d.pick([(1, 2), (2, 3), (1, 3), (3, 4), (2, 5)])
            let k = d.int(1...6)
            let small = p * p * k
            return q(u, "Two similar figures have a similarity ratio of \(p) : \(r). The smaller one has an area of \(small) cm². What is the area of the larger one?",
                     "닮음비가 \(p) : \(r)인 두 닮은 도형에서 작은 도형의 넓이가 \(small) cm²예요. 큰 도형의 넓이는 몇 cm²인가요?",
                     ans: "\(r * r * k)", unit: "cm²",
                     why: "The area ratio is \(p)² : \(r)² = \(p * p) : \(r * r). Larger area = \(small) × \(r * r)/\(p * p) = \(r * r * k) cm².",
                     kwhy: "넓이의 비는 닮음비의 제곱: \(p)² : \(r)² = \(p * p) : \(r * r). 큰 도형의 넓이 = \(small) × \(r * r)/\(p * p) = \(r * r * k) cm²")
        case 2:
            let (a, b, c) = d.pick(triples)
            return q(u, "A right triangle has legs \(a) cm and \(b) cm. How long is the hypotenuse?",
                     "직각을 낀 두 변의 길이가 \(a) cm, \(b) cm인 직각삼각형의 빗변의 길이는 몇 cm인가요?",
                     ans: "\(c)", unit: "cm",
                     why: "Pythagorean theorem: c² = \(a)² + \(b)² = \(a * a) + \(b * b) = \(c * c), so c = \(c).",
                     kwhy: "피타고라스 정리: c² = \(a)² + \(b)² = \(a * a) + \(b * b) = \(c * c), c = \(c)")
        case 3:
            let (a, b, c) = d.pick(triples)
            return q(u, "A right triangle has a hypotenuse of \(c) cm and one leg of \(a) cm. How long is the other leg?",
                     "빗변의 길이가 \(c) cm이고 한 변의 길이가 \(a) cm인 직각삼각형에서 나머지 한 변의 길이는 몇 cm인가요?",
                     ans: "\(b)", unit: "cm",
                     why: "b² = \(c)² - \(a)² = \(c * c) - \(a * a) = \(b * b), so b = \(b).",
                     kwhy: "b² = \(c)² - \(a)² = \(c * c) - \(a * a) = \(b * b), b = \(b)")
        case 4:
            let (p, r) = d.pick([(1, 2), (2, 3), (1, 3)])
            let k = d.int(1...5)
            let small = p * p * p * k
            return q(u, "Two similar solids have a similarity ratio of \(p) : \(r). The smaller one has a volume of \(small) cm³. What is the volume of the larger one?",
                     "닮음비가 \(p) : \(r)인 두 닮은 입체도형에서 작은 입체도형의 부피가 \(small) cm³예요. 큰 입체도형의 부피는 몇 cm³인가요?",
                     ans: "\(r * r * r * k)", unit: "cm³",
                     why: "The volume ratio is \(p)³ : \(r)³ = \(p * p * p) : \(r * r * r). Larger volume = \(small) × \(r * r * r)/\(p * p * p) = \(r * r * r * k) cm³.",
                     kwhy: "부피의 비는 닮음비의 세제곱: \(p)³ : \(r)³ = \(p * p * p) : \(r * r * r). 큰 입체도형의 부피 = \(small) × \(r * r * r)/\(p * p * p) = \(r * r * r * k) cm³")
        default:
            if d.bool() {
                let x = d.int(3...20) * 2
                return q(u, "In triangle ABC, M is the midpoint of AB and N is the midpoint of AC. BC = \(x) cm. How long is MN?",
                         "삼각형 ABC에서 점 M, N은 각각 AB, AC의 중점이고 BC = \(x) cm예요. MN의 길이는 몇 cm인가요?",
                         ans: "\(x / 2)", unit: "cm",
                         why: "Midpoint theorem: MN is parallel to BC and half as long: \(x) ÷ 2 = \(x / 2) cm.",
                         kwhy: "삼각형의 두 변의 중점을 연결한 선분은 나머지 변과 평행하고 길이는 그 절반이에요: \(x) ÷ 2 = \(x / 2) cm")
            } else {
                let (a, b, c) = d.pick(triples)
                return q(u, "A rectangle is \(a) cm by \(b) cm. How long is its diagonal?",
                         "가로 \(a) cm, 세로 \(b) cm인 직사각형의 대각선의 길이는 몇 cm인가요?",
                         ans: "\(c)", unit: "cm",
                         why: "The diagonal is the hypotenuse of a right triangle with legs \(a) and \(b): √(\(a * a) + \(b * b)) = √\(c * c) = \(c) cm.",
                         kwhy: "대각선은 두 변이 \(a), \(b)인 직각삼각형의 빗변이에요: √(\(a * a) + \(b * b)) = √\(c * c) = \(c) cm")
            }
        }
    }

    // MARK: - 경우의 수와 확률

    static func m2Probability(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.m2Probability
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let s = d.int(2...12)
            let cnt = 6 - abs(s - 7)
            return q(u, "Two dice are rolled. What is the probability that the sum is \(s)?",
                     "두 개의 주사위를 동시에 던질 때, 나온 눈의 수의 합이 \(s)일 확률은?",
                     ans: Frac(cnt, 36).mixed,
                     why: "There are 6 × 6 = 36 outcomes. Pairs with sum \(s): \(cnt). Probability = \(simp(cnt, 36)).",
                     kwhy: "모든 경우는 6 × 6 = 36가지. 합이 \(s)인 경우는 \(cnt)가지. 확률 = \(simp(cnt, 36))")
        case 1:
            let n = d.int(2...3), k = d.int(0...n)
            let c = n == 2 ? [1, 2, 1][k] : [1, 3, 3, 1][k]
            let all = n == 2 ? 4 : 8
            return q(u, "\(n) coins are tossed. What is the probability of getting exactly \(k) heads?",
                     "동전 \(n)개를 동시에 던질 때, 앞면이 정확히 \(k)개 나올 확률은?",
                     ans: Frac(c, all).mixed,
                     why: "There are 2\(sup(n)) = \(all) outcomes. Ways to get exactly \(k) heads: \(c). Probability = \(simp(c, all)).",
                     kwhy: "모든 경우는 2\(sup(n)) = \(all)가지. 앞면이 \(k)개인 경우는 \(c)가지. 확률 = \(simp(c, all))")
        case 2:
            let r = d.int(1...9), b = d.int(1...9)
            return q(u, "A bag has \(r) red balls and \(b) blue balls. One ball is picked. What is the probability that it is red?",
                     "주머니에 빨간 공 \(r)개, 파란 공 \(b)개가 들어 있어요. 한 개를 꺼낼 때 빨간 공일 확률은?",
                     ans: Frac(r, r + b).mixed,
                     why: "Probability = red ÷ total = \(r) ÷ \(r + b) = \(simp(r, r + b)).",
                     kwhy: "확률 = (빨간 공의 수) ÷ (전체 공의 수) = \(r) ÷ \(r + b) = \(simp(r, r + b))")
        case 3:
            switch d.int(0...2) {
            case 0:
                let n = d.int(3...5)
                let f = (1...n).reduce(1, *)
                return q(u, "In how many ways can \(n) people stand in a line?", "\(n)명이 한 줄로 서는 경우의 수는?",
                         ans: "\(f)", unit: "ways",
                         why: "\((1...n).reversed().map(String.init).joined(separator: " × ")) = \(f).",
                         kwhy: "\((1...n).reversed().map(String.init).joined(separator: " × ")) = \(f)가지")
            case 1:
                let n = d.int(4...10)
                return q(u, "In how many ways can 2 representatives be chosen from \(n) students?", "학생 \(n)명 중에서 대표 2명을 뽑는 경우의 수는?",
                         ans: "\(n * (n - 1) / 2)", unit: "ways",
                         why: "\(n) × \(n - 1) ÷ 2 = \(n * (n - 1) / 2) (order does not matter, so divide by 2).",
                         kwhy: "자격이 같은 2명을 뽑으므로 순서를 생각하지 않아요: \(n) × \(n - 1) ÷ 2 = \(n * (n - 1) / 2)가지")
            default:
                let n = d.int(4...10)
                return q(u, "In how many ways can a president and a vice president be chosen from \(n) students?",
                         "학생 \(n)명 중에서 회장 1명, 부회장 1명을 뽑는 경우의 수는?",
                         ans: "\(n * (n - 1))", unit: "ways",
                         why: "President: \(n) choices, vice president: \(n - 1) choices. \(n) × \(n - 1) = \(n * (n - 1)).",
                         kwhy: "회장 \(n)가지, 부회장은 나머지 \(n - 1)가지: \(n) × \(n - 1) = \(n * (n - 1))가지")
            }
        case 4:
            let n = d.int(2...5)
            let all = ipow(2, n)
            return q(u, "A coin is tossed \(n) times. What is the probability of getting at least one head?",
                     "동전 한 개를 \(n)번 던질 때, 앞면이 적어도 한 번 나올 확률은?",
                     ans: Frac(all - 1, all).mixed,
                     why: "Use the opposite event: P(no heads) = (1/2)\(sup(n)) = 1/\(all). P(at least one) = 1 - 1/\(all) = \(simp(all - 1, all)).",
                     kwhy: "'적어도'는 반대 경우를 이용해요: 한 번도 앞면이 안 나올 확률 = (1/2)\(sup(n)) = 1/\(all). 1 - 1/\(all) = \(simp(all - 1, all))")
        default:
            let r = d.int(2...6), b = d.int(1...6)
            let t = r + b
            return q(u, "A bag has \(r) red balls and \(b) blue balls. Two balls are taken out one after the other without putting the first back. What is the probability that both are red?",
                     "주머니에 빨간 공 \(r)개, 파란 공 \(b)개가 있어요. 공을 한 개씩 연속으로 두 번 꺼낼 때(꺼낸 공은 다시 넣지 않아요), 두 개 모두 빨간 공일 확률은?",
                     ans: Frac(r * (r - 1), t * (t - 1)).mixed,
                     why: "First red: \(r)/\(t). Then \(r - 1) red of \(t - 1) left: \(r - 1)/\(t - 1). Multiply: \(r)/\(t) × \(r - 1)/\(t - 1) = \(simp(r * (r - 1), t * (t - 1))).",
                     kwhy: "첫 번째가 빨간 공일 확률 \(r)/\(t), 남은 \(t - 1)개 중 빨간 공 \(r - 1)개이므로 두 번째는 \(r - 1)/\(t - 1). 곱하면 \(simp(r * (r - 1), t * (t - 1)))")
        }
    }
}
