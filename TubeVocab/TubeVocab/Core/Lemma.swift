import Foundation

/// 규칙 기반 기본형 후보. 불규칙형(went→go)은 사전 DB의 forms 표로 처리하고, 여기서는 규칙형만 만든다.

private let contractions: [String: String] = [
    "won't": "will", "can't": "can", "shan't": "shall", "ain't": "be", "i'm": "i", "let's": "let",
]

/// 긴 것부터 (정규식 `(.+?)(n't|'s|...)$` 과 같은 결과)
private let clitics = ["n't", "'re", "'ve", "'ll", "'s", "'d", "'m", "s'"]

func ruleLemmas(_ word: String) -> [String] {
    var w = normalizeWord(word)
    var out = [w]
    func add(_ s: String) {
        if s.count >= 2 && !out.contains(s) { out.append(s) }
    }
    if let c = contractions[w] {
        add(c)
        return out
    }
    if let suf = clitics.first(where: { w.hasSuffix($0) && w.count > $0.count }) {
        w = String(w.dropLast(suf.count))
        add(w)
    }
    let n = w.count
    if w.hasSuffix("ies") && n > 4 { add(String(w.dropLast(3)) + "y") }
    if w.hasSuffix("ied") && n > 4 { add(String(w.dropLast(3)) + "y") }
    if w.hasSuffix("es") && n > 3 { add(String(w.dropLast(2))) }
    if w.hasSuffix("s") && !w.hasSuffix("ss") && n > 3 { add(String(w.dropLast(1))) }
    for suf in ["ed", "ing", "er", "est"] {
        guard w.hasSuffix(suf), n >= suf.count + 2 else { continue }
        let stem = String(w.dropLast(suf.count))
        add(stem)
        add(stem + "e")
        let cs = Array(stem)
        if cs.count >= 3, cs[cs.count - 1] == cs[cs.count - 2], !"aeiou".contains(cs[cs.count - 1]) {
            add(String(stem.dropLast()))
        }
        if stem.hasSuffix("i") { add(String(stem.dropLast()) + "y") }
        if suf == "ing" && stem.hasSuffix("y") { add(String(stem.dropLast()) + "ie") }
    }
    if w.hasSuffix("ly") && n > 4 {
        add(String(w.dropLast(2)))
        if w.hasSuffix("ily") { add(String(w.dropLast(3)) + "y") }
    }
    return out
}
