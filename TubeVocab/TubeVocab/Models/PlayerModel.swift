import Foundation
import Observation
import UIKit
import WebKit

/// 유튜브 재생 방식. 앞의 방식이 막히면 자동으로 다음 방식으로 넘어간다.
enum PlayMode: Int, CaseIterable {
    /// 우리 페이지 안에 유튜브 IFrame 플레이어
    case iframe
    /// 유튜브 임베드 페이지를 직접 열기
    case embedPage
    /// 유튜브 모바일 시청 페이지 (임베드를 막아 둔 영상도 재생됨)
    case mobilePage

    var label: String {
        switch self {
        case .iframe: return "기본 플레이어"
        case .embedPage: return "임베드 페이지"
        case .mobilePage: return "유튜브 모바일 페이지"
        }
    }

    var next: PlayMode? { PlayMode(rawValue: rawValue + 1) }
}

/// 영상·자막 상태. WKWebView 는 앱 전체에서 하나만 만들고, 화면은 위치만 바꿔서 붙인다 → 탭을 바꿔도 재생이 안 끊김.
@MainActor
@Observable
final class PlayerModel {
    private(set) var videoId: String?
    private(set) var isPlaying = false
    /// 현재 재생 시간 (재생 중 0.25초마다 갱신)
    private(set) var timeMs = 0
    private(set) var cues: [BiCue] = []
    private(set) var loading = false
    private(set) var info: String?
    private(set) var error: String?
    /// 지금 재생 방식
    private(set) var mode: PlayMode = .iframe
    /// 영상이 실제로 떴는지 (플레이어 준비 또는 재생 시간이 들어옴)
    private(set) var videoReady = false
    /// 재생 방식 안내 (방식을 바꿨을 때)
    private(set) var playInfo: String?
    var showEn = true
    /// 한국어 자막 표시. 끄면 가려 두고, 영상·자막을 두 번 탭할 때만 그 줄을 보여 준다
    var showKo = true
    /// 한국어를 끈 상태에서 두 번 탭해 펼친 줄 (다음 줄로 넘어가면 다시 가려짐)
    private(set) var revealedKoIndex: Int?
    /// 영상 화면 위에 이중자막 겹쳐 보이기
    var showOnVideo = true
    /// 앱 자체 전체화면 (가로, 이중자막 유지)
    private(set) var isFullscreen = false
    /// 다른 탭에서 미니 플레이어를 닫았는지
    var miniHidden = false

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private let bridge: PlayerBridge
    @ObservationIgnored private var rawEn: [Cue] = []
    @ObservationIgnored private var rawKo: [Cue] = []
    @ObservationIgnored private var ytCues: [BiCue] = []
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    /// 영상을 새로 띄울 때마다 1씩. 늦게 온 신호가 다른 영상에 섞이지 않게.
    @ObservationIgnored private var generation = 0
    /// 방식을 바꾼 직후에는 이전 페이지가 늦게 보낸 오류 신호를 무시한다
    @ObservationIgnored private var ignoreErrorsUntil = Date.distantPast

    /// 플레이어 페이지 출처. 유튜브는 출처(Referer)가 없으면 오류 152/153 을 내므로 앱 번들 ID 로 만든 https 주소를 준다.
    static let origin = playerOrigin

    var currentIndex: Int { findCueIndex(cues, timeMs) }

    /// 이 줄의 한국어 자막을 보여 줄지
    func showsKo(at index: Int) -> Bool {
        showKo || revealedKoIndex == index
    }

    /// 두 번 탭: 한국어를 꺼 둔 상태면 지금 줄의 한국어를 보였다/가렸다
    func toggleKoReveal() {
        guard !showKo else { return }
        let i = currentIndex
        guard i >= 0 else { return }
        revealedKoIndex = revealedKoIndex == i ? nil : i
    }

