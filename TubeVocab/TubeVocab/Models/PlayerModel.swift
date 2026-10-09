import Foundation
import Observation
import WebKit

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
    var showEn = true
    var showKo = true
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

    /// loadHTMLString 의 baseURL. 유튜브 임베드는 Referer 가 없으면 오류(152/153)를 내므로 https 출처를 준다.
    static let origin = "https://tubevocab.app"

    var currentIndex: Int { findCueIndex(cues, timeMs) }

    init() {
        let bridge = PlayerBridge()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(bridge, name: "yt")
        self.bridge = bridge
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        bridge.model = self
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
        webView.loadHTMLString(Self.playerHTML(videoId: id, startSeconds: (startMs ?? 0) / 1000), baseURL: URL(string: Self.origin))
        loadCaptions(id)
        return true
    }

    func play() {
        js("player && player.playVideo && player.playVideo()")
        isPlaying = true
    }

    func pause() {
        js("player && player.pauseVideo && player.pauseVideo()")
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
        js("player && player.seekTo && player.seekTo(\(Double(max(0, ms)) / 1000), true)")
        timeMs = ms
    }

    private func js(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    fileprivate func handle(event: String, value: Any?) {
        switch event {
        case "state":
            // 1 재생, 2 일시정지, 0 끝, 3 버퍼링
            switch value as? Int {
            case 1: isPlaying = true
            case 0, 2: isPlaying = false
            default: break
            }
        case "time":
            if let s = value as? Double { timeMs = Int(s * 1000) }
        case "error":
            let code = value as? Int ?? 0
            error = (code == 101 || code == 150 || code == 152 || code == 153)
                ? "이 영상은 앱 안에서 재생할 수 없어요 (오류 \(code))."
                : "재생 오류 (\(code))"
        default:
            break
        }
    }

    // MARK: 자막

    private func loadCaptions(_ id: String) {
        loadTask?.cancel()
        loading = true
        info = nil
        error = nil
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
                self.error = error.localizedDescription
            }
        }
    }

    /// .srt / .vtt 파일. 영/한이 한 파일에 섞여 있어도 줄마다 나눈다. 파일에 없는 언어는 기존 자막 유지.
    func loadSubtitleFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let text = decodeSubtitleData(data) else {
            error = "자막 파일을 열지 못했어요"
            return
        }
        let parsed = parseSrtVtt(text)
        guard !parsed.isEmpty else {
            error = "자막 파일을 읽지 못했어요 (.srt / .vtt 만 지원)"
            return
        }
        let (en, ko) = splitBilingual(parsed)
        let baseEn = !rawEn.isEmpty ? rawEn : ytCues.filter { !$0.en.isEmpty }.map { Cue(start: $0.start, end: $0.end, text: $0.en) }
        let baseKo = !rawKo.isEmpty ? rawKo : ytCues.filter { !$0.ko.isEmpty }.map { Cue(start: $0.start, end: $0.end, text: $0.ko) }
        rawEn = en.isEmpty ? baseEn : en
        rawKo = ko.isEmpty ? baseKo : ko
        error = nil
        info = "파일 자막: \(url.lastPathComponent)" + (en.isEmpty ? "" : " (영어)") + (ko.isEmpty ? "" : " (한국어)")
        recompute()
    }

    private func recompute() {
        cues = rawEn.isEmpty && rawKo.isEmpty ? ytCues : alignBilingual(rawEn, rawKo)
    }

    // MARK: HTML

    private static func playerHTML(videoId: String, startSeconds: Int) -> String {
        """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}#player{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body>
        <div id="player"></div>
        <script>
        var player;
        function post(e, v) { window.webkit.messageHandlers.yt.postMessage({ event: e, value: v }); }
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        document.head.appendChild(tag);
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            width: '100%', height: '100%', videoId: '\(videoId)',
            playerVars: { playsinline: 1, autoplay: 1, rel: 0, iv_load_policy: 3, cc_load_policy: 0, fs: 0,
                          start: \(startSeconds), origin: '\(origin)' },
            events: {
              onReady: function () { post('ready', 0); player.playVideo(); },
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
}

/// WKScriptMessageHandler 가 강한 참조를 잡으므로 모델은 약하게 들고 있는다.
final class PlayerBridge: NSObject, WKScriptMessageHandler {
    weak var model: PlayerModel?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
        let value = body["value"]
        MainActor.assumeIsolated {
            model?.handle(event: event, value: value)
        }
    }
}
