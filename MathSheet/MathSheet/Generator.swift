import Foundation

/// 날짜로 씨앗을 정하는 난수. 같은 날짜·설정이면 같은 학습지가 나와요.
final class Dice {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    convenience init(text: String) {
        var h: UInt64 = 0xcbf29ce484222325
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        self.init(seed: h)
    }

    private func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    func int(_ r: ClosedRange<Int>) -> Int {
        r.lowerBound + Int(next() % UInt64(r.count))
    }

    func bool() -> Bool { int(0...1) == 1 }

    func pick<T>(_ a: [T]) -> T { a[int(0...(a.count - 1))] }

    func shuffle<T>(_ a: [T]) -> [T] {
        var a = a
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, int(0...i)) }
        return a
    }

    /// 기약 진분수 하나
    func properFraction(maxDen: Int = 9) -> Frac {
        while true {
            let d = int(2...maxDen)
            let n = int(1...(d - 1))
            if Frac.gcd(n, d) == 1 { return Frac(n, d) }
        }
    }
}

/// 한국어 조사 (받침 있으면 a, 없으면 b)
func josa(_ s: String, _ a: String, _ b: String) -> String {
    s + (hasBatchim(s) ? a : b)
}

func hasBatchim(_ s: String) -> Bool {
    guard let last = s.trimmingCharacters(in: .whitespaces).last else { return false }
    if let v = last.unicodeScalars.first?.value, (0xAC00...0xD7A3).contains(v) {
        return (v - 0xAC00) % 28 != 0
    }
    // 숫자: 영·일·삼·육·칠·팔 (십·백·천·만도 받침 있음)
    if last.isNumber { return "013678".contains(last) }
    return false
}

enum Generator {
    /// (영어 이름, 한국어 이름)
    static let people: [(String, String)] = [
        ("Jiwoo", "지우"), ("Minsu", "민수"), ("Seoyeon", "서연"), ("Jiho", "지호"), ("Hana", "하나"),
        ("Yuna", "유나"), ("Doyun", "도윤"), ("Juno", "주노"), ("Sora", "소라"), ("Taeyang", "태양"),
    ]

    static func worksheet(day: String, number: Int = 1, settings: Settings) -> [Problem] {
        let units = settings.units(on: day)
        let d = Dice(text: "\(day)#\(number)#\(settings.problemsPerDay)#\(units.map(\.rawValue).joined())")
        var slots: [MathUnit] = []
        while slots.count < settings.problemsPerDay { slots += d.shuffle(units) }
        slots = Array(slots.prefix(settings.problemsPerDay))
        // 심화 문제는 무작위 자리에 정한 비율만큼, 학습지 뒤쪽에 모아요.
        let hardCount = Int((Double(settings.problemsPerDay) * Double(settings.challengePercent) / 100).rounded())
        let hardSlots = Set(d.shuffle(Array(slots.indices)).prefix(hardCount))
        let plan = slots.enumerated()
            .map { (unit: $0.element, hard: hardSlots.contains($0.offset)) }
            .sorted { ($0.hard ? 1 : 0, $0.unit.number) < ($1.hard ? 1 : 0, $1.unit.number) }

        var out: [Problem] = []
        var seen = Set<String>()
        for (i, slot) in plan.enumerated() {
            let unit = slot.unit
            func one() -> Problem { slot.hard ? challenge(unit, d) : make(unit, d) }
            var p = one()
            var tries = 0
            while seen.contains(p.text + (p.expr ?? "")) && tries < 20 {
                p = one()
                tries += 1
            }
            seen.insert(p.text + (p.expr ?? ""))
            p.id = "\(day)-\(number)-\(i)"
            out.append(p)
        }
        return out
    }

    static func make(_ unit: MathUnit, _ d: Dice) -> Problem {
        switch unit {
        case .range: return range(d)
        case .fractionMul: return fraction(d)
        case .symmetry: return symmetry(d)
        case .decimalMul: return decimal(d)
        case .cuboid: return cuboid(d)
        case .average: return average(d)
        }
    }

    // MARK: - 만들기 도우미

    static func num(_ u: MathUnit, _ text: String, ko: String, expr: String? = nil, answer: String,
                    unit: String? = nil, why: String) -> Problem {
        Problem(id: "", unit: u, kind: .number, text: text, expr: expr, answer: answer,
                choices: nil, unitLabel: unit, explanation: why, ko: ko)
    }

    static func choice(_ u: MathUnit, _ text: String, ko: String, answer: String, wrong: [String],
                       shuffle: Bool = true, d: Dice, why: String) -> Problem {
        let all = [answer] + wrong
        return Problem(id: "", unit: u, kind: .choice, text: text, expr: nil, answer: answer,
                       choices: shuffle ? d.shuffle(all) : all, unitLabel: nil, explanation: why, ko: ko)
    }

    // MARK: - 1. 수의 범위와 어림하기

