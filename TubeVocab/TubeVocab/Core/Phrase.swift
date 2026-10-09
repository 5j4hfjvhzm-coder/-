import Foundation

/// 숙어·구동사 매칭.
/// - 각 문장 토큰은 기본형 후보 집합을 가진다 (gave → give)
/// - 분리형 구동사: 불변화사(up/off/...) 앞에 목적어 1~3단어를 끼워도 된다 (pick it up → pick up)
/// - 사전 표제어의 someone/something 은 1~3단어, one's 는 소유격 1단어와 맞는다

let particles: Set<String> = [
    "up", "down", "out", "off", "in", "on", "away", "back", "over", "through",
    "around", "about", "along", "apart", "aside", "by", "forward", "together",
]

/// scripts/build_dict.py 의 PLACEHOLDERS 와 같게 유지
private let placeholders: Set<String> = ["someone", "somebody", "something", "sb", "sth", "one"]
private let possessivePlaceholders: Set<String> = ["one's", "someone's", "somebody's", "oneself"]
private let possessives: Set<String> = ["my", "your", "his", "her", "its", "our", "their"]
private let reflexives: Set<String> = [
    "myself", "yourself", "himself", "herself", "itself", "ourselves", "yourselves", "themselves",
]

struct PhraseMatch: Equatable, Hashable {
    var phrase: String
    /// 문장에서 매칭된 첫/끝 토큰 (포함)
    var start: Int
    var end: Int
    /// 표제어의 실제 단어와 맞은 토큰 인덱스
    var literal: [Int]
    /// 사이에 끼어든 단어가 있었는지
    var gapped: Bool
}

func phraseFirstToken(_ phrase: String) -> String? {
    for t in phrase.lowercased().split(separator: " ").map(String.init)
    where !placeholders.contains(t) && !possessivePlaceholders.contains(t) {
        return t
    }
    return nil
}

/// - Parameters:
///   - tokens: 문장 단어(소문자)
///   - lemmas: tokens[i] 의 기본형 후보 (tokens[i] 자신 포함)
///   - tap: 탭한 단어 인덱스
///   - phrases: 후보 표제어 (여러 단어)
func matchPhrases(tokens: [String], lemmas: [[String]], tap: Int, phrases: [String], maxSpan: Int = 7) -> [PhraseMatch] {
    var results: [PhraseMatch] = []
    var seen = Set<String>()
    let lo = max(0, tap - maxSpan + 1)
    guard tap >= 0, tap < tokens.count else { return [] }
    for phrase in phrases {
        let pat = normalizeWord(phrase).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if pat.count < 2 { continue }
        let key = phrase.lowercased()
        if seen.contains(key) { continue }
        for s in lo...tap {
            guard let m = matchAt(pat, tokens, lemmas, s) else { continue }
            if m.end - s + 1 > maxSpan || !m.literal.contains(tap) { continue }
            seen.insert(key)
            results.append(PhraseMatch(phrase: phrase, start: s, end: m.end, literal: m.literal, gapped: m.gapped))
            break
        }
    }
    // 실제 단어가 많이 맞은 것, 끼어든 단어 없는 것 우선
    return results.enumerated().sorted { a, b in
        let x = a.element, y = b.element
        if x.literal.count != y.literal.count { return x.literal.count > y.literal.count }
        if x.gapped != y.gapped { return !x.gapped }
        if x.start != y.start { return x.start < y.start }
        return a.offset < b.offset
    }.map(\.element)
}

private func matchAt(_ pat: [String], _ tokens: [String], _ lemmas: [[String]], _ start: Int)
    -> (end: Int, literal: [Int], gapped: Bool)? {
    var literal: [Int] = []
    var gapped = false

    func matches(_ p: String, _ k: Int) -> Bool {
        tokens[k] == p || (k < lemmas.count && lemmas[k].contains(p))
    }

    func rec(_ j: Int, _ k: Int) -> Int? {
        if j == pat.count { return k - 1 }
        let p = pat[j]
        if possessivePlaceholders.contains(p) {
            guard k < tokens.count else { return nil }
            let t = tokens[k]
            if possessives.contains(t) || reflexives.contains(t) || t.hasSuffix("'s") { return rec(j + 1, k + 1) }
            return nil
        }
        if placeholders.contains(p) {
            if j == 0 { return nil } // 자리표시자로 시작하는 표현은 건너뜀
            var n = 1
            while n <= 3 && k + n <= tokens.count {
                if let r = rec(j + 1, k + n) { return r }
                n += 1
            }
            return nil
        }
        if k < tokens.count && matches(p, k) {
            literal.append(k)
            if let r = rec(j + 1, k + 1) { return r }
            literal.removeLast()
        }
        // 분리형 구동사: 동사 다음, 불변화사 앞에 목적어 1~3단어
        if j > 0 && particles.contains(p) && !gapped {
            var n = 1
            while n <= 3 && k + n < tokens.count {
                if matches(p, k + n) {
                    gapped = true
                    literal.append(k + n)
                    if let r = rec(j + 1, k + n + 1) { return r }
                    literal.removeLast()
                    gapped = false
                }
                n += 1
            }
        }
        return nil
    }

    guard start < tokens.count, matches(pat[0], start), let end = rec(0, start) else { return nil }
    return (end, literal, gapped)
}
