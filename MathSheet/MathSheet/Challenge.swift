import Foundation

/// 심화 문제. 여러 단계로 생각해야 하는 문제들이고, 풀이는 영어 + 한국어로 나와요.
extension Generator {
    static func challenge(_ unit: MathUnit, _ d: Dice) -> Problem {
        var p: Problem
        switch unit {
        case .range: p = rangeHard(d)
        case .fractionMul: p = fractionHard(d)
        case .symmetry: p = symmetryHard(d)
        case .decimalMul: p = decimalHard(d)
        case .cuboid: p = cuboidHard(d)
        case .average: p = averageHard(d)
        }
        p.hard = true
        return p
    }

    private static func hard(_ u: MathUnit, _ text: String, ko: String, expr: String? = nil, answer: String,
                             unit: String? = nil, why: String, whyKo: String) -> Problem {
        var p = num(u, text, ko: ko, expr: expr, answer: answer, unit: unit, why: why)
        p.whyKo = whyKo
        return p
    }

    private static func minus1(_ f: Frac) -> Frac { Frac(f.d - f.n, f.d) }

    // MARK: - 1. 수의 범위와 어림하기

    static func rangeHard(_ d: Dice) -> Problem {
        let u = MathUnit.range
        switch d.int(0...4) {
        case 0:
            let t = d.int(12...98) * 10
            let small = d.bool()
            let ans = small ? t - 5 : t + 4
            return hard(u, "A whole number is rounded to the nearest ten, and the result is \(t). What is the \(small ? "smallest" : "largest") number it can be?",
                        ko: "어떤 자연수를 반올림하여 십의 자리까지 나타내면 \(t)이 돼요. 이 자연수가 될 수 있는 가장 \(small ? "작은" : "큰") 수는 얼마인가요?",
                        answer: "\(ans)",
                        why: "Numbers from \(t - 5) to \(t + 4) round to \(t): if the ones digit is 5 or more we round up, and if it is less than 5 we round down. So the \(small ? "smallest" : "largest") is \(ans).",
                        whyKo: "일의 자리에서 반올림하여 \(t)이 되는 수는 \(t - 5)부터 \(t + 4)까지예요. (일의 자리가 5 이상이면 올리고, 5 미만이면 버려요.) 그래서 가장 \(small ? "작은" : "큰") 수는 \(ans)예요.")
        case 1:
            let (place, name, nameKo) = d.pick([(10, "tens", "십"), (100, "hundreds", "백")])
            let base = d.int(11...99) * place
            let up = d.bool()
            let lo = up ? base - place + 1 : base
            let hi = up ? base : base + place - 1
            return hard(u, "A whole number is rounded \(up ? "up" : "down") to the \(name) place, and the result is \(comma(base)). How many whole numbers can it be?",
                        ko: "어떤 자연수를 \(up ? "올림" : "버림")하여 \(nameKo)의 자리까지 나타내면 \(comma(base))이 돼요. 이 자연수가 될 수 있는 수는 모두 몇 개인가요?",
                        answer: "\(place)", unit: "numbers",
                        why: "Rounding \(up ? "up" : "down") to the \(name) place gives \(comma(base)) for the numbers from \(comma(lo)) to \(comma(hi)). That is \(hi) − \(lo) + 1 = \(place) numbers.",
                        whyKo: "\(up ? "올림" : "버림")하여 \(comma(base))이 되는 수는 \(comma(lo))부터 \(comma(hi))까지예요. 모두 \(hi) − \(lo) + 1 = \(place)개예요.")
        case 2:
            var k = 0, lo = 0, hi = 0, count = 0
            repeat {
                k = d.int(3...9); lo = d.int(10...50); hi = lo + d.int(20...60)
                count = (hi - 1) / k - (lo - 1) / k
            } while count < 2
            let first = (lo + k - 1) / k * k
            let last = (hi - 1) / k * k
            return hard(u, "How many multiples of \(k) are at least \(lo) and less than \(hi)?",
                        ko: "\(lo) 이상 \(hi) 미만인 수 중에서 \(k)의 배수는 모두 몇 개인가요?",
                        answer: "\(count)",
                        why: "\"At least \(lo)\" includes \(lo), and \"less than \(hi)\" does not include \(hi). The multiples of \(k) in this range are \(first), \(first + k), …, \(last). That is \(count) numbers.",
                        whyKo: "\(lo) 이상은 \(josa("\(lo)", "을", "를")) 포함하고, \(hi) 미만은 \(josa("\(hi)", "을", "를")) 포함하지 않아요. 이 범위에 있는 \(k)의 배수는 \(first), \(first + k), …, \(last) → 모두 \(count)개예요.")
        case 3:
            let child = d.int(5...15) * 100
            let adult = child * 2
            let ages = d.shuffle([d.pick([6, 7, 8]), d.pick([12, 13]), d.int(9...11), d.int(35...45), d.int(36...46)])
            let free = ages.filter { $0 < 8 }.count
            let kids = ages.filter { $0 >= 8 && $0 < 13 }.count
            let adults = ages.filter { $0 >= 13 }.count
            let total = kids * child + adults * adult
            let agesText = ages.map(String.init).joined(separator: ", ")
            return hard(u, "Bus fares: free for people under 8 years old, \(comma(child)) won for people who are at least 8 and under 13, and \(comma(adult)) won for people 13 or older. The ages of a family are \(agesText). How much do they pay in total?",
                        ko: "버스 요금은 8세 미만은 무료, 8세 이상 13세 미만은 \(comma(child))원, 13세 이상은 \(comma(adult))원이에요. 가족의 나이가 각각 \(agesText)세예요. 가족의 버스 요금은 모두 얼마인가요?",
                        answer: comma(total), unit: "won",
                        why: "Under 8 (free): \(free) people. At least 8 and under 13: \(kids) people × \(comma(child)) = \(comma(kids * child)) won. 13 or older: \(adults) people × \(comma(adult)) = \(comma(adults * adult)) won. Total: \(comma(total)) won. (8 is \"at least 8\", and 13 is not \"under 13\".)",
                        whyKo: "8세 미만(무료): \(free)명. 8세 이상 13세 미만: \(kids)명 × \(comma(child))원 = \(comma(kids * child))원. 13세 이상: \(adults)명 × \(comma(adult))원 = \(comma(adults * adult))원. 합계 \(comma(total))원이에요. (8세는 '8세 이상'에 들어가고, 13세는 '13세 미만'에 들어가지 않아요.)")
        default:
            let digits = Array(d.shuffle(Array(1...9)).prefix(4))
            let largest = Int(digits.sorted(by: >).map(String.init).joined())!
            let smallest = Int(digits.sorted().map(String.init).joined())!
            let cards = digits.map(String.init).joined(separator: ", ")
            if d.bool() {
                let a = (largest + 50) / 100 * 100
                return hard(u, "Use each of the digit cards \(cards) once to make the largest four-digit number. Then round it to the nearest hundred.",
                            ko: "숫자 카드 \(josa(cards, "을", "를")) 한 번씩 모두 사용하여 가장 큰 네 자리 수를 만들고, 그 수를 반올림하여 백의 자리까지 나타내세요.",
                            answer: comma(a),
                            why: "Put the digits from largest to smallest: \(comma(largest)). The tens digit is \((largest / 10) % 10), so round \((largest / 10) % 10 >= 5 ? "up" : "down"): \(comma(a)).",
                            whyKo: "큰 숫자부터 차례로 놓으면 가장 큰 수는 \(comma(largest))예요. 십의 자리 숫자가 \((largest / 10) % 10)이므로 \((largest / 10) % 10 >= 5 ? "올려서" : "버려서") \(comma(a))이 돼요.")
            } else {
                let a = (smallest + 9) / 10 * 10
                return hard(u, "Use each of the digit cards \(cards) once to make the smallest four-digit number. Then round it up to the tens place.",
                            ko: "숫자 카드 \(josa(cards, "을", "를")) 한 번씩 모두 사용하여 가장 작은 네 자리 수를 만들고, 그 수를 올림하여 십의 자리까지 나타내세요.",
                            answer: comma(a),
                            why: "Put the digits from smallest to largest: \(comma(smallest)). Rounding up to the tens place: \(comma(a)).",
                            whyKo: "작은 숫자부터 차례로 놓으면 가장 작은 수는 \(comma(smallest))예요. 올림하여 십의 자리까지 나타내면 \(comma(a))이 돼요.")
            }
        }
    }

