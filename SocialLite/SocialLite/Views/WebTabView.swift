import SwiftUI
import WebKit

/// 플랫폼 탭 하나: 위쪽 도구 막대 + 웹 화면.
struct WebTabView: View {
    @Environment(AppModel.self) private var model
    let tab: BrowserTab

    var body: some View {
        VStack(spacing: 0) {
            BrowserBar(tab: tab)
            ZStack {
                WebViewContainer(webView: tab.webView)
                if let message = tab.errorMessage {
                    ErrorPanel(message: message) { tab.reload() }
                }
                if model.isOverLimit(tab.platform) {
                    LimitOverlay(platform: tab.platform)
                }
            }
        }
        .onAppear { tab.loadIfNeeded() }
    }
}

struct BrowserBar: View {
    @Environment(AppModel.self) private var model
    let tab: BrowserTab

    var body: some View {
        HStack(spacing: 4) {
            barButton("chevron.left", enabled: tab.canGoBack) { tab.goBack() }
            barButton("chevron.right", enabled: tab.canGoForward) { tab.goForward() }

            Text(heading)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { tab.scrollTopOrHome() }

            barButton(tab.isLoading ? "xmark" : "arrow.clockwise", enabled: true) { tab.reloadOrStop() }
            menu
        }
        .padding(.horizontal, 6)
        .frame(height: 40)
        .background(.bar)
        .overlay(alignment: .bottom) {
            if tab.isLoading {
                ProgressView(value: max(tab.progress, 0.05))
                    .progressViewStyle(.linear)
                    .tint(tab.platform.tint)
            } else {
                Divider()
            }
        }
    }

    private var heading: String {
        if !tab.title.isEmpty { return tab.title }
        return tab.url?.host ?? tab.platform.name
    }

    private func barButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
        }
        .disabled(!enabled)
    }

    private var menu: some View {
        Menu {
            Button { tab.goHome() } label: { Label("시작 화면", systemImage: "house") }
            if let url = tab.url {
                let clean = Platform.cleanShareURL(url)
                let saved = model.bookmarks.contains(url)
                Button {
                    let added = model.bookmarks.toggle(title: tab.title, url: url)
                    model.showToast(added ? "저장했어요" : "저장을 취소했어요")
                } label: {
                    Label(saved ? "저장 취소" : "링크 저장", systemImage: saved ? "bookmark.slash" : "bookmark")
                }
                Button {
                    UIPasteboard.general.string = clean.absoluteString
                    model.showToast("링크를 복사했어요 (추적 정보 제거)")
                } label: {
                    Label("링크 복사", systemImage: "doc.on.doc")
                }
                ShareLink(item: clean) {
                    Label("공유", systemImage: "square.and.arrow.up")
                }
                Button { UIApplication.shared.open(url) } label: {
                    Label("Safari·앱에서 열기", systemImage: "safari")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 36, height: 36)
        }
    }
}

/// 만들어 둔 WKWebView를 그대로 화면에 붙여요(탭을 바꿔도 페이지가 유지됨).
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ErrorPanel: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("다시 시도", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct LimitOverlay: View {
    @Environment(AppModel.self) private var model
    let platform: Platform

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundStyle(platform.tint)
            Text("오늘 \(platform.name) 시간을 다 썼어요")
                .font(.title3.bold())
            Text("하루 \(model.settings.limit(for: platform))분 · 더보기 › 설정에서 바꿀 수 있어요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button {
                    model.select(.more)
                } label: {
                    Text("그만 볼래요").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    model.grantExtra(platform)
                } label: {
                    Text("5분만 더 보기").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .frame(maxWidth: 280)
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
