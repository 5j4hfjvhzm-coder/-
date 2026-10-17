import Foundation

/// 일본어 활용형 → 기본형 (Yomichan 방식 규칙).
/// 예: 食べました → 食べる, 行った → 行く, 待っています → 待つ, 楽しかった → 楽しい

enum WordType: String {
    case v1, v5, vs, vk, adjI, te, ta
}

struct DeinflectRule {
    /// 활용 어미
    let from: String
    /// 기본형 어미
    let to: String
    /// 이 어미가 붙은 말이 될 수 있는 품사 (빈 배열 = 원문에서만)
    let inTypes: [WordType]
    /// 결과 품사
    let outType: WordType
    /// 화면에 보여 줄 이유 (한국어)
    let why: String
}

struct Deinflection: Equatable {
    var term: String
    var reasons: [String]
    /// nil = 원문 그대로
    var type: WordType?
}

enum Deinflector {
    static let rules: [DeinflectRule] = buildRules().sorted { $0.from.count > $1.from.count }

    /// 활용형으로 보이는 말 → 기본형 후보들 (원문 자체도 첫 번째로 포함)
    static func deinflect(_ text: String) -> [Deinflection] {
        var out = [Deinflection(term: text, reasons: [], type: nil)]
        var seen: Set<String> = [text + "|"]
        var k = 0
        while k < out.count && out.count < 200 {
            let c = out[k]
            k += 1
            if c.reasons.count >= 5 { continue }
            for rule in rules {
                if let t = c.type, !rule.inTypes.contains(t) { continue }
                guard c.term.hasSuffix(rule.from) else { continue }
                let stem = String(c.term.dropLast(rule.from.count))
                if stem.isEmpty && rule.to.count <= 1 { continue }
                let term = stem + rule.to
                let key = term + "|" + rule.outType.rawValue
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(Deinflection(term: term, reasons: [rule.why] + c.reasons, type: rule.outType))
            }
        }
        return out
    }

    /// 결과 품사와 기본형 어미가 맞는지 (예: 1단 동사는 る 로 끝나야)
    static func typeFits(_ term: String, _ type: WordType?) -> Bool {
        guard let type else { return true }
        switch type {
        case .v1: return term.hasSuffix("る")
        case .v5: return term.last.map { "うくぐすつぬぶむる".contains($0) } ?? false
        case .vs: return term.hasSuffix("する")
        case .vk: return term.hasSuffix("くる") || term.hasSuffix("来る")
        case .adjI: return term.hasSuffix("い")
        case .te, .ta: return false // 중간 단계
        }
    }

    // MARK: 규칙 표

    private struct VerbForms {
        var i: String, a: String, te: String, ta: String, ba: String
        var vol: String?
        var imp: [String]
        var pot: [String]
        var pass: [String]
        var caus: [String]
    }