    static func range(_ d: Dice) -> Problem {
        let u = MathUnit.range
        switch d.int(0...6) {
        case 0:
            // 범위 안의 자연수 개수
            let lo = d.int(10...60)
            let hi = lo + d.int(5...12)
            let loIn = d.bool(), hiIn = d.bool()
            let first = loIn ? lo : lo + 1
            let last = hiIn ? hi : hi - 1
            let count = last - first + 1
            let text = "How many whole numbers are \(loIn ? "at least" : "greater than") \(lo) and \(hiIn ? "at most" : "less than") \(hi)?"
            let ko = "\(lo) \(loIn ? "이상" : "초과")이고 \(hi) \(hiIn ? "이하" : "미만")인 자연수는 모두 몇 개인가요?"
            let loWhy = loIn ? "\"At least \(lo)\" includes \(lo)." : "\"Greater than \(lo)\" does not include \(lo)."
            let hiWhy = hiIn ? "\"At most \(hi)\" includes \(hi)." : "\"Less than \(hi)\" does not include \(hi)."
            let why = "\(loWhy) \(hiWhy) So the numbers are \(first), \(first + 1), …, \(last). That is \(count) numbers."
            return num(u, text, ko: ko, answer: "\(count)", why: why)

        case 1:
            // 범위에 들어가는 수 고르기 (경계값 함정 포함)
            let t = d.int(20...80)
            let kind = d.int(0...3)
            let phrase = ["at least", "at most", "greater than", "less than"][kind]
            let phraseKo = ["이상", "이하", "초과", "미만"][kind]
            func ok(_ x: Int) -> Bool { [x >= t, x <= t, x > t, x < t][kind] }
            let near = d.shuffle(Array((t - 6)...(t + 6)).filter { $0 != t })
            let correct: Int
            let wrong: [Int]
            if ok(t) {
                correct = t
                wrong = Array(near.filter { !ok($0) }.prefix(3))
            } else {
                correct = near.first(where: ok)!
                wrong = [t] + Array(near.filter { !ok($0) }.prefix(2))
            }
            let rule: String
            switch kind {
            case 0: rule = "\"At least \(t)\" means \(t) or more, so \(t) is included."
            case 1: rule = "\"At most \(t)\" means \(t) or less, so \(t) is included."
            case 2: rule = "\"Greater than \(t)\" means more than \(t), so \(t) itself is NOT included."
            default: rule = "\"Less than \(t)\" means smaller than \(t), so \(t) itself is NOT included."
            }
            return choice(u, "Which number is \(phrase) \(t)?", ko: "\(t) \(phraseKo)인 수는 어느 것인가요?",
                          answer: "\(correct)", wrong: wrong.map { "\($0)" }, d: d,
                          why: rule + " The answer is \(correct).")

        case 2, 3:
            // 자연수 올림·버림·반올림
            let places = [(10, "tens", "ten", "십"), (100, "hundreds", "hundred", "백"), (1000, "thousands", "thousand", "천")]
            let (place, placeName, nearestName, placeKo) = d.pick(places)
            var n = d.int(1000...99999)
            if n % place == 0 { n += d.int(1...(place - 1)) }
            let digitBelow = (n / (place / 10)) % 10
            let below = ["tens": "ones", "hundreds": "tens", "thousands": "hundreds"][placeName]!
            let nKo = josa(comma(n), "을", "를")
            switch d.int(0...2) {
            case 0:
                let a = (n + place - 1) / place * place
                return num(u, "Round up \(comma(n)) to the \(placeName) place.",
                           ko: "\(nKo) 올림하여 \(placeKo)의 자리까지 나타내세요.", answer: comma(a),
                           why: "Rounding up: if any digit below the \(placeName) place is not 0, add 1 to the \(placeName) digit and change the digits below it to 0. \(comma(n)) → \(comma(a)).")
            case 1:
                let a = n / place * place
                return num(u, "Round down \(comma(n)) to the \(placeName) place.",
                           ko: "\(nKo) 버림하여 \(placeKo)의 자리까지 나타내세요.", answer: comma(a),
                           why: "Rounding down: change all the digits below the \(placeName) place to 0. \(comma(n)) → \(comma(a)).")
            default:
                let a = (n + place / 2) / place * place
                let how = digitBelow >= 5 ? "It is 5 or more, so round up" : "It is less than 5, so round down"
                return num(u, "Round \(comma(n)) to the nearest \(nearestName).",
                           ko: "\(nKo) 반올림하여 \(placeKo)의 자리까지 나타내세요.", answer: comma(a),
                           why: "Look at the \(below) digit: \(digitBelow). \(how). \(comma(n)) → \(comma(a)).")
            }

        case 4:
            // 소수 반올림 (천분의 일까지 있는 수)
            var v = d.int(1001...9999)
            if v % 10 == 0 { v += 1 }
            let toTenths = d.bool()
            let step = toTenths ? 100 : 10   // 천분의 일 단위로
            let placeName = toTenths ? "tenths place (1 decimal place)" : "hundredths place (2 decimal places)"
            let placeKo = toTenths ? "소수 첫째 자리" : "소수 둘째 자리"
            let belowName = toTenths ? "hundredths" : "thousandths"
            let digitBelow = (v / (step / 10)) % 10
            let x = dec(v, 3)
            let xKo = josa(x, "을", "를")
            switch d.int(0...2) {
            case 0:
                let a = (v + step - 1) / step * step
                return num(u, "Round up \(x) to the \(placeName).", ko: "\(xKo) 올림하여 \(placeKo)까지 나타내세요.",
                           answer: dec(a, 3),
                           why: "Rounding up: the digits after the \(toTenths ? "tenths" : "hundredths") place are not all 0, so add 1 to that place and drop the rest. \(x) → \(dec(a, 3)).")
            case 1:
                let a = v / step * step
                return num(u, "Round down \(x) to the \(placeName).", ko: "\(xKo) 버림하여 \(placeKo)까지 나타내세요.",
                           answer: dec(a, 3),
                           why: "Rounding down: drop all the digits after the \(toTenths ? "tenths" : "hundredths") place. \(x) → \(dec(a, 3)).")
            default:
                let a = (v + step / 2) / step * step
                let how = digitBelow >= 5 ? "It is 5 or more, so round up" : "It is less than 5, so round down"
                return num(u, "Round \(x) to the \(placeName).", ko: "\(xKo) 반올림하여 \(placeKo)까지 나타내세요.",
                           answer: dec(a, 3),
                           why: "Look at the \(belowName) digit: \(digitBelow). \(how). \(x) → \(dec(a, 3)).")
            }

        default:
            // 어림하기 문장제
            let (name, nk) = d.pick(people)
            switch d.int(0...2) {
            case 0:
                let pack = d.pick([10, 100])
                var need = d.int(120...980)
                if need % pack == 0 { need += 7 }
                let buy = (need + pack - 1) / pack * pack
                return num(u, "Pencils are sold only in packs of \(pack). \(name) needs \(need) pencils. What is the smallest number of pencils \(name) has to buy?",
                           ko: "연필은 \(pack)자루씩 묶음으로만 팔아요. \(josa(nk, "은", "는")) 연필이 \(need)자루 필요해요. 연필을 적어도 몇 자루 사야 하나요?",
                           answer: comma(buy), unit: "pencils",
                           why: "\(name) can't buy part of a pack, so round UP \(need) to the \(pack == 10 ? "tens" : "hundreds") place: \(comma(buy)) pencils.")
            case 1:
                var money = d.int(1100...9900)
                if money % 1000 == 0 { money += 300 }
                let bills = money / 1000 * 1000
                return num(u, "\(name) has \(comma(money)) won in coins. \(name) wants to change the coins into 1,000-won bills. At most how many won can \(name) get in 1,000-won bills?",
                           ko: "\(josa(nk, "은", "는")) 동전으로 \(comma(money))원을 가지고 있어요. 동전을 1,000원짜리 지폐로 바꾸려고 해요. 1,000원짜리 지폐로 최대 얼마까지 바꿀 수 있나요?",
                           answer: comma(bills), unit: "won",
                           why: "Money less than 1,000 won can't become a 1,000-won bill, so round DOWN to the thousands place: \(comma(bills)) won.")
            default:
                var crowd = d.int(101...399)
                if crowd % 10 == 0 { crowd += 3 }
                let trips = (crowd + 9) / 10
                return num(u, "A boat can carry 10 people at a time. \(crowd) people want to cross the river. At least how many trips does the boat need to make?",
                           ko: "배 한 척에 한 번에 10명이 탈 수 있어요. \(crowd)명이 강을 건너려고 해요. 배는 적어도 몇 번 건너야 하나요?",
                           answer: "\(trips)", unit: "trips",
                           why: "Round UP \(crowd) to the tens place: \(trips * 10). Then \(trips * 10) ÷ 10 = \(trips) trips, so the last few people also get a ride.")
            }
        }
    }

