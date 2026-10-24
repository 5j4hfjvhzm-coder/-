import SwiftUI

struct BuildView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 20)
            BuildOrb(progress: model.progress, active: model.isBusy)
                .frame(width: 220, height: 220)

            VStack(spacing: 8) {
                Text(model.isBusy ? "만드는 중" : (model.errorMessage == nil ? "대기 중" : "멈췄어요"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.neon)
                Text(model.status)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            GlassCard(padding: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(model.log.enumerated()), id: \.offset) { i, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(line.contains("❌") ? Color.orange : (line.contains("⚠️") ? Color.yellow : Color.white.opacity(0.75)))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: model.log.count) { _, n in
                        withAnimation { proxy.scrollTo(n - 1, anchor: .bottom) }
                    }
                }
            }
            .frame(maxWidth: 720, maxHeight: 220)

            if !model.isBusy {
                HStack(spacing: 12) {
                    Button("스타일로 돌아가기") { model.step = .style }.buttonStyle(GhostButtonStyle())
                    if model.errorMessage != nil || model.versions.isEmpty {
                        Button { model.generate() } label: { Label("다시 시도", systemImage: "arrow.clockwise") }
                            .buttonStyle(NeonButtonStyle())
                            .disabled(!model.canGenerate)
                    }
                }
            }
            Spacer(minLength: 20)
        }
        .padding(30)
    }
}

/// 빙글 도는 네온 링
struct BuildOrb: View {
    var progress: Double?
    var active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.pink.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 120))
                    .scaleEffect(active ? 1 + 0.06 * sin(t * 2.4) : 1)
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 10)
                if let progress {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Theme.neonDiagonal, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Theme.pink, radius: 12)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                } else {
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(Theme.neonDiagonal, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(active ? t * 220 : 0))
                        .shadow(color: Theme.pink, radius: 12)
                    Circle()
                        .trim(from: 0, to: 0.12)
                        .stroke(Theme.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(22)
                        .rotationEffect(.degrees(active ? -t * 300 : 0))
                    Image(systemName: active ? "wand.and.stars" : "moon.zzz.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Theme.neon)
                }
            }
        }
    }
}
