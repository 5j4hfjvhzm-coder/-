import Foundation

/// 네이버 사전 검색 (비공식 API).
/// https://github.com/seia-soto/naverDict 가 쓰는 `dict.naver.com/api3/{언어}ko/search` 엔드포인트를 그대로 Swift로 옮겼다.
enum NaverDict {
    enum Lang: String, CaseIterable {
        case enko   // 영한 (한글로 찾으면 한영)
        case koko   // 국어

        var label: String {
            switch self {
            case .enko: "영한"
            case .koko: "국어"
            }
        }
        var host: String {
            switch self {
            case .enko: "en.dict.naver.com"
            case .koko: "ko.dict.naver.com"
            }
        }
    }

    struct Entry: Identifiable, Hashable {
        let id = UUID()
        var word: String
        var superscript: String?
        var phonetic: String?
        var source: String?
        var groups: [MeanGroup]
    }

    struct MeanGroup: Hashable {
        var partOfSpeech: String?
        var means: [String]
    }

    enum SearchError: LocalizedError {
        case badResponse(Int)
        case badData

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): "사전 서버 응답 오류 (\(code))"
            case .badData: "사전 결과를 읽지 못했어요."
            }
        }
    }

    static func search(_ query: String, lang: Lang) async throws -> [Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        // 언어별 도메인 → 실패하면 라이브러리와 같은 dict.naver.com 으로 한 번 더
        let hosts = [lang.host, "dict.naver.com"]
        var lastError: Error = SearchError.badData
        for host in hosts {
            do {
                return try await request(q, lang: lang, host: host)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func request(_ query: String, lang: Lang, host: String) async throws -> [Entry] {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.path = "/api3/\(lang.rawValue)/search"
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "m", value: "pc"),
            URLQueryItem(name: "range", value: "word"),
        ]
        guard let url = comps.url else { throw SearchError.badData }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("ko-KR,ko;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        req.setValue("https://\(lang.host)/", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                     forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SearchError.badResponse(http.statusCode)
        }
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> [Entry] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultMap = root["searchResultMap"] as? [String: Any],
              let listMap = resultMap["searchResultListMap"] as? [String: Any]
        else { throw SearchError.badData }

        guard let word = listMap["WORD"] as? [String: Any],
              let items = word["items"] as? [[String: Any]]
        else { return [] }

        return items.compactMap(entry(from:))
    }

    private static func entry(from item: [String: Any]) -> Entry? {
        let word = clean(item["expEntry"] as? String)
        guard !word.isEmpty else { return nil }

        let sup = clean(item["expEntrySuperscript"] as? String)

        var phonetic: String?
        if let symbols = item["searchPhoneticSymbolList"] as? [[String: Any]] {
            let parts = symbols.compactMap { s -> String? in
                let value = clean((s["symbolValue"] ?? s["phoneticSymbol"]) as? String)
                guard !value.isEmpty else { return nil }
                let type = clean(s["symbolType"] as? String)
                return type.isEmpty ? "[\(value)]" : "\(type) [\(value)]"
            }
            if !parts.isEmpty { phonetic = parts.prefix(2).joined(separator: "  ") }
        }

        var groups: [MeanGroup] = []
        if let collectors = item["meansCollector"] as? [[String: Any]] {
            for c in collectors {
                let pos = [clean(c["partOfSpeech"] as? String), clean(c["partOfSpeech2"] as? String)]
                    .first { !$0.isEmpty }
                var means: [String] = []
                if let list = c["means"] as? [[String: Any]] {
                    means = list.map { clean($0["value"] as? String) }.filter { !$0.isEmpty }
                } else {
                    // 옛 응답 형식: { value: "..." }
                    let v = clean(c["value"] as? String)
                    if !v.isEmpty { means = [v] }
                }
                if !means.isEmpty { groups.append(MeanGroup(partOfSpeech: pos, means: means)) }
            }
        }

        let source = clean(item["sourceDictnameKO"] as? String)
        return Entry(word: word,
                     superscript: sup.isEmpty ? nil : sup,
                     phonetic: phonetic,
                     source: source.isEmpty ? nil : source,
                     groups: groups)
    }

    /// HTML 태그를 지우고 엔티티를 풀어 한 줄 텍스트로 만든다.
    static func clean(_ html: String?) -> String {
        guard var s = html, !s.isEmpty else { return "" }
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let named = ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&middot;": "·"]
        for (k, v) in named { s = s.replacingOccurrences(of: k, with: v) }
        // 숫자 엔티티 (&#1234; / &#x1F600;)
        if s.contains("&#") {
            let pattern = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);")
            let ns = s as NSString
            var out = ""
            var last = 0
            for m in pattern?.matches(in: s, range: NSRange(location: 0, length: ns.length)) ?? [] {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let hex = ns.substring(with: m.range(at: 1)) == "x"
                let num = ns.substring(with: m.range(at: 2))
                if let code = UInt32(num, radix: hex ? 16 : 10), let scalar = UnicodeScalar(code) {
                    out.append(Character(scalar))
                } else {
                    out += ns.substring(with: m.range)
                }
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            s = out
        }
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
