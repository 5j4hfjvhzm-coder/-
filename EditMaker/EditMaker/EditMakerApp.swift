import SwiftUI

@main
struct EditMakerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("에딧 메이커") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

        Settings {
            SettingsView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            AuroraBackground()
            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 250)
                Rectangle().fill(Theme.stroke).frame(width: 1)
                VStack(spacing: 0) {
                    Group {
                        switch model.step {
                        case .materials: MaterialsView()
                        case .style: StyleView()
                        case .build: BuildView()
                        case .review: ReviewView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    StatusBar()
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.step)
        .alert("문제가 생겼어요", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("확인") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 로고
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.neonDiagonal)
                    Image(systemName: "play.fill").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)
                .shadow(color: Theme.pink.opacity(0.6), radius: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("EDIT MAKER")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.neon)
                    Text("for After Effects").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.dim)
                }
            }
            .padding(.top, 38)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)

            VStack(spacing: 6) {
                ForEach(Step.allCases) { s in
                    StepRow(step: s, current: model.step == s, enabled: isEnabled(s)) {
                        model.step = s
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                if let ae = model.selectedAE {
                    Chip(text: ae.name.replacingOccurrences(of: "Adobe ", with: ""), symbol: "checkmark.seal.fill", tint: Theme.cyan)
                } else {
                    Chip(text: "After Effects 없음", symbol: "exclamationmark.triangle.fill", tint: .orange)
                }
                if let c = AIClient.current() {
                    Chip(text: "AI 감독 · \(c.provider.name)", symbol: "sparkles", tint: Theme.pink)
                } else {
                    Chip(text: "AI 키 없음 (규칙 모드)", symbol: "sparkles", tint: .white.opacity(0.6))
                }
                Button {
                    openSettings()
                } label: {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .buttonStyle(GhostButtonStyle())
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.25))
    }

    private func isEnabled(_ s: Step) -> Bool {
        switch s {
        case .materials: return true
        case .style: return model.referenceURL != nil
        case .build: return model.isBusy || !model.log.isEmpty
        case .review: return !model.versions.isEmpty
        }
    }
}

struct StepRow: View {
    var step: Step
    var current: Bool
    var enabled: Bool
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(current ? AnyShapeStyle(Theme.neonDiagonal) : AnyShapeStyle(Color.white.opacity(0.07)))
                    Image(systemName: step.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(current ? .white : Theme.dim)
                }
                .frame(width: 32, height: 32)
                .shadow(color: current ? Theme.pink.opacity(0.6) : .clear, radius: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(step.rawValue + 1). \(step.title)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(current ? Color.white : Color.white.opacity(0.8))
                    Text(step.subtitle).font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(current ? Color.white.opacity(0.08) : (hover ? Color.white.opacity(0.04) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { hover = $0 }
    }
}

struct StatusBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            if model.isBusy {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(model.errorMessage == nil ? Theme.cyan : .orange).frame(width: 7, height: 7)
                    .shadow(color: Theme.cyan, radius: 4)
            }
            Text(model.status.isEmpty ? "준비 완료" : model.status)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            if let p = model.progress {
                ProgressView(value: p).progressViewStyle(.linear).frame(width: 180).tint(Theme.pink)
                Text("\(Int(p * 100))%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.pink)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(Color.black.opacity(0.35))
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
    }
}
