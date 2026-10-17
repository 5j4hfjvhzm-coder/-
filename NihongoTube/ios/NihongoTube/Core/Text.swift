import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - 정규식 도우미

extension String {
    func replacingRegex(_ pattern: String, with template: String) -> String {
        guard let re = RegexCache.cached(pattern) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: template)
    }

    func matchesRegex(_ pattern: String) -> Bool {
        guard let re = RegexCache.cached(pattern) else { return false }
        return re.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }
}

enum RegexCache {
    private static var cache: [String: NSRegularExpression] = [:]
    private static let lock = NSLock()

    static func cached(_ pattern: String) -> NSRegularExpression? {
        lock.lock()
        defer { lock.unlock() }
        if let re = cache[pattern] { return re }
        let re = try? NSRegularExpression(pattern: pattern)
        cache[pattern] = re
        return re
    }
}

/// 순서를 지키면서 중복 제거
func uniqued<T: Hashable>(_ items: [T]) -> [T] {
    var seen = Set<T>()
    return items.filter { seen.insert($0).inserted }
}

// MARK: - 글자 종류

extension Unicode.Scalar {
    var isKana: Bool { (0x3040...0x30FF).contains(value) }
    var isKanji: Bool {
        (0x3400...0x9FFF).contains(value) || (0xF900...0xFAFF).contains(value) || value == 0x3005 // 々
    }
    var isHangul: Bool { (0xAC00...0xD7A3).contains(value) || (0x3131...0x318E).contains(value) }
}

func containsKana(_ s: String) -> Bool { s.unicodeScalars.contains { $0.isKana } }
func containsKanji(_ s: String) -> Bool { s.unicodeScalars.contains { $0.isKanji } }
func containsHangul(_ s: String) -> Bool { s.unicodeScalars.contains { $0.isHangul } }
func containsJapanese(_ s: String) -> Bool { s.unicodeScalars.contains { $0.isKana || $0.isKanji } }

/// 가타카나 → 히라가나 (ァ..ヶ)
func toHiragana(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    for u in s.unicodeScalars {
        if (0x30A1...0x30F6).contains(u.value), let h = Unicode.Scalar(u.value - 0x60) {
            out.append(h)
        } else {
            out.append(u)
        }
    }
    return String(out)
}

/// 정답 비교용: 전각/반각 통일, 공백·문장부호 제거, 히라가나로
func normalizeAnswer(_ s: String) -> String {
    let folded = s.precomposedStringWithCompatibilityMapping
    let stripped = folded.filter { ch in
        !ch.isWhitespace && !"。、！？!?.,「」『』・…".contains(ch)
    }
    return toHiragana(String(stripped))
}

/// 탭할 수 있는 글자 (일본어·영숫자)
func isWordChar(_ ch: Character) -> Bool {
    ch.unicodeScalars.contains { u in
        u.isKana || u.isKanji || u.properties.isAlphabetic || ("0"..."9").contains(Character(u)) || u.value == 0x30FC
    }
}

// MARK: - 단어 나누기

/// 탭 단위 한 조각. start 는 문장 안 글자(Character) 위치
struct Segment: Equatable {
    var text: String
    var start: Int
    var isWord: Bool
}

/// 일본어 문장을 단어 단위로 나눈다 (iOS 내장 형태소 분석). 사용할 수 없으면 글자 단위.
func segmentJapanese(_ text: String) -> [Segment] {
    let chars = Array(text)
    var out: [Segment] = []
    #if canImport(NaturalLanguage)
    let tok = NLTokenizer(unit: .word)
    tok.setLanguage(.japanese)
    tok.string = text
    var cursor = text.startIndex
    var pos = 0
    func emitGap(upTo end: String.Index) {
        guard cursor < end else { return }
        let gap = String(text[cursor..<end])
        // 형태소 분석이 건너뛴 부분(문장부호 등)은 한 글자씩
        for ch in gap {
            out.append(Segment(text: String(ch), start: pos, isWord: isWordChar(ch)))
            pos += 1
        }
        cursor = end
    }
    tok.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
        emitGap(upTo: range.lowerBound)
        let piece = String(text[range])
        out.append(Segment(text: piece, start: pos, isWord: piece.contains(where: isWordChar)))
        pos += piece.count
        cursor = range.upperBound
        return true
    }
    emitGap(upTo: text.endIndex)
    if pos == chars.count { return out }
    out = []
    #endif
    for (i, ch) in chars.enumerated() {
        out.append(Segment(text: String(ch), start: i, isWord: isWordChar(ch)))
    }
    return out
}
