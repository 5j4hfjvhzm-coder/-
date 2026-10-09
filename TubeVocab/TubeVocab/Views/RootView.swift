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
                    PlayerOverlay(slot: anchor.map { proxy[$0] }, container: proxy.size)
                }
            }
        }
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

    private let miniW: CGFloat = 208
    private let miniH: CGFloat = 117
    private let barH: CGFloat = 30

    var body: some View {
        let player = app.player
        let full = app.tab == .video
        let hidden = !full && player.miniHidden
        let rect = full
            ? (slot ?? .zero)
            : CGRect(x: container.width - miniW - 10,
                     y: container.height - TabBar.height - 12 - miniH - barH,
                     width: miniW, height: miniH + barH)

        VStack(spacing: 0) {
            if !full {
                MiniBar()
                    .frame(height: barH)
            }
            PlayerWebView(webView: player.webView)
        }
        .frame(width: rect.width, height: rect.height)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: full ? 0 : 10))
        .shadow(color: .black.opacity(full ? 0 : 0.3), radius: 8, y: 3)
        .offset(x: rect.minX, y: rect.minY)
        .opacity(hidden ? 0 : 1)
        .allowsHitTesting(!hidden)
        .animation(.easeInOut(duration: 0.22), value: full)
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
