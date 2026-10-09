import Foundation

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

// MARK: - 토큰

/// 영어 문장을 단어/비단어 토큰으로 나눈다. 탭 가능한 단어 렌더링과 사전 조회에 같이 쓴다.
struct Token: Equatable {
    let text: String
    /// 단어면 소문자·아포스트로피 정규화된 값, 아니면 ""
    let norm: String
    let isWord: Bool
    let range: Range<String.Index>
}

func normalizeWord(_ w: String) -> String {
    w.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
}

private let wordPattern = "[A-Za-z0-9]+(?:['\u{2019}][A-Za-z]+)*"

func tokenize(_ text: String) -> [Token] {
    guard let re = RegexCache.cached(wordPattern) else { return [] }
    var out: [Token] = []
    var last = text.startIndex
    for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        guard let r = Range(m.range, in: text) else { continue }
        if r.lowerBound > last {
            out.append(Token(text: String(text[last..<r.lowerBound]), norm: "", isWord: false, range: last..<r.lowerBound))
        }
        let word = String(text[r])
        let isWord = word.contains { $0.isASCII && $0.isLetter }
        out.append(Token(text: word, norm: isWord ? normalizeWord(word) : "", isWord: isWord, range: r))
        last = r.upperBound
    }
    if last < text.endIndex {
        out.append(Token(text: String(text[last...]), norm: "", isWord: false, range: last..<text.endIndex))
    }
    return out
}

/// 단어 토큰만 (소문자)
func wordTokens(_ text: String) -> [String] {
    tokenize(text).filter(\.isWord).map(\.norm)
}
