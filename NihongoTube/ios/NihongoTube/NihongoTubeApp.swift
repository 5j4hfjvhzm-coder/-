import SwiftUI
import UIKit

@main
struct NihongoTubeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
    }
}

/// 아이폰: 평소에는 세로 고정, 영상 전체화면일 때만 가로.
/// 아이패드: 어느 방향이든 (화면 분할·Stage Manager 도 됨)
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : Self.orientationLock
    }
}

enum ScreenOrientation {
    @MainActor
    static func set(landscape: Bool) {
        // 맥·아이패드에서는 화면을 돌리지 않고 창 안을 꽉 채운다
        if ProcessInfo.processInfo.isMacCatalystApp || ProcessInfo.processInfo.isiOSAppOnMac { return }
        if UIDevice.current.userInterfaceIdiom == .pad { return }
        #if !targetEnvironment(macCatalyst)
        AppDelegate.orientationLock = landscape ? .landscape : .portrait
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        let mask: UIInterfaceOrientationMask = landscape ? .landscapeRight : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            print("화면 회전 실패: \(error)")
        }
        #endif
    }
}
