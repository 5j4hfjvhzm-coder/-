import Foundation

/// 빈칸 문제 만들기, 정답 판정

struct BlankTarget: Equatable {
    /// 저장할 때 문장에 있던 모양 (gave up, went)
    var surface: String
    /// 기본형 (give up, go)
    var lemma: String
    /// 활용형 목록
    var forms: [String]
}

struct BlankQuestion: Equatable {
    var before: String
    var answer: String
    var after: String
    /// 빈칸 표시 (단어 수만큼 _____ )
    var display: String
}

private func norm(_ s: String) -> String {
    normalizeWord(s).replacingRegex("\\s+", with: " ").trimmingCharacters(in: .whitespaces)
}

/// 문장에서 단어를 찾아 빈칸으로 만든다.
/// 1) 저장한 모양 그대로 2) 활용형/기본형 3) 분리형(pick it up)이면 사이 목적어까지 범위로
func makeBlank(_ sentence: String, _ target: BlankTarget) -> BlankQuestion? {
    let toks = tokenize(sentence)
    let wordIdx = toks.indices.filter { toks[$0].isWord }
    let candidates = uniqued(([target.surface] + target.forms + [target.lemma]).map(norm).filter { !$0.isEmpty })

    for cand in candidates {
        let parts = cand.split(separator: " ").map(String.init)
        guard parts.count <= wordIdx.count else { continue }
        for w in 0...(wordIdx.count - parts.count) {
            let ok = parts.indices.allSatisfy { toks[wordIdx[w + $0]].norm == parts[$0] }
            if !ok { continue }
            let first = toks[wordIdx[w]], last = toks[wordIdx[w + parts.count - 1]]
            return build(sentence, first.range.lowerBound, last.range.upperBound, parts.count)
        }
    }

    let parts = norm(target.surface).split(separator: " ").map(String.init)
    if parts.count > 1 {
        for w in wordIdx.indices where toks[wordIdx[w]].norm == parts[0] {
            var k = w
            var ok = true
            for j in 1..<parts.count {
                var found = -1
                var n = k + 1
                while n <= min(wordIdx.count - 1, k + 4) {
                    if toks[wordIdx[n]].norm == parts[j] {
                        found = n
                        break
                    }
                    n += 1
                }
                if found < 0 {
                    ok = false
                    break
                }
                k = found
            }
            if ok {
                return build(sentence, toks[wordIdx[w]].range.lowerBound, toks[wordIdx[k]].range.upperBound, parts.count)
            }
        }
    }
    return nil
}

private func build(_ s: String, _ start: String.Index, _ end: String.Index, _ nWords: Int) -> BlankQuestion {
    BlankQuestion(
        before: String(s[..<start]),
        answer: String(s[start..<end]),
        after: String(s[end...]),
        display: Array(repeating: "_____", count: nWords).joined(separator: " ")
    )
}

/// 활용형·기본형 둘 다 정답 인정
func isCorrect(_ input: String, _ target: BlankTarget, blankAnswer: String? = nil) -> Bool {
    let a = norm(input)
    if a.isEmpty { return false }
    var accepted = Set(([target.surface, target.lemma] + target.forms + [blankAnswer ?? ""]).map(norm))
    accepted.remove("")
    return accepted.contains(a)
}

func firstLetterHint(_ answer: String) -> String {
    var atStart = true
    return String(answer.map { ch -> Character in
        if ch.isWhitespace {
            atStart = true
            return ch
        }
        if atStart {
            atStart = false
            return ch
        }
        return "_"
    })
}

/// 퀴즈 힌트: 첫 글자 + 나머지는 밑줄 + 글자 수 (예전 빈칸 단어장과 같은 모양)
/// 예: "went" → "w＿＿＿ (4글자)", "gave up" → "g＿＿＿ u＿ (6글자)"
func quizHintText(_ answer: String) -> String {
    let letters = answer.filter { !$0.isWhitespace }.count
    return firstLetterHint(answer).replacingOccurrences(of: "_", with: "＿") + " (\(letters)글자)"
}