    // MARK: - 2. 분수의 곱셈

    static func fractionHard(_ d: Dice) -> Problem {
        let u = MathUnit.fractionMul
        let (name, nk) = d.pick(people)
        switch d.int(0...4) {
        case 0:
            let f = d.properFraction(maxDen: 5), g = d.properFraction(maxDen: 5)
            let r1 = minus1(f), r2 = minus1(g)
            let a = r1 * r2
            return hard(u, "\(name) read \(f.improper) of a book on Monday. On Tuesday, \(name) read \(g.improper) of the rest. What fraction of the whole book is still left to read?",
                        ko: "\(josa(nk, "은", "는")) 월요일에 책 전체의 \(f.improper)를 읽었어요. 화요일에는 나머지의 \(g.improper)를 읽었어요. 아직 읽지 않은 부분은 책 전체의 몇 분의 몇인가요?",
                        answer: a.mixed,
                        why: "After Monday, 1 − \(f.improper) = \(r1.improper) of the book is left. On Tuesday \(name) read \(g.improper) of that, so 1 − \(g.improper) = \(r2.improper) of it is still left. \(r1.improper) × \(r2.improper) = \(a.mixed).",
                        whyKo: "월요일에 읽고 남은 부분은 1 − \(f.improper) = \(r1.improper)예요. 화요일에 그 나머지의 \(g.improper)를 읽었으니, 나머지의 1 − \(g.improper) = \(r2.improper)가 남아요. 그래서 남은 부분은 \(r1.improper) × \(r2.improper) = \(a.mixed)예요.")
        case 1:
            let r = d.pick([Frac(1, 2), Frac(2, 3), Frac(3, 4), Frac(3, 5), Frac(4, 5)])
            let h = r.d * r.d * d.int(1...4)
            let first = Frac(h) * r
            let second = first * r
            return hard(u, "A ball bounces back up to \(r.improper) of the height it falls from. It is dropped from a height of \(h) m. How high does it go on the second bounce?",
                        ko: "이 공은 떨어진 높이의 \(r.improper)만큼 튀어 올라요. 공을 \(h) m 높이에서 떨어뜨렸을 때, 두 번째로 튀어 오른 높이는 몇 m인가요?",
                        answer: second.mixed, unit: "m",
                        why: "First bounce: \(h) × \(r.improper) = \(first.mixed) m. Second bounce: \(first.mixed) × \(r.improper) = \(second.mixed) m.",
                        whyKo: "첫 번째로 튀어 오른 높이: \(h) × \(r.improper) = \(first.mixed) m. 두 번째로 튀어 오른 높이: \(first.mixed) × \(r.improper) = \(second.mixed) m예요.")
        case 2:
            let p = d.properFraction(maxDen: 5), q = d.properFraction(maxDen: 5)
            let x = Frac(d.int(1...3) * p.d + p.n, p.d)
            let y = Frac(d.int(1...3) * q.d + q.n, q.d)
            let prod = x * y
            let ans = prod.isWhole ? prod.n - 1 : prod.n / prod.d
            return hard(u, "What is the largest whole number that can go in the box?",
                        ko: "□ 안에 들어갈 수 있는 가장 큰 자연수를 구하세요.",
                        expr: "□ < \(x.mixed) × \(y.mixed)", answer: "\(ans)",
                        why: "\(x.mixed) × \(y.mixed) = \(x.improper) × \(y.improper) = \(prod.mixed). The box must be less than \(prod.mixed), so the largest whole number is \(ans).",
                        whyKo: "\(x.mixed) × \(y.mixed) = \(x.improper) × \(y.improper) = \(prod.mixed)예요. □는 \(prod.mixed)보다 작아야 하므로 가장 큰 자연수는 \(ans)예요.")
        case 3:
            let a = d.int(2...9)
            let g = d.properFraction(maxDen: 6)
            let w = Frac(a) * g
            let area = Frac(a) * w
            return hard(u, "A rectangle is \(a) m long. Its width is \(g.improper) of its length. What is its area?",
                        ko: "가로가 \(a) m인 직사각형이 있어요. 세로는 가로의 \(g.improper)예요. 이 직사각형의 넓이는 몇 m²인가요?",
                        answer: area.mixed, unit: "m²",
                        why: "Width = \(a) × \(g.improper) = \(w.mixed) m. Area = \(a) × \(w.mixed) = \(area.mixed) m².",
                        whyKo: "세로 = \(a) × \(g.improper) = \(w.mixed) m예요. 넓이 = \(a) × \(w.mixed) = \(area.mixed) m²예요.")
        default:
            let f = d.pick([Frac(1, 3), Frac(3, 8), Frac(1, 4), Frac(5, 12), Frac(1, 6)])
            let rest = 24 * (f.d - f.n) / f.d
            let dens = (2...6).filter { rest % $0 == 0 }
            let m = d.pick(dens)
            var k = d.int(1...(m - 1))
            while Frac.gcd(k, m) != 1 { k = d.int(1...(m - 1)) }
            let g = Frac(k, m)
            let school = rest * k / m
            return hard(u, "A day has 24 hours. \(name) sleeps for \(f.improper) of a day and spends \(g.improper) of the rest of the day at school. How many hours does \(name) spend at school?",
                        ko: "하루는 24시간이에요. \(josa(nk, "은", "는")) 하루의 \(f.improper)만큼 자고, 나머지 시간의 \(g.improper)만큼 학교에 있어요. \(josa(nk, "이", "가")) 학교에 있는 시간은 몇 시간인가요?",
                        answer: "\(school)", unit: "hours",
                        why: "Sleeping: 24 × \(f.improper) = \(24 * f.n / f.d) hours. The rest: 24 − \(24 * f.n / f.d) = \(rest) hours. At school: \(rest) × \(g.improper) = \(school) hours.",
                        whyKo: "자는 시간: 24 × \(f.improper) = \(24 * f.n / f.d)시간. 나머지 시간: 24 − \(24 * f.n / f.d) = \(rest)시간. 학교에 있는 시간: \(rest) × \(g.improper) = \(school)시간이에요.")
        }
    }

