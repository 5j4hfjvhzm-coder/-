import Foundation

/// 유튜브 공개 자막 가져오기 (API 키 없음).
/// 1) InnerTube player 엔드포인트(안드로이드 클라이언트) 2) 시청 페이지 HTML 의 captionTracks 순서로 시도.
enum CaptionService {
    struct Result {
        var cues: [BiCue]
        /// 화면에 보여줄 출처 설명
        var info: String
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let androidVersion = "20.10.38"
    private static let androidUA = "com.google.android.youtube/\(androidVersion) (Linux; U; Android 14) gzip"
    private static let desktopUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    static func load(videoId: String) async throws -> Result {
        let sources: [(String, (String) async throws -> [CaptionTrack])] = [
            (androidUA, tracksFromInnertube),
            (desktopUA, tracksFromWatchPage),
        ]
        var sawTracks = false
        for (ua, getTracks) in sources {
            guard let tracks = try? await getTracks(videoId) else { continue }
            if !tracks.isEmpty { sawTracks = true }
            guard let plan = planTracks(tracks),
                  let jaJson = await fetchJson3(json3Url(plan.ja.baseUrl), ua: ua) else { continue }
            let isAsr = plan.ja.kind == "asr"
            let ja = isAsr ? wordsToSentences(json3ToWords(jaJson)) : json3ToCues(jaJson)
            var ko: [Cue] = []
            if let koUrl = plan.koUrl, let koJson = await fetchJson3(koUrl, ua: ua) {
                ko = json3ToCues(koJson)
            }
            var parts = [isAsr ? "일본어 자동생성 자막(문장 단위로 합침)" : "일본어 자막"]
            if ko.isEmpty {
                parts.append("한국어 자막 없음")
            } else {
                parts.append(plan.koSource == .manual ? "한국어 자막" : "한국어 자동번역")
            }
            return Result(cues: alignBilingual(ja, ko), info: parts.joined(separator: " · "))
        }
        throw Failure(message: sawTracks
            ? "일본어 자막을 받지 못했어요. \"자막 파일\"로 .srt/.vtt 를 불러와 주세요."
            : "공개 일본어 자막이 없거나 가져올 수 없어요. \"자막 파일\"로 .srt/.vtt 를 불러와 주세요.")
    }

    private static func tracksFromInnertube(_ videoId: String) async throws -> [CaptionTrack] {
        var req = URLRequest(url: URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(androidUA, forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "videoId": videoId,
            "context": ["client": [
                "clientName": "ANDROID", "clientVersion": androidVersion, "androidSdkVersion": 34, "hl": "ja", "gl": "JP",
            ]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let captions = json?["captions"] as? [String: Any]
        let renderer = captions?["playerCaptionsTracklistRenderer"] as? [String: Any]
        return normalizeTracks(renderer?["captionTracks"])
    }

    private static func tracksFromWatchPage(_ videoId: String) async throws -> [CaptionTrack] {
        var req = URLRequest(url: URL(string: "https://www.youtube.com/watch?v=\(videoId)&hl=ja")!)
        req.setValue(desktopUA, forHTTPHeaderField: "User-Agent")
        req.setValue("ja,ko;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        let (data, _) = try await URLSession.shared.data(for: req)
        let html = String(decoding: data, as: UTF8.self)
        return normalizeTracks(extractJsonAfter(html, key: "captionTracks"))
    }

    private static func fetchJson3(_ url: String, ua: String) async -> Json3? {
        guard let u = URL(string: url) else { return nil }
        var req = URLRequest(url: u)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        guard let response = try? await URLSession.shared.data(for: req) else { return nil }
        let data = response.0
        guard !data.isEmpty,
              let json = try? JSONDecoder().decode(Json3.self, from: data),
              !(json.events ?? []).isEmpty else { return nil }
        return json
    }
}

/// 자막 파일 글자 인코딩: UTF-8 → (Shift_JIS 와 CP949 중 더 그럴듯한 쪽) → UTF-16
func decodeSubtitleData(_ data: Data) -> String? {
    if let s = String(data: data, encoding: .utf8) { return s }
    let cp949 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosKorean.rawValue)))
    let sj = String(data: data, encoding: .shiftJIS)
    let kr = String(data: data, encoding: cp949)
    func ratio(_ s: String?, _ test: (Unicode.Scalar) -> Bool) -> Double {
        guard let s, !s.isEmpty else { return -1 }
        let n = s.unicodeScalars.count
        return Double(s.unicodeScalars.filter(test).count) / Double(n)
    }
    // 일본어 파일이면 가나가, 한국어 파일이면 한글이 많이 나온다
    let sjScore = ratio(sj) { $0.isKana }
    let krScore = ratio(kr) { $0.isHangul }
    if sjScore >= 0 || krScore >= 0 { return sjScore >= krScore ? sj : kr }
    return String(data: data, encoding: .utf16)
}
