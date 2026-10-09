import SwiftUI

@main
struct BlankVocabApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .tint(Theme.pri)
                .overlay(alignment: .bottom) {
                    if let t = store.toast {
                        Text(t)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onTapGesture { store.toast = nil }
                    }
                }
                .animation(.easeOut(duration: 0.2), value: store.toast)
        }
    }
}
