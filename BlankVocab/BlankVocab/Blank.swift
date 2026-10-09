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
        var stems = [word.w]
        // solve → solving, study → studies 처럼 끝 글자가 바뀌는 형태도 찾기
        if word.w.count > 3, let last = word.w.last, "eyEY".contains(last) {
            stems.append(String(word.w.dropLast()))
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

    /// 힌트: 첫 글자 + 나머지는 밑줄
    var hintText: String {
        guard let first = ans.first else { return "" }
        return String(first) + String(repeating: "＿", count: max(ans.count - 1, 0)) + " (\(ans.count)글자)"
    }
}
