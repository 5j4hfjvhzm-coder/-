import Foundation

/// 빈칸 문제 만들기, 보기 만들기, 정답 판정

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

/// 시드 고정 난수 (테스트 재현용, xorshift32)
func seededRandom(_ seed: UInt32) -> () -> Double {
    var s: UInt32 = seed == 0 ? 1 : seed
    return {
        s ^= s << 13
        s ^= s >> 17
        s ^= s << 5
        return Double(s) / 4_294_967_296
    }
}

func shuffled<T>(_ arr: [T], _ rand: () -> Double) -> [T] {
    var a = arr
    guard a.count > 1 else { return a }
    for i in stride(from: a.count - 1, to: 0, by: -1) {
        let j = min(i, Int(rand() * Double(i + 1)))
        a.swapAt(i, j)
    }
    return a
}

private let fallbackWords = [
    "answer", "bring", "carry", "decide", "enjoy", "follow", "happen", "imagine", "keep", "leave",
    "manage", "notice", "offer", "prepare", "realize", "suggest", "throw", "wonder", "quiet",
    "strange", "useful", "careful", "early", "simply", "figure out", "come up with", "look into",
]

/// 4지선다 보기. 정답은 빈칸에 실제로 들어갔던 모양(answer).
/// 오답은 다른 저장 단어(같은 기본형 제외) → 부족하면 기본 단어 목록. 여러 단어 정답이면 여러 단어 오답 우선.
func makeChoices(answer: String, target: BlankTarget, pool: [String], rand: () -> Double, count n: Int = 4) -> [String] {
    let own = Set(([answer, target.surface, target.lemma] + target.forms).map(norm))
    let multi = answer.trimmingCharacters(in: .whitespaces).contains(" ")
    var picks: [String] = []
    for s in distractors(pool, own, multi, rand) + distractors(fallbackWords, own, multi, rand) {
        if picks.count >= n - 1 { break }
        if !picks.contains(where: { norm($0) == norm(s) }) { picks.append(s) }
    }
    return shuffled([answer] + picks, rand)
}

private func distractors(_ list: [String], _ own: Set<String>, _ multi: Bool, _ rand: () -> Double) -> [String] {
    let items = uniqued(list.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !own.contains(norm($0)) })
    let mixed = shuffled(items, rand)
    // 정답과 단어 수 성격이 같은 것 먼저 (섞은 순서 유지)
    return mixed.filter { $0.contains(" ") == multi } + mixed.filter { $0.contains(" ") != multi }
}