    // MARK: - 2. 분수의 곱셈

    /// "12/3 = 4" — 약분이 필요 없으면 "2/3" 만
    private static func tail(_ n: Int, _ d: Int) -> String {
        let raw = "\(n)/\(d)"
        let f = Frac(n, d)
        return raw == f.mixed ? raw : "\(raw) = \(f.mixed)"
    }

    static func fraction(_ d: Dice) -> Problem {
        let u = MathUnit.fractionMul
        let calc = "Calculate. Write your answer in simplest form."
        let calcKo = "계산하세요. 답은 기약분수(가장 간단한 분수)로 나타내세요."
        switch d.int(0...5) {
        case 0:
            let w = d.int(2...12)
            let f = d.properFraction()
            let a = Frac(w) * f
            if d.bool() {
                return num(u, calc, ko: calcKo, expr: "\(w) × \(f.improper)", answer: a.mixed,
                           why: "\(w) × \(f.n)/\(f.d) = (\(w) × \(f.n))/\(f.d) = \(tail(w * f.n, f.d))")
            } else {
                return num(u, calc, ko: calcKo, expr: "\(f.improper) × \(w)", answer: a.mixed,
                           why: "\(f.n)/\(f.d) × \(w) = (\(f.n) × \(w))/\(f.d) = \(tail(w * f.n, f.d))")
            }
        case 1:
            let f = d.properFraction(), g = d.properFraction()
            let a = f * g
            return num(u, calc, ko: calcKo, expr: "\(f.improper) × \(g.improper)", answer: a.mixed,
                       why: "Multiply the numerators and the denominators: (\(f.n) × \(g.n))/(\(f.d) × \(g.d)) = \(tail(f.n * g.n, f.d * g.d))")
        case 2:
            let whole = d.int(1...3)
            let p = d.properFraction(maxDen: 6)
            let mixed = Frac(whole * p.d + p.n, p.d)
            let w = d.int(2...6)
            let a = mixed * Frac(w)
            return num(u, calc, ko: calcKo, expr: "\(mixed.mixed) × \(w)", answer: a.mixed,
                       why: "Change the mixed number to an improper fraction: \(mixed.mixed) = \(mixed.improper). Then \(mixed.improper) × \(w) = \(tail(mixed.n * w, mixed.d))")
        case 3:
            let p = d.properFraction(maxDen: 5), q = d.properFraction(maxDen: 5)
            let x = Frac(d.int(1...2) * p.d + p.n, p.d)
            let y = Frac(d.int(1...2) * q.d + q.n, q.d)
            let a = x * y
            return num(u, calc, ko: calcKo, expr: "\(x.mixed) × \(y.mixed)", answer: a.mixed,
                       why: "Change to improper fractions: \(x.mixed) = \(x.improper), \(y.mixed) = \(y.improper). Then (\(x.n) × \(y.n))/(\(x.d) × \(y.d)) = \(tail(x.n * y.n, x.d * y.d))")
        case 4:
            let f = d.properFraction(maxDen: 6), g = d.properFraction(maxDen: 6), h = d.properFraction(maxDen: 6)
            let a = f * g * h
            return num(u, calc, ko: calcKo, expr: "\(f.improper) × \(g.improper) × \(h.improper)", answer: a.mixed,
                       why: "Multiply all the numerators and all the denominators: (\(f.n) × \(g.n) × \(h.n))/(\(f.d) × \(g.d) × \(h.d)) = \(tail(f.n * g.n * h.n, f.d * g.d * h.d))")
        default:
            let (name, nk) = d.pick(people)
            switch d.int(0...3) {
            case 0:
                let den = d.pick([2, 3, 4, 5, 6, 10, 12])
                var n = d.int(1...(den - 1))
                while Frac.gcd(n, den) != 1 { n = d.int(1...(den - 1)) }
                let a = 60 * n / den
                return num(u, "There are 60 minutes in 1 hour. How many minutes are in \(n)/\(den) of an hour?",
                           ko: "1시간은 60분이에요. \(n)/\(den)시간은 몇 분인가요?",
                           answer: "\(a)", unit: "minutes",
                           why: "60 × \(n)/\(den) = (60 × \(n))/\(den) = \(60 * n)/\(den) = \(a) minutes")
            case 1:
                let w = d.int(2...9)
                let f = d.properFraction()
                let a = Frac(w) * f
                return num(u, "A ribbon is \(w) m long. \(name) used \(f.improper) of the ribbon. How many meters of ribbon did \(name) use?",
                           ko: "리본이 \(w) m 있어요. \(josa(nk, "은", "는")) 리본의 \(f.improper)만큼 사용했어요. \(josa(nk, "이", "가")) 사용한 리본은 몇 m인가요?",
                           answer: a.mixed, unit: "m",
                           why: "\(f.improper) of \(w) m means \(w) × \(f.improper) = \(tail(w * f.n, f.d)) m")
            case 2:
                let f = d.properFraction(maxDen: 8), g = d.properFraction(maxDen: 6)
                let a = f * g
                return num(u, "There is \(f.improper) L of milk. \(name) drank \(g.improper) of it. How many liters of milk did \(name) drink?",
                           ko: "우유가 \(f.improper) L 있어요. \(josa(nk, "은", "는")) 그중 \(g.improper)만큼 마셨어요. \(josa(nk, "이", "가")) 마신 우유는 몇 L인가요?",
                           answer: a.mixed, unit: "L",
                           why: "\(g.improper) of \(f.improper) L means \(f.improper) × \(g.improper) = \(tail(f.n * g.n, f.d * g.d)) L")
            default:
                let p = d.properFraction(maxDen: 4)
                let len = Frac(d.int(1...3) * p.d + p.n, p.d)
                let wid = d.properFraction(maxDen: 5)
                let a = len * wid
                return num(u, "A rectangle is \(len.mixed) m long and \(wid.improper) m wide. What is its area?",
                           ko: "가로가 \(len.mixed) m, 세로가 \(wid.improper) m인 직사각형이 있어요. 이 직사각형의 넓이는 몇 m²인가요?",
                           answer: a.mixed, unit: "m²",
                           why: "Area = length × width = \(len.mixed) × \(wid.improper) = \(len.improper) × \(wid.improper) = \(tail(len.n * wid.n, len.d * wid.d)) m²")
            }
        }
    }

