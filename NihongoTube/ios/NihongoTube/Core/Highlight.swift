import Foundation

/// 저장한 단어를 자막에서 노랗게 칠하기

struct HighlightIndex: Equatable {
    /// 찾을 모양들 (긴 것부터)
    var needles: [String] = []
}

func buildHighlightIndex(_ items: [BlankTarget]) -> HighlightIndex {
    var set = Set<String>()
    for it in items {
        if !it.surface.isEmpty { set.insert(it.surface) }
        if it.term.count >= 2 { set.insert(it.term) }
    }
    return HighlightIndex(needles: set.sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 })
}

/// 문장의 글자마다 저장 단어에 들어가는지
func highlightMarks(_ text: String, _ index: HighlightIndex) -> [Bool] {
    let chars = Array(text)
    var marks = Array(repeating: false, count: chars.count)
    for n in index.needles {
        let nc = Array(n)
        // 가나 한 글자는 너무 흔해서 칠하지 않는다
        if nc.count == 1 && !containsKanji(n) { continue }
        guard nc.count <= chars.count else { continue }
        var i = 0
        while i + nc.count <= chars.count {
            if chars[i] == nc[0] && Array(chars[i..<(i + nc.count)]) == nc {
                for k in i..<(i + nc.count) { marks[k] = true }
                i += nc.count
            } else {
                i += 1
            }
        }
    }
    return marks
}