    // MARK: - 3. 합동과 대칭

    static func symmetryHard(_ d: Dice) -> Problem {
        let u = MathUnit.symmetry
        switch d.int(0...4) {
        case 0:
            var a = 0, b = 0, c = 0
            repeat {
                a = d.int(4...12); b = d.int(4...12); c = d.int(4...12)
            } while !(a + b > c && b + c > a && a + c > b)
            let p = a + b + c
            return hard(u, "Triangle ABC and triangle DEF are congruent. (A matches D, B matches E, and C matches F.) The perimeter of triangle DEF is \(p) cm. AB = \(a) cm and BC = \(b) cm. What is the length of side DF?",
                        ko: "삼각형 ABC와 삼각형 DEF는 서로 합동이에요. (점 A와 점 D, 점 B와 점 E, 점 C와 점 F가 대응점이에요.) 삼각형 DEF의 둘레는 \(p) cm이고, AB = \(a) cm, BC = \(b) cm예요. 변 DF의 길이는 몇 cm인가요?",
                        answer: "\(c)", unit: "cm",
                        why: "DE corresponds to AB, so DE = \(a) cm. EF corresponds to BC, so EF = \(b) cm. DF = \(p) − \(a) − \(b) = \(c) cm.",
                        whyKo: "변 DE는 변 AB와 대응하므로 \(a) cm, 변 EF는 변 BC와 대응하므로 \(b) cm예요. 변 DF = \(p) − \(a) − \(b) = \(c) cm예요.")
        case 1:
            let x = d.int(30...75)
            let a = 180 - 2 * x
            return hard(u, "Triangle ABC is line-symmetric, and its line of symmetry passes through vertex A. Angle B is \(x)°. What is the size of angle A?",
                        ko: "삼각형 ABC는 선대칭도형이고, 대칭축이 꼭짓점 A를 지나요. 각 B가 \(x)°일 때, 각 A의 크기는 몇 도인가요?",
                        answer: "\(a)", unit: "°",
                        why: "Angle B and angle C are corresponding angles, so angle C = \(x)°. The angles of a triangle add up to 180°: angle A = 180° − \(x)° − \(x)° = \(a)°.",
                        whyKo: "각 B와 각 C는 대응각이므로 각 C도 \(x)°예요. 삼각형의 세 각의 합은 180°이므로 각 A = 180° − \(x)° − \(x)° = \(a)°예요.")
        case 2:
            let a = d.int(3...12), b = d.int(3...12)
            return hard(u, "Quadrilateral ABCD is line-symmetric, and its line of symmetry is the diagonal AC. AB = \(a) cm and BC = \(b) cm. What is the perimeter of ABCD?",
                        ko: "사각형 ABCD는 선대칭도형이고, 대각선 AC가 대칭축이에요. AB = \(a) cm, BC = \(b) cm일 때, 사각형 ABCD의 둘레는 몇 cm인가요?",
                        answer: "\(2 * (a + b))", unit: "cm",
                        why: "Point B corresponds to point D. So AD = AB = \(a) cm and CD = CB = \(b) cm. Perimeter = (\(a) + \(b)) × 2 = \(2 * (a + b)) cm.",
                        whyKo: "점 B와 점 D가 대응점이에요. 그래서 AD = AB = \(a) cm, CD = CB = \(b) cm예요. 둘레 = (\(a) + \(b)) × 2 = \(2 * (a + b)) cm예요.")
        case 3:
            let x = d.int(50...130)
            return hard(u, "Quadrilateral ABCD is point-symmetric. (A matches C, and B matches D.) Angle A is \(x)°. What is the size of angle B?",
                        ko: "사각형 ABCD는 점대칭도형이에요. (점 A와 점 C, 점 B와 점 D가 대응점이에요.) 각 A가 \(x)°일 때, 각 B의 크기는 몇 도인가요?",
                        answer: "\(180 - x)", unit: "°",
                        why: "Corresponding angles are equal: angle C = angle A = \(x)°, and angle B = angle D. The four angles add up to 360°, so angle B = (360° − \(x)° − \(x)°) ÷ 2 = \(180 - x)°.",
                        whyKo: "대응각의 크기는 같아요. 각 C = 각 A = \(x)°이고, 각 B = 각 D예요. 사각형의 네 각의 합은 360°이므로 각 B = (360° − \(x)° − \(x)°) ÷ 2 = \(180 - x)°예요.")
        default:
            let pool = ["A", "B", "C", "D", "E", "H", "I", "K", "M", "N", "O", "S", "T", "U", "X", "Z"]
            let both: Set<String> = ["H", "I", "O", "X"]
            var letters: [String] = []
            repeat { letters = Array(d.shuffle(pool).prefix(6)) } while !letters.contains(where: { both.contains($0) })
            letters.sort()
            let found = letters.filter { both.contains($0) }
            let list = letters.joined(separator: ", ")
            return hard(u, "How many of these capital letters are BOTH line-symmetric and point-symmetric?\n\(list)",
                        ko: "다음 알파벳 중에서 선대칭도형이면서 동시에 점대칭도형인 것은 모두 몇 개인가요?\n\(list)",
                        answer: "\(found.count)",
                        why: "H, I, O, and X have a line of symmetry AND look the same after a 180° turn. Here they are: \(found.joined(separator: ", ")). That is \(found.count).",
                        whyKo: "H, I, O, X는 대칭축이 있으면서 180° 돌려도 같은 모양이에요. 여기서는 \(found.joined(separator: ", "))로 모두 \(found.count)개예요.")
        }
    }

