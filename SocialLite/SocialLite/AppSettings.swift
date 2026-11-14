import Foundation
import Observation

/// 사용자 설정. 바뀔 때마다 UserDefaults에 저장합니다.
@MainActor @Observable
final class AppSettings {
    /// 라이트 모드(숨기기) 설정이 바뀌면 열려 있는 탭에 바로 적용하려고 부릅니다.
    @ObservationIgnored var onLiteChange: (() -> Void)?
    @ObservationIgnored private let defaults = UserDefaults.standard

    // MARK: 탭
    private var enabledRaw: [String] { didSet { defaults.set(enabledRaw, forKey: "enabled") } }
    var startTab: Platform { didSet { defaults.set(startTab.rawValue, forKey: "startTab") } }
    var pauseOnSwitch: Bool { didSet { defaults.set(pauseOnSwitch, forKey: "pauseOnSwitch") } }
    private var startPagesRaw: [String: String] { didSet { defaults.set(startPagesRaw, forKey: "startPages") } }

    // MARK: 라이트 모드
    var hideShorts: Bool { didSet { saveLite(hideShorts, "hideShorts") } }
    var shortsAsVideo: Bool { didSet { saveLite(shortsAsVideo, "shortsAsVideo") } }
    var hideReelsTab: Bool { didSet { saveLite(hideReelsTab, "hideReelsTab") } }
    var blockReelsFeed: Bool { didSet { saveLite(blockReelsFeed, "blockReelsFeed") } }
    var hideSponsored: Bool { didSet { saveLite(hideSponsored, "hideSponsored") } }
    var hideAds: Bool { didSet { saveLite(hideAds, "hideAds") } }
    var hideAppBanners: Bool { didSet { saveLite(hideAppBanners, "hideAppBanners") } }
    var grayscale: Bool { didSet { saveLite(grayscale, "grayscale") } }

    // MARK: 사용 시간 제한 (분, 0 = 없음)
    private var limitsRaw: [String: Int] { didSet { defaults.set(limitsRaw, forKey: "limits") } }

    init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }

        let enabled = (d.stringArray(forKey: "enabled") ?? Platform.allCases.map(\.rawValue))
            .filter { Platform(rawValue: $0) != nil }
        enabledRaw = enabled.isEmpty ? Platform.allCases.map(\.rawValue) : enabled
        startTab = Platform(rawValue: d.string(forKey: "startTab") ?? "") ?? .youtube
        pauseOnSwitch = bool("pauseOnSwitch", true)
        startPagesRaw = d.dictionary(forKey: "startPages") as? [String: String] ?? [:]

        hideShorts = bool("hideShorts", false)
        shortsAsVideo = bool("shortsAsVideo", false)
        hideReelsTab = bool("hideReelsTab", false)
        blockReelsFeed = bool("blockReelsFeed", false)
        hideSponsored = bool("hideSponsored", true)
        hideAds = bool("hideAds", true)
        hideAppBanners = bool("hideAppBanners", true)
        grayscale = bool("grayscale", false)

        limitsRaw = d.dictionary(forKey: "limits") as? [String: Int] ?? [:]
    }

    private func saveLite(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
        onLiteChange?()
    }

    // MARK: 편의 접근자

    var enabledPlatforms: [Platform] {
        Platform.allCases.filter { enabledRaw.contains($0.rawValue) }
    }

    func isEnabled(_ p: Platform) -> Bool { enabledRaw.contains(p.rawValue) }

    func setEnabled(_ p: Platform, _ on: Bool) {
        if on {
            if !enabledRaw.contains(p.rawValue) { enabledRaw.append(p.rawValue) }
        } else if enabledRaw.count > 1 {
            enabledRaw.removeAll { $0 == p.rawValue }
        }
    }

    /// 처음 열 탭. 꺼져 있으면 켜진 첫 탭.
    var effectiveStartTab: Platform {
        isEnabled(startTab) ? startTab : (enabledPlatforms.first ?? .youtube)
    }

    func startPage(_ p: Platform) -> StartPage {
        StartPage(rawValue: startPagesRaw[p.rawValue] ?? "") ?? .home
    }

    func setStartPage(_ page: StartPage, for p: Platform) {
        startPagesRaw[p.rawValue] = page.rawValue
    }

    func limit(for p: Platform) -> Int { limitsRaw[p.rawValue] ?? 0 }

    func setLimit(_ minutes: Int, for p: Platform) {
        limitsRaw[p.rawValue] = max(0, minutes)
    }
}
