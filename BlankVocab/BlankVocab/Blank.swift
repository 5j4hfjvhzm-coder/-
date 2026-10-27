import Foundation

/// 예문에서 단어가 들어간 자리를 찾아 빈칸 문제로 나눠요.
/// 예: "She is responsible for it." → pre "She is ", ans "responsible", post " for it."
struct Blank {
    var pre: String
    var ans: String
    var post: String

    var fullSentence: String { pre + ans + post }

    init(pre: String, ans: String, post: String) {
        self.pre = pre
        self.ans = ans
        self.post = post
    }

    init(_ word: Word) {
        let e = word.e
        // 적힌 그대로 → 괄호를 뺀 형태, "/" 등으로 나눈 각 형태 (긴 것부터) 순서로 찾아요.
        var forms = [word.w.trimmingCharacters(in: .whitespaces)]
        for f in Blank.answers(for: word.w).sorted(by: { $0.count > $1.count }) where !forms.contains(f) {
            forms.append(f)
        }
        var stems: [String] = []
        for f in forms {
            stems.append(f)
            // solve → solving, study → studies 처럼 끝 글자가 바뀌는 형태도 찾기
            if f.count > 3, let last = f.last, "eyEY".contains(last) {
                stems.append(String(f.dropLast()))
            }
        }
        for s in stems where !s.isEmpty {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: s) + "\\w*"
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = e as NSString
            if let m = re.firstMatch(in: e, range: NSRange(location: 0, length: ns.length)) {
                self.init(
                    pre: ns.substring(to: m.range.location),
                    ans: ns.substring(with: m.range),
                    post: ns.substring(from: m.range.location + m.range.length)
                )
                return
            }
        }
        self.init(pre: "", ans: word.w, post: "")
    }

    enum Grade {
        /// 문장에 들어가는 형태 그대로 맞힘
        case exact
        /// 기본형(단어장에 적힌 형태)으로 맞힘. 문장에는 다른 형태(solving 등)가 들어가요.
        case baseForm
        case wrong
    }

    /// 입력한 답을 채점해요. 대소문자, 앞뒤 공백·문장부호, 둥근 따옴표(’) 차이는 무시해요.
    func grade(_ input: String, word: Word) -> Grade {
        let v = Blank.normalize(input)
        guard !v.isEmpty else { return .wrong }
        if v == Blank.normalize(ans) { return .exact }
        if Blank.answers(for: word.w).contains(v) { return .baseForm }
        return .wrong
    }

    /// 단어장에 적힌 단어에서 정답으로 인정할 형태들.
    /// "colour / color", "look up, look into"처럼 여러 개를 적었거나 "responsible (for)"처럼 괄호가 있으면 각각 인정해요.
    static func answers(for w: String) -> Set<String> {
        var out: Set<String> = [normalize(w)]
        var noParen = w
        while let r = noParen.range(of: #"\([^)]*\)"#, options: .regularExpression) { noParen.removeSubrange(r) }
        out.insert(normalize(noParen))
        out.insert(normalize(w.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")))
        for part in noParen.split(whereSeparator: { "/,;".contains($0) }) {
            out.insert(normalize(String(part)))
        }
        out.remove("")
        return out
    }

    static func normalize(_ s: String) -> String {
        var t = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US"))
        for (from, to) in [("\u{2019}", "'"), ("\u{2018}", "'"), ("\u{02BC}", "'"), ("`", "'"), ("\u{201C}", "\""), ("\u{201D}", "\""),
                           ("\u{00A0}", " "), ("\u{2010}", "-"), ("\u{2011}", "-"), ("\u{2013}", "-"), ("\u{2014}", "-")] {
            t = t.replacingOccurrences(of: from, with: to)
        }
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,!?;:\"'()[]")))
    }

    /// 힌트: 첫 글자 + 나머지는 밑줄
    var hintText: String {
        guard let first = ans.first else { return "" }
        return String(first) + String(repeating: "＿", count: max(ans.count - 1, 0)) + " (\(ans.count)글자)"
    }
}