    private static func buildRules() -> [DeinflectRule] {
        var rules: [DeinflectRule] = []
        func r(_ from: String, _ to: String, _ inT: [WordType], _ out: WordType, _ why: String) {
            rules.append(DeinflectRule(from: from, to: to, inTypes: inT, outType: out, why: why))
        }

        func verb(_ base: String, _ f: VerbForms, _ type: WordType) {
            for (s, why) in [
                ("ます", "정중(ます)"), ("ません", "정중 부정(ません)"), ("ました", "정중 과거(ました)"),
                ("ませんでした", "정중 과거 부정"), ("ましょう", "권유(ましょう)"), ("ましょうか", "권유(ましょうか)"),
                ("まして", "정중 て형"), ("ながら", "~하면서(ながら)"), ("なさい", "명령(なさい)"),
                ("そう", "~할 것 같다(そう)"), ("に", "~하러(に)"), ("ませ", "정중 명령"),
                ("かた", "~하는 법(方)"), ("方", "~하는 법(方)"),
            ] {
                r(f.i + s, base, [], type, why)
            }
            r(f.i + "たい", base, [.adjI], type, "희망(たい)")
            r(f.i + "すぎる", base, [.v1], type, "너무 ~하다(すぎる)")
            r(f.i + "やすい", base, [.adjI], type, "~하기 쉽다")
            r(f.i + "にくい", base, [.adjI], type, "~하기 어렵다")
            r(f.i + "たがる", base, [.v5], type, "~하고 싶어하다")
            r(f.a + "ない", base, [.adjI], type, "부정(ない)")
            for (s, why) in [
                ("ず", "부정(ず)"), ("ずに", "~하지 않고(ずに)"), ("ぬ", "부정(ぬ)"), ("ん", "부정(ん)"),
                ("なきゃ", "~해야 해(なきゃ)"), ("なくちゃ", "~해야 해(なくちゃ)"),
                ("なければ", "~하지 않으면"), ("ないで", "~하지 말고(ないで)"),
            ] {
                r(f.a + s, base, [], type, why)
            }
            r(f.te, base, [.te], type, "て형")
            r(f.ta, base, [.ta], type, "과거(た)")
            r(f.ta + "ら", base, [], type, "~하면(たら)")
            r(f.ta + "り", base, [], type, "~하거나(たり)")
            r(f.ba + "ば", base, [], type, "가정(ば)")
            if let vol = f.vol { r(vol, base, [], type, "의지(よう)") }
            for s in f.imp { r(s, base, [], type, "명령형") }
            for s in f.pot { r(s, base, [.v1], type, "가능") }
            for s in f.pass { r(s, base, [.v1], type, "수동") }
            for s in f.caus { r(s, base, [.v1, .v5], type, "사역") }
        }

        // 5단 동사: 기본 어미 → [い단, あ단, え단, お단, て형, た형]
        let godan: [(String, [String])] = [
            ("う", ["い", "わ", "え", "お", "って", "った"]),
            ("く", ["き", "か", "け", "こ", "いて", "いた"]),
            ("ぐ", ["ぎ", "が", "げ", "ご", "いで", "いだ"]),
            ("す", ["し", "さ", "せ", "そ", "して", "した"]),
            ("つ", ["ち", "た", "て", "と", "って", "った"]),
            ("ぬ", ["に", "な", "ね", "の", "んで", "んだ"]),
            ("ぶ", ["び", "ば", "べ", "ぼ", "んで", "んだ"]),
            ("む", ["み", "ま", "め", "も", "んで", "んだ"]),
            ("る", ["り", "ら", "れ", "ろ", "って", "った"]),
        ]
        for (u, f) in godan {
            verb(u, VerbForms(i: f[0], a: f[1], te: f[4], ta: f[5], ba: f[2], vol: f[3] + "う", imp: [f[2]],
                              pot: [f[2] + "る"], pass: [f[1] + "れる"],
                              caus: [f[1] + "せる", f[1] + "す", f[1] + "せられる", f[1] + "される"]), .v5)
        }
        // 行く 는 て/た형이 특별
        for k in ["行", "い"] {
            r(k + "って", k + "く", [.te], .v5, "て형")
            r(k + "った", k + "く", [.ta], .v5, "과거(た)")
            r(k + "ったら", k + "く", [], .v5, "~하면(たら)")
            r(k + "ったり", k + "く", [], .v5, "~하거나(たり)")
        }
        // 1단 동사
        verb("る", VerbForms(i: "", a: "", te: "て", ta: "た", ba: "れ", vol: "よう", imp: ["ろ", "よ"],
                             pot: ["られる", "れる"], pass: ["られる"], caus: ["させる", "さす", "させられる"]), .v1)
        // する
        verb("する", VerbForms(i: "し", a: "し", te: "して", ta: "した", ba: "すれ", vol: "しよう", imp: ["しろ", "せよ"],
                               pot: ["できる"], pass: ["される"], caus: ["させる", "させられる"]), .vs)
        r("さない", "する", [.adjI], .vs, "부정(ない)")
        r("せず", "する", [], .vs, "부정(ず)")
        r("せずに", "する", [], .vs, "~하지 않고(ずに)")
        // 来る
        verb("くる", VerbForms(i: "き", a: "こ", te: "きて", ta: "きた", ba: "くれ", vol: "こよう", imp: ["こい"],
                               pot: ["こられる", "これる"], pass: ["こられる"], caus: ["こさせる"]), .vk)
        verb("来る", VerbForms(i: "来", a: "来", te: "来て", ta: "来た", ba: "来れ", vol: "来よう", imp: ["来い"],
                               pot: ["来られる", "来れる"], pass: ["来られる"], caus: ["来させる"]), .vk)

        // い형용사
        r("く", "い", [], .adjI, "부사형(く)")
        r("くて", "い", [.te], .adjI, "て형(くて)")
        r("かった", "い", [.ta], .adjI, "과거(かった)")
        r("かったら", "い", [], .adjI, "~하면(かったら)")
        r("かったり", "い", [], .adjI, "~하거나(かったり)")
        r("くない", "い", [.adjI], .adjI, "부정(くない)")
        r("くなる", "い", [.v5], .adjI, "~해지다(くなる)")
        r("くする", "い", [.vs], .adjI, "~하게 하다(くする)")
        r("ければ", "い", [], .adjI, "가정(ければ)")
        r("けりゃ", "い", [], .adjI, "가정(けりゃ)")
        r("さ", "い", [], .adjI, "명사형(さ)")
        r("そう", "い", [], .adjI, "~해 보인다(そう)")
        r("すぎる", "い", [.v1], .adjI, "너무 ~하다(すぎる)")
        r("かろう", "い", [], .adjI, "추측(かろう)")
        r("くありません", "い", [], .adjI, "정중 부정")
        r("くありませんでした", "い", [], .adjI, "정중 과거 부정")
        r("き", "い", [], .adjI, "문어체(き)")
        r("げ", "い", [], .adjI, "~한 듯(げ)")
        r("かったです", "い", [], .adjI, "정중 과거")
        r("いです", "い", [], .adjI, "정중(です)")
        r("え", "い", [], .adjI, "구어체(すげえ)")

        // て형 뒤에 붙는 보조 동사·축약 → て형으로
        let teAux: [(String, [WordType], String)] = [
            ("いる", [.v1], "~하고 있다(ている)"), ("る", [.v1], "~하고 있다(てる)"),
            ("いた", [.ta], "~하고 있었다(ていた)"), ("た", [.ta], "~하고 있었다(てた)"),
            ("います", [], "~하고 있습니다"), ("ます", [], "~하고 있습니다(てます)"),
            ("しまう", [.v5], "~해 버리다(てしまう)"), ("おく", [.v5], "~해 두다(ておく)"),
            ("ある", [.v5], "~해 있다(てある)"), ("いく", [.v5], "~해 가다(ていく)"),
            ("くる", [.vk], "~해 오다(てくる)"), ("みる", [.v1], "~해 보다(てみる)"),
            ("あげる", [.v1], "~해 주다(てあげる)"), ("くれる", [.v1], "~해 주다(てくれる)"),
            ("もらう", [.v5], "~해 받다(てもらう)"), ("ください", [], "~해 주세요(てください)"),
            ("くれ", [], "~해 줘(てくれ)"), ("ほしい", [.adjI], "~해 줬으면(てほしい)"),
            ("も", [], "~해도(ても)"), ("は", [], "~해서는(ては)"), ("いい", [], "~해도 된다"),
            ("よ", [], "~해 줘(てよ)"), ("ね", [], "~해 줘(てね)"),
        ]
        for (aux, inT, why) in teAux {
            r("て" + aux, "て", inT, .te, why)
            r("で" + aux, "で", inT, .te, why)
        }
        // 축약형
        r("ちゃう", "て", [.v5], .te, "~해 버리다(ちゃう)")
        r("じゃう", "で", [.v5], .te, "~해 버리다(じゃう)")
        r("ちまう", "て", [.v5], .te, "~해 버리다(ちまう)")
        r("ちゃ", "て", [], .te, "~하면(ちゃ)")
        r("じゃ", "で", [], .te, "~하면(じゃ)")
        r("とく", "て", [.v5], .te, "~해 두다(とく)")
        r("どく", "で", [.v5], .te, "~해 두다(どく)")
        r("とる", "て", [.v5], .te, "~하고 있다(とる)")
        return rules
    }
}
