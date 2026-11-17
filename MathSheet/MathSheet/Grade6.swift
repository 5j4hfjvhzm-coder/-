import Foundation

/// 초등 6학년 1학기 · 2학기 문제
extension Generator {
    private static let polyNames: [(Int, String, String)] = [
        (3, "triangular", "삼각"), (4, "quadrangular", "사각"), (5, "pentagonal", "오각"),
        (6, "hexagonal", "육각"), (7, "heptagonal", "칠각"), (8, "octagonal", "팔각"),
    ]

    // MARK: - 6-1 분수의 나눗셈

    static func e61Frac(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e61Frac
        let calc = "Calculate. Write your answer in simplest form."
        let calcKo = "계산하세요. 답은 기약분수(또는 대분수)로 나타내세요."
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            var a = d.int(1...12), b = d.int(2...9)
            while a % b == 0 { a = d.int(1...12); b = d.int(2...9) }
            return q(u, calc, calcKo, ans: Frac(a, b).mixed, expr: "\(a) ÷ \(b)",
                     why: "a ÷ b = a/b: the number being divided is the numerator. \(a) ÷ \(b) = \(simp(a, b))",
                     kwhy: "(자연수) ÷ (자연수)의 몫은 나누어지는 수를 분자, 나누는 수를 분모로 써요. \(a) ÷ \(b) = \(simp(a, b))")
        case 1:
            let f = d.properFraction(), w = d.int(2...9)
            return q(u, calc, calcKo, ans: Frac(f.n, f.d * w).mixed, expr: "\(f.improper) ÷ \(w)",
                     why: "Dividing by \(w) is the same as multiplying by 1/\(w): \(f.improper) × 1/\(w) = \(simp(f.n, f.d * w))",
                     kwhy: "÷ \(josa("\(w)", "은", "는")) × 1/\(w)로 바꿔서 계산해요: \(f.improper) × 1/\(w) = \(simp(f.n, f.d * w))")
        case 2:
            let p = d.properFraction(maxDen: 6), w = d.int(2...6)
            let m = Frac(d.int(1...3) * p.d + p.n, p.d)
            return q(u, calc, calcKo, ans: Frac(m.n, m.d * w).mixed, expr: "\(m.mixed) ÷ \(w)",
                     why: "Change the mixed number to an improper fraction: \(m.mixed) = \(m.improper). Then \(m.improper) × 1/\(w) = \(simp(m.n, m.d * w))",
                     kwhy: "대분수를 가분수로 바꿔요: \(m.mixed) = \(m.improper). 그다음 \(m.improper) × 1/\(w) = \(simp(m.n, m.d * w))")
        case 3:
            var w = d.int(2...9), n = d.int(2...9)
            while w % n == 0 { w = d.int(2...9); n = d.int(2...9) }
            return q(u, "\(w) kg of rice is shared equally among \(n) people. How many kg of rice does each person get?",
                     "쌀 \(w) kg을 \(n)명이 똑같이 나누어 가져요. 한 사람이 가지는 쌀은 몇 kg인가요?",
                     ans: Frac(w, n).mixed, unit: "kg",
                     why: "\(w) ÷ \(n) = \(simp(w, n)) kg",
                     kwhy: "\(w) ÷ \(n) = \(simp(w, n)) kg이에요.")
        case 4:
            let f = d.properFraction(maxDen: 8), w = d.int(2...7)
            let m = Frac(d.int(1...4) * f.d + f.n, f.d)
            return q(u, "What number goes in the box?", "□ 안에 알맞은 수를 구하세요.",
                     ans: Frac(m.n, m.d * w).mixed, expr: "□ × \(w) = \(m.mixed)",
                     why: "□ = \(m.mixed) ÷ \(w) = \(m.improper) × 1/\(w) = \(simp(m.n, m.d * w))",
                     kwhy: "□ = \(m.mixed) ÷ \(w) = \(m.improper) × 1/\(w) = \(simp(m.n, m.d * w))")
        default:
            let (sides, en, ko) = d.pick([(3, "an equilateral triangle", "정삼각형"), (4, "a square", "정사각형"), (5, "a regular pentagon", "정오각형")])
            let f = d.properFraction(maxDen: 7)
            let per = Frac(d.int(2...9) * f.d + f.n, f.d)
            return q(u, "The perimeter of \(en) is \(per.mixed) m. How long is one side?",
                     "둘레가 \(per.mixed) m인 \(ko)이 있어요. 한 변의 길이는 몇 m인가요?",
                     ans: Frac(per.n, per.d * sides).mixed, unit: "m",
                     why: "It has \(sides) equal sides, so divide the perimeter by \(sides): \(per.mixed) ÷ \(sides) = \(per.improper) × 1/\(sides) = \(simp(per.n, per.d * sides)) m",
                     kwhy: "변이 \(sides)개이고 길이가 모두 같으니 둘레를 \(sides)로 나눠요: \(per.mixed) ÷ \(sides) = \(per.improper) × 1/\(sides) = \(simp(per.n, per.d * sides)) m")
        }
    }

    // MARK: - 6-1 각기둥과 각뿔

    static func e61Prism(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e61Prism
        let (n, en, ko) = d.pick(polyNames)
        let parts: [(String, String)] = [("faces", "면은"), ("edges", "모서리는"), ("vertices", "꼭짓점은")]
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let i = d.int(0...2)
            let ans = [n + 2, 3 * n, 2 * n][i]
            return q(u, "How many \(parts[i].0) does a \(en) prism have?", "\(ko)기둥의 \(parts[i].1) 몇 개인가요?",
                     ans: "\(ans)", unit: parts[i].0,
                     why: "A prism with an \(n)-sided base has \(n) + 2 = \(n + 2) faces, \(n) × 3 = \(3 * n) edges, and \(n) × 2 = \(2 * n) vertices.",
                     kwhy: "밑면이 \(n)각형인 각기둥은 면이 \(n) + 2 = \(n + 2)개, 모서리가 \(n) × 3 = \(3 * n)개, 꼭짓점이 \(n) × 2 = \(2 * n)개예요.")
        case 1:
            let i = d.int(0...2)
            let ans = [n + 1, 2 * n, n + 1][i]
            return q(u, "How many \(parts[i].0) does a \(en) pyramid have?", "\(ko)뿔의 \(parts[i].1) 몇 개인가요?",
                     ans: "\(ans)", unit: parts[i].0,
                     why: "A pyramid with an \(n)-sided base has \(n) + 1 = \(n + 1) faces, \(n) × 2 = \(2 * n) edges, and \(n) + 1 = \(n + 1) vertices.",
                     kwhy: "밑면이 \(n)각형인 각뿔은 면이 \(n) + 1 = \(n + 1)개, 모서리가 \(n) × 2 = \(2 * n)개, 꼭짓점이 \(n) + 1 = \(n + 1)개예요.")
        case 2:
            let prism = d.bool()
            return q(u, "How many side faces (lateral faces) does a \(en) \(prism ? "prism" : "pyramid") have?",
                     "\(ko)\(prism ? "기둥" : "뿔")의 옆면은 몇 개인가요?",
                     ans: "\(n)", unit: "faces",
                     why: "The number of side faces equals the number of sides of the base: \(n). They are \(prism ? "rectangles" : "triangles").",
                     kwhy: "옆면의 수는 밑면의 변의 수와 같아요: \(n)개. 옆면 모양은 \(prism ? "직사각형" : "삼각형")이에요.")
        case 3:
            return q(u, "For a \(en) prism, what is (number of faces) + (number of edges) + (number of vertices)?",
                     "\(ko)기둥의 면의 수, 모서리의 수, 꼭짓점의 수의 합은 얼마인가요?",
                     ans: "\(6 * n + 2)",
                     why: "Faces \(n + 2), edges \(3 * n), vertices \(2 * n): \(n + 2) + \(3 * n) + \(2 * n) = \(6 * n + 2).",
                     kwhy: "면 \(n + 2)개, 모서리 \(3 * n)개, 꼭짓점 \(2 * n)개이므로 \(n + 2) + \(3 * n) + \(2 * n) = \(6 * n + 2)예요.")
        case 4:
            return q(u, "A prism has \(3 * n) edges. How many vertices does it have?",
                     "모서리가 \(3 * n)개인 각기둥이 있어요. 이 각기둥의 꼭짓점은 몇 개인가요?",
                     ans: "\(2 * n)", unit: "vertices",
                     why: "A prism with an n-sided base has 3n edges, so n = \(3 * n) ÷ 3 = \(n). Vertices: \(n) × 2 = \(2 * n).",
                     kwhy: "밑면이 n각형인 각기둥의 모서리는 n × 3개예요. n = \(3 * n) ÷ 3 = \(n)이므로 꼭짓점은 \(n) × 2 = \(2 * n)개예요.")
        default:
            return q(u, "A pyramid has \(2 * n) edges. How many faces does it have?",
                     "모서리가 \(2 * n)개인 각뿔이 있어요. 이 각뿔의 면은 몇 개인가요?",
                     ans: "\(n + 1)", unit: "faces",
                     why: "A pyramid with an n-sided base has 2n edges, so n = \(2 * n) ÷ 2 = \(n). Faces: \(n) + 1 = \(n + 1).",
                     kwhy: "밑면이 n각형인 각뿔의 모서리는 n × 2개예요. n = \(2 * n) ÷ 2 = \(n)이므로 면은 \(n) + 1 = \(n + 1)개예요.")
        }
    }

    // MARK: - 6-1 소수의 나눗셈

    private static func nz10(_ d: Dice, _ r: ClosedRange<Int>) -> Int {
        var v = d.int(r)
        while v % 10 == 0 { v = d.int(r) }
        return v
    }

    static func e61Dec(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e61Dec
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let qv = nz10(d, 11...999), w = d.int(2...9)
            return q(u, "Calculate.", "계산하세요.", ans: dec(qv, 2), expr: "\(dec(qv * w, 2)) ÷ \(w)",
                     why: "Divide as whole numbers: \(qv * w) ÷ \(w) = \(qv). The answer has the same number of decimal places (2): \(dec(qv, 2)).",
                     kwhy: "자연수처럼 나눠요: \(qv * w) ÷ \(w) = \(qv). 나누어지는 수가 소수 두 자리이므로 몫도 소수 두 자리예요: \(dec(qv, 2))")
        case 1:
            let w = d.pick([2, 4, 5, 8])
            var a = d.int(1...40)
            while a % w == 0 { a = d.int(1...40) }
            let ans = dec(a * 1000 / w, 3)
            return q(u, "Write the quotient as a decimal.", "몫을 소수로 나타내세요.", ans: ans, expr: "\(a) ÷ \(w)",
                     why: "Write \(a) as \(a).000 and keep dividing: \(a) ÷ \(w) = \(ans).",
                     kwhy: "\(josa("\(a)", "을", "를")) \(a).000으로 생각하고 계속 나눠요: \(a) ÷ \(w) = \(ans)")
        case 2:
            let qv = nz10(d, 2...49), n = d.int(2...9)
            return q(u, "\(dec(qv * n, 1)) L of water is poured equally into \(n) bottles. How much water is in each bottle?",
                     "물 \(dec(qv * n, 1)) L를 병 \(n)개에 똑같이 나누어 담았어요. 병 한 개에 담긴 물은 몇 L인가요?",
                     ans: dec(qv, 1), unit: "L",
                     why: "\(dec(qv * n, 1)) ÷ \(n) = \(dec(qv, 1)) L",
                     kwhy: "\(dec(qv * n, 1)) ÷ \(n) = \(dec(qv, 1)) L예요.")
        case 3:
            let s = nz10(d, 11...99)
            return q(u, "The perimeter of a square is \(dec(4 * s, 1)) cm. How long is one side?",
                     "둘레가 \(dec(4 * s, 1)) cm인 정사각형의 한 변의 길이는 몇 cm인가요?",
                     ans: dec(s, 1), unit: "cm",
                     why: "A square has 4 equal sides: \(dec(4 * s, 1)) ÷ 4 = \(dec(s, 1)) cm",
                     kwhy: "정사각형은 네 변의 길이가 같아요: \(dec(4 * s, 1)) ÷ 4 = \(dec(s, 1)) cm")
        case 4:
            let k = nz10(d, 11...99), m = d.int(3...9)
            return q(u, "□ × \(m) = \(dec(k * m, 1)). What is □ ÷ 4?",
                     "□ × \(m) = \(dec(k * m, 1))일 때, □ ÷ 4의 값을 구하세요.",
                     ans: dec(k * 25, 3),
                     why: "□ = \(dec(k * m, 1)) ÷ \(m) = \(dec(k, 1)). Then \(dec(k, 1)) ÷ 4 = \(dec(k * 25, 3)).",
                     kwhy: "□ = \(dec(k * m, 1)) ÷ \(m) = \(dec(k, 1))이에요. 그래서 \(dec(k, 1)) ÷ 4 = \(dec(k * 25, 3))")
        default:
            let p = nz10(d, 11...99), cuts = d.int(2...8)
            let pieces = cuts + 1
            return q(u, "A pipe \(dec(p * pieces, 2)) m long is cut \(cuts) times into pieces of equal length. How long is each piece?",
                     "길이가 \(dec(p * pieces, 2)) m인 관을 \(cuts)번 잘라서 길이가 같은 도막으로 나누었어요. 한 도막의 길이는 몇 m인가요?",
                     ans: dec(p, 2), unit: "m",
                     why: "Cutting \(cuts) times makes \(pieces) pieces (not \(cuts)!). \(dec(p * pieces, 2)) ÷ \(pieces) = \(dec(p, 2)) m",
                     kwhy: "\(cuts)번 자르면 도막은 \(pieces)개가 돼요 (\(cuts)개가 아니에요!). \(dec(p * pieces, 2)) ÷ \(pieces) = \(dec(p, 2)) m")
        }
    }

    // MARK: - 6-1 비와 비율

    static func e61Ratio(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e61Ratio
        let (name, nk) = d.pick(people)
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let b = d.pick([2, 4, 5, 8, 10, 20, 25, 40, 50]), a = d.int(1...30)
            let ans = dec(a * 1000 / b, 3)
            return q(u, "Write the ratio value of \(a) : \(b) as a decimal.", "\(a) : \(b)의 비율을 소수로 나타내세요.",
                     ans: ans,
                     why: "Ratio value = (compared amount) ÷ (base amount) = \(a) ÷ \(b) = \(ans).",
                     kwhy: "비율 = (비교하는 양) ÷ (기준량) = \(a) ÷ \(b) = \(ans)")
        case 1:
            let b = d.pick([4, 5, 10, 20, 25, 50]), a = d.int(1...(b - 1))
            return q(u, "\(name) took \(b) shots and made \(a) of them. What percent of the shots went in?",
                     "\(josa(nk, "은", "는")) 슛을 \(b)번 던져서 \(a)번 넣었어요. 넣은 비율은 몇 %인가요?",
                     ans: "\(a * 100 / b)", unit: "%",
                     why: "\(a) ÷ \(b) × 100 = \(a * 100 / b)%",
                     kwhy: "백분율 = 비율 × 100: \(a) ÷ \(b) × 100 = \(a * 100 / b)%")
        case 2:
            let p = d.int(2...30) * 1000, r = d.pick([10, 20, 25, 30, 40, 50])
            let sale = p * (100 - r) / 100
            return q(u, "A bag costs \(comma(p)) won. It is on sale for \(r)% off. What is the sale price?",
                     "\(comma(p))원짜리 가방을 \(r)% 할인해서 팔아요. 할인된 가격은 얼마인가요?",
                     ans: comma(sale), unit: "won",
                     why: "Discount: \(comma(p)) × \(r)/100 = \(comma(p * r / 100)) won. Sale price: \(comma(p)) − \(comma(p * r / 100)) = \(comma(sale)) won.",
                     kwhy: "할인 금액: \(comma(p)) × \(r)/100 = \(comma(p * r / 100))원. 할인된 가격: \(comma(p)) − \(comma(p * r / 100)) = \(comma(sale))원")
        case 3:
            let s = d.int(40...90), t = d.int(2...5)
            return q(u, "A car traveled \(s * t) km in \(t) hours at the same speed. How many km did it travel per hour?",
                     "자동차가 같은 빠르기로 \(t)시간 동안 \(s * t) km를 달렸어요. 1시간 동안 달린 거리는 몇 km인가요?",
                     ans: "\(s)", unit: "km",
                     why: "Distance per hour = \(s * t) ÷ \(t) = \(s) km.",
                     kwhy: "걸린 시간에 대한 간 거리의 비율: \(s * t) ÷ \(t) = \(s) km")
        case 4:
            var t = 0, p = 0
            repeat { t = d.pick([100, 200, 250, 400, 500]); p = d.pick([4, 5, 8, 10, 12, 15, 20, 25]) } while (t * p) % 100 != 0
            let s = t * p / 100
            return q(u, "\(s) g of salt is dissolved in \(t - s) g of water. What is the concentration of the salt water in percent?",
                     "물 \(t - s) g에 소금 \(s) g을 녹였어요. 소금물의 진하기는 몇 %인가요?",
                     ans: "\(p)", unit: "%",
                     why: "The salt water weighs \(t - s) + \(s) = \(t) g (not \(t - s) g!). Concentration: \(s) ÷ \(t) × 100 = \(p)%.",
                     kwhy: "소금물의 양은 물 + 소금 = \(t - s) + \(s) = \(t) g이에요 (물만 \(t - s) g이 아니에요!). 진하기: \(s) ÷ \(t) × 100 = \(p)%")
        default:
            let p = d.int(1...9) * 10000, a = d.pick([10, 20, 25, 30, 50]), b = d.pick([10, 20, 25, 30, 50])
            let up = p * (100 + a) / 100
            let fin = p / 10000 * (100 + a) * (100 - b)
            return q(u, "A toy costs \(comma(p)) won. The price goes up by \(a)%, and then the new price goes down by \(b)%. What is the final price?",
                     "\(comma(p))원짜리 장난감의 가격을 \(a)% 올렸다가, 올린 가격에서 다시 \(b)% 내렸어요. 마지막 가격은 얼마인가요?",
                     ans: comma(fin), unit: "won",
                     why: "After going up: \(comma(p)) × \(100 + a)/100 = \(comma(up)) won. After going down: \(comma(up)) × \(100 - b)/100 = \(comma(fin)) won.",
                     kwhy: "올린 가격: \(comma(p)) × \(100 + a)/100 = \(comma(up))원. 내린 가격: \(comma(up)) × \(100 - b)/100 = \(comma(fin))원 (처음 가격 기준이 아니라 올린 가격 기준이에요!)")
        }
    }

    // MARK: - 6-1 여러 가지 그래프

    static func e61Graph(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e61Graph
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let p = d.int(1...12) * 5
            return q(u, "In a pie chart, one part is \(p)% of the whole. What is the central angle of that part?",
                     "원그래프에서 어떤 항목이 전체의 \(p)%예요. 이 항목이 차지하는 부분의 중심각은 몇 도인가요?",
                     ans: "\(18 * p / 5)", unit: "°",
                     why: "A whole circle is 360°. 360 × \(p)/100 = \(18 * p / 5)°.",
                     kwhy: "원 전체는 360°예요. 360 × \(p)/100 = \(18 * p / 5)°")
        case 1:
            var t = 0, p = 0
            repeat { t = d.pick([20, 40, 50, 60, 80, 200, 300]); p = d.int(1...12) * 5 } while (t * p) % 100 != 0
            return q(u, "There are \(t) students. \(p)% of them like soccer. How many students like soccer?",
                     "학생 \(t)명 중 \(p)%가 축구를 좋아해요. 축구를 좋아하는 학생은 몇 명인가요?",
                     ans: "\(t * p / 100)", unit: "students",
                     why: "\(t) × \(p)/100 = \(t * p / 100) students.",
                     kwhy: "\(t) × \(p)/100 = \(t * p / 100)명")
        case 2:
            var l = 0, c = 0
            repeat { l = d.pick([10, 20, 25, 40]); c = d.int(1...(l - 1)) } while (c * 100) % l != 0
            return q(u, "A band graph is \(l) cm long. The part for 'rice' is \(c) cm long. What percent of the whole is 'rice'?",
                     "길이가 \(l) cm인 띠그래프에서 '밥' 부분의 길이는 \(c) cm예요. '밥'은 전체의 몇 %인가요?",
                     ans: "\(c * 100 / l)", unit: "%",
                     why: "\(c) ÷ \(l) × 100 = \(c * 100 / l)%",
                     kwhy: "\(c) ÷ \(l) × 100 = \(c * 100 / l)%")
        case 3:
            var a = 0, b = 0, c = 0
            repeat { a = d.int(2...9) * 5; b = d.int(2...9) * 5; c = d.int(1...6) * 5 } while a + b + c >= 95
            let rest = 100 - a - b - c
            return q(u, "In a pie chart, A is \(a)%, B is \(b)%, C is \(c)%, and D is the rest. What percent is D?",
                     "원그래프에서 A는 \(a)%, B는 \(b)%, C는 \(c)%이고, 나머지는 D예요. D는 몇 %인가요?",
                     ans: "\(rest)", unit: "%",
                     why: "All the parts add up to 100%: 100 − \(a) − \(b) − \(c) = \(rest)%.",
                     kwhy: "전체는 100%예요: 100 − \(a) − \(b) − \(c) = \(rest)%")
        case 4:
            var a = 0, b = 0
            repeat { a = d.int(4...10) * 5; b = d.int(2...8) * 5 } while (100 - a - b) % 3 != 0 || 100 - a - b < 15
            let r = 100 - a - b
            return q(u, "In a pie chart, A is \(a)% and B is \(b)%. The rest is C and D, and C is twice as big as D. What percent is C?",
                     "원그래프에서 A는 \(a)%, B는 \(b)%예요. 나머지는 C와 D이고, C는 D의 2배예요. C는 몇 %인가요?",
                     ans: "\(2 * r / 3)", unit: "%",
                     why: "C + D = 100 − \(a) − \(b) = \(r)%. If D is 1 part, C is 2 parts: 3 parts = \(r)%, 1 part = \(r / 3)%. C = \(r / 3) × 2 = \(2 * r / 3)%.",
                     kwhy: "C + D = 100 − \(a) − \(b) = \(r)%. D를 1이라 하면 C는 2이므로 3 = \(r)%, 1 = \(r / 3)%. C = \(r / 3) × 2 = \(2 * r / 3)%")
        default:
            var t = 0, s = 0
            repeat { t = d.pick([120, 180, 200, 240, 360]); s = d.int(1...(t / 2)) } while (360 * s) % t != 0
            let angle = 360 * s / t
            return q(u, "A pie chart shows the favorite pets of \(t) students. The part for 'dogs' has a central angle of \(angle)°. How many students chose dogs?",
                     "학생 \(t)명이 좋아하는 동물을 조사한 원그래프에서 '개' 부분의 중심각이 \(angle)°예요. 개를 고른 학생은 몇 명인가요?",
                     ans: "\(s)", unit: "students",
                     why: "\(angle)° out of 360° is \(angle)/360 of the whole. \(t) × \(angle)/360 = \(s) students.",
                     kwhy: "\(angle)°는 전체 360°의 \(angle)/360이에요. \(t) × \(angle)/360 = \(s)명")
        }
    }

    // MARK: - 6-1 직육면체의 부피와 겉넓이

    static func e61Volume(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e61Volume
        let a = d.int(2...12), b = d.int(2...12), c = d.int(2...12), e = d.int(2...10)
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            return q(u, "A cuboid is \(a) cm long, \(b) cm wide, and \(c) cm high. What is its volume?",
                     "가로 \(a) cm, 세로 \(b) cm, 높이 \(c) cm인 직육면체의 부피는 몇 cm³인가요?",
                     ans: "\(a * b * c)", unit: "cm³",
                     why: "Volume = length × width × height = \(a) × \(b) × \(c) = \(a * b * c) cm³",
                     kwhy: "직육면체의 부피 = 가로 × 세로 × 높이 = \(a) × \(b) × \(c) = \(a * b * c) cm³")
        case 1:
            return q(u, "Each edge of a cube is \(e) cm long. What is its volume?",
                     "한 모서리의 길이가 \(e) cm인 정육면체의 부피는 몇 cm³인가요?",
                     ans: "\(e * e * e)", unit: "cm³",
                     why: "Volume = edge × edge × edge = \(e) × \(e) × \(e) = \(e * e * e) cm³",
                     kwhy: "정육면체의 부피 = 한 모서리 × 한 모서리 × 한 모서리 = \(e) × \(e) × \(e) = \(e * e * e) cm³")
        case 2:
            let s = 2 * (a * b + b * c + c * a)
            return q(u, "A cuboid is \(a) cm long, \(b) cm wide, and \(c) cm high. What is its surface area?",
                     "가로 \(a) cm, 세로 \(b) cm, 높이 \(c) cm인 직육면체의 겉넓이는 몇 cm²인가요?",
                     ans: "\(s)", unit: "cm²",
                     why: "Surface area = (ab + bc + ca) × 2 = (\(a * b) + \(b * c) + \(c * a)) × 2 = \(s) cm²",
                     kwhy: "겉넓이 = (서로 다른 세 면의 넓이의 합) × 2 = (\(a * b) + \(b * c) + \(c * a)) × 2 = \(s) cm²")
        case 3:
            return q(u, "Each edge of a cube is \(e) cm long. What is its surface area?",
                     "한 모서리의 길이가 \(e) cm인 정육면체의 겉넓이는 몇 cm²인가요?",
                     ans: "\(6 * e * e)", unit: "cm²",
                     why: "A cube has 6 equal square faces: \(e) × \(e) × 6 = \(6 * e * e) cm²",
                     kwhy: "정육면체는 넓이가 같은 정사각형 면이 6개예요: \(e) × \(e) × 6 = \(6 * e * e) cm²")
        case 4:
            let v = a * b * c
            return q(u, "A cuboid has a volume of \(v) cm³. It is \(a) cm long and \(b) cm wide. How high is it?",
                     "부피가 \(v) cm³인 직육면체의 가로는 \(a) cm, 세로는 \(b) cm예요. 높이는 몇 cm인가요?",
                     ans: "\(c)", unit: "cm",
                     why: "Height = volume ÷ (length × width) = \(v) ÷ \(a * b) = \(c) cm",
                     kwhy: "높이 = 부피 ÷ (가로 × 세로) = \(v) ÷ \(a * b) = \(c) cm")
        default:
            if d.bool() {
                return q(u, "The surface area of a cube is \(6 * e * e) cm². What is its volume?",
                         "겉넓이가 \(6 * e * e) cm²인 정육면체의 부피는 몇 cm³인가요?",
                         ans: "\(e * e * e)", unit: "cm³",
                         why: "One face: \(6 * e * e) ÷ 6 = \(e * e) cm², so one edge is \(e) cm (\(e) × \(e) = \(e * e)). Volume: \(e) × \(e) × \(e) = \(e * e * e) cm³",
                         kwhy: "한 면의 넓이: \(6 * e * e) ÷ 6 = \(e * e) cm²이므로 한 모서리는 \(e) cm예요 (\(e) × \(e) = \(e * e)). 부피: \(e) × \(e) × \(e) = \(e * e * e) cm³")
            } else {
                let x = d.int(1...5), y = d.int(1...5), z = d.pick([20, 40, 50, 60, 80])
                return q(u, "A box is \(x) m long, \(y) m wide, and \(z) cm high. What is its volume in m³?",
                         "가로 \(x) m, 세로 \(y) m, 높이 \(z) cm인 상자의 부피는 몇 m³인가요?",
                         ans: dec(x * y * z, 2), unit: "m³",
                         why: "Change \(z) cm to \(dec(z, 2)) m first. \(x) × \(y) × \(dec(z, 2)) = \(dec(x * y * z, 2)) m³",
                         kwhy: "먼저 \(z) cm를 \(dec(z, 2)) m로 바꿔요. \(x) × \(y) × \(dec(z, 2)) = \(dec(x * y * z, 2)) m³")
            }
        }
    }

    // MARK: - 6-2 분수의 나눗셈

    static func e62Frac(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e62Frac
        let calc = "Calculate. Write your answer in simplest form."
        let calcKo = "계산하세요. 답은 기약분수(또는 대분수)로 나타내세요."
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let n = d.int(5...12)
            var a = d.int(1...(n - 1)), b = d.int(1...(n - 1))
            while a == b { a = d.int(1...(n - 1)); b = d.int(1...(n - 1)) }
            return q(u, calc, calcKo, ans: Frac(a, b).mixed, expr: "\(a)/\(n) ÷ \(b)/\(n)",
                     why: "When the denominators are the same, just divide the numerators: \(a) ÷ \(b) = \(simp(a, b))",
                     kwhy: "분모가 같으면 분자끼리 나눠요: \(a) ÷ \(b) = \(simp(a, b))")
        case 1:
            let f = d.properFraction(), g = d.properFraction()
            return q(u, calc, calcKo, ans: Frac(f.n * g.d, f.d * g.n).mixed, expr: "\(f.improper) ÷ \(g.improper)",
                     why: "Multiply by the reciprocal: \(f.improper) × \(g.d)/\(g.n) = \(simp(f.n * g.d, f.d * g.n))",
                     kwhy: "나누는 분수의 분모와 분자를 바꾸어 곱해요: \(f.improper) × \(g.d)/\(g.n) = \(simp(f.n * g.d, f.d * g.n))")
        case 2:
            let w = d.int(2...9), f = d.properFraction()
            return q(u, calc, calcKo, ans: Frac(w * f.d, f.n).mixed, expr: "\(w) ÷ \(f.improper)",
                     why: "\(w) ÷ \(f.improper) = \(w) × \(f.d)/\(f.n) = \(simp(w * f.d, f.n))",
                     kwhy: "\(w) ÷ \(f.improper) = \(w) × \(f.d)/\(f.n) = \(simp(w * f.d, f.n))")
        case 3:
            let p = d.properFraction(maxDen: 6), g = d.properFraction(maxDen: 6)
            let m = Frac(d.int(1...3) * p.d + p.n, p.d)
            return q(u, calc, calcKo, ans: Frac(m.n * g.d, m.d * g.n).mixed, expr: "\(m.mixed) ÷ \(g.improper)",
                     why: "\(m.mixed) = \(m.improper). \(m.improper) × \(g.d)/\(g.n) = \(simp(m.n * g.d, m.d * g.n))",
                     kwhy: "대분수를 가분수로: \(m.mixed) = \(m.improper). \(m.improper) × \(g.d)/\(g.n) = \(simp(m.n * g.d, m.d * g.n))")
        case 4:
            let f = d.properFraction(maxDen: 6)
            let p = d.properFraction(maxDen: 5)
            let g = Frac(d.int(1...4) * p.d + p.n, p.d)
            let a = Frac(g.n * f.d, g.d * f.n)
            return q(u, "With \(f.improper) kg of paint, you can paint \(g.mixed) m² of wall. How many m² can you paint with 1 kg of paint?",
                     "페인트 \(f.improper) kg으로 벽 \(g.mixed) m²를 칠할 수 있어요. 페인트 1 kg으로는 벽을 몇 m² 칠할 수 있나요?",
                     ans: a.mixed, unit: "m²",
                     why: "Area for 1 kg = area ÷ paint = \(g.mixed) ÷ \(f.improper) = \(g.improper) × \(f.d)/\(f.n) = \(simp(g.n * f.d, g.d * f.n)) m²",
                     kwhy: "1 kg으로 칠하는 넓이 = 칠한 넓이 ÷ 쓴 페인트 양 = \(g.mixed) ÷ \(f.improper) = \(g.improper) × \(f.d)/\(f.n) = \(simp(g.n * f.d, g.d * f.n)) m²")
        default:
            let f = d.properFraction(maxDen: 5), g = d.properFraction(maxDen: 7)
            let x = g * f
            let a = x * f
            return q(u, "A number divided by \(f.improper) is \(g.improper). What do you get when you multiply that number by \(f.improper)?",
                     "어떤 수 ÷ \(f.improper) = \(g.improper)일 때, (어떤 수) × \(f.improper)의 값은 얼마인가요?",
                     ans: a.mixed,
                     why: "The number = \(g.improper) × \(f.improper) = \(x.mixed). Then \(x.mixed) × \(f.improper) = \(a.mixed).",
                     kwhy: "어떤 수 = \(g.improper) × \(f.improper) = \(x.mixed)예요. 그래서 \(x.mixed) × \(f.improper) = \(a.mixed)")
        }
    }

    // MARK: - 6-2 소수의 나눗셈

    static func e62Dec(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e62Dec
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let b = nz10(d, 2...49), qv = d.int(2...9)
            return q(u, "Calculate.", "계산하세요.", ans: "\(qv)", expr: "\(dec(qv * b, 1)) ÷ \(dec(b, 1))",
                     why: "Multiply both numbers by 10: \(qv * b) ÷ \(b) = \(qv).",
                     kwhy: "나누는 수와 나누어지는 수에 똑같이 10을 곱해요: \(qv * b) ÷ \(b) = \(qv)")
        case 1:
            let qv = nz10(d, 11...99), b = nz10(d, 2...19)
            return q(u, "Calculate.", "계산하세요.", ans: dec(qv, 1), expr: "\(dec(qv * b, 2)) ÷ \(dec(b, 1))",
                     why: "Move both decimal points 1 place right: \(dec(qv * b, 1)) ÷ \(b) = \(dec(qv, 1)).",
                     kwhy: "두 수의 소수점을 똑같이 오른쪽으로 한 칸 옮겨요: \(dec(qv * b, 1)) ÷ \(b) = \(dec(qv, 1))")
        case 2:
            var b = 0, qv = 0
            repeat { b = d.pick([2, 4, 5, 6, 8, 12, 15, 25]); qv = d.int(2...60) } while (qv * b) % 10 != 0
            let w = qv * b / 10
            return q(u, "Calculate.", "계산하세요.", ans: "\(qv)", expr: "\(w) ÷ \(dec(b, 1))",
                     why: "Multiply both numbers by 10: \(w * 10) ÷ \(b) = \(qv).",
                     kwhy: "두 수에 똑같이 10을 곱해요: \(w * 10) ÷ \(b) = \(qv)")
        case 3:
            let a = d.int(10...99), b = d.pick([3, 6, 7, 9, 11])
            let tenths = (a * 20 + b) / (2 * b)
            let hundredths = a * 100 / b
            return q(u, "Find the quotient rounded to the nearest tenth (1 decimal place).",
                     "몫을 반올림하여 소수 첫째 자리까지 나타내세요.",
                     ans: dec(tenths, 1), expr: "\(a) ÷ \(b)",
                     why: "Divide to 2 decimal places: \(a) ÷ \(b) = \(dec(hundredths, 2))… The hundredths digit is \(hundredths % 10), so round \(hundredths % 10 >= 5 ? "up" : "down"): \(dec(tenths, 1)).",
                     kwhy: "소수 둘째 자리까지 구해요: \(a) ÷ \(b) = \(dec(hundredths, 2))… 소수 둘째 자리 숫자가 \(hundredths % 10)이므로 \(hundredths % 10 >= 5 ? "올려서" : "버려서") \(dec(tenths, 1))")
        case 4:
            let bb = d.pick([12, 15, 18, 25]), qv = d.int(3...12), r = d.int(1...(bb - 1))
            let total = qv * bb + r
            return q(u, "\(dec(total, 1)) L of juice is poured into bottles that each hold \(dec(bb, 1)) L. After filling as many bottles as possible, how many liters are left over?",
                     "주스 \(dec(total, 1)) L를 한 병에 \(dec(bb, 1)) L씩 담아요. 병을 최대한 채우고 남는 주스는 몇 L인가요?",
                     ans: dec(r, 1), unit: "L",
                     why: "\(dec(total, 1)) ÷ \(dec(bb, 1)) = \(qv) remainder \(dec(r, 1)). (Check: \(dec(bb, 1)) × \(qv) + \(dec(r, 1)) = \(dec(total, 1)).) The remainder keeps the original decimal point.",
                     kwhy: "\(dec(total, 1)) ÷ \(dec(bb, 1)) = \(qv) … \(dec(r, 1)). (확인: \(dec(bb, 1)) × \(qv) + \(dec(r, 1)) = \(dec(total, 1))) 나머지의 소수점은 처음 수의 소수점 자리에 맞춰요.")
        default:
            let p = nz10(d, 2...19), n = d.int(3...12)
            return q(u, "A rope \(dec(p * n, 1)) m long is cut into pieces that are each \(dec(p, 1)) m long. How many times must you cut it?",
                     "길이가 \(dec(p * n, 1)) m인 줄을 \(dec(p, 1)) m씩 잘라요. 모두 몇 번 잘라야 하나요?",
                     ans: "\(n - 1)", unit: "times",
                     why: "Pieces: \(dec(p * n, 1)) ÷ \(dec(p, 1)) = \(n). To make \(n) pieces you cut \(n) − 1 = \(n - 1) times.",
                     kwhy: "도막 수: \(dec(p * n, 1)) ÷ \(dec(p, 1)) = \(n)개. \(n)도막을 만들려면 \(n) − 1 = \(n - 1)번 잘라요.")
        }
    }

    // MARK: - 6-2 공간과 입체

    static func e62Space(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e62Space
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0, 1:
            let cols = (0..<d.int(4...6)).map { _ in d.int(1...4) }
            let list = cols.map(String.init).joined(separator: ", ")
            if d.bool() {
                let total = cols.reduce(0, +)
                return q(u, "A shape is built from unit cubes. In the top view, the numbers of cubes stacked on the squares are \(list). How many cubes are used in all?",
                         "쌓기나무로 쌓은 모양을 위에서 본 모양의 각 칸에 쌓은 개수를 쓰면 \(josa(list, "이에요", "예요")). 쌓기나무는 모두 몇 개인가요?",
                         ans: "\(total)", unit: "cubes",
                         why: "Add the numbers: \(cols.map(String.init).joined(separator: " + ")) = \(total).",
                         kwhy: "각 칸의 수를 모두 더해요: \(cols.map(String.init).joined(separator: " + ")) = \(total)개")
            } else {
                let fl = d.int(2...3)
                let n = cols.filter { $0 >= fl }.count
                return q(u, "A shape is built from unit cubes. In the top view, the numbers of cubes stacked on the squares are \(list). How many cubes are on floor \(fl)?",
                         "쌓기나무로 쌓은 모양을 위에서 본 모양의 각 칸에 쌓은 개수를 쓰면 \(josa(list, "이에요", "예요")). \(fl)층에 있는 쌓기나무는 몇 개인가요?",
                         ans: "\(n)", unit: "cubes",
                         why: "A square has a cube on floor \(fl) if its number is \(fl) or more. Count them: \(n).",
                         kwhy: "\(fl)층에 쌓기나무가 있으려면 그 칸의 수가 \(fl) 이상이어야 해요. 그런 칸을 세면 \(n)개예요.")
            }
        case 2:
            let n = d.int(2...6)
            return q(u, "How many unit cubes are needed to build a big cube that is \(n) cubes long on each edge?",
                     "쌓기나무로 한 모서리에 \(n)개씩 놓인 큰 정육면체를 만들려면 쌓기나무가 몇 개 필요한가요?",
                     ans: "\(n * n * n)", unit: "cubes",
                     why: "\(n) × \(n) × \(n) = \(n * n * n)",
                     kwhy: "\(n) × \(n) × \(n) = \(n * n * n)개")
        case 3:
            let n = d.int(3...5), x = d.int((n * n * n / 3)...(n * n * n - 2))
            return q(u, "You have \(x) unit cubes. How many more do you need to build a big cube that is \(n) cubes long on each edge?",
                     "쌓기나무가 \(x)개 있어요. 한 모서리에 \(n)개씩 놓인 큰 정육면체를 만들려면 몇 개가 더 필요한가요?",
                     ans: "\(n * n * n - x)", unit: "cubes",
                     why: "The big cube needs \(n) × \(n) × \(n) = \(n * n * n) cubes. \(n * n * n) − \(x) = \(n * n * n - x).",
                     kwhy: "큰 정육면체에는 \(n) × \(n) × \(n) = \(n * n * n)개가 필요해요. \(n * n * n) − \(x) = \(n * n * n - x)개")
        default:
            let n = d.int(3...6)
            let k = d.int(0...4)
            let asks = ["exactly 3 faces painted", "exactly 2 faces painted", "exactly 1 face painted", "no faces painted", "at least 1 face painted"]
            let asksKo = ["세 면이 칠해진", "두 면만 칠해진", "한 면만 칠해진", "한 면도 칠해지지 않은", "한 면 이상 칠해진"]
            let m = n - 2
            let ans = [8, 12 * m, 6 * m * m, m * m * m, n * n * n - m * m * m][k]
            let whys = [
                ("Only the 8 corner cubes have 3 painted faces.", "꼭짓점에 있는 8개만 세 면이 칠해져요."),
                ("Each of the 12 edges has \(n) − 2 = \(m) cubes with 2 painted faces: 12 × \(m) = \(12 * m).", "모서리 12개마다 꼭짓점을 뺀 \(n) − 2 = \(m)개가 두 면이 칠해져요: 12 × \(m) = \(12 * m)개"),
                ("Each of the 6 faces has a \(m) × \(m) middle part with 1 painted face: 6 × \(m * m) = \(6 * m * m).", "6개의 면마다 가운데 \(m) × \(m)개가 한 면만 칠해져요: 6 × \(m * m) = \(6 * m * m)개"),
                ("The inside cube \(m) × \(m) × \(m) = \(m * m * m) has no paint.", "속에 있는 \(m) × \(m) × \(m) = \(m * m * m)개는 칠해지지 않아요."),
                ("All \(n * n * n) cubes minus the \(m * m * m) unpainted inside cubes: \(n * n * n - m * m * m).", "전체 \(n * n * n)개에서 칠해지지 않은 속의 \(m * m * m)개를 빼요: \(n * n * n - m * m * m)개"),
            ][k]
            return q(u, "A big cube made of \(n) × \(n) × \(n) unit cubes is painted on the outside. How many unit cubes have \(asks[k])?",
                     "쌓기나무 \(n) × \(n) × \(n)개로 만든 큰 정육면체의 겉면을 모두 색칠했어요. \(asksKo[k]) 쌓기나무는 몇 개인가요?",
                     ans: "\(ans)", unit: "cubes", why: whys.0, kwhy: whys.1)
        }
    }

    // MARK: - 6-2 비례식과 비례배분

    static func e62Proportion(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e62Proportion
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let a = d.int(2...9), b = d.int(2...9), k = d.int(2...6)
            return q(u, "Find the number that goes in the box.", "□ 안에 알맞은 수를 구하세요.",
                     ans: "\(b * k)", expr: "\(a) : \(b) = \(a * k) : □",
                     why: "In a proportion, the product of the outer terms equals the product of the inner terms: \(a) × □ = \(b) × \(a * k), so □ = \(b * a * k) ÷ \(a) = \(b * k).",
                     kwhy: "비례식에서 외항의 곱과 내항의 곱은 같아요: \(a) × □ = \(b) × \(a * k), □ = \(b * a * k) ÷ \(a) = \(b * k)")
        case 1:
            var a = 0, b = 0
            repeat { a = d.int(1...9); b = d.int(1...9) } while a == b || Frac.gcd(a, b) != 1
            let k = d.int(2...6)
            let other = k == 2 ? 3 : 2
            return qc(u, "Write \(a * k) : \(b * k) as the simplest ratio of natural numbers.",
                      "\(a * k) : \(josa("\(b * k)", "을", "를")) 가장 간단한 자연수의 비로 나타내세요.",
                      ans: "\(a) : \(b)", wrong: ["\(b) : \(a)", "\(a * other) : \(b * other)", "\(a + 1) : \(b)"], d: d,
                      why: "Divide both terms by their greatest common factor \(k): \(a * k) ÷ \(k) = \(a), \(b * k) ÷ \(k) = \(b).",
                      kwhy: "두 항을 최대공약수 \(k)로 나눠요: \(a * k) ÷ \(k) = \(a), \(b * k) ÷ \(k) = \(b)")
        case 2:
            var a = 0, b = 0
            repeat { a = d.int(1...7); b = d.int(1...7) } while a == b || Frac.gcd(a, b) != 1
            let unit = d.int(2...20)
            let t = (a + b) * unit
            let (name, nk) = d.pick(people)
            return q(u, "\(t) candies are shared between \(name) and a friend in the ratio \(a) : \(b). How many candies does \(name) get?",
                     "사탕 \(t)개를 \(josa(nk, "과", "와")) 친구가 \(a) : \(b)로 나누어 가져요. \(josa(nk, "이", "가")) 가지는 사탕은 몇 개인가요?",
                     ans: "\(a * unit)", unit: "candies",
                     why: "\(name) gets \(a)/(\(a) + \(b)) = \(a)/\(a + b) of the total: \(t) × \(a)/\(a + b) = \(a * unit).",
                     kwhy: "비례배분: 전체의 \(a)/(\(a) + \(b)) = \(a)/\(a + b)만큼 가져요. \(t) × \(a)/\(a + b) = \(a * unit)개")
        case 3:
            let s = d.pick([10000, 20000, 25000, 50000]), c = d.int(2...12)
            let km = dec(c * s / 1000, 2)
            return q(u, "On a map with a scale of 1 : \(comma(s)), two towns are \(c) cm apart. What is the real distance in km?",
                     "축척이 1 : \(comma(s))인 지도에서 두 마을 사이의 거리가 \(c) cm예요. 실제 거리는 몇 km인가요?",
                     ans: km, unit: "km",
                     why: "Real distance = \(c) × \(comma(s)) = \(comma(c * s)) cm. 1 km = 100,000 cm, so \(comma(c * s)) cm = \(km) km.",
                     kwhy: "실제 거리 = \(c) × \(comma(s)) = \(comma(c * s)) cm. 1 km = 100,000 cm이므로 \(km) km")
        case 4:
            var a = 0, b = 0
            repeat { a = d.int(2...9); b = d.int(2...9) } while a == b || Frac.gcd(a, b) != 1
            return qc(u, "Write 1/\(a) : 1/\(b) as the simplest ratio of natural numbers.",
                      "1/\(a) : 1/\(b)을 가장 간단한 자연수의 비로 나타내세요.",
                      ans: "\(b) : \(a)", wrong: ["\(a) : \(b)", "1 : \(b)", "\(a) : 1"], d: d,
                      why: "Multiply both terms by \(a * b): 1/\(a) × \(a * b) = \(b), 1/\(b) × \(a * b) = \(a). So \(b) : \(a).",
                      kwhy: "두 항에 분모의 공배수 \(josa("\(a * b)", "을", "를")) 곱해요: 1/\(a) × \(a * b) = \(b), 1/\(b) × \(a * b) = \(a). 그래서 \(b) : \(a)")
        default:
            var ta = 0, tb = 0, k = 0
            repeat {
                ta = d.pick([12, 16, 18, 20, 24, 30, 36]); tb = d.pick([12, 16, 18, 20, 24, 30, 36]); k = d.int(2...12)
            } while ta == tb || (ta * k) % tb != 0
            return q(u, "Gear A has \(ta) teeth and gear B has \(tb) teeth. They turn together. When gear A turns \(k) times, how many times does gear B turn?",
                     "톱니가 \(ta)개인 톱니바퀴 A와 톱니가 \(tb)개인 톱니바퀴 B가 맞물려 돌아요. A가 \(k)바퀴 돌 때, B는 몇 바퀴 도나요?",
                     ans: "\(ta * k / tb)", unit: "times",
                     why: "The number of teeth that pass is the same: \(ta) × \(k) = \(ta * k). B turns \(ta * k) ÷ \(tb) = \(ta * k / tb) times.",
                     kwhy: "맞물린 톱니 수는 같아요: \(ta) × \(k) = \(ta * k)개. B는 \(ta * k) ÷ \(tb) = \(ta * k / tb)바퀴 돌아요.")
        }
    }

    // MARK: - 6-2 원의 넓이 (원주율 3.14)

    static func e62Circle(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e62Circle
        let pi = " (Use 3.14 for π.)"
        let piKo = " (원주율: 3.14)"
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let dd = d.int(2...30)
            return q(u, "The diameter of a circle is \(dd) cm. What is its circumference?" + pi,
                     "지름이 \(dd) cm인 원의 원주는 몇 cm인가요?" + piKo,
                     ans: dec(dd * 314, 2), unit: "cm",
                     why: "Circumference = diameter × 3.14 = \(dd) × 3.14 = \(dec(dd * 314, 2)) cm",
                     kwhy: "원주 = 지름 × 원주율 = \(dd) × 3.14 = \(dec(dd * 314, 2)) cm")
        case 1:
            let r = d.int(2...15)
            return q(u, "The radius of a circle is \(r) cm. What is its area?" + pi,
                     "반지름이 \(r) cm인 원의 넓이는 몇 cm²인가요?" + piKo,
                     ans: dec(r * r * 314, 2), unit: "cm²",
                     why: "Area = radius × radius × 3.14 = \(r) × \(r) × 3.14 = \(dec(r * r * 314, 2)) cm²",
                     kwhy: "원의 넓이 = 반지름 × 반지름 × 원주율 = \(r) × \(r) × 3.14 = \(dec(r * r * 314, 2)) cm²")
        case 2:
            let dd = d.int(2...30)
            return q(u, "The circumference of a circle is \(dec(dd * 314, 2)) cm. What is its diameter?" + pi,
                     "원주가 \(dec(dd * 314, 2)) cm인 원의 지름은 몇 cm인가요?" + piKo,
                     ans: "\(dd)", unit: "cm",
                     why: "Diameter = circumference ÷ 3.14 = \(dec(dd * 314, 2)) ÷ 3.14 = \(dd) cm",
                     kwhy: "지름 = 원주 ÷ 원주율 = \(dec(dd * 314, 2)) ÷ 3.14 = \(dd) cm")
        case 3:
            let r = d.int(2...12)
            return q(u, "What is the area of a semicircle with a radius of \(r) cm?" + pi,
                     "반지름이 \(r) cm인 반원의 넓이는 몇 cm²인가요?" + piKo,
                     ans: dec(r * r * 157, 2), unit: "cm²",
                     why: "Half of the circle: \(r) × \(r) × 3.14 ÷ 2 = \(dec(r * r * 157, 2)) cm²",
                     kwhy: "원의 넓이의 반: \(r) × \(r) × 3.14 ÷ 2 = \(dec(r * r * 157, 2)) cm²")
        case 4:
            let big = d.int(4...12), small = d.int(1...(big - 1))
            let ans = dec((big * big - small * small) * 314, 2)
            return q(u, "A ring is made by cutting a circle of radius \(small) cm out of the middle of a circle of radius \(big) cm (same center). What is the area of the ring?" + pi,
                     "반지름이 \(big) cm인 원의 한가운데에서 반지름이 \(small) cm인 원을 (중심이 같게) 잘라 냈어요. 남은 고리 모양의 넓이는 몇 cm²인가요?" + piKo,
                     ans: ans, unit: "cm²",
                     why: "Big circle − small circle = \(big) × \(big) × 3.14 − \(small) × \(small) × 3.14 = (\(big * big) − \(small * small)) × 3.14 = \(ans) cm²",
                     kwhy: "큰 원 − 작은 원 = \(big) × \(big) × 3.14 − \(small) × \(small) × 3.14 = (\(big * big) − \(small * small)) × 3.14 = \(ans) cm²")
        default:
            let a = d.int(2...10) * 2
            let r = a / 2
            let ans = dec(a * a * 100 - r * r * 314, 2)
            return q(u, "The biggest possible circle is drawn inside a square with sides of \(a) cm. What is the area of the part of the square outside the circle?" + pi,
                     "한 변이 \(a) cm인 정사각형 안에 가장 큰 원을 그렸어요. 정사각형에서 원을 뺀 부분의 넓이는 몇 cm²인가요?" + piKo,
                     ans: ans, unit: "cm²",
                     why: "The circle's diameter is \(a) cm, so its radius is \(r) cm. Square − circle = \(a) × \(a) − \(r) × \(r) × 3.14 = \(a * a) − \(dec(r * r * 314, 2)) = \(ans) cm²",
                     kwhy: "원의 지름은 \(a) cm, 반지름은 \(r) cm예요. 정사각형 − 원 = \(a) × \(a) − \(r) × \(r) × 3.14 = \(a * a) − \(dec(r * r * 314, 2)) = \(ans) cm²")
        }
    }

    // MARK: - 6-2 원기둥, 원뿔, 구

    static func e62Solids(_ d: Dice, _ h: Bool) -> Problem {
        let u = MathUnit.e62Solids
        let pi = " (Use 3.14 for π.)"
        let piKo = " (원주율: 3.14)"
        switch h ? d.int(4...5) : d.int(0...3) {
        case 0:
            let r = d.int(2...10)
            return q(u, "A cylinder has a base with a radius of \(r) cm. In its net, how long is the side of the rectangle that wraps around the base?" + pi,
                     "밑면의 반지름이 \(r) cm인 원기둥의 전개도에서, 옆면인 직사각형의 가로 길이는 몇 cm인가요?" + piKo,
                     ans: dec(2 * r * 314, 2), unit: "cm",
                     why: "It equals the circumference of the base: \(r * 2) × 3.14 = \(dec(2 * r * 314, 2)) cm",
                     kwhy: "옆면의 가로는 밑면의 둘레(원주)와 같아요: \(r * 2) × 3.14 = \(dec(2 * r * 314, 2)) cm")
        case 1:
            let asks: [(String, String, Int, String, String)] = [
                ("How many vertices does a cone have?", "원뿔의 꼭짓점은 몇 개인가요?", 1, "A cone has 1 vertex at the top.", "원뿔은 뾰족한 꼭짓점이 1개 있어요."),
                ("How many bases does a cylinder have?", "원기둥의 밑면은 몇 개인가요?", 2, "A cylinder has 2 parallel, congruent circular bases.", "원기둥은 서로 평행하고 합동인 원 모양의 밑면이 2개예요."),
                ("How many bases does a cone have?", "원뿔의 밑면은 몇 개인가요?", 1, "A cone has 1 circular base.", "원뿔의 밑면은 원 1개예요."),
                ("How many vertices does a cylinder have?", "원기둥의 꼭짓점은 몇 개인가요?", 0, "A cylinder has no vertices (no pointed corners).", "원기둥은 꼭짓점이 없어요."),
            ]
            let (en, ko, n, why, kwhy) = d.pick(asks)
            return q(u, en, ko, ans: "\(n)", why: why, kwhy: kwhy)
        case 2:
            let r = d.int(2...15)
            return q(u, "The diameter of a sphere is \(2 * r) cm. What is its radius?",
                     "지름이 \(2 * r) cm인 구의 반지름은 몇 cm인가요?",
                     ans: "\(r)", unit: "cm",
                     why: "The radius is half the diameter: \(2 * r) ÷ 2 = \(r) cm.",
                     kwhy: "구의 반지름은 지름의 반이에요: \(2 * r) ÷ 2 = \(r) cm")
        case 3:
            let a = d.int(2...12), b = d.int(2...12)
            return q(u, "A rectangle that is \(a) cm wide and \(b) cm tall is turned around its \(b) cm side to make a cylinder. What is the diameter of the base of the cylinder?",
                     "가로 \(a) cm, 세로 \(b) cm인 직사각형을 세로(\(b) cm)를 기준으로 한 바퀴 돌려 원기둥을 만들었어요. 원기둥의 밑면의 지름은 몇 cm인가요?",
                     ans: "\(2 * a)", unit: "cm",
                     why: "The \(a) cm side becomes the radius, so the diameter is \(a) × 2 = \(2 * a) cm. The height is \(b) cm.",
                     kwhy: "가로 \(a) cm가 밑면의 반지름이 되므로 지름은 \(a) × 2 = \(2 * a) cm예요. 높이는 \(b) cm예요.")
        case 4:
            let r = d.int(2...8), hh = d.int(3...15)
            let ans = dec(2 * (2 * r * 314 + hh * 100), 2)
            return q(u, "A cylinder has a base radius of \(r) cm and a height of \(hh) cm. In its net, what is the perimeter of the rectangle (the side surface)?" + pi,
                     "밑면의 반지름이 \(r) cm, 높이가 \(hh) cm인 원기둥의 전개도에서 옆면인 직사각형의 둘레는 몇 cm인가요?" + piKo,
                     ans: ans, unit: "cm",
                     why: "The rectangle is \(dec(2 * r * 314, 2)) cm (the circumference: \(2 * r) × 3.14) by \(hh) cm. Perimeter: (\(dec(2 * r * 314, 2)) + \(hh)) × 2 = \(ans) cm",
                     kwhy: "직사각형의 가로는 밑면의 둘레 \(2 * r) × 3.14 = \(dec(2 * r * 314, 2)) cm, 세로는 높이 \(hh) cm예요. 둘레: (\(dec(2 * r * 314, 2)) + \(hh)) × 2 = \(ans) cm")
        default:
            let a = d.int(2...10), b = d.int(3...12)
            return q(u, "A right triangle has legs of \(a) cm (bottom) and \(b) cm (height). It is turned around the \(b) cm leg to make a cone. What is the circumference of the cone's base?" + pi,
                     "밑변이 \(a) cm, 높이가 \(b) cm인 직각삼각형을 높이(\(b) cm)를 기준으로 한 바퀴 돌려 원뿔을 만들었어요. 원뿔의 밑면의 둘레는 몇 cm인가요?" + piKo,
                     ans: dec(2 * a * 314, 2), unit: "cm",
                     why: "The \(a) cm leg becomes the radius of the base. Circumference: \(2 * a) × 3.14 = \(dec(2 * a * 314, 2)) cm",
                     kwhy: "밑변 \(a) cm가 밑면의 반지름이 돼요. 밑면의 둘레: \(2 * a) × 3.14 = \(dec(2 * a * 314, 2)) cm")
        }
    }
}
