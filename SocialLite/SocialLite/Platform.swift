import SwiftUI

/// 앱이 지원하는 세 플랫폼. 각 플랫폼은 공식 모바일 웹사이트를 앱 안에서 엽니다.
enum Platform: String, CaseIterable, Identifiable, Codable, Hashable {
    case youtube, tiktok, instagram

    var id: String { rawValue }

    var name: String {
        switch self {
        case .youtube: "YouTube"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        }
    }

    var symbol: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .tiktok: "music.note"
        case .instagram: "camera"
        }
    }

    var tint: Color {
        switch self {
        case .youtube: .red
        case .tiktok: .cyan
        case .instagram: .purple
        }
    }

    /// 이 탭에서 여는 주소들.
    var domains: [String] {
        switch self {
        case .youtube: ["youtube.com", "youtu.be", "youtube-nocookie.com"]
        case .tiktok: ["tiktok.com"]
        case .instagram: ["instagram.com", "instagr.am"]
        }
    }

    /// 로그인 등으로 탭 안에서 잠깐 거쳐 가도 되는 주소들.
    var supportDomains: [String] {
        switch self {
        case .youtube: ["google.com", "google.co.kr"]
        case .tiktok: ["tiktokv.com"]
        case .instagram: ["facebook.com", "fb.com", "meta.com"]
        }
    }

    /// 로그아웃(데이터 지우기) 때 지울 사이트 데이터.
    var dataDomains: [String] {
        switch self {
        case .youtube: ["youtube.com", "google.com", "google.co.kr", "googlevideo.com", "ytimg.com"]
        case .tiktok: ["tiktok.com", "tiktokv.com", "tiktokcdn.com", "ttwstatic.com", "byteoversea.com"]
        case .instagram: ["instagram.com", "cdninstagram.com", "facebook.com", "fbcdn.net"]
        }
    }

    /// 어느 플랫폼에서든 "다른 계정으로 로그인"할 때 쓰는 주소.
    static let loginHosts = [
        "accounts.google.com", "appleid.apple.com", "facebook.com",
        "accounts.kakao.com", "kauth.kakao.com", "nid.naver.com",
        "access.line.me", "x.com", "twitter.com",
    ]

    func owns(_ host: String) -> Bool {
        domains.contains { host.isHost(of: $0) }
    }

    func allowsSupport(_ host: String) -> Bool {
        supportDomains.contains { host.isHost(of: $0) }
            || Platform.loginHosts.contains { host.isHost(of: $0) }
    }

    static func matching(_ url: URL) -> Platform? {
        guard let host = url.host?.lowercased() else { return nil }
        return allCases.first { $0.owns(host) }
    }

    func startURL(_ page: StartPage) -> URL {
        let s: String
        switch (self, page) {
        case (.youtube, .home): s = "https://m.youtube.com/"
        case (.youtube, .following): s = "https://m.youtube.com/feed/subscriptions"
        case (.tiktok, .home): s = "https://www.tiktok.com/"
        case (.tiktok, .following): s = "https://www.tiktok.com/following"
        case (.instagram, .home): s = "https://www.instagram.com/"
        case (.instagram, .following): s = "https://www.instagram.com/?variant=following"
        }
        return URL(string: s)!
    }

    func label(for page: StartPage) -> String {
        switch (self, page) {
        case (.youtube, .home): "홈"
        case (.youtube, .following): "구독"
        case (.tiktok, .home): "추천"
        case (.tiktok, .following): "팔로잉"
        case (.instagram, .home): "홈"
        case (.instagram, .following): "팔로잉"
        }
    }

    /// 공유·복사할 때 붙어 있는 추적용 파라미터(si, igsh, utm_… 등)를 뺍니다.
    static func cleanShareURL(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return url }
        let tracking: Set<String> = [
            "si", "feature", "pp", "igsh", "igshid", "fbclid", "gclid",
            "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "utm_id",
            "is_from_webapp", "sender_device", "sender_web_id", "_t", "_r",
            "share_app_id", "share_link_id", "tt_from", "u_code", "timestamp",
            "user_id", "sec_user_id", "social_sharing", "share_item_id",
        ]
        let kept = items.filter { !tracking.contains($0.name.lowercased()) }
        comps.queryItems = kept.isEmpty ? nil : kept
        return comps.url ?? url
    }
}

enum StartPage: String, CaseIterable, Codable, Hashable {
    case home, following
}

enum AppTab: Hashable {
    case platform(Platform)
    case more
}

extension String {
    func isHost(of domain: String) -> Bool {
        self == domain || hasSuffix("." + domain)
    }
}

/// 짧은 시간 표시: "12분", "1시간 5분"
func formatDuration(_ seconds: Double) -> String {
    let m = Int(seconds) / 60
    if m < 60 { return "\(m)분" }
    return m % 60 == 0 ? "\(m / 60)시간" : "\(m / 60)시간 \(m % 60)분"
}
