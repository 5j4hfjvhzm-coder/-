import Foundation
import Observation
import WebKit

struct ExternalLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// 앱 전체 상태: 탭, 링크 연결, 사용 시간 제한.
@MainActor @Observable
final class AppModel {
    let settings: AppSettings
    let usage: UsageTracker
    let bookmarks: BookmarkStore

    private(set) var selection: AppTab
    var externalLink: ExternalLink? = nil
    private(set) var toast: String? = nil

    @ObservationIgnored private var tabs: [Platform: BrowserTab] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var isActive = true

    init() {
        let s = AppSettings()
        settings = s
        usage = UsageTracker()
        bookmarks = BookmarkStore()
        selection = .platform(s.effectiveStartTab)

        for p in Platform.allCases {
            tabs[p] = BrowserTab(platform: p, settings: s, model: self)
        }
        s.onLiteChange = { [weak self] in self?.applyLite() }
        startTimer()
    }

    func tab(_ p: Platform) -> BrowserTab { tabs[p]! }

    var visiblePlatforms: [Platform] { settings.enabledPlatforms }

    // MARK: 탭 전환

    /// 탭 바에서 누를 때. 같은 탭을 다시 누르면 맨 위로 / 시작 화면으로.
    func select(_ new: AppTab) {
        if new == selection {
            if case .platform(let p) = new { tab(p).scrollTopOrHome() }
            return
        }
        if settings.pauseOnSwitch, case .platform(let old) = selection {
            tab(old).pauseMedia()
        }
        selection = new
    }

    /// 켜진 탭이 바뀌었을 때, 지금 탭이 꺼졌으면 다른 탭으로.
    func validateSelection() {
        if case .platform(let p) = selection, !settings.isEnabled(p) {
            tab(p).pauseMedia()
            selection = .platform(settings.effectiveStartTab)
        }
    }

    // MARK: 링크 열기

    func open(_ url: URL, in p: Platform) {
        guard settings.isEnabled(p) else {
            openExternal(url)
            return
        }
        select(.platform(p))
        tab(p).load(url)
    }

    func openExternal(_ url: URL) {
        let scheme = url.scheme?.lowercased()
        guard scheme == "http" || scheme == "https" else { return }
        externalLink = ExternalLink(url: url)
    }

    /// 아무 링크나: 세 플랫폼이면 해당 탭에서, 아니면 Safari 창으로.
    func openLink(_ url: URL) {
        if let p = Platform.matching(url) {
            open(url, in: p)
        } else {
            openExternal(url)
        }
    }

    /// 붙여 넣은 글에서 첫 링크를 찾아 열어요. "youtu.be/…"처럼 https가 없어도 돼요.
    @discardableResult
    func openText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           var url = match.url {
            // 앱 플랫폼 링크는 항상 https로
            if url.scheme?.lowercased() != "https", Platform.matching(url) != nil,
               var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                comps.scheme = "https"
                url = comps.url ?? url
            }
            openLink(url)
            return true
        }
        return false
    }

    /// sociallite://open?url=… , sociallite://youtube 등 외부에서 들어온 주소.
    func handleIncoming(_ url: URL) {
        guard url.scheme?.lowercased() == "sociallite" else {
            openLink(url)
            return
        }
        let host = url.host?.lowercased() ?? ""
        if host == "open",
           let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "url" })?.value {
            if !openText(value) { showToast("열 수 있는 링크가 아니에요") }
        } else if let p = Platform(rawValue: host), settings.isEnabled(p) {
            select(.platform(p))
            tab(p).loadIfNeeded()
        }
    }

    // MARK: 라이트 모드

    private func applyLite() {
        for t in tabs.values { t.installScripts() }
    }

    // MARK: 사용 시간

    func setActive(_ active: Bool) {
        isActive = active
        if !active { usage.save() }
    }

    private func startTimer() {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isActive, case .platform(let p) = selection else { return }
        guard !isOverLimit(p) else { return }
        usage.add(1, to: p)
        if isOverLimit(p) { tab(p).pauseMedia() }
    }

    func isOverLimit(_ p: Platform) -> Bool {
        let limit = settings.limit(for: p)
        guard limit > 0 else { return false }
        return usage.seconds(p) >= Double(limit * 60) + usage.extraSeconds(p)
    }

    func grantExtra(_ p: Platform) {
        usage.grantExtra(5 * 60, to: p)
    }

    // MARK: 데이터 지우기

    /// 플랫폼 하나(로그아웃) 또는 전체(nil) 사이트 데이터를 지워요.
    func clearData(for p: Platform?) async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        let targets: [WKWebsiteDataRecord]
        if let p {
            targets = records.filter { r in p.dataDomains.contains { r.displayName.lowercased().isHost(of: $0) } }
        } else {
            targets = records
        }
        await store.removeData(ofTypes: types, for: targets)
        for platform in Platform.allCases where p == nil || platform == p {
            tab(platform).goHome()
        }
        showToast(p.map { "\($0.name)에서 로그아웃했어요" } ?? "모든 사이트 데이터를 지웠어요")
    }

    // MARK: 알림 띠

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
