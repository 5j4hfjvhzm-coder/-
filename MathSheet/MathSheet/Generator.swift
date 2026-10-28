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

enum Generator {
    static let names = ["Jiwoo", "Minsu", "Seoyeon", "Jiho", "Hana", "Yuna", "Doyun", "Juno", "Sora", "Taeyang"]

    static func worksheet(day: String, settings: Settings) -> [Problem] {
        let d = Dice(text: "\(day)#\(settings.problemsPerDay)#\(settings.units.map(\.rawValue).joined())")
        let units = settings.units.isEmpty ? MathUnit.allCases : settings.units
        var plan: [MathUnit] = []
        while plan.count < settings.problemsPerDay { plan += d.shuffle(units) }
        plan = Array(plan.prefix(settings.problemsPerDay)).sorted { $0.number < $1.number }

        var out: [Problem] = []
        var seen = Set<String>()
        for (i, unit) in plan.enumerated() {
            var p = make(unit, d)
            var tries = 0
            while seen.contains(p.text + (p.expr ?? "")) && tries < 20 {
                p = make(unit, d)
                tries += 1
            }
            seen.insert(p.text + (p.expr ?? ""))
            p.id = "\(day)-\(i)"
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

    static func num(_ u: MathUnit, _ text: String, expr: String? = nil, answer: String,
                    unit: String? = nil, why: String) -> Problem {
        Problem(id: "", unit: u, kind: .number, text: text, expr: expr, answer: answer,
                choices: nil, unitLabel: unit, explanation: why)
    }

    static func choice(_ u: MathUnit, _ text: String, answer: String, wrong: [String],
                       shuffle: Bool = true, d: Dice, why: String) -> Problem {
        let all = [answer] + wrong
        return Problem(id: "", unit: u, kind: .choice, text: text, expr: nil, answer: answer,
                       choices: shuffle ? d.shuffle(all) : all, unitLabel: nil, explanation: why)
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
            let loWhy = loIn ? "\"At least \(lo)\" includes \(lo)." : "\"Greater than \(lo)\" does not include \(lo)."
            let hiWhy = hiIn ? "\"At most \(hi)\" includes \(hi)." : "\"Less than \(hi)\" does not include \(hi)."
            let why = "\(loWhy) \(hiWhy) So the numbers are \(first), \(first + 1), …, \(last). That is \(count) numbers."
            return num(u, text, answer: "\(count)", why: why)

        case 1:
            // 범위에 들어가는 수 고르기 (경계값 함정 포함)
            let t = d.int(20...80)
            let kind = d.int(0...3)
            let phrase = ["at least", "at most", "greater than", "less than"][kind]
            func ok(_ x: Int) -> Bool { [x >= t, x <= t, x > t, x < t][kind] }
            let near = d.shuffle(Array((t - 6)...(t + 6)).filter { $0 != t })
            let correct: Int
            let wrong: [Int]
            if ok(t) {
                correct = t
                wrong = Array(near.filter { !ok($0) }.prefix(3))
            } else {
                correct = near.first(where: ok)!
                wrong = [t] + near.filter { !ok($0) }.prefix(2)
            }
            let rule: String
            switch kind {
            case 0: rule = "\"At least \(t)\" means \(t) or more, so \(t) is included."
            case 1: rule = "\"At most \(t)\" means \(t) or less, so \(t) is included."
            case 2: rule = "\"Greater than \(t)\" means more than \(t), so \(t) itself is NOT included."
            default: rule = "\"Less than \(t)\" means smaller than \(t), so \(t) itself is NOT included."
            }
            return choice(u, "Which number is \(phrase) \(t)?", answer: "\(correct)",
                          wrong: wrong.map { "\($0)" }, d: d, why: rule + " The answer is \(correct).")

        case 2, 3:
            // 자연수 올림·버림·반올림
            let places = [(10, "tens", "ten"), (100, "hundreds", "hundred"), (1000, "thousands", "thousand")]
            let (place, placeName, nearestName) = d.pick(places)
            var n = d.int(1000...99999)
            if n % place == 0 { n += d.int(1...(place - 1)) }
            let digitBelow = (n / (place / 10)) % 10
            let below = ["tens": "ones", "hundreds": "tens", "thousands": "hundreds"][placeName]!
            switch d.int(0...2) {
            case 0:
                let a = (n + place - 1) / place * place
                return num(u, "Round up \(comma(n)) to the \(placeName) place.", answer: comma(a),
                           why: "Rounding up: if any digit below the \(placeName) place is not 0, add 1 to the \(placeName) digit and change the digits below it to 0. \(comma(n)) → \(comma(a)).")
            case 1:
                let a = n / place * place
                return num(u, "Round down \(comma(n)) to the \(placeName) place.", answer: comma(a),
                           why: "Rounding down: change all the digits below the \(placeName) place to 0. \(comma(n)) → \(comma(a)).")
            default:
                let a = (n + place / 2) / place * place
                let how = digitBelow >= 5 ? "It is 5 or more, so round up" : "It is less than 5, so round down"
                return num(u, "Round \(comma(n)) to the nearest \(nearestName).", answer: comma(a),
                           why: "Look at the \(below) digit: \(digitBelow). \(how). \(comma(n)) → \(comma(a)).")
            }

        case 4:
            // 소수 반올림 (천분의 일까지 있는 수)
            var v = d.int(1001...9999)
            if v % 10 == 0 { v += 1 }
            let toTenths = d.bool()
            let step = toTenths ? 100 : 10   // 천분의 일 단위로
            let placeName = toTenths ? "tenths place (1 decimal place)" : "hundredths place (2 decimal places)"
            let belowName = toTenths ? "hundredths" : "thousandths"
            let digitBelow = (v / (step / 10)) % 10
            let x = dec(v, 3)
            switch d.int(0...2) {
            case 0:
                let a = (v + step - 1) / step * step
                return num(u, "Round up \(x) to the \(placeName).", answer: dec(a, 3),
                           why: "Rounding up: the digits after the \(toTenths ? "tenths" : "hundredths") place are not all 0, so add 1 to that place and drop the rest. \(x) → \(dec(a, 3)).")
            case 1:
                let a = v / step * step
                return num(u, "Round down \(x) to the \(placeName).", answer: dec(a, 3),
                           why: "Rounding down: drop all the digits after the \(toTenths ? "tenths" : "hundredths") place. \(x) → \(dec(a, 3)).")
            default:
                let a = (v + step / 2) / step * step
                let how = digitBelow >= 5 ? "It is 5 or more, so round up" : "It is less than 5, so round down"
                return num(u, "Round \(x) to the \(placeName).", answer: dec(a, 3),
                           why: "Look at the \(belowName) digit: \(digitBelow). \(how). \(x) → \(dec(a, 3)).")
            }

        default:
            // 어림하기 문장제
            let name = d.pick(names)
            switch d.int(0...2) {
            case 0:
                let pack = d.pick([10, 100])
                var need = d.int(120...980)
                if need % pack == 0 { need += 7 }
                let buy = (need + pack - 1) / pack * pack
                return num(u, "Pencils are sold only in packs of \(pack). \(name) needs \(need) pencils. What is the smallest number of pencils \(name) has to buy?",
                           answer: comma(buy), unit: "pencils",
                           why: "\(name) can't buy part of a pack, so round UP \(need) to the \(pack == 10 ? "tens" : "hundreds") place: \(comma(buy)) pencils.")
            case 1:
                var money = d.int(1100...9900)
                if money % 1000 == 0 { money += 300 }
                let bills = money / 1000 * 1000
                return num(u, "\(name) has \(comma(money)) won in coins. \(name) wants to change the coins into 1,000-won bills. At most how many won can \(name) get in 1,000-won bills?",
                           answer: comma(bills), unit: "won",
                           why: "Money less than 1,000 won can't become a 1,000-won bill, so round DOWN to the thousands place: \(comma(bills)) won.")
            default:
                var people = d.int(101...399)
                if people % 10 == 0 { people += 3 }
                let trips = (people + 9) / 10
                return num(u, "A boat can carry 10 people at a time. \(people) people want to cross the river. At least how many trips does the boat need to make?",
                           answer: "\(trips)", unit: "trips",
                           why: "Round UP \(people) to the tens place: \((people + 9) / 10 * 10). Then \((people + 9) / 10 * 10) ÷ 10 = \(trips) trips, so the last few people also get a ride.")
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
        switch d.int(0...5) {
        case 0:
            let w = d.int(2...12)
            let f = d.properFraction()
            let a = Frac(w) * f
            if d.bool() {
                return num(u, calc, expr: "\(w) × \(f.improper)", answer: a.mixed,
                           why: "\(w) × \(f.n)/\(f.d) = (\(w) × \(f.n))/\(f.d) = \(tail(w * f.n, f.d))")
            } else {
                return num(u, calc, expr: "\(f.improper) × \(w)", answer: a.mixed,
                           why: "\(f.n)/\(f.d) × \(w) = (\(f.n) × \(w))/\(f.d) = \(tail(w * f.n, f.d))")
            }
        case 1:
            let f = d.properFraction(), g = d.properFraction()
            let a = f * g
            return num(u, calc, expr: "\(f.improper) × \(g.improper)", answer: a.mixed,
                       why: "Multiply the numerators and the denominators: (\(f.n) × \(g.n))/(\(f.d) × \(g.d)) = \(tail(f.n * g.n, f.d * g.d))")
        case 2:
            let whole = d.int(1...3)
            let p = d.properFraction(maxDen: 6)
            let mixed = Frac(whole * p.d + p.n, p.d)
            let w = d.int(2...6)
            let a = mixed * Frac(w)
            return num(u, calc, expr: "\(mixed.mixed) × \(w)", answer: a.mixed,
                       why: "Change the mixed number to an improper fraction: \(mixed.mixed) = \(mixed.improper). Then \(mixed.improper) × \(w) = \(tail(mixed.n * w, mixed.d))")
        case 3:
            let p = d.properFraction(maxDen: 5), q = d.properFraction(maxDen: 5)
            let x = Frac(d.int(1...2) * p.d + p.n, p.d)
            let y = Frac(d.int(1...2) * q.d + q.n, q.d)
            let a = x * y
            return num(u, calc, expr: "\(x.mixed) × \(y.mixed)", answer: a.mixed,
                       why: "Change to improper fractions: \(x.mixed) = \(x.improper), \(y.mixed) = \(y.improper). Then (\(x.n) × \(y.n))/(\(x.d) × \(y.d)) = \(tail(x.n * y.n, x.d * y.d))")
        case 4:
            let f = d.properFraction(maxDen: 6), g = d.properFraction(maxDen: 6), h = d.properFraction(maxDen: 6)
            let a = f * g * h
            return num(u, calc, expr: "\(f.improper) × \(g.improper) × \(h.improper)", answer: a.mixed,
                       why: "Multiply all the numerators and all the denominators: (\(f.n) × \(g.n) × \(h.n))/(\(f.d) × \(g.d) × \(h.d)) = \(tail(f.n * g.n * h.n, f.d * g.d * h.d))")
        default:
            let name = d.pick(names)
            switch d.int(0...3) {
            case 0:
                let den = d.pick([2, 3, 4, 5, 6, 10, 12])
                var n = d.int(1...(den - 1))
                while Frac.gcd(n, den) != 1 { n = d.int(1...(den - 1)) }
                let a = 60 * n / den
                return num(u, "There are 60 minutes in 1 hour. How many minutes are in \(n)/\(den) of an hour?",
                           answer: "\(a)", unit: "minutes",
                           why: "60 × \(n)/\(den) = (60 × \(n))/\(den) = \(60 * n)/\(den) = \(a) minutes")
            case 1:
                let w = d.int(2...9)
                let f = d.properFraction()
                let a = Frac(w) * f
                return num(u, "A ribbon is \(w) m long. \(name) used \(f.improper) of the ribbon. How many meters of ribbon did \(name) use?",
                           answer: a.mixed, unit: "m",
                           why: "\(f.improper) of \(w) m means \(w) × \(f.improper) = \(tail(w * f.n, f.d)) m")
            case 2:
                let f = d.properFraction(maxDen: 8), g = d.properFraction(maxDen: 6)
                let a = f * g
                return num(u, "There is \(f.improper) L of milk. \(name) drank \(g.improper) of it. How many liters of milk did \(name) drink?",
                           answer: a.mixed, unit: "L",
                           why: "\(g.improper) of \(f.improper) L means \(f.improper) × \(g.improper) = \(tail(f.n * g.n, f.d * g.d)) L")
            default:
                let p = d.properFraction(maxDen: 4)
                let len = Frac(d.int(1...3) * p.d + p.n, p.d)
                let wid = d.properFraction(maxDen: 5)
                let a = len * wid
                return num(u, "A rectangle is \(len.mixed) m long and \(wid.improper) m wide. What is its area?",
                           answer: a.mixed, unit: "m²",
                           why: "Area = length × width = \(len.mixed) × \(wid.improper) = \(len.improper) × \(wid.improper) = \(tail(len.n * wid.n, len.d * wid.d)) m²")
            }
        }
    }

    // MARK: - 3. 합동과 대칭

    static func symmetry(_ d: Dice) -> Problem {
        let u = MathUnit.symmetry
        let match = "(A matches D, B matches E, and C matches F.)"
        switch d.int(0...6) {
        case 0:
            var a = 0, b = 0, c = 0
            repeat {
                a = d.int(4...12); b = d.int(4...12); c = d.int(4...12)
            } while !(a + b > c && b + c > a && a + c > b) || a == b || b == c || a == c
            let sides = [("DE", "AB", a), ("EF", "BC", b), ("FD", "CA", c)]
            let (ask, from, len) = d.pick(sides)
            return num(u, "Triangle ABC and triangle DEF are congruent. \(match) AB = \(a) cm, BC = \(b) cm, and CA = \(c) cm. What is the length of side \(ask)?",
                       answer: "\(len)", unit: "cm",
                       why: "In congruent figures, corresponding sides have the same length. Side \(ask) corresponds to side \(from), so \(ask) = \(len) cm.")
        case 1:
            let b = d.int(40...80), c = d.int(30...70)
            let a = 180 - b - c
            if d.bool() {
                return num(u, "Triangle ABC and triangle DEF are congruent. \(match) Angle B = \(b)° and angle C = \(c)°. What is the size of angle D?",
                           answer: "\(a)", unit: "°",
                           why: "Angle D corresponds to angle A. The three angles of a triangle add up to 180°, so angle A = 180° − \(b)° − \(c)° = \(a)°. So angle D = \(a)°.")
            } else {
                return num(u, "Triangle ABC and triangle DEF are congruent. \(match) Angle A = \(a)° and angle B = \(b)°. What is the size of angle F?",
                           answer: "\(c)", unit: "°",
                           why: "Angle F corresponds to angle C. Angle C = 180° − \(a)° − \(b)° = \(c)°. So angle F = \(c)°.")
            }
        case 2:
            let s = (0..<4).map { _ in d.int(3...12) }
            let total = s.reduce(0, +)
            return num(u, "Quadrilateral ABCD and quadrilateral EFGH are congruent. The sides of ABCD are AB = \(s[0]) cm, BC = \(s[1]) cm, CD = \(s[2]) cm, and DA = \(s[3]) cm. What is the perimeter of EFGH?",
                       answer: "\(total)", unit: "cm",
                       why: "Congruent figures have sides of the same lengths, so the perimeter is the same: \(s[0]) + \(s[1]) + \(s[2]) + \(s[3]) = \(total) cm.")
        case 3:
            let shapes: [(String, Int, String)] = [
                ("a square", 4, "A square has 4 lines of symmetry: 2 through the middles of opposite sides and 2 diagonals."),
                ("a rectangle that is not a square", 2, "A rectangle has 2 lines of symmetry, through the middles of opposite sides. Its diagonals are not lines of symmetry."),
                ("an equilateral triangle", 3, "An equilateral triangle has 3 lines of symmetry, one from each vertex to the middle of the opposite side."),
                ("a regular pentagon", 5, "A regular polygon has as many lines of symmetry as it has sides. A regular pentagon has 5."),
                ("a regular hexagon", 6, "A regular polygon has as many lines of symmetry as it has sides. A regular hexagon has 6."),
                ("a regular octagon", 8, "A regular polygon has as many lines of symmetry as it has sides. A regular octagon has 8."),
                ("an isosceles triangle (not equilateral)", 1, "An isosceles triangle has only 1 line of symmetry, through the vertex between the two equal sides."),
                ("a rhombus that is not a square", 2, "A rhombus has 2 lines of symmetry: its two diagonals."),
            ]
            let (name, n, why) = d.pick(shapes)
            return num(u, "How many lines of symmetry does \(name) have?", answer: "\(n)", unit: "lines", why: why)
        case 4:
            if d.bool() {
                let yes = ["A", "M", "T", "U", "V", "W", "Y"]
                let no = ["F", "G", "J", "L", "P", "R", "N", "S", "Z"]
                let ans = d.pick(yes)
                return choice(u, "Which capital letter is line-symmetric (has a line of symmetry)?", answer: ans,
                              wrong: Array(d.shuffle(no).prefix(3)), d: d,
                              why: "If you fold \(ans) along a line down its middle, the two halves match exactly. The other letters can't be folded that way.")
            } else {
                let yes = ["N", "S", "Z"]
                let no = ["A", "T", "M", "U", "V", "F", "L", "P", "R", "K", "E", "C"]
                let ans = d.pick(yes)
                return choice(u, "Which capital letter is point-symmetric?", answer: ans,
                              wrong: Array(d.shuffle(no).prefix(3)), d: d,
                              why: "If you turn \(ans) 180° around its center, it looks exactly the same. The other letters look different after a half turn.")
            }
        case 5:
            let yes = ["a parallelogram", "a rectangle", "a regular hexagon", "a rhombus"]
            let no = ["an equilateral triangle", "a regular pentagon", "an isosceles triangle", "a trapezoid (not a parallelogram)"]
            let ans = d.pick(yes)
            return choice(u, "Which shape is point-symmetric?", answer: ans,
                          wrong: Array(d.shuffle(no).prefix(3)), d: d,
                          why: "\(ans.prefix(1).uppercased() + String(ans.dropFirst())) looks the same after a 180° turn around its center. Triangles, regular pentagons, and trapezoids like that do not.")
        default:
            let k = d.int(2...12)
            switch d.int(0...2) {
            case 0:
                return num(u, "In a line-symmetric figure, point A is \(k) cm away from the line of symmetry. How far apart are point A and its corresponding point?",
                           answer: "\(2 * k)", unit: "cm",
                           why: "Corresponding points are the same distance from the line of symmetry, on opposite sides. So the distance is \(k) × 2 = \(2 * k) cm.")
            case 1:
                return num(u, "In a point-symmetric figure, the segment joining point A and its corresponding point is \(2 * k) cm long. How far is point A from the center of symmetry?",
                           answer: "\(k)", unit: "cm",
                           why: "The center of symmetry cuts the segment between corresponding points in half: \(2 * k) ÷ 2 = \(k) cm.")
            default:
                return num(u, "In a line-symmetric figure, the segment joining two corresponding points meets the line of symmetry. What angle do they make?",
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

    private static func productWhy(_ x: String, _ y: String, _ xi: Int, _ yi: Int, _ p: Int, _ px: Int, _ py: Int) -> String {
        let raw = dec(xi * yi, p, trim: false)
        let trimmed = dec(xi * yi, p)
        let count = (px > 0 && py > 0) ? "\(px) + \(py) = \(p) decimal places" : placesText(p)
        return "First multiply as whole numbers: \(xi) × \(yi) = \(xi * yi). The numbers have \(count) in total, so the answer has \(placesText(p)): \(raw)\(raw == trimmed ? "" : " = \(trimmed)")."
    }

    static func decimal(_ d: Dice) -> Problem {
        let u = MathUnit.decimalMul
        let calc = "Calculate."
        switch d.int(0...5) {
        case 0:
            let p = d.int(1...2)
            let a = nz(d, p == 1 ? 2...99 : 11...499)
            let w = d.int(2...9)
            let x = dec(a, p)
            return num(u, calc, expr: "\(x) × \(w)", answer: dec(a * w, p),
                       why: productWhy(x, "\(w)", a, w, p, p, 0))
        case 1:
            let p = d.int(1...2)
            let a = nz(d, p == 1 ? 2...49 : 11...99)
            let w = d.int(3...25)
            let x = dec(a, p)
            return num(u, calc, expr: "\(w) × \(x)", answer: dec(a * w, p),
                       why: productWhy("\(w)", x, w, a, p, 0, p))
        case 2:
            let pa = d.int(1...2)
            let a = nz(d, pa == 1 ? 2...99 : 11...299)
            let b = nz(d, 2...49)
            let x = dec(a, pa), y = dec(b, 1)
            return num(u, calc, expr: "\(x) × \(y)", answer: dec(a * b, pa + 1),
                       why: productWhy(x, y, a, b, pa + 1, pa, 1))
        case 3:
            if d.bool() {
                let a = nz(d, 101...9999)
                let p = d.int(1...3)
                let m = d.pick([10, 100, 1000])
                let shift = String(m).count - 1
                let x = dec(a, p)
                let ans = dec(a * m, p)
                return num(u, calc, expr: "\(x) × \(comma(m))", answer: ans,
                           why: "Multiplying by \(comma(m)) moves the decimal point \(shift) place\(shift == 1 ? "" : "s") to the RIGHT: \(x) → \(ans).")
            } else {
                let w = nz(d, 2...9999)
                let k = d.int(1...3)
                let m = dec(1, k)
                let ans = dec(w, k)
                return num(u, calc, expr: "\(w) × \(m)", answer: ans,
                           why: "Multiplying by \(m) moves the decimal point \(k) place\(k == 1 ? "" : "s") to the LEFT: \(w) → \(ans).")
            }
        case 4:
            let a = nz(d, 11...99), b = nz(d, 11...99)
            let pa = d.int(0...2), pb = d.int(1...2)
            let x = dec(a, pa), y = dec(b, pb)
            let ans = dec(a * b, pa + pb)
            return num(u, "\(a) × \(b) = \(a * b). Use this to find the answer.", expr: "\(x) × \(y)", answer: ans,
                       why: "\(x) has \(placesText(pa)) and \(y) has \(placesText(pb)), so the answer has \(placesText(pa + pb)). Move the decimal point in \(a * b): \(ans).")
        default:
            let name = d.pick(names)
            switch d.int(0...2) {
            case 0:
                let k = nz(d, 11...39)
                let days = d.int(3...9)
                return num(u, "\(name) walks \(dec(k, 1)) km every day. How many kilometers does \(name) walk in \(days) days?",
                           answer: dec(k * days, 1), unit: "km",
                           why: "\(dec(k, 1)) × \(days) = \(dec(k * days, 1)) km")
            case 1:
                let big = nz(d, 21...89)
                let times = nz(d, 2...9)
                return num(u, "A watermelon weighs \(dec(big, 1)) kg. A melon weighs 0.\(times) times as much as the watermelon. How much does the melon weigh?",
                           answer: dec(big * times, 2), unit: "kg",
                           why: productWhy(dec(big, 1), "0.\(times)", big, times, 2, 1, 1) + " So the melon weighs \(dec(big * times, 2)) kg.")
            default:
                let l = nz(d, 11...49), w = nz(d, 2...19)
                return num(u, "A rectangle is \(dec(l, 1)) m long and \(dec(w, 1)) m wide. What is its area?",
                           answer: dec(l * w, 2), unit: "m²",
                           why: "Area = length × width = \(dec(l, 1)) × \(dec(w, 1)). " + productWhy(dec(l, 1), dec(w, 1), l, w, 2, 1, 1))
            }
        }
    }

    // MARK: - 5. 직육면체

    static func cuboid(_ d: Dice) -> Problem {
        let u = MathUnit.cuboid
        switch d.int(0...6) {
        case 0:
            let shape = d.pick(["cuboid", "cube"])
            let (part, n) = d.pick([("faces", 6), ("edges", 12), ("vertices", 8)])
            return num(u, "How many \(part) does a \(shape) have?", answer: "\(n)", unit: part,
                       why: "Every \(shape) has 6 faces, 12 edges, and 8 vertices.")
        case 1:
            var a = 0, b = 0, c = 0
            repeat { a = d.int(2...15); b = d.int(2...15); c = d.int(2...15) } while a == b || b == c || a == c
            let total = 4 * (a + b + c)
            return num(u, "A cuboid is \(a) cm long, \(b) cm wide, and \(c) cm high. What is the total length of all its edges?",
                       answer: "\(total)", unit: "cm",
                       why: "A cuboid has 4 edges of each length. (\(a) + \(b) + \(c)) × 4 = \(a + b + c) × 4 = \(total) cm.")
        case 2:
            let e = d.int(2...15)
            if d.bool() {
                return num(u, "Each edge of a cube is \(e) cm long. What is the total length of all its edges?",
                           answer: "\(12 * e)", unit: "cm",
                           why: "A cube has 12 edges of the same length: \(e) × 12 = \(12 * e) cm.")
            } else {
                return num(u, "The total length of all the edges of a cube is \(12 * e) cm. How long is one edge?",
                           answer: "\(e)", unit: "cm",
                           why: "A cube has 12 equal edges: \(12 * e) ÷ 12 = \(e) cm.")
            }
        case 3:
            let asks: [(String, Int, String, String)] = [
                ("edges are drawn with dotted lines", 3, "edges", "hidden edges"),
                ("edges are drawn with solid lines", 9, "edges", "visible edges"),
                ("vertices are hidden", 1, "vertices", "hidden vertices"),
                ("vertices can be seen", 7, "vertices", "visible vertices"),
                ("faces can be seen", 3, "faces", "visible faces"),
            ]
            let (q, n, unit, _) = d.pick(asks)
            return num(u, "In a sketch of a cuboid, the edges we can see are drawn with solid lines and the hidden edges are drawn with dotted lines. How many \(q)?",
                       answer: "\(n)", unit: unit,
                       why: "In a sketch of a cuboid: 9 solid edges and 3 dotted edges, 7 visible vertices and 1 hidden vertex, 3 visible faces and 3 hidden faces.")
        case 4:
            let asks: [(String, Int, String, String)] = [
                ("How many faces of a cuboid are perpendicular to one face?", 4, "faces", "Each face meets 4 neighboring faces at right angles. Only the opposite face is not perpendicular to it."),
                ("How many faces of a cuboid are parallel to one face?", 1, "face", "Only the face directly opposite is parallel. A cuboid has 3 pairs of parallel faces."),
                ("How many pairs of parallel faces does a cuboid have?", 3, "pairs", "Top–bottom, front–back, and left–right: 3 pairs."),
                ("How many edges meet at one vertex of a cuboid?", 3, "edges", "At every vertex, 3 edges meet (length, width, and height)."),
                ("How many squares are in the net of a cube?", 6, "squares", "A cube has 6 square faces, so its net has 6 squares."),
            ]
            let (q, n, unit, why) = d.pick(asks)
            return num(u, q, answer: "\(n)", unit: unit, why: why)
        case 5:
            if d.bool() {
                let truths = ["All 6 faces are squares.", "All 12 edges have the same length.", "It has 8 vertices."]
                let lie = d.pick(["It has 10 edges.", "Two faces next to each other are parallel.", "It has 4 faces."])
                return choice(u, "Which statement about a cube is NOT true?", answer: lie, wrong: truths, d: d,
                              why: "\"\(lie)\" is false. A cube has 6 square faces, 12 equal edges, and 8 vertices, and faces next to each other are perpendicular.")
            } else {
                let truths = ["It has 6 faces.", "Opposite faces are parallel.", "Faces next to each other are perpendicular."]
                let lie = d.pick(["All its faces must be squares.", "It has 6 vertices.", "It has 8 edges."])
                return choice(u, "Which statement about a cuboid is NOT true?", answer: lie, wrong: truths, d: d,
                              why: "\"\(lie)\" is false. A cuboid has 6 rectangular faces (they don't have to be squares), 12 edges, and 8 vertices.")
            }
        default:
            var a = 0, b = 0, c = 0
            repeat { a = d.int(2...12); b = d.int(2...12); c = d.int(2...12) } while a == b || b == c || a == c
            let total = 4 * (a + b + c)
            return num(u, "The total length of all the edges of a cuboid is \(total) cm. Its length is \(a) cm and its width is \(b) cm. What is its height?",
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

    static func average(_ d: Dice) -> Problem {
        let u = MathUnit.average
        let name = d.pick(names)
        switch d.int(0...5) {
        case 0, 1:
            let n = d.int(4...6)
            let contexts: [(String, String, Int, ClosedRange<Int>)] = [
                ("\(name)'s math test scores are %@. What is the average score?", "points", d.int(70...92), 50...100),
                ("\(name) read %@ pages of a book on \(n) different days. On average, how many pages did \(name) read per day?", "pages", d.int(15...40), 1...80),
                ("The jump rope records of \(n) students are %@ jumps. What is the average number of jumps?", "jumps", d.int(30...90), 5...150),
                ("The heights of \(n) seedlings are %@ cm. What is their average height?", "cm", d.int(10...30), 1...60),
            ]
            let (tmpl, unit, m, r) = d.pick(contexts)
            let v = values(d, count: n, mean: m, spread: 10, range: r)
            let sum = v.reduce(0, +)
            return num(u, tmpl.replacingOccurrences(of: "%@", with: list(v)), answer: "\(m)", unit: unit,
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
                       answer: "\(missing)",
                       why: "Total = average × count = \(m) × \(n) = \(m * n). The known numbers add up to \(known.reduce(0, +)). \(m * n) − \(known.reduce(0, +)) = \(missing).")
        case 3:
            let pa = d.int(3...6), pb = d.int(3...6)
            let ma = d.int(8...20)
            var mb = d.int(8...20)
            while mb == ma { mb = d.int(8...20) }
            let ans = ma > mb ? "Team A" : "Team B"
            return choice(u, "Team A has \(pa) members who read \(pa * ma) books in total. Team B has \(pb) members who read \(pb * mb) books in total. Which team read more books per person on average?",
                          answer: ans, wrong: [ma > mb ? "Team B" : "Team A", "They are the same"], shuffle: false, d: d,
                          why: "Team A: \(pa * ma) ÷ \(pa) = \(ma) books. Team B: \(pb * mb) ÷ \(pb) = \(mb) books. \(ans) has the greater average.")
                .ordered(["Team A", "Team B", "They are the same"])
        case 4:
            let events = possibilityEvents
            let (event, level, why) = d.pick(events)
            return choice(u, "How likely is this to happen?\n\"\(event)\"", answer: level,
                          wrong: possibilityWords.filter { $0 != level }, shuffle: false, d: d,
                          why: why)
                .ordered(possibilityWords)
        default:
            let events = possibilityEvents.filter { [possibilityWords[0], possibilityWords[2], possibilityWords[4]].contains($0.1) }
            let (event, level, why) = d.pick(events)
            let value = level == possibilityWords[0] ? "0" : level == possibilityWords[4] ? "1" : "1/2"
            return num(u, "Write the possibility as a number (0, 1/2, or 1).\n\"\(event)\"", answer: value,
                       why: why + " Impossible = 0, even chance = 1/2, certain = 1. So the answer is \(value).")
        }
    }

    static let possibilityWords = ["impossible", "unlikely", "even chance (half and half)", "likely", "certain"]

    static let possibilityEvents: [(String, String, String)] = [
        ("You roll a regular die and get a number less than 7.", "certain", "Every number on a die (1–6) is less than 7, so it will surely happen."),
        ("You pick a marble from a bag of only red marbles, and it is red.", "certain", "Every marble is red, so it will surely be red."),
        ("Tomorrow will come after today.", "certain", "This always happens."),
        ("You roll a regular die and get 7.", "impossible", "A die only has the numbers 1 to 6, so you can never get 7."),
        ("You pick a blue marble from a bag of only red marbles.", "impossible", "There are no blue marbles in the bag, so it can't happen."),
        ("A week has 10 days.", "impossible", "A week always has 7 days."),
        ("You flip a coin and get heads.", "even chance (half and half)", "A coin has 2 sides, heads and tails, so the chance is half and half."),
        ("You roll a regular die and get an even number.", "even chance (half and half)", "3 of the 6 numbers (2, 4, 6) are even, so the chance is half and half."),
        ("You pick a marble from a bag with 3 red and 3 blue marbles, and it is red.", "even chance (half and half)", "Half of the marbles are red, so the chance is half and half."),
        ("You roll a regular die and get a number greater than 1.", "likely", "5 of the 6 numbers (2–6) are greater than 1, so it will probably happen."),
        ("You pick a marble from a bag with 9 red and 1 blue marble, and it is red.", "likely", "Most of the marbles are red, so it will probably happen."),
        ("You roll a regular die and get a 6.", "unlikely", "Only 1 of the 6 numbers is a 6, so it probably won't happen."),
        ("You pick a marble from a bag with 9 red and 1 blue marble, and it is blue.", "unlikely", "Only 1 of the 10 marbles is blue, so it probably won't happen."),
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