    // MARK: - 3. 합동과 대칭

    static func symmetry(_ d: Dice) -> Problem {
        let u = MathUnit.symmetry
        let match = "(A matches D, B matches E, and C matches F.)"
        let matchKo = "(점 A와 점 D, 점 B와 점 E, 점 C와 점 F가 서로 대응점이에요.)"
        let triKo = "삼각형 ABC와 삼각형 DEF는 서로 합동이에요. \(matchKo)"
        switch d.int(0...6) {
        case 0:
            var a = 0, b = 0, c = 0
            repeat {
                a = d.int(4...12); b = d.int(4...12); c = d.int(4...12)
            } while !(a + b > c && b + c > a && a + c > b) || a == b || b == c || a == c
            let sides = [("DE", "AB", a), ("EF", "BC", b), ("FD", "CA", c)]
            let (ask, from, len) = d.pick(sides)
            return num(u, "Triangle ABC and triangle DEF are congruent. \(match) AB = \(a) cm, BC = \(b) cm, and CA = \(c) cm. What is the length of side \(ask)?",
                       ko: "\(triKo) AB = \(a) cm, BC = \(b) cm, CA = \(c) cm예요. 변 \(ask)의 길이는 몇 cm인가요?",
                       answer: "\(len)", unit: "cm",
                       why: "In congruent figures, corresponding sides have the same length. Side \(ask) corresponds to side \(from), so \(ask) = \(len) cm.")
        case 1:
            let b = d.int(40...80), c = d.int(30...70)
            let a = 180 - b - c
            if d.bool() {
                return num(u, "Triangle ABC and triangle DEF are congruent. \(match) Angle B = \(b)° and angle C = \(c)°. What is the size of angle D?",
                           ko: "\(triKo) 각 B = \(b)°, 각 C = \(c)°예요. 각 D의 크기는 몇 도인가요?",
                           answer: "\(a)", unit: "°",
                           why: "Angle D corresponds to angle A. The three angles of a triangle add up to 180°, so angle A = 180° − \(b)° − \(c)° = \(a)°. So angle D = \(a)°.")
            } else {
                return num(u, "Triangle ABC and triangle DEF are congruent. \(match) Angle A = \(a)° and angle B = \(b)°. What is the size of angle F?",
                           ko: "\(triKo) 각 A = \(a)°, 각 B = \(b)°예요. 각 F의 크기는 몇 도인가요?",
                           answer: "\(c)", unit: "°",
                           why: "Angle F corresponds to angle C. Angle C = 180° − \(a)° − \(b)° = \(c)°. So angle F = \(c)°.")
            }
        case 2:
            let s = (0..<4).map { _ in d.int(3...12) }
            let total = s.reduce(0, +)
            return num(u, "Quadrilateral ABCD and quadrilateral EFGH are congruent. The sides of ABCD are AB = \(s[0]) cm, BC = \(s[1]) cm, CD = \(s[2]) cm, and DA = \(s[3]) cm. What is the perimeter of EFGH?",
                       ko: "사각형 ABCD와 사각형 EFGH는 서로 합동이에요. 사각형 ABCD의 변의 길이는 AB = \(s[0]) cm, BC = \(s[1]) cm, CD = \(s[2]) cm, DA = \(s[3]) cm예요. 사각형 EFGH의 둘레는 몇 cm인가요?",
                       answer: "\(total)", unit: "cm",
                       why: "Congruent figures have sides of the same lengths, so the perimeter is the same: \(s[0]) + \(s[1]) + \(s[2]) + \(s[3]) = \(total) cm.")
        case 3:
            let shapes: [(String, String, Int, String)] = [
                ("a square", "정사각형", 4, "A square has 4 lines of symmetry: 2 through the middles of opposite sides and 2 diagonals."),
                ("a rectangle that is not a square", "정사각형이 아닌 직사각형", 2, "A rectangle has 2 lines of symmetry, through the middles of opposite sides. Its diagonals are not lines of symmetry."),
                ("an equilateral triangle", "정삼각형", 3, "An equilateral triangle has 3 lines of symmetry, one from each vertex to the middle of the opposite side."),
                ("a regular pentagon", "정오각형", 5, "A regular polygon has as many lines of symmetry as it has sides. A regular pentagon has 5."),
                ("a regular hexagon", "정육각형", 6, "A regular polygon has as many lines of symmetry as it has sides. A regular hexagon has 6."),
                ("a regular octagon", "정팔각형", 8, "A regular polygon has as many lines of symmetry as it has sides. A regular octagon has 8."),
                ("an isosceles triangle (not equilateral)", "이등변삼각형(정삼각형이 아닌)", 1, "An isosceles triangle has only 1 line of symmetry, through the vertex between the two equal sides."),
                ("a rhombus that is not a square", "정사각형이 아닌 마름모", 2, "A rhombus has 2 lines of symmetry: its two diagonals."),
            ]
            let (name, nameKo, n, why) = d.pick(shapes)
            return num(u, "How many lines of symmetry does \(name) have?", ko: "\(nameKo)의 대칭축은 몇 개인가요?",
                       answer: "\(n)", unit: "lines", why: why)
        case 4:
            if d.bool() {
                let yes = ["A", "M", "T", "U", "V", "W", "Y"]
                let no = ["F", "G", "J", "L", "P", "R", "N", "S", "Z"]
                let ans = d.pick(yes)
                return choice(u, "Which capital letter is line-symmetric (has a line of symmetry)?",
                              ko: "선대칭인(대칭축이 있는) 알파벳 대문자는 어느 것인가요?", answer: ans,
                              wrong: Array(d.shuffle(no).prefix(3)), d: d,
                              why: "If you fold \(ans) along a line down its middle, the two halves match exactly. The other letters can't be folded that way.")
            } else {
                let yes = ["N", "S", "Z"]
                let no = ["A", "T", "M", "U", "V", "F", "L", "P", "R", "K", "E", "C"]
                let ans = d.pick(yes)
                return choice(u, "Which capital letter is point-symmetric?",
                              ko: "점대칭인 알파벳 대문자는 어느 것인가요?", answer: ans,
                              wrong: Array(d.shuffle(no).prefix(3)), d: d,
                              why: "If you turn \(ans) 180° around its center, it looks exactly the same. The other letters look different after a half turn.")
            }
        case 5:
            let yes = ["a parallelogram", "a rectangle", "a regular hexagon", "a rhombus"]
            let no = ["an equilateral triangle", "a regular pentagon", "an isosceles triangle", "a trapezoid (not a parallelogram)"]
            let ans = d.pick(yes)
            return choice(u, "Which shape is point-symmetric?", ko: "점대칭도형은 어느 것인가요?", answer: ans,
                          wrong: Array(d.shuffle(no).prefix(3)), d: d,
                          why: "\(ans.prefix(1).uppercased() + String(ans.dropFirst())) looks the same after a 180° turn around its center. Triangles, regular pentagons, and trapezoids like that do not.")
        default:
            let k = d.int(2...12)
            switch d.int(0...2) {
            case 0:
                return num(u, "In a line-symmetric figure, point A is \(k) cm away from the line of symmetry. How far apart are point A and its corresponding point?",
                           ko: "선대칭도형에서 점 A는 대칭축에서 \(k) cm 떨어져 있어요. 점 A와 그 대응점 사이의 거리는 몇 cm인가요?",
                           answer: "\(2 * k)", unit: "cm",
                           why: "Corresponding points are the same distance from the line of symmetry, on opposite sides. So the distance is \(k) × 2 = \(2 * k) cm.")
            case 1:
                return num(u, "In a point-symmetric figure, the segment joining point A and its corresponding point is \(2 * k) cm long. How far is point A from the center of symmetry?",
                           ko: "점대칭도형에서 점 A와 그 대응점을 이은 선분의 길이는 \(2 * k) cm예요. 점 A에서 대칭의 중심까지의 거리는 몇 cm인가요?",
                           answer: "\(k)", unit: "cm",
                           why: "The center of symmetry cuts the segment between corresponding points in half: \(2 * k) ÷ 2 = \(k) cm.")
            default:
                return num(u, "In a line-symmetric figure, the segment joining two corresponding points meets the line of symmetry. What angle do they make?",
                           ko: "선대칭도형에서 두 대응점을 이은 선분은 대칭축과 만나요. 이때 이루는 각은 몇 도인가요?",
                           answer: "90", unit: "°",
                           why: "The line of symmetry is always perpendicular to the segment joining corresponding points, so the angle is 90°.")
            }
        }
    }

