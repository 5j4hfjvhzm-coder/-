import Foundation

/// 빈칸 문제 만들기, 정답 판정 (일본어)

struct BlankTarget: Equatable {
    /// 저장할 때 문장에 있던 모양 (食べました)
    var surface: String
    /// 기본형 (食べる)
    var term: String
    /// 기본형 읽기들 (たべる)
    var readings: [String]
    /// 문장 안 시작 글자 위치 (모르면 nil)
    var start: Int? = nil
}

struct BlankQuestion: Equatable {
    var before: String
    var answer: String
    var after: String
}

/// 문장에서 저장한 표현 자리를 빈칸으로. 저장할 때 위치 → 같은 모양 → 기본형 순으로 찾는다.
func makeBlank(_ sentence: String, _ target: BlankTarget) -> BlankQuestion? {
    let chars = Array(sentence)
    let surface = Array(target.surface)
    if let s = target.start, s >= 0, s + surface.count <= chars.count, Array(chars[s..<(s + surface.count)]) == surface,
       !surface.isEmpty {
        return BlankQuestion(before: String(chars[..<s]), answer: target.surface, after: String(chars[(s + surface.count)...]))
    }
    for cand in uniqued([target.surface, target.term]) where !cand.isEmpty {
        if let r = sentence.range(of: cand) {
            return BlankQuestion(before: String(sentence[..<r.lowerBound]), answer: String(sentence[r]),
                                 after: String(sentence[r.upperBound...]))
        }
    }
    return nil
}

/// 정답 판정: 문장 속 모양, 기본형, 기본형 읽기, 다른 활용형(히라가나 포함) 모두 인정
func isCorrect(_ input: String, _ target: BlankTarget, blankAnswer: String? = nil) -> Bool {
    let a = normalizeAnswer(input)
    if a.isEmpty { return false }
    var ok = Set(([target.surface, target.term, blankAnswer ?? ""] + target.readings).map(normalizeAnswer))
    ok.remove("")
    if ok.contains(a) { return true }
    for c in Deinflector.deinflect(a) where Deinflector.typeFits(c.term, c.type) {
        if ok.contains(normalizeAnswer(c.term)) { return true }
    }
    return false
}

/// 퀴즈 힌트: 첫 글자 + 나머지는 밑줄 + 글자 수. 예: "食べた" → "食＿＿ (3글자)"
func quizHintText(_ answer: String) -> String {
    let chars = Array(answer)
    guard let first = chars.first else { return "" }
    return String(first) + String(repeating: "＿", count: max(0, chars.count - 1)) + " (\(chars.count)글자)"
}
