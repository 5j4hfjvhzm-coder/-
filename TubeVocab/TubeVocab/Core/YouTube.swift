import Foundation

/// 유튜브 링크 파싱 + 공개 자막 트랙(captionTracks) 선택. API 키를 쓰지 않는다.

struct CaptionTrack: Equatable {
    var baseUrl: String
    var languageCode: String
    /// "asr" = 자동생성
    var kind: String? = nil
    var name: String? = nil
    var isTranslatable: Bool? = nil
}

enum KoSource: Equatable {
    case manual
    case autoTranslate
}

struct TrackPlan: Equatable {
    var en: CaptionTrack
    /// 한국어 트랙 URL (원본 한국어 자막 또는 &tlang=ko 자동번역)
    var koUrl: String?
    var koSource: KoSource?
}

private func isVideoId(_ s: String) -> Bool {
    s.matchesRegex("^[A-Za-z0-9_-]{11}$")
}

func parseVideoId(_ input: String) -> String? {
    let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if isVideoId(s) { return s }
    let withScheme = s.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) != nil ? s : "https://\(s)"
    guard let comps = URLComponents(string: withScheme), var host = comps.host?.lowercased() else { return nil }
    if let p = ["www.", "m.", "music."].first(where: { host.hasPrefix($0) }) {
        host.removeFirst(p.count)
    }
    let parts = comps.path.split(separator: "/").map(String.init)
    var id: String?
    if host == "youtu.be" {
        id = parts.first
    } else if host == "youtube.com" || host == "youtube-nocookie.com" {
        id = comps.queryItems?.first(where: { $0.name == "v" })?.value
        if id == nil, parts.count >= 2, ["shorts", "embed", "live", "v"].contains(parts[0]) {
            id = parts[1]
        }
    }
    guard let id, isVideoId(id) else { return nil }
    return id
}

/// 페이지 HTML 안에서 `"key":` 뒤의 JSON 값(배열/객체)을 괄호 짝 맞춰 잘라내 파싱한다.
func extractJsonAfter(_ html: String, key: String) -> Any? {
    guard let r = html.range(of: "\"\(key)\":") else { return nil }
    let bytes = Array(html.utf8)
    var i = html.utf8.distance(from: html.utf8.startIndex, to: r.upperBound)
    while i < bytes.count && bytes[i] == UInt8(ascii: " ") { i += 1 }
    guard i < bytes.count else { return nil }
    let open = bytes[i]
    let close: UInt8
    switch open {
    case UInt8(ascii: "["): close = UInt8(ascii: "]")
    case UInt8(ascii: "{"): close = UInt8(ascii: "}")
    default: return nil
    }
    let quote = UInt8(ascii: "\""), backslash = UInt8(ascii: "\\")
    var depth = 0
    var inStr = false
    var j = i
    while j < bytes.count {
        let ch = bytes[j]
        if inStr {
            if ch == backslash { j += 1 } else if ch == quote { inStr = false }
        } else if ch == quote {
            inStr = true
        } else if ch == open {
            depth += 1
        } else if ch == close {
            depth -= 1
            if depth == 0 {
                return try? JSONSerialization.jsonObject(with: Data(bytes[i...j]))
            }
        }
        j += 1
    }
    return nil
}

func normalizeTracks(_ raw: Any?) -> [CaptionTrack] {
    guard let list = raw as? [[String: Any]] else { return [] }
    return list.compactMap { t in
        guard let base = t["baseUrl"] as? String, let lang = t["languageCode"] as? String else { return nil }
        var name: String?
        if let n = t["name"] as? [String: Any] {
            name = (n["simpleText"] as? String)
                ?? (n["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
        }
        return CaptionTrack(
            baseUrl: base.replacingOccurrences(of: "\\u0026", with: "&"),
            languageCode: lang,
            kind: t["kind"] as? String,
            name: name,
            isTranslatable: t["isTranslatable"] as? Bool
        )
    }
}

private func isLang(_ t: CaptionTrack, _ lang: String) -> Bool {
    t.languageCode == lang || t.languageCode.hasPrefix("\(lang)-")
}

/// 영어 트랙은 수동 > 자동생성 순, 한국어는 수동 트랙이 없으면 영어 트랙에 &tlang=ko
func planTracks(_ tracks: [CaptionTrack]) -> TrackPlan? {
    guard let en = tracks.first(where: { isLang($0, "en") && $0.kind != "asr" }) ?? tracks.first(where: { isLang($0, "en") })
    else { return nil }
    if let ko = tracks.first(where: { isLang($0, "ko") && $0.kind != "asr" }) ?? tracks.first(where: { isLang($0, "ko") }) {
        return TrackPlan(en: en, koUrl: json3Url(ko.baseUrl), koSource: .manual)
    }
    if en.isTranslatable == false { return TrackPlan(en: en, koUrl: nil, koSource: nil) }
    return TrackPlan(en: en, koUrl: json3Url(en.baseUrl, tlang: "ko"), koSource: .autoTranslate)
}

func json3Url(_ baseUrl: String, tlang: String? = nil) -> String {
    var url = baseUrl.replacingRegex("([?&])(fmt|tlang)=[^&]*", with: "$1")
    url = url.replacingRegex("[?&]+$", with: "").replacingRegex("&&+", with: "&")
    url += (url.contains("?") ? "&" : "?") + "fmt=json3"
    if let tlang { url += "&tlang=\(tlang)" }
    return url
}
