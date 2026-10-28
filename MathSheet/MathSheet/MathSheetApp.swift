import Combine
import SwiftUI

@main
struct MathSheetApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                // 앱을 다시 열거나 자정이 지나면 새 학습지를 만들어요.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                    store.refresh()
                }
        }
    }
}