    // MARK: - 4. 소수의 곱셈

    static func decimalHard(_ d: Dice) -> Problem {
        let u = MathUnit.decimalMul
        let (name, nk) = d.pick(people)
        switch d.int(0...4) {
        case 0:
            var a = d.int(101...999)
            while a % 10 == 0 { a = d.int(101...999) }
            let wrong = dec(a, 1), x = dec(a, 2), ans = dec(a, 3)
            return hard(u, "\(name) was supposed to multiply a number by 0.1, but multiplied it by 10 by mistake and got \(wrong). What is the correct answer?",
                        ko: "\(josa(nk, "은", "는")) 어떤 수에 0.1을 곱해야 할 것을 잘못하여 10을 곱했더니 \(josa(wrong, "이", "가")) 되었어요. 바르게 계산한 값은 얼마인가요?",
                        answer: ans,
                        why: "The number × 10 = \(wrong), so the number is \(x) (move the decimal point 1 place left). The correct answer is \(x) × 0.1 = \(ans).",
                        whyKo: "어떤 수 × 10 = \(wrong)이므로 어떤 수는 \(x)예요 (소수점을 왼쪽으로 한 칸). 바르게 계산하면 \(x) × 0.1 = \(ans)예요.")
        case 1:
            var l = d.int(11...59)
            while l % 10 == 0 { l = d.int(11...59) }
            let a = d.pick([20, 25, 40, 50, 60, 75])   // 0.xx
            let b = d.pick([2, 4, 5])                   // 0.x
            let after1 = l * (100 - a)                  // 소수 3자리
            let left = after1 * (10 - b)                // 소수 4자리
            return hard(u, "A tape is \(dec(l, 1)) m long. \(name) used \(dec(a, 2)) of it, and then used \(dec(b, 1)) of the rest. How many meters of tape are left?",
                        ko: "길이가 \(dec(l, 1)) m인 테이프가 있어요. \(josa(nk, "은", "는")) 전체의 \(dec(a, 2))만큼 사용하고, 나머지의 \(dec(b, 1))만큼 또 사용했어요. 남은 테이프는 몇 m인가요?",
                        answer: dec(left, 4), unit: "m",
                        why: "After the first use, 1 − \(dec(a, 2)) = \(dec(100 - a, 2)) of the tape is left: \(dec(l, 1)) × \(dec(100 - a, 2)) = \(dec(after1, 3)) m. Then 1 − \(dec(b, 1)) = \(dec(10 - b, 1)) of that is left: \(dec(after1, 3)) × \(dec(10 - b, 1)) = \(dec(left, 4)) m.",
                        whyKo: "처음 사용하고 남은 부분은 전체의 1 − \(dec(a, 2)) = \(dec(100 - a, 2))이므로 \(dec(l, 1)) × \(dec(100 - a, 2)) = \(dec(after1, 3)) m예요. 다시 그 나머지의 1 − \(dec(b, 1)) = \(dec(10 - b, 1))가 남으므로 \(dec(after1, 3)) × \(dec(10 - b, 1)) = \(dec(left, 4)) m예요.")
        case 2:
            let p = d.int(8...30) * 100
            var len = d.int(101...499)
            while len % 10 == 0 { len = d.int(101...499) }
            let cost = p * len / 100
            return hard(u, "1 m of rope costs \(comma(p)) won. How much do \(dec(len, 2)) m of rope cost?",
                        ko: "줄 1 m의 값은 \(comma(p))원이에요. 이 줄 \(dec(len, 2)) m의 값은 얼마인가요?",
                        answer: comma(cost), unit: "won",
                        why: "\(comma(p)) × \(dec(len, 2)): \(p) × \(len) = \(p * len), and the answer has 2 decimal places: \(comma(cost)) won.",
                        whyKo: "\(josa("\(comma(p)) × \(dec(len, 2))", "을", "를")) 계산해요. \(p) × \(len) = \(p * len)이고, 소수 두 자리이므로 \(comma(cost))원이에요.")
        case 3:
            var l = d.int(11...49), w = d.int(11...39)
            while l % 10 == 0 { l = d.int(11...49) }
            while w % 10 == 0 { w = d.int(11...39) }
            let f = d.pick([12, 15, 5, 8])               // 1.2, 1.5, 0.5, 0.8
            let nl = l * f, nw = w * f                    // 소수 2자리
            let area = nl * nw                             // 소수 4자리
            return hard(u, "A rectangle is \(dec(l, 1)) m long and \(dec(w, 1)) m wide. Its length and its width are each multiplied by \(dec(f, 1)). What is the area of the new rectangle?",
                        ko: "가로 \(dec(l, 1)) m, 세로 \(dec(w, 1)) m인 직사각형이 있어요. 가로와 세로를 각각 \(dec(f, 1))배 하여 새 직사각형을 만들었어요. 새 직사각형의 넓이는 몇 m²인가요?",
                        answer: dec(area, 4), unit: "m²",
                        why: "New length: \(dec(l, 1)) × \(dec(f, 1)) = \(dec(nl, 2)) m. New width: \(dec(w, 1)) × \(dec(f, 1)) = \(dec(nw, 2)) m. Area: \(dec(nl, 2)) × \(dec(nw, 2)) = \(dec(area, 4)) m².",
                        whyKo: "새 가로: \(dec(l, 1)) × \(dec(f, 1)) = \(dec(nl, 2)) m. 새 세로: \(dec(w, 1)) × \(dec(f, 1)) = \(dec(nw, 2)) m. 넓이: \(dec(nl, 2)) × \(dec(nw, 2)) = \(dec(area, 4)) m²예요.")
        default:
            let a = d.int(5...9)                     // 0.0a L
            var k = d.int(101...499)                 // k/10 km
            while k % 10 == 0 { k = d.int(101...499) }
            let fuel = a * k                          // 소수 3자리
            return hard(u, "A car uses 0.0\(a) L of fuel to drive 1 km. How many liters of fuel does it use to drive \(dec(k, 1)) km?",
                        ko: "어떤 자동차는 1 km를 가는 데 연료 0.0\(a) L를 써요. 이 자동차가 \(dec(k, 1)) km를 가는 데 쓰는 연료는 몇 L인가요?",
                        answer: dec(fuel, 3), unit: "L",
                        why: "0.0\(a) × \(dec(k, 1)): \(a) × \(k) = \(fuel). There are 2 + 1 = 3 decimal places, so the answer is \(dec(fuel, 3, trim: false))\(dec(fuel, 3, trim: false) == dec(fuel, 3) ? "" : " = \(dec(fuel, 3))") L.",
                        whyKo: "\(josa("0.0\(a) × \(dec(k, 1))", "을", "를")) 계산해요. \(a) × \(k) = \(fuel)이고, 소수점 아래 자리는 2 + 1 = 3자리이므로 \(dec(fuel, 3)) L예요.")
        }
    }

