import SwiftUI
import UIKit
import WebKit

/// 영상 탭의 플레이어 자리 (VideoView 가 알려주면 그 위에 플레이어를 겹쳐 그린다)
struct PlayerSlotKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// 하단 탭 3개. 시스템 TabView 대신 직접 그리는 이유:
/// 플레이어(WKWebView)를 탭 바깥 한 곳에 두고 위치만 바꿔야 탭을 바꿔도 재생이 끊기지 않기 때문.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page(.video) { VideoView() }
                page(.words) { WordsView() }
                page(.quiz) { QuizView() }
            }
            TabBar()
        }
        .overlayPreferenceValue(PlayerSlotKey.self) { anchor in
            GeometryReader { proxy in
                if app.player.videoId != nil {
                    PlayerOverlay(slot: anchor.map { proxy[$0] }, container: proxy.size, safeArea: proxy.safeAreaInsets)
                }
            }
            // 전체화면이 화면 끝까지 덮을 수 있게. 다른 위치는 safeArea 로 직접 계산
            .ignoresSafeArea()
        }
        .statusBarHidden(app.player.isFullscreen)
        .persistentSystemOverlays(app.player.isFullscreen ? .hidden : .automatic)
    }

    /// 탭을 바꿔도 화면을 없애지 않는다 (상태·스크롤 유지)
    private func page<V: View>(_ tab: AppTab, @ViewBuilder _ content: () -> V) -> some View {
        let on = app.tab == tab
        return content()
            .opacity(on ? 1 : 0)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }
}

struct TabBar: View {
    static let height: CGFloat = 54
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack {
            item(.video, "영상", "play.rectangle.fill")
            item(.words, "단어장", "book.fill")
            item(.quiz, "시험", "checkmark.circle.fill")
        }
        .frame(height: Self.height)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func item(_ tab: AppTab, _ title: String, _ icon: String) -> some View {
        Button {
            app.tab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19))
                Text(title).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(app.tab == tab ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

/// 앱 전체에 하나뿐인 유튜브 플레이어. 영상 탭에서는 자기 자리에, 다른 탭에서는 오른쪽 아래 미니 플레이어.
struct PlayerOverlay: View {
    @Environment(AppModel.self) private var app
    let slot: CGRect?
    let container: CGSize
    let safeArea: EdgeInsets

    private let miniW: CGFloat = 208
    private let miniH: CGFloat = 117
    private let barH: CGFloat = 30

    var body: some View {
        let player = app.player
        let fullscreen = player.isFullscreen
        let full = fullscreen || app.tab == .video
        let hidden = !full && player.miniHidden
        let rect = frameRect(fullscreen: fullscreen, full: full)

        VStack(spacing: 0) {
            if !full {
                MiniBar()
                    .frame(height: barH)
            }
            PlayerWebView(webView: player.webView)
                .overlay(alignment: .bottom) {
                    if fullscreen || (full && player.showOnVideo) {
                        VideoSubtitleOverlay(large: fullscreen, safeArea: fullscreen ? safeArea : EdgeInsets())
                    }
                }
                .overlay(alignment: .topLeading) {
                    if fullscreen {
                        Button {
                            player.setFullscreen(false)
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.55), in: Circle())
                        }
                        .accessibilityLabel("전체화면 끝내기")
                        .padding(.leading, safeArea.leading + 12)
                        .padding(.top, safeArea.top + 12)
                    }
                }
        }
        .frame(width: rect.width, height: rect.height)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: full ? 0 : 10))
        .shadow(color: .black.opacity(full ? 0 : 0.3), radius: 8, y: 3)
        .offset(x: rect.minX, y: rect.minY)
        .opacity(hidden ? 0 : 1)
        .allowsHitTesting(!hidden)
        .animation(.easeInOut(duration: 0.22), value: full)
        .animation(.easeInOut(duration: 0.22), value: fullscreen)
    }

    /// 전체화면 → 화면 전체, 영상 탭 → VideoView 의 플레이어 자리, 다른 탭 → 오른쪽 아래 미니
    private func frameRect(fullscreen: Bool, full: Bool) -> CGRect {
        if fullscreen { return CGRect(origin: .zero, size: container) }
        if full { return slot ?? .zero }
        return CGRect(x: container.width - safeArea.trailing - miniW - 10,
                      y: container.height - safeArea.bottom - TabBar.height - 12 - miniH - barH,
                      width: miniW, height: miniH + barH)
    }
}

/// 영상 화면 안에 겹쳐 보이는 영/한 자막. 영어 단어를 탭하면 사전.
private struct VideoSubtitleOverlay: View {
    @Environment(AppModel.self) private var app
    /// 전체화면이면 글자를 크게
    var large = false
    var safeArea = EdgeInsets()

    var body: some View {
        let player = app.player
        let idx = player.currentIndex
        if idx >= 0 && idx < player.cues.count {
            let cue = player.cues[idx]
            let showEn = player.showEn && !cue.en.isEmpty
            let showKo = player.showKo && !cue.ko.isEmpty
            if showEn || showKo {
                VStack(spacing: 2) {
                    if showEn {
                        TappableText(text: cue.en, highlight: app.vocab.highlight, textColor: .white) { tap, words in
                            app.openWord(cue: cue, tap: tap, words: words)
                        }
                        .font(.system(size: large ? 22 : 15, weight: .semibold))
                        .lineLimit(3)
                    }
                    if showKo {
                        Text(cue.ko)
                            .font(.system(size: large ? 18 : 13, weight: .medium))
                            .foregroundStyle(Color.yellow)
                            .lineLimit(2)
                    }
                }
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .shadow(color: .black, radius: 1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                .padding(.leading, safeArea.leading + 10)
                .padding(.trailing, safeArea.trailing + 10)
                // 유튜브 재생 막대 위로
                .padding(.bottom, safeArea.bottom + (large ? 48 : 36))
            }
        }
    }
}

private struct MiniBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack {
            Button {
                app.player.togglePlay()
            } label: {
                Image(systemName: app.player.isPlaying ? "pause.fill" : "play.fill")
            }
            Spacer()
            Button("자막 보기") { app.tab = .video }
                .font(.caption.weight(.semibold))
            Spacer()
            Button {
                app.player.pause()
                app.player.miniHidden = true
            } label: {
                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal, 10)
        .foregroundStyle(.white)
        .background(Color(white: 0.12))
    }
}

/// 같은 WKWebView 인스턴스를 붙였다 뗐다만 한다 (다시 만들지 않음)
struct PlayerWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
