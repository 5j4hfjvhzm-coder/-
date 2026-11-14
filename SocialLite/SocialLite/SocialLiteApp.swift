import SwiftUI
import AVFoundation

@main
struct SocialLiteApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 무음 스위치가 켜져 있어도 동영상 소리가 나고, PIP(화면 속 화면)가 되도록.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { model.handleIncoming($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            model.setActive(phase == .active)
        }
    }
}