    // MARK: - 4. 소수의 곱셈

    /// 끝자리가 0이 아닌 정수
    private static func nz(_ d: Dice, _ r: ClosedRange<Int>) -> Int {
        var v = d.int(r)
        while v % 10 == 0 { v = d.int(r) }
        return v
    }

    private static func placesText(_ p: Int) -> String { p == 1 ? "1 decimal place" : "\(p) decimal places" }

    private static func productWhy(_ xi: Int, _ yi: Int, _ p: Int, _ px: Int, _ py: Int) -> String {
        let raw = dec(xi * yi, p, trim: false)
        let trimmed = dec(xi * yi, p)
        let count = (px > 0 && py > 0) ? "\(px) + \(py) = \(p) decimal places" : placesText(p)
        return "First multiply as whole numbers: \(xi) × \(yi) = \(xi * yi). The numbers have \(count) in total, so the answer has \(placesText(p)): \(raw)\(raw == trimmed ? "" : " = \(trimmed)")."
    }

    static func decimal(_ d: Dice) -> Problem {
        let u = MathUnit.decimalMul
        let calc = "Calculate."
        let calcKo = "계산하세요."
        switch d.int(0...5) {
        case 0:
            let p = d.int(1...2)
            let a = nz(d, p == 1 ? 2...99 : 11...499)
            let w = d.int(2...9)
            return num(u, calc, ko: calcKo, expr: "\(dec(a, p)) × \(w)", answer: dec(a * w, p),
                       why: productWhy(a, w, p, p, 0))
        case 1:
            let p = d.int(1...2)
            let a = nz(d, p == 1 ? 2...49 : 11...99)
            let w = d.int(3...25)
            return num(u, calc, ko: calcKo, expr: "\(w) × \(dec(a, p))", answer: dec(a * w, p),
                       why: productWhy(w, a, p, 0, p))
        case 2:
            let pa = d.int(1...2)
            let a = nz(d, pa == 1 ? 2...99 : 11...299)
            let b = nz(d, 2...49)
            return num(u, calc, ko: calcKo, expr: "\(dec(a, pa)) × \(dec(b, 1))", answer: dec(a * b, pa + 1),
                       why: productWhy(a, b, pa + 1, pa, 1))
        case 3:
            if d.bool() {
                let a = nz(d, 101...9999)
                let p = d.int(1...3)
                let m = d.pick([10, 100, 1000])
                let shift = String(m).count - 1
                let x = dec(a, p)
                let ans = dec(a * m, p)
                return num(u, calc, ko: calcKo, expr: "\(x) × \(comma(m))", answer: ans,
                           why: "Multiplying by \(comma(m)) moves the decimal point \(shift) place\(shift == 1 ? "" : "s") to the RIGHT: \(x) → \(ans).")
            } else {
                let w = nz(d, 2...9999)
                let k = d.int(1...3)
                let m = dec(1, k)
                let ans = dec(w, k)
                return num(u, calc, ko: calcKo, expr: "\(w) × \(m)", answer: ans,
                           why: "Multiplying by \(m) moves the decimal point \(k) place\(k == 1 ? "" : "s") to the LEFT: \(w) → \(ans).")
            }
        case 4:
            let a = nz(d, 11...99), b = nz(d, 11...99)
            let pa = d.int(0...2), pb = d.int(1...2)
            let x = dec(a, pa), y = dec(b, pb)
            let ans = dec(a * b, pa + pb)
            return num(u, "\(a) × \(b) = \(a * b). Use this to find the answer.",
                       ko: "\(a) × \(b) = \(josa("\(a * b)", "이에요", "예요")). 이것을 이용하여 계산하세요.",
                       expr: "\(x) × \(y)", answer: ans,
                       why: "\(x) has \(placesText(pa)) and \(y) has \(placesText(pb)), so the answer has \(placesText(pa + pb)). Move the decimal point in \(a * b): \(ans).")
        default:
            let (name, nk) = d.pick(people)
            switch d.int(0...2) {
            case 0:
                let k = nz(d, 11...39)
                let days = d.int(3...9)
                return num(u, "\(name) walks \(dec(k, 1)) km every day. How many kilometers does \(name) walk in \(days) days?",
                           ko: "\(josa(nk, "은", "는")) 매일 \(dec(k, 1)) km씩 걸어요. \(days)일 동안 걷는 거리는 모두 몇 km인가요?",
                           answer: dec(k * days, 1), unit: "km",
                           why: "\(dec(k, 1)) × \(days) = \(dec(k * days, 1)) km")
            case 1:
                let big = nz(d, 21...89)
                let times = nz(d, 2...9)
                return num(u, "A watermelon weighs \(dec(big, 1)) kg. A melon weighs 0.\(times) times as much as the watermelon. How much does the melon weigh?",
                           ko: "수박의 무게는 \(dec(big, 1)) kg이에요. 멜론의 무게는 수박 무게의 0.\(times)배예요. 멜론의 무게는 몇 kg인가요?",
                           answer: dec(big * times, 2), unit: "kg",
                           why: productWhy(big, times, 2, 1, 1) + " So the melon weighs \(dec(big * times, 2)) kg.")
            default:
                let l = nz(d, 11...49), w = nz(d, 2...19)
                return num(u, "A rectangle is \(dec(l, 1)) m long and \(dec(w, 1)) m wide. What is its area?",
                           ko: "가로가 \(dec(l, 1)) m, 세로가 \(dec(w, 1)) m인 직사각형이 있어요. 이 직사각형의 넓이는 몇 m²인가요?",
                           answer: dec(l * w, 2), unit: "m²",
                           why: "Area = length × width = \(dec(l, 1)) × \(dec(w, 1)). " + productWhy(l, w, 2, 1, 1))
            }
        }
    }