    init() {
        let bridge = PlayerBridge()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.userContentController.add(bridge, name: "nt")
        // 유튜브 페이지(임베드·모바일, iframe 포함) 안의 <video> 를 직접 읽고 조종하는 스크립트
        config.userContentController.addUserScript(
            WKUserScript(source: Self.videoControlScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        self.bridge = bridge
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // 유튜브가 앱 웹뷰를 옛 브라우저로 보고 막지 않도록 사파리와 같은 이름을 쓴다
        webView.customUserAgent = Self.safariUA
        bridge.model = self
        webView.navigationDelegate = bridge
        webView.uiDelegate = bridge
    }

    // MARK: 영상

    /// 링크/ID 로 영상 열기. startMs 가 있으면 그 시점부터.
    @discardableResult
    func open(_ input: String, startMs: Int? = nil) -> Bool {
        guard let id = parseVideoId(input) else { return false }
        miniHidden = false
        if id == videoId {
            if let startMs { seek(startMs) }
            play()
            return true
        }
        videoId = id
        timeMs = startMs ?? 0
        rawEn = []
        rawKo = []
        ytCues = []
        cues = []
        isPlaying = true
        mode = .iframe
        playInfo = nil
        loadVideo()
        loadCaptions(id)
        return true
    }

    /// 지금 방식으로 영상 띄우기
    private func loadVideo() {
        guard let id = videoId else { return }
        generation += 1
        let gen = generation
        videoReady = false
        error = nil
        ignoreErrorsUntil = Date().addingTimeInterval(1.5)
        let start = max(0, timeMs / 1000)
        webView.stopLoading()
        switch mode {
        case .iframe:
            webView.loadHTMLString(Self.playerHTML(videoId: id, startSeconds: start), baseURL: URL(string: Self.origin))
        case .embedPage:
            var comps = URLComponents(string: "https://www.youtube.com/embed/\(id)")!
            comps.queryItems = [
                URLQueryItem(name: "playsinline", value: "1"), URLQueryItem(name: "autoplay", value: "1"),
                URLQueryItem(name: "rel", value: "0"), URLQueryItem(name: "iv_load_policy", value: "3"),
                URLQueryItem(name: "start", value: String(start)), URLQueryItem(name: "enablejsapi", value: "1"),
                URLQueryItem(name: "origin", value: Self.origin), URLQueryItem(name: "widget_referrer", value: Self.origin),
            ]
            var req = URLRequest(url: comps.url!)
            req.setValue(Self.origin + "/", forHTTPHeaderField: "Referer")
            webView.load(req)
        case .mobilePage:
            webView.load(URLRequest(url: URL(string: "https://m.youtube.com/watch?v=\(id)&t=\(start)s")!))
        }
        // 정해진 시간 안에 영상이 안 뜨면 다음 방식으로
        watchdog?.cancel()
        let wait: Double = mode == .mobilePage ? 20 : 10
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, let self, self.generation == gen, !self.videoReady else { return }
            self.fallback(reason: "영상이 뜨지 않아서")
        }
    }

    /// 다음 재생 방식으로. 더 없으면 안내.
    private func fallback(reason: String, skipTo target: PlayMode? = nil) {
        guard videoId != nil else { return }
        if let next = target ?? mode.next, next.rawValue > mode.rawValue {
            mode = next
            playInfo = "\(reason) \(next.label)(으)로 다시 열었어요"
            loadVideo()
        } else {
            watchdog?.cancel()
            error = "이 영상은 앱 안에서 재생되지 않아요. 아래 \"유튜브 앱에서 열기\"를 써 주세요."
        }
    }

    /// 화면의 "다른 방식으로 재생" 버튼: 다음 방식(마지막이면 처음)으로
    func switchMode() {
        guard videoId != nil else { return }
        mode = mode.next ?? .iframe
        playInfo = "\(mode.label)(으)로 재생해요"
        loadVideo()
    }

    /// 유튜브 앱(없으면 사파리)으로 지금 시간부터 열기
    func openInYouTubeApp() {
        guard let id = videoId else { return }
        pause()
        let t = max(0, timeMs / 1000)
        // 유튜브 앱이 깔려 있으면 이 링크가 앱으로 열린다
        if let web = URL(string: "https://www.youtube.com/watch?v=\(id)&t=\(t)s") {
            UIApplication.shared.open(web)
        }
    }

    func play() {
        js(mode == .iframe ? "player && player.playVideo && player.playVideo()" : "window.__ntCmd && __ntCmd('play')")
        isPlaying = true
    }

    func pause() {
        js(mode == .iframe ? "player && player.pauseVideo && player.pauseVideo()" : "window.__ntCmd && __ntCmd('pause')")
        isPlaying = false
    }

    func setFullscreen(_ on: Bool) {
        guard on != isFullscreen else { return }
        isFullscreen = on
        ScreenOrientation.set(landscape: on)
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func seek(_ ms: Int) {
        let s = Double(max(0, ms)) / 1000
        js(mode == .iframe ? "player && player.seekTo && player.seekTo(\(s), true)" : "window.__ntCmd && __ntCmd('seek', \(s))")
        timeMs = ms
    }

    /// 대사 단위로 이동하고 재생: -1 이전 대사, 0 지금 대사 처음부터, +1 다음 대사
    func jumpLine(_ offset: Int) {
        guard !cues.isEmpty else { return }
        let i = max(0, min(cues.count - 1, max(currentIndex, 0) + offset))
        seek(cues[i].start)
        play()
    }

    private func js(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// 웹뷰가 죽었을 때 지금 영상·시간으로 다시 불러오기
    fileprivate func reloadPlayer() {
        loadVideo()
    }

    fileprivate func handle(event: String, value: Any?) {
        let number = value as? NSNumber
        switch event {
        case "ready":
            markReady()
        case "state":
            // 1 재생, 2 일시정지, 0 끝, 3 버퍼링
            switch number?.intValue {
            case 1: isPlaying = true; markReady()
            case 0, 2: isPlaying = false
            default: break
            }
        case "time":
            if let s = number?.doubleValue, s.isFinite, s >= 0 {
                timeMs = Int(s * 1000)
                markReady()
            }
        case "error", "pageError":
            guard Date() >= ignoreErrorsUntil else { return }
            if event == "pageError" {
                if !videoReady { fallback(reason: "유튜브가 재생을 막아서") }
                return
            }
            // IFrame 플레이어 오류. 101/150 은 영상 주인이 임베드를 막은 것 → 모바일 페이지로 바로
            let code = number?.intValue ?? 0
            if code == 100 {
                watchdog?.cancel()
                error = "영상을 찾을 수 없어요 (삭제되었거나 비공개)."
            } else if code == 101 || code == 150 {
                fallback(reason: "임베드가 막힌 영상이라", skipTo: .mobilePage)
            } else {
                fallback(reason: "재생 오류(\(code))가 나서")
            }
        default:
            break
        }
    }

    private func markReady() {
        guard !videoReady else { return }
        videoReady = true
        error = nil
        watchdog?.cancel()
    }

    /// 메인 프레임 이동 허락 여부 (PlayerBridge 가 부른다)
    fileprivate func allowsNavigation(to url: URL, userTapped: Bool) -> Bool {
        let host = url.host?.lowercased() ?? ""
        if url.scheme == "about" || host == URL(string: Self.origin)?.host { return true }
        guard url.scheme == "https" || url.scheme == "http" else { return false }
        let youtube = host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com")
        let google = host.hasSuffix("google.com") || host.hasSuffix("google.co.kr") || host.hasSuffix("gstatic.com")
        if youtube, let id = videoId, url.absoluteString.contains(id) { return true }
        // 유튜브 안에서 다른 곳(로고·추천 영상)을 누르면 바깥으로
        if userTapped { return false }
        return youtube || google
    }

    // MARK: 자막

    private func loadCaptions(_ id: String) {
        loadTask?.cancel()
        loading = true
        info = nil
        loadTask = Task { [weak self] in
            do {
                let r = try await CaptionService.load(videoId: id)
                guard let self, self.videoId == id, !Task.isCancelled else { return }
                self.ytCues = r.cues
                self.info = r.info
                self.loading = false
                self.recompute()
            } catch {
                guard let self, self.videoId == id, !Task.isCancelled else { return }
                self.loading = false
                self.info = error.localizedDescription
            }
        }
    }

    /// .srt / .vtt 파일. 영/한이 한 파일에 섞여 있어도 줄마다 나눈다. 파일에 없는 언어는 기존 자막 유지.
    func loadSubtitleFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let text = decodeSubtitleData(data) else {
            info = "자막 파일을 열지 못했어요"
            return
        }
        let parsed = parseSrtVtt(text)
        guard !parsed.isEmpty else {
            info = "자막 파일을 읽지 못했어요 (.srt / .vtt 만 지원)"
            return
        }
        let (en, ko) = splitBilingual(parsed)
        let baseEn = !rawEn.isEmpty ? rawEn : ytCues.filter { !$0.en.isEmpty }.map { Cue(start: $0.start, end: $0.end, text: $0.en) }
        let baseKo = !rawKo.isEmpty ? rawKo : ytCues.filter { !$0.ko.isEmpty }.map { Cue(start: $0.start, end: $0.end, text: $0.ko) }
        rawEn = en.isEmpty ? baseEn : en
        rawKo = ko.isEmpty ? baseKo : ko
        info = "파일 자막: \(url.lastPathComponent)" + (en.isEmpty ? "" : " (영어)") + (ko.isEmpty ? "" : " (한국어)")
        recompute()
    }

    private func recompute() {
        cues = rawEn.isEmpty && rawKo.isEmpty ? ytCues : alignBilingual(rawEn, rawKo)
    }

    // MARK: HTML · 스크립트

    private static let safariUA =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    private static func playerHTML(videoId: String, startSeconds: Int) -> String {
        """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}#player{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body>
        <div id="player"></div>
        <script>
        var player;
        function post(e, v) { try { window.webkit.messageHandlers.nt.postMessage({ event: e, value: v }); } catch (x) {} }
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        tag.onerror = function () { post('error', 5); };
        document.head.appendChild(tag);
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            width: '100%', height: '100%', videoId: '\(videoId)',
            playerVars: { playsinline: 1, autoplay: 1, rel: 0, iv_load_policy: 3, cc_load_policy: 0, fs: 0,
                          start: \(startSeconds), origin: '\(origin)', widget_referrer: '\(origin)' },
            events: {
              onReady: function () { post('ready', 1); player.playVideo(); },
              onStateChange: function (e) { post('state', e.data); },
              onError: function (e) { post('error', e.data); }
            }
          });
          setInterval(function () {
            if (player && player.getPlayerState && player.getPlayerState() === 1) post('time', player.getCurrentTime());
          }, 250);
        }
        </script>
        </body></html>
        """
    }

    /// 유튜브 임베드·모바일 페이지(그리고 iframe) 안에서 <video> 를 찾아 시간·상태를 앱에 알리고, 앱의 명령(재생·멈춤·이동)을 받는다.
    /// 모바일 페이지에서는 영상만 화면 가득 보이게 한다.
    private static let videoControlScript = #"""
    (function () {
      if (window.__ntInstalled) return;
      var host = location.hostname;
      var isYT = /(^|\.)youtube(-nocookie)?\.com$/.test(host);
      if (!isYT) return;
      window.__ntInstalled = true;
      var isMobile = host === 'm.youtube.com';
      function post(e, v) { try { window.webkit.messageHandlers.nt.postMessage({ event: e, value: v }); } catch (x) {} }
      function video() { return document.querySelector('video'); }
      var styled = false, readySent = false, errSent = false, lastState = -1, lastT = -1;
      function fullscreenVideo(v) {
        if (!styled) {
          styled = true;
          var st = document.createElement('style');
          st.textContent = 'html,body{overflow:hidden!important;background:#000!important}' +
            'video.nt-full{position:fixed!important;left:0!important;top:0!important;width:100vw!important;height:100vh!important;' +
            'max-width:none!important;max-height:none!important;z-index:2147483647!important;object-fit:contain!important;' +
            'background:#000!important;transform:none!important;margin:0!important}';
          (document.head || document.documentElement).appendChild(st);
        }
        if (!v.classList.contains('nt-full')) v.classList.add('nt-full');
        if (!v.controls) v.controls = true;
        v.setAttribute('playsinline', '');
        v.setAttribute('webkit-playsinline', '');
      }
      setInterval(function () {
        var v = video();
        if (v) {
          if (isMobile) fullscreenVideo(v);
          if (!readySent && v.readyState >= 1) { readySent = true; post('ready', 1); }
          var s = v.ended ? 0 : (v.paused ? 2 : 1);
          if (s !== lastState) { lastState = s; post('state', s); }
          if (!v.paused && v.currentTime !== lastT) { lastT = v.currentTime; post('time', v.currentTime); }
        }
        if (!errSent) {
          var e = document.querySelector('.ytp-error, ytm-player-error-message-renderer, .player-error-message-container');
          if (e && e.offsetParent !== null) { errSent = true; post('pageError', 1); }
        }
      }, 250);
      window.__ntCmd = function (c, a) {
        var v = video();
        if (!v) return;
        if (c === 'play') { var p = v.play(); if (p && p.catch) p.catch(function () {}); }
        else if (c === 'pause') v.pause();
        else if (c === 'seek') v.currentTime = a;
      };
    })();
    """#
}

/// 플레이어 페이지 출처: https://<번들 ID>
private let playerOrigin = "https://" + (Bundle.main.bundleIdentifier ?? "tubevocab.app").lowercased()

/// 웹뷰 → 앱 연결. WKWebView 가 강한 참조를 잡으므로 모델은 약하게 들고 있는다.
/// 모델 호출은 항상 메인 액터 Task 로 넘긴다 (어떤 스레드에서 불려도 앱이 죽지 않게).
final class PlayerBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    weak var model: PlayerModel?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
        let value = body["value"] as? NSNumber
        Task { @MainActor [weak self] in
            self?.model?.handle(event: event, value: value)
        }
    }

    /// 유튜브 iframe(하위 프레임) 안의 이동은 그대로 두고, 메인 프레임은 지금 영상 페이지만 허락.
    /// 밖으로 나가는 링크는 사파리/유튜브 앱으로 연다.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame, let url = navigationAction.request.url else { return .allow }
        let tapped = navigationAction.navigationType == .linkActivated
        let allowed = await MainActor.run { [weak self] in
            self?.model?.allowsNavigation(to: url, userTapped: tapped) ?? true
        }
        if allowed { return .allow }
        if tapped, url.scheme == "https" || url.scheme == "http" {
            await MainActor.run { UIApplication.shared.open(url) }
        }
        return .cancel
    }

    /// target=_blank / window.open (유튜브 로고, "YouTube에서 보기") → 바깥
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, url.scheme == "https" || url.scheme == "http" {
            Task { @MainActor in UIApplication.shared.open(url) }
        }
        return nil
    }

    /// 웹뷰 프로세스가 죽으면(메모리 부족 등) 빈 화면 대신 플레이어를 다시 띄운다
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Task { @MainActor [weak self] in
            self?.model?.reloadPlayer()
        }
    }
}
