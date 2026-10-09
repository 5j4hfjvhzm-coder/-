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
                  let enJson = await fetchJson3(json3Url(plan.en.baseUrl), ua: ua) else { continue }
            let isAsr = plan.en.kind == "asr"
            let en = isAsr ? wordsToSentences(json3ToWords(enJson)) : mergeLinesToSentences(json3ToCues(enJson))
            var ko: [Cue] = []
            if let koUrl = plan.koUrl, let koJson = await fetchJson3(koUrl, ua: ua) {
                ko = json3ToCues(koJson)
            }
            var parts = [isAsr ? "영어 자동생성 자막(문장 단위로 합침)" : "영어 자막"]
            if ko.isEmpty {
                parts.append("한국어 자막 없음")
            } else {
                parts.append(plan.koSource == .manual ? "한국어 자막" : "한국어 자동번역")
            }
            return Result(cues: alignBilingual(en, ko), info: parts.joined(separator: " · "))
        }
        throw Failure(message: sawTracks
            ? "영어 자막을 받지 못했어요. \"자막 파일\"로 .srt/.vtt 를 불러와 주세요."
            : "공개 영어 자막이 없거나 가져올 수 없어요. \"자막 파일\"로 .srt/.vtt 를 불러와 주세요.")
    }

    private static func tracksFromInnertube(_ videoId: String) async throws -> [CaptionTrack] {
        var req = URLRequest(url: URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(androidUA, forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "videoId": videoId,
            "context": ["client": [
                "clientName": "ANDROID", "clientVersion": androidVersion, "androidSdkVersion": 34, "hl": "en", "gl": "US",
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
        var req = URLRequest(url: URL(string: "https://www.youtube.com/watch?v=\(videoId)&hl=en")!)
        req.setValue(desktopUA, forHTTPHeaderField: "User-Agent")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
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

/// 자막 파일 글자 인코딩: UTF-8 → CP949(EUC-KR) → UTF-16
func decodeSubtitleData(_ data: Data) -> String? {
    if let s = String(data: data, encoding: .utf8) { return s }
    let cp949 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosKorean.rawValue)))
    if let s = String(data: data, encoding: cp949) { return s }
    return String(data: data, encoding: .utf16)
}