    // MARK: - 5. 직육면체

    static func cuboid(_ d: Dice) -> Problem {
        let u = MathUnit.cuboid
        switch d.int(0...6) {
        case 0:
            let (shape, shapeKo) = d.pick([("cuboid", "직육면체"), ("cube", "정육면체")])
            let (part, partKo, n) = d.pick([("faces", "면은", 6), ("edges", "모서리는", 12), ("vertices", "꼭짓점은", 8)])
            return num(u, "How many \(part) does a \(shape) have?", ko: "\(shapeKo)의 \(partKo) 몇 개인가요?",
                       answer: "\(n)", unit: part,
                       why: "Every \(shape) has 6 faces, 12 edges, and 8 vertices.")
        case 1:
            var a = 0, b = 0, c = 0
            repeat { a = d.int(2...15); b = d.int(2...15); c = d.int(2...15) } while a == b || b == c || a == c
            let total = 4 * (a + b + c)
            return num(u, "A cuboid is \(a) cm long, \(b) cm wide, and \(c) cm high. What is the total length of all its edges?",
                       ko: "가로 \(a) cm, 세로 \(b) cm, 높이 \(c) cm인 직육면체가 있어요. 모든 모서리의 길이의 합은 몇 cm인가요?",
                       answer: "\(total)", unit: "cm",
                       why: "A cuboid has 4 edges of each length. (\(a) + \(b) + \(c)) × 4 = \(a + b + c) × 4 = \(total) cm.")
        case 2:
            let e = d.int(2...15)
            if d.bool() {
                return num(u, "Each edge of a cube is \(e) cm long. What is the total length of all its edges?",
                           ko: "한 모서리의 길이가 \(e) cm인 정육면체가 있어요. 모든 모서리의 길이의 합은 몇 cm인가요?",
                           answer: "\(12 * e)", unit: "cm",
                           why: "A cube has 12 edges of the same length: \(e) × 12 = \(12 * e) cm.")
            } else {
                return num(u, "The total length of all the edges of a cube is \(12 * e) cm. How long is one edge?",
                           ko: "정육면체의 모든 모서리의 길이의 합은 \(12 * e) cm예요. 한 모서리의 길이는 몇 cm인가요?",
                           answer: "\(e)", unit: "cm",
                           why: "A cube has 12 equal edges: \(12 * e) ÷ 12 = \(e) cm.")
            }
        case 3:
            let asks: [(String, String, Int, String)] = [
                ("edges are drawn with dotted lines", "점선으로 그린 모서리는 몇 개인가요?", 3, "edges"),
                ("edges are drawn with solid lines", "실선으로 그린 모서리는 몇 개인가요?", 9, "edges"),
                ("vertices are hidden", "보이지 않는 꼭짓점은 몇 개인가요?", 1, "vertices"),
                ("vertices can be seen", "보이는 꼭짓점은 몇 개인가요?", 7, "vertices"),
                ("faces can be seen", "보이는 면은 몇 개인가요?", 3, "faces"),
            ]
            let (q, qKo, n, unit) = d.pick(asks)
            return num(u, "In a sketch of a cuboid, the edges we can see are drawn with solid lines and the hidden edges are drawn with dotted lines. How many \(q)?",
                       ko: "직육면체의 겨냥도에서 보이는 모서리는 실선으로, 보이지 않는 모서리는 점선으로 그려요. \(qKo)",
                       answer: "\(n)", unit: unit,
                       why: "In a sketch of a cuboid: 9 solid edges and 3 dotted edges, 7 visible vertices and 1 hidden vertex, 3 visible faces and 3 hidden faces.")
        case 4:
            let asks: [(String, String, Int, String, String)] = [
                ("How many faces of a cuboid are perpendicular to one face?", "직육면체에서 한 면과 수직인 면은 몇 개인가요?", 4, "faces", "Each face meets 4 neighboring faces at right angles. Only the opposite face is not perpendicular to it."),
                ("How many faces of a cuboid are parallel to one face?", "직육면체에서 한 면과 평행한 면은 몇 개인가요?", 1, "face", "Only the face directly opposite is parallel. A cuboid has 3 pairs of parallel faces."),
                ("How many pairs of parallel faces does a cuboid have?", "직육면체에서 서로 평행한 면은 모두 몇 쌍인가요?", 3, "pairs", "Top and bottom, front and back, and left and right: 3 pairs."),
                ("How many edges meet at one vertex of a cuboid?", "직육면체의 한 꼭짓점에서 만나는 모서리는 몇 개인가요?", 3, "edges", "At every vertex, 3 edges meet (length, width, and height)."),
                ("How many squares are in the net of a cube?", "정육면체의 전개도는 정사각형 몇 개로 이루어져 있나요?", 6, "squares", "A cube has 6 square faces, so its net has 6 squares."),
            ]
            let (q, qKo, n, unit, why) = d.pick(asks)
            return num(u, q, ko: qKo, answer: "\(n)", unit: unit, why: why)
        case 5:
            if d.bool() {
                let truths = ["All 6 faces are squares.", "All 12 edges have the same length.", "It has 8 vertices."]
                let lie = d.pick(["It has 10 edges.", "Two faces next to each other are parallel.", "It has 4 faces."])
                return choice(u, "Which statement about a cube is NOT true?", ko: "정육면체에 대한 설명으로 틀린 것은 어느 것인가요?",
                              answer: lie, wrong: truths, d: d,
                              why: "\"\(lie)\" is false. A cube has 6 square faces, 12 equal edges, and 8 vertices, and faces next to each other are perpendicular.")
            } else {
                let truths = ["It has 6 faces.", "Opposite faces are parallel.", "Faces next to each other are perpendicular."]
                let lie = d.pick(["All its faces must be squares.", "It has 6 vertices.", "It has 8 edges."])
                return choice(u, "Which statement about a cuboid is NOT true?", ko: "직육면체에 대한 설명으로 틀린 것은 어느 것인가요?",
                              answer: lie, wrong: truths, d: d,
                              why: "\"\(lie)\" is false. A cuboid has 6 rectangular faces (they don't have to be squares), 12 edges, and 8 vertices.")
            }
        default:
            var a = 0, b = 0, c = 0
            repeat { a = d.int(2...12); b = d.int(2...12); c = d.int(2...12) } while a == b || b == c || a == c
            let total = 4 * (a + b + c)
            return num(u, "The total length of all the edges of a cuboid is \(total) cm. Its length is \(a) cm and its width is \(b) cm. What is its height?",
                       ko: "직육면체의 모든 모서리의 길이의 합은 \(total) cm예요. 가로는 \(a) cm, 세로는 \(b) cm예요. 높이는 몇 cm인가요?",
                       answer: "\(c)", unit: "cm",
                       why: "One length + one width + one height = \(total) ÷ 4 = \(a + b + c) cm. Height = \(a + b + c) − \(a) − \(b) = \(c) cm.")
        }
    }

