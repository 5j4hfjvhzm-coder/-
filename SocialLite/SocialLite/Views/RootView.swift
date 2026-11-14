import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: Binding(get: { model.selection }, set: { model.select($0) })) {
            ForEach(model.visiblePlatforms) { p in
                WebTabView(tab: model.tab(p))
                    .tabItem { Label(p.name, systemImage: p.symbol) }
                    .tag(AppTab.platform(p))
            }
            MoreView()
                .tabItem { Label("더보기", systemImage: "square.grid.2x2") }
                .tag(AppTab.more)
        }
        .sheet(item: $model.externalLink) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4, y: 2)
                    .padding(.top, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: model.toast)
    }
}