    // MARK: - 5. 직육면체

    static func cuboidHard(_ d: Dice) -> Problem {
        let u = MathUnit.cuboid
        let (name, nk) = d.pick(people)
        func dims(_ r: ClosedRange<Int>) -> (Int, Int, Int) {
            var a = 0, b = 0, c = 0
            repeat { a = d.int(r); b = d.int(r); c = d.int(r) } while a == b || b == c || a == c
            return (a, b, c)
        }
        switch d.int(0...4) {
        case 0:
            var (a, b, c) = dims(2...15)
            while (a + b + c) % 3 != 0 { (a, b, c) = dims(2...15) }
            let t = 4 * (a + b + c), e = t / 12
            return hard(u, "A cuboid is \(a) cm long, \(b) cm wide, and \(c) cm high. A cube has the same total edge length as this cuboid. How long is one edge of the cube?",
                        ko: "가로 \(a) cm, 세로 \(b) cm, 높이 \(c) cm인 직육면체가 있어요. 모든 모서리의 길이의 합이 이 직육면체와 같은 정육면체의 한 모서리의 길이는 몇 cm인가요?",
                        answer: "\(e)", unit: "cm",
                        why: "Cuboid: (\(a) + \(b) + \(c)) × 4 = \(t) cm. A cube has 12 equal edges: \(t) ÷ 12 = \(e) cm.",
                        whyKo: "직육면체의 모든 모서리의 길이의 합은 (\(a) + \(b) + \(c)) × 4 = \(t) cm예요. 정육면체는 길이가 같은 모서리가 12개이므로 \(t) ÷ 12 = \(e) cm예요.")
        case 1:
            let (a, b, c) = dims(3...15)
            let need = 4 * (a + b + c)
            let wire = need + d.int(5...50)
            return hard(u, "\(name) has a wire \(wire) cm long. \(name) uses it to make the frame (all the edges) of a cuboid that is \(a) cm long, \(b) cm wide, and \(c) cm high. How many cm of wire are left?",
                        ko: "\(josa(nk, "은", "는")) 길이가 \(wire) cm인 철사로 가로 \(a) cm, 세로 \(b) cm, 높이 \(c) cm인 직육면체의 뼈대(모든 모서리)를 만들었어요. 남은 철사는 몇 cm인가요?",
                        answer: "\(wire - need)", unit: "cm",
                        why: "The frame needs (\(a) + \(b) + \(c)) × 4 = \(need) cm of wire. Left: \(wire) − \(need) = \(wire - need) cm.",
                        whyKo: "뼈대에 필요한 철사는 (\(a) + \(b) + \(c)) × 4 = \(need) cm예요. 남은 철사는 \(wire) − \(need) = \(wire - need) cm예요.")
        case 2:
            let k = d.int(1...6)
            if d.bool() {
                return hard(u, "On a die, the numbers on opposite (parallel) faces always add up to 7. What is the sum of the numbers on the four faces that are perpendicular to the face showing \(k)?",
                            ko: "주사위에서 서로 평행한 두 면의 눈의 수의 합은 항상 7이에요. \(k)의 눈이 있는 면과 수직인 면 4개의 눈의 수의 합은 얼마인가요?",
                            answer: "14",
                            why: "All six faces add up to 1 + 2 + 3 + 4 + 5 + 6 = 21. Take away the face \(k) and its parallel face \(7 - k) (together 7): 21 − 7 = 14.",
                            whyKo: "여섯 면의 눈의 수의 합은 1 + 2 + 3 + 4 + 5 + 6 = 21이에요. \(k)의 면과 평행한 면(\(7 - k))을 빼면 21 − 7 = 14예요.")
            } else {
                let other = d.pick(Array(1...6).filter { $0 != k && $0 != 7 - k })
                return hard(u, "On a die, the numbers on opposite (parallel) faces always add up to 7. What is the sum of the numbers on the faces that are parallel to the face showing \(k) and to the face showing \(other)?",
                            ko: "주사위에서 서로 평행한 두 면의 눈의 수의 합은 항상 7이에요. \(k)의 눈이 있는 면과 평행한 면, \(other)의 눈이 있는 면과 평행한 면의 눈의 수의 합은 얼마인가요?",
                            answer: "\(14 - k - other)",
                            why: "The face parallel to \(k) shows 7 − \(k) = \(7 - k). The face parallel to \(other) shows 7 − \(other) = \(7 - other). Sum: \(7 - k) + \(7 - other) = \(14 - k - other).",
                            whyKo: "\(k)의 눈이 있는 면과 평행한 면은 7 − \(k) = \(7 - k), \(other)의 눈이 있는 면과 평행한 면은 7 − \(other) = \(7 - other)예요. 합은 \(7 - k) + \(7 - other) = \(14 - k - other)예요.")
            }
        case 3:
            let (a, b, c) = dims(2...15)
            let dotted = d.bool()
            let ans = dotted ? a + b + c : 3 * (a + b + c)
            return hard(u, "In a sketch of a cuboid that is \(a) cm long, \(b) cm wide, and \(c) cm high, what is the total length of the edges drawn with \(dotted ? "dotted" : "solid") lines?",
                        ko: "가로 \(a) cm, 세로 \(b) cm, 높이 \(c) cm인 직육면체의 겨냥도에서 \(dotted ? "점선" : "실선")으로 그린 모서리의 길이의 합은 몇 cm인가요?",
                        answer: "\(ans)", unit: "cm",
                        why: "The 3 dotted (hidden) edges are one length, one width, and one height: \(a) + \(b) + \(c) = \(a + b + c) cm. The 9 solid edges are 3 of each: (\(a) + \(b) + \(c)) × 3 = \(3 * (a + b + c)) cm.",
                        whyKo: "점선 3개는 가로, 세로, 높이가 하나씩이에요: \(a) + \(b) + \(c) = \(a + b + c) cm. 실선 9개는 가로, 세로, 높이가 3개씩이에요: (\(a) + \(b) + \(c)) × 3 = \(3 * (a + b + c)) cm.")
        default:
            let e = d.int(2...12)
            let n = d.int(2...3)
            let t = 4 * (n * e + e + e)
            return hard(u, "\(n) cubes, each with edges \(e) cm long, are put together in a row to make a cuboid. What is the total length of all the edges of the cuboid?",
                        ko: "한 모서리의 길이가 \(e) cm인 정육면체 \(n)개를 한 줄로 이어 붙여 직육면체를 만들었어요. 만든 직육면체의 모든 모서리의 길이의 합은 몇 cm인가요?",
                        answer: "\(t)", unit: "cm",
                        why: "The cuboid is \(n * e) cm long, \(e) cm wide, and \(e) cm high. (\(n * e) + \(e) + \(e)) × 4 = \(t) cm.",
                        whyKo: "만든 직육면체는 가로 \(n * e) cm, 세로 \(e) cm, 높이 \(e) cm예요. (\(n * e) + \(e) + \(e)) × 4 = \(t) cm예요.")
        }
    }

