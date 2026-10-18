import Foundation

/// 네이버 영어사전 검색 (API 키 없음, 네이버 사전 웹이 쓰는 공개 경로). 인터넷이 없거나 막히면 nil.
actor NaverDictService {
    static let shared = NaverDictService()

    private var cache: [String: [Entry]] = [:]

    private static let hosts = ["https://en.dict.naver.com", "https://dict.naver.com"]
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// 단어·숙어 검색. 실패하면 nil (결과가 없으면 빈 배열)
    func search(_ query: String) async -> [Entry]? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        if let hit = cache[q] { return hit }
        for host in Self.hosts {
            var comps = URLComponents(string: "\(host)/api3/enko/search")!
            comps.queryItems = [
                URLQueryItem(name: "query", value: q), URLQueryItem(name: "m", value: "pc"),
                URLQueryItem(name: "range", value: "word"), URLQueryItem(name: "shouldSearchOpen", value: "false"),
            ]
            guard let url = comps.url else { continue }
            var req = URLRequest(url: url, timeoutInterval: 6)
            req.setValue("https://en.dict.naver.com/", forHTTPHeaderField: "Referer")
            req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            req.setValue("ko-KR,ko;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { continue }
            let entries = NaverDictParser.parse(data, query: q)
            // 응답은 왔는데 모양을 못 읽었으면 다음 주소로
            if entries.isEmpty, !String(decoding: data, as: UTF8.self).contains("searchResultMap") { continue }
            cache[q] = entries
            return entries
        }
        return nil
    }
}