    // MARK: - 6. 평균과 가능성

    /// 평균이 m 이 되도록 n 개의 수를 만들어요.
    private static func values(_ d: Dice, count n: Int, mean m: Int, spread: Int, range: ClosedRange<Int>) -> [Int] {
        while true {
            var v = (0..<(n - 1)).map { _ in m + d.int(-spread...spread) }
            let last = m * n - v.reduce(0, +)
            v.append(last)
            if v.allSatisfy({ range.contains($0) }) && Set(v).count > 1 { return d.shuffle(v) }
        }
    }

    private static func list(_ v: [Int]) -> String {
        guard v.count > 1 else { return v.map(String.init).joined() }
        return v.dropLast().map(String.init).joined(separator: ", ") + ", and \(v.last!)"
    }

    private static func listKo(_ v: [Int]) -> String { v.map(String.init).joined(separator: ", ") }

    static func average(_ d: Dice) -> Problem {
        let u = MathUnit.average
        let (name, nk) = d.pick(people)
        switch d.int(0...5) {
        case 0, 1:
            let n = d.int(4...6)
            // (영어, 한국어, 단위, 평균, 값 범위)
            let contexts: [(String, String, String, Int, ClosedRange<Int>)] = [
                ("\(name)'s math test scores are %@. What is the average score?",
                 "\(nk)의 수학 시험 점수는 %@점이에요. 평균 점수는 몇 점인가요?", "points", d.int(70...92), 50...100),
                ("\(name) read %@ pages of a book on \(n) different days. On average, how many pages did \(name) read per day?",
                 "\(josa(nk, "은", "는")) \(n)일 동안 책을 각각 %@쪽 읽었어요. 하루에 평균 몇 쪽을 읽었나요?", "pages", d.int(15...40), 1...80),
                ("The jump rope records of \(n) students are %@ jumps. What is the average number of jumps?",
                 "학생 \(n)명의 줄넘기 기록은 %@번이에요. 줄넘기 기록의 평균은 몇 번인가요?", "jumps", d.int(30...90), 5...150),
                ("The heights of \(n) seedlings are %@ cm. What is their average height?",
                 "새싹 \(n)개의 키는 %@ cm예요. 새싹 키의 평균은 몇 cm인가요?", "cm", d.int(10...30), 1...60),
            ]
            let (tmpl, tmplKo, unit, m, r) = d.pick(contexts)
            let v = values(d, count: n, mean: m, spread: 10, range: r)
            let sum = v.reduce(0, +)
            return num(u, tmpl.replacingOccurrences(of: "%@", with: list(v)),
                       ko: tmplKo.replacingOccurrences(of: "%@", with: listKo(v)),
                       answer: "\(m)", unit: unit,
                       why: "Average = total ÷ number of values. Total = \(v.map(String.init).joined(separator: " + ")) = \(sum). \(sum) ÷ \(n) = \(m).")
        case 2:
            let n = d.int(4...5)
            let m = d.int(12...30)
            var known: [Int] = []
            var missing = 0
            repeat {
                known = (0..<(n - 1)).map { _ in m + d.int(-8...8) }
                missing = m * n - known.reduce(0, +)
            } while missing <= 0 || abs(missing - m) > 12
            let word = n == 4 ? "fourth" : "fifth"
            return num(u, "The average of \(n) numbers is \(m). \(n - 1 == 3 ? "Three" : "Four") of the numbers are \(list(known)). What is the \(word) number?",
                       ko: "수 \(n)개의 평균은 \(josa("\(m)", "이에요", "예요")). 그중 \(n - 1)개의 수는 \(josa(listKo(known), "이에요", "예요")). 나머지 한 수는 얼마인가요?",
                       answer: "\(missing)",
                       why: "Total = average × count = \(m) × \(n) = \(m * n). The known numbers add up to \(known.reduce(0, +)). \(m * n) − \(known.reduce(0, +)) = \(missing).")
        case 3:
            let pa = d.int(3...6), pb = d.int(3...6)
            let ma = d.int(8...20)
            var mb = d.int(8...20)
            while mb == ma { mb = d.int(8...20) }
            let ans = ma > mb ? "Team A" : "Team B"
            return choice(u, "Team A has \(pa) members who read \(pa * ma) books in total. Team B has \(pb) members who read \(pb * mb) books in total. Which team read more books per person on average?",
                          ko: "A 모둠은 \(pa)명이 책을 모두 \(pa * ma)권 읽었어요. B 모둠은 \(pb)명이 책을 모두 \(pb * mb)권 읽었어요. 한 사람당 평균적으로 책을 더 많이 읽은 모둠은 어느 모둠인가요?",
                          answer: ans, wrong: [ma > mb ? "Team B" : "Team A", "They are the same"], shuffle: false, d: d,
                          why: "Team A: \(pa * ma) ÷ \(pa) = \(ma) books. Team B: \(pb * mb) ÷ \(pb) = \(mb) books. \(ans) has the greater average.")
                .ordered(["Team A", "Team B", "They are the same"])
        case 4:
            let (event, eventKo, level, why) = d.pick(possibilityEvents)
            return choice(u, "How likely is this to happen?\n\"\(event)\"",
                          ko: "다음 일이 일어날 가능성은 어느 정도인가요?\n\"\(eventKo)\"", answer: level,
                          wrong: possibilityWords.filter { $0 != level }, shuffle: false, d: d,
                          why: why)
                .ordered(possibilityWords)
        default:
            let events = possibilityEvents.filter { [possibilityWords[0], possibilityWords[2], possibilityWords[4]].contains($0.2) }
            let (event, eventKo, level, why) = d.pick(events)
            let value = level == possibilityWords[0] ? "0" : level == possibilityWords[4] ? "1" : "1/2"
            return num(u, "Write the possibility as a number (0, 1/2, or 1).\n\"\(event)\"",
                       ko: "다음 일이 일어날 가능성을 수(0, 1/2, 1)로 나타내세요.\n\"\(eventKo)\"",
                       answer: value,
                       why: why + " Impossible = 0, even chance = 1/2, certain = 1. So the answer is \(value).")
        }
    }

