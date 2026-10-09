import Foundation

/// 저장한 단어를 자막에서 하이라이트할 토큰 찾기

struct HighlightIndex: Equatable {
    var single: Set<String> = []
    /// 여러 단어 표현 (단어 배열)
    var multi: [[String]] = []
}

func buildHighlightIndex(_ items: [BlankTarget]) -> HighlightIndex {
    var idx = HighlightIndex()
    for it in items {
        for f in [it.surface, it.lemma] + it.forms {
            let n = normalizeWord(f).trimmingCharacters(in: .whitespaces)
            if n.isEmpty { continue }
            if n.contains(" ") {
                idx.multi.append(n.split(whereSeparator: { $0.isWhitespace }).map(String.init))
            } else {
                idx.single.insert(n)
            }
        }
    }
    return idx
}

/// tokens 와 같은 길이의 true/false 배열
func highlightTokens(_ tokens: [Token], _ index: HighlightIndex) -> [Bool] {
    var marks = tokens.map { $0.isWord && index.single.contains($0.norm) }
    let wordIdx = tokens.indices.filter { tokens[$0].isWord }
    for parts in index.multi where parts.count <= wordIdx.count {
        for w in 0...(wordIdx.count - parts.count)
        where parts.indices.allSatisfy({ tokens[wordIdx[w + $0]].norm == parts[$0] }) {
            for j in parts.indices { marks[wordIdx[w + j]] = true }
        }
    }
    return marks
}
