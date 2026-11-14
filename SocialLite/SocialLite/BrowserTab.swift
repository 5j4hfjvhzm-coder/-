import UIKit
import WebKit
import Observation

/// 플랫폼 하나의 웹 화면(WKWebView)과 그 상태.
@MainActor @Observable
final class BrowserTab {
    let platform: Platform
    let webView: WKWebView

    var title = ""
    var url: URL? = nil
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var progress = 0.0
    var errorMessage: String? = nil

    @ObservationIgnored weak var model: AppModel?
    private let settings: AppSettings
    private let delegate: WebDelegate
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var hasLoaded = false

    init(platform: Platform, settings: AppSettings, model: AppModel) {
        self.platform = platform
        self.settings = settings
        self.model = model
        self.delegate = WebDelegate()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // 로그인 유지
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Safari와 같은 모바일 화면을 받도록 Safari 이름을 붙여요.
        let major = UIDevice.current.systemVersion.split(separator: ".").first.map(String.init) ?? "17"
        config.applicationNameForUserAgent = "Version/\(major).0 Mobile/15E148 Safari/604.1"

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = .systemBackground
        #if DEBUG
        wv.isInspectable = true
        #endif

        let refresh = UIRefreshControl()
        refresh.addAction(UIAction { [weak wv, weak refresh] _ in
            wv?.reload()
            refresh?.endRefreshing()
        }, for: .valueChanged)
        wv.scrollView.refreshControl = refresh
        webView = wv

        delegate.tab = self
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate

        installScripts()
        observe()
    }

    // MARK: 상태 동기화

    private func observe() {
        func watch<V>(_ kp: KeyPath<WKWebView, V>) -> NSKeyValueObservation {
            webView.observe(kp, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.sync() }
            }
        }
        observations = [
            watch(\.title), watch(\.url), watch(\.canGoBack), watch(\.canGoForward),
            watch(\.isLoading), watch(\.estimatedProgress),
        ]
    }

    private func sync() {
        title = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        let current = webView.url
        if current != url {
            url = current
            if let current { enforceRulesAfterChange(current) }
        }
    }

    // MARK: 동작

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        goHome()
    }

    func load(_ url: URL) {
        hasLoaded = true
        errorMessage = nil
        webView.load(URLRequest(url: rewrite(url) ?? url))
    }

    func goHome() {
        load(platform.startURL(settings.startPage(platform)))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    func reloadOrStop() {
        if webView.isLoading { webView.stopLoading() } else { reload() }
    }

    func reload() {
        errorMessage = nil
        if webView.url == nil { goHome() } else { webView.reload() }
    }

    /// 탭을 다시 누르면: 스크롤돼 있으면 맨 위로, 이미 맨 위면 시작 화면으로.
    func scrollTopOrHome() {
        let sv = webView.scrollView
        let top = -sv.adjustedContentInset.top
        if sv.contentOffset.y > top + 10 {
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: top), animated: true)
        } else {
            goHome()
        }
    }

    func pauseMedia() {
        webView.pauseAllMediaPlayback(completionHandler: nil)
    }

    /// 라이트 모드 설정을 다음에 열 페이지와 지금 페이지 모두에 적용.
    func installScripts() {
        let css = LiteScripts.css(for: platform, settings: settings)
        let sponsored = LiteScripts.hidesSponsored(platform, settings: settings)
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(
            source: LiteScripts.bootstrap(css: css, sponsored: sponsored),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        if hasLoaded {
            webView.evaluateJavaScript(LiteScripts.bootstrap(css: css, sponsored: sponsored), completionHandler: nil)
        }
    }

    // MARK: 주소 규칙

    /// 쇼츠 → 일반 영상 주소로 바꾸기.
    private func rewrite(_ url: URL) -> URL? {
        guard platform == .youtube, settings.shortsAsVideo,
              let host = url.host?.lowercased(), platform.owns(host) else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count >= 2, parts[0] == "shorts" else { return nil }
        return URL(string: "https://m.youtube.com/watch?v=\(parts[1])")
    }

    /// 릴스 피드(/reels/…) 막기. 공유받은 릴스(/reel/…)는 열려요.
    private func isBlocked(_ url: URL) -> Bool {
        platform == .instagram && settings.blockReelsFeed
            && (url.path == "/reels" || url.path.hasPrefix("/reels/"))
    }

    /// 사이트가 페이지 이동 없이 주소만 바꾸는 경우(SPA)에도 규칙 적용.
    private func enforceRulesAfterChange(_ url: URL) {
        if let target = rewrite(url) {
            webView.evaluateJavaScript("location.replace(\(LiteScripts.js(target.absoluteString)))", completionHandler: nil)
        } else if isBlocked(url) {
            model?.showToast("릴스 피드는 꺼 두었어요 (설정에서 바꿀 수 있어요)")
            if webView.canGoBack { webView.goBack() } else { goHome() }
        }
    }

    /// 페이지 이동을 허락할지 정합니다.
    func policy(for action: WKNavigationAction) -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .allow }
        let scheme = url.scheme?.lowercased() ?? ""

        if ["about", "blob", "data", "javascript"].contains(scheme) { return .allow }
        if ["mailto", "tel", "sms"].contains(scheme) {
            UIApplication.shared.open(url)
            return .cancel
        }
        // youtube://, instagram:// 같은 "앱으로 열기"는 막고 여기서 계속 봐요.
        guard scheme == "http" || scheme == "https" else { return .cancel }

        // iframe(동영상 플레이어, 로그인 위젯 등)은 그대로 둬요.
        guard action.targetFrame?.isMainFrame ?? true else { return .allow }
        guard let host = url.host?.lowercased() else { return .allow }

        if platform.owns(host) {
            if let target = rewrite(url) {
                load(target)
                return .cancel
            }
            if isBlocked(url) {
                model?.showToast("릴스 피드는 꺼 두었어요 (설정에서 바꿀 수 있어요)")
                return .cancel
            }
            return .allow
        }
        if let other = Platform.matching(url) {
            model?.open(url, in: other)
            return .cancel
        }
        if platform.allowsSupport(host) { return .allow }

        model?.openExternal(url)
        return .cancel
    }

    /// target=_blank / window.open 링크.
    func openPopup(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https", let host = url.host?.lowercased() else { return }
        if platform.owns(host) || platform.allowsSupport(host) {
            load(url)
        } else if let other = Platform.matching(url) {
            model?.open(url, in: other)
        } else {
            model?.openExternal(url)
        }
    }

    func didFail(_ error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return } // 이동 중단(정상)
        errorMessage = ns.domain == NSURLErrorDomain && ns.code == NSURLErrorNotConnectedToInternet
            ? "인터넷에 연결되어 있지 않아요."
            : "페이지를 열지 못했어요.\n\(ns.localizedDescription)"
    }

    func didCommit() { errorMessage = nil }
}

/// WKWebView 이벤트를 BrowserTab으로 넘겨 줍니다.
@MainActor
final class WebDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var tab: BrowserTab?

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        tab?.policy(for: navigationAction) ?? .allow
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        tab?.didCommit()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        tab?.didFail(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { tab?.openPopup(url) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        _ = await Self.present(message: message, cancellable: false)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await Self.present(message: message, cancellable: true)
    }

    private static func present(message: String, cancellable: Bool) async -> Bool {
        guard let presenter = topViewController() else { return false }
        return await withCheckedContinuation { cont in
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            if cancellable {
                alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in cont.resume(returning: false) })
            }
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in cont.resume(returning: true) })
            presenter.present(alert, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let next = vc?.presentedViewController { vc = next }
        return vc
    }
}