    // MARK: - 6. 평균과 가능성

    static func averageHard(_ d: Dice) -> Problem {
        let u = MathUnit.average
        let (name, nk) = d.pick(people)
        switch d.int(0...4) {
        case 0:
            var n = 0, m = 0, r = 0, need = 0
            repeat {
                n = d.int(3...4); m = d.int(70...90); r = d.int(1...3)
                need = (n + 1) * (m + r) - n * m
            } while need > 100
            return hard(u, "The average of \(name)'s first \(n) test scores is \(m) points. What score does \(name) need on the next test to raise the average to \(m + r) points?",
                        ko: "\(nk)의 시험 \(n)번의 점수 평균은 \(m)점이에요. 다음 시험까지 \(n + 1)번의 평균을 \(m + r)점으로 올리려면 다음 시험에서 몇 점을 받아야 하나요?",
                        answer: "\(need)", unit: "points",
                        why: "Total so far: \(m) × \(n) = \(m * n). Total needed for \(n + 1) tests: \(m + r) × \(n + 1) = \((m + r) * (n + 1)). Score needed: \((m + r) * (n + 1)) − \(m * n) = \(need).",
                        whyKo: "지금까지 점수의 합: \(m) × \(n) = \(m * n)점. \(n + 1)번의 평균이 \(m + r)점이 되려면 합이 \(m + r) × \(n + 1) = \((m + r) * (n + 1))점이어야 해요. 그래서 \((m + r) * (n + 1)) − \(m * n) = \(need)점이 필요해요.")
        case 1:
            var n1 = 0, n2 = 0, a1 = 0, a2 = 0
            repeat {
                n1 = d.int(10...16); n2 = d.int(10...16); a1 = d.int(70...92); a2 = d.int(70...92)
            } while a1 == a2 || (n1 * a1 + n2 * a2) % (n1 + n2) != 0
            let all = (n1 * a1 + n2 * a2) / (n1 + n2)
            return hard(u, "In a class, the average math score of \(n1) boys is \(a1) points and the average of \(n2) girls is \(a2) points. What is the average score of the whole class?",
                        ko: "어느 반에서 남학생 \(n1)명의 수학 점수 평균은 \(a1)점, 여학생 \(n2)명의 평균은 \(a2)점이에요. 반 전체의 평균은 몇 점인가요?",
                        answer: "\(all)", unit: "points",
                        why: "Boys' total: \(a1) × \(n1) = \(a1 * n1). Girls' total: \(a2) × \(n2) = \(a2 * n2). Class total: \(a1 * n1 + a2 * n2). Average: \(a1 * n1 + a2 * n2) ÷ \(n1 + n2) = \(all).",
                        whyKo: "남학생 점수의 합: \(a1) × \(n1) = \(a1 * n1), 여학생 점수의 합: \(a2) × \(n2) = \(a2 * n2). 반 전체 합: \(a1 * n1 + a2 * n2)점. 평균: \(a1 * n1 + a2 * n2) ÷ \(n1 + n2) = \(all)점이에요. (두 평균을 그냥 더해서 2로 나누면 안 돼요!)")
        case 2:
            var m = 0, x = 0
            repeat { m = d.int(12...30); x = d.int(5...45) } while (5 * m - x) % 4 != 0 || x == m
            let newAvg = (5 * m - x) / 4
            return hard(u, "The average of 5 numbers is \(m). When the number \(x) is taken away, what is the average of the other 4 numbers?",
                        ko: "수 5개의 평균은 \(josa("\(m)", "이에요", "예요")). 이 중에서 \(josa("\(x)", "을", "를")) 빼면 나머지 4개의 수의 평균은 얼마인가요?",
                        answer: "\(newAvg)",
                        why: "Total of 5 numbers: \(m) × 5 = \(5 * m). Without \(x): \(5 * m) − \(x) = \(5 * m - x). New average: \(5 * m - x) ÷ 4 = \(newAvg).",
                        whyKo: "5개의 합: \(m) × 5 = \(5 * m). \(josa("\(x)", "을", "를")) 빼면 \(5 * m) − \(x) = \(5 * m - x). 새 평균: \(5 * m - x) ÷ 4 = \(newAvg)예요.")
        case 3:
            var a = 0, g = 0, need = 0
            repeat {
                a = d.int(15...30); g = a + d.int(2...8)
                need = 6 * g - 4 * a
            } while need % 2 != 0
            let per = need / 2
            return hard(u, "\(name) read an average of \(a) pages a day for 4 days. How many pages a day must \(name) read on average for the next 2 days to make the 6-day average \(g) pages?",
                        ko: "\(josa(nk, "은", "는")) 4일 동안 하루 평균 \(a)쪽씩 책을 읽었어요. 6일 동안의 평균을 \(g)쪽으로 만들려면, 남은 2일 동안 하루 평균 몇 쪽씩 읽어야 하나요?",
                        answer: "\(per)", unit: "pages",
                        why: "4 days: \(a) × 4 = \(4 * a) pages. 6 days needed: \(g) × 6 = \(6 * g) pages. The last 2 days: \(6 * g) − \(4 * a) = \(need) pages, so \(need) ÷ 2 = \(per) pages a day.",
                        whyKo: "4일 동안 읽은 쪽수: \(a) × 4 = \(4 * a)쪽. 6일 평균이 \(g)쪽이려면 \(g) × 6 = \(6 * g)쪽을 읽어야 해요. 남은 2일 동안 \(6 * g) − \(4 * a) = \(need)쪽, 하루에 \(need) ÷ 2 = \(per)쪽이에요.")
        default:
            let k = d.int(2...5)
            let n = 2 * k
            let cond: String, condKo: String, value: String, why: String, whyKo: String
            switch d.int(0...2) {
            case 0:
                cond = "an even number"; condKo = "짝수"; value = "1/2"
                why = "Half of the cards (\(k) of \(n)) are even, so the possibility is 1/2."
                whyKo = "\(n)장 중 \(k)장이 짝수로 딱 절반이므로 가능성은 1/2이에요."
            case 1:
                cond = "less than \(n + 1)"; condKo = "\(n + 1)보다 작은 수"; value = "1"
                why = "Every card (1 to \(n)) is less than \(n + 1), so it is certain: 1."
                whyKo = "모든 카드(1~\(n))가 \(n + 1)보다 작으므로 확실해요. 가능성은 1이에요."
            default:
                cond = "greater than \(n)"; condKo = "\(n)보다 큰 수"; value = "0"
                why = "No card is greater than \(n), so it is impossible: 0."
                whyKo = "\(n)보다 큰 카드는 없으므로 불가능해요. 가능성은 0이에요."
            }
            return hard(u, "There are \(n) cards numbered 1 to \(n). You pick one card without looking. Write the possibility that the number is \(cond) as a number (0, 1/2, or 1).",
                        ko: "1부터 \(n)까지의 수가 적힌 카드 \(n)장이 있어요. 보지 않고 한 장을 뽑을 때, \(condKo)가 나올 가능성을 수(0, 1/2, 1)로 나타내세요.",
                        answer: value, why: why, whyKo: whyKo)
        }
    }
}