    static let possibilityWords = ["impossible", "unlikely", "even chance (half and half)", "likely", "certain"]

    /// (영어, 한국어, 가능성, 풀이)
    static let possibilityEvents: [(String, String, String, String)] = [
        ("You roll a regular die and get a number less than 7.", "주사위를 굴려서 7보다 작은 수가 나와요.",
         "certain", "Every number on a die (1 to 6) is less than 7, so it will surely happen."),
        ("You pick a marble from a bag of only red marbles, and it is red.", "빨간 구슬만 들어 있는 주머니에서 구슬을 하나 꺼내면 빨간 구슬이에요.",
         "certain", "Every marble is red, so it will surely be red."),
        ("Tomorrow will come after today.", "오늘 다음에 내일이 와요.",
         "certain", "This always happens."),
        ("You roll a regular die and get 7.", "주사위를 굴려서 7이 나와요.",
         "impossible", "A die only has the numbers 1 to 6, so you can never get 7."),
        ("You pick a blue marble from a bag of only red marbles.", "빨간 구슬만 들어 있는 주머니에서 파란 구슬을 꺼내요.",
         "impossible", "There are no blue marbles in the bag, so it can't happen."),
        ("A week has 10 days.", "일주일은 10일이에요.",
         "impossible", "A week always has 7 days."),
        ("You flip a coin and get heads.", "동전을 던져서 그림 면(앞면)이 나와요.",
         "even chance (half and half)", "A coin has 2 sides, heads and tails, so the chance is half and half."),
        ("You roll a regular die and get an even number.", "주사위를 굴려서 짝수가 나와요.",
         "even chance (half and half)", "3 of the 6 numbers (2, 4, 6) are even, so the chance is half and half."),
        ("You pick a marble from a bag with 3 red and 3 blue marbles, and it is red.", "빨간 구슬 3개와 파란 구슬 3개가 든 주머니에서 구슬을 하나 꺼내면 빨간 구슬이에요.",
         "even chance (half and half)", "Half of the marbles are red, so the chance is half and half."),
        ("You roll a regular die and get a number greater than 1.", "주사위를 굴려서 1보다 큰 수가 나와요.",
         "likely", "5 of the 6 numbers (2 to 6) are greater than 1, so it will probably happen."),
        ("You pick a marble from a bag with 9 red and 1 blue marble, and it is red.", "빨간 구슬 9개와 파란 구슬 1개가 든 주머니에서 구슬을 하나 꺼내면 빨간 구슬이에요.",
         "likely", "Most of the marbles are red, so it will probably happen."),
        ("You roll a regular die and get a 6.", "주사위를 굴려서 6이 나와요.",
         "unlikely", "Only 1 of the 6 numbers is a 6, so it probably won't happen."),
        ("You pick a marble from a bag with 9 red and 1 blue marble, and it is blue.", "빨간 구슬 9개와 파란 구슬 1개가 든 주머니에서 구슬을 하나 꺼내면 파란 구슬이에요.",
         "unlikely", "Only 1 of the 10 marbles is blue, so it probably won't happen."),
    ]
}

private extension Problem {
    /// 보기를 정해진 순서로 (가능성 단어: 불가능 → 확실)
    func ordered(_ order: [String]) -> Problem {
        var p = self
        p.choices = order.filter { (choices ?? []).contains($0) }
        return p
    }
}
