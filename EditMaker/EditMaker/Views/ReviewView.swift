import AVKit
import SwiftUI

/// 영상 검토 + 수정 요청 화면
struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var player = PlayerBox()
    @State private var selection: TimelineSelection?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                versionBar
                HStack(alignment: .top, spacing: 16) {
                    preview
                    if let draft = model.draft {
                        Inspector(selection: $selection, plan: Binding(get: { model.draft ?? draft }, set: { model.draft = $0 }),
                                  clips: model.clips)
                            .frame(width: 290)
                    }
                }
                if let draft = model.draft {
                    TimelineStrip(plan: draft, current: player.time, selection: $selection) { t in player.seek(t) }
                        .frame(height: 118)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)

            Rectangle().fill(Theme.stroke).frame(width: 1)
            ChatPanel()
                .frame(width: 340)
        }
        .onAppear { player.load(model.currentVersion?.renderURL) }
        .onChange(of: model.currentVersionID) { _, _ in
            player.load(model.currentVersion?.renderURL)
            selection = nil
        }
    }

    // MARK: 버전 바

    private var versionBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.versions) { v in
                        let on = v.id == model.currentVersionID
                        Button { model.select(v) } label: {
                            HStack(spacing: 6) {
                                Text("v\(v.number)").font(.system(size: 12, weight: .black, design: .rounded))
                                Text(v.note).font(.system(size: 11)).lineLimit(1).frame(maxWidth: 140)
                                    .foregroundStyle(on ? .white.opacity(0.9) : Theme.dim)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(on ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Color.white.opacity(0.07)), in: Capsule())
                            .shadow(color: on ? Theme.pink.opacity(0.5) : .clear, radius: 8)
                        }
                        .buttonStyle(.plain)
                        .help(v.note)
                    }
                }
            }
            Spacer()
            if let v = model.currentVersion {
                Button { model.openInAE(v) } label: { Label("AE에서 열기", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(GhostButtonStyle())
                Button { model.reveal(v) } label: { Label("Finder", systemImage: "folder") }
                    .buttonStyle(GhostButtonStyle())
            }
            Button { model.generate(reshuffle: true) } label: { Label("새로 섞기", systemImage: "shuffle") }
                .buttonStyle(GhostButtonStyle())
                .disabled(model.isBusy)
                .help("클립 배치와 효과를 새로 뽑아서 다시 만들어요")
        }
    }

    // MARK: 미리보기

    private var preview: some View {
        let plan = model.draft
        let ratio = plan.map { CGFloat($0.width) / CGFloat($0.height) } ?? (9 / 16)
        return ZStack {
            if model.currentVersion?.renderURL != nil {
                VideoPlayer(player: player.player)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack").font(.system(size: 40)).foregroundStyle(Theme.neon)
                    Text("미리보기 렌더를 끈 상태예요").font(.system(size: 13, weight: .bold))
                    Text("After Effects에서 열어서 확인하세요").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                    if let v = model.currentVersion {
                        Button("AE에서 열기") { model.openInAE(v) }.buttonStyle(NeonButtonStyle())
                    }
                }
            }
            if model.isBusy {
                ZStack {
                    Color.black.opacity(0.55)
                    VStack(spacing: 10) {
                        BuildOrb(progress: model.progress, active: true).frame(width: 110, height: 110)
                        Text(model.status).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center).padding(.horizontal)
                    }
                }
            }
        }
        .aspectRatio(ratio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.neonDiagonal.opacity(0.6), lineWidth: 1.2))
        .shadow(color: Theme.purple.opacity(0.35), radius: 30)
    }
}

@MainActor
final class PlayerBox: ObservableObject {
    let player = AVPlayer()
    @Published var time: Double = 0
    private var observer: Any?

    init() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] t in
            MainActor.assumeIsolated { self?.time = t.seconds }
        }
    }

    func load(_ url: URL?) {
        guard let url else { player.replaceCurrentItem(with: nil); return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }

    func seek(_ t: Double) {
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

enum TimelineSelection: Equatable {
    case segment(Int)
    case subtitle(Int)
}

// MARK: - 타임라인

struct TimelineStrip: View {
    var plan: EditPlan
    var current: Double
    @Binding var selection: TimelineSelection?
    var seek: (Double) -> Void

    var body: some View {
        GlassCard(padding: 12) {
            GeometryReader { geo in
                let w = geo.size.width
                let scale = w / max(plan.duration, 0.1)
                ZStack(alignment: .topLeading) {
                    // 비트 눈금
                    ForEach(Array(plan.beats.enumerated()), id: \.offset) { _, b in
                        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 82).offset(x: b * scale)
                    }
                    // 클립 구간
                    ForEach(plan.segments) { s in
                        let on = selection == .segment(s.id)
                        Button { selection = .segment(s.id); seek(s.start) } label: {
                            ZStack(alignment: .bottomLeading) {
                                Thumbnail(url: URL(fileURLWithPath: s.clip), time: s.clipIn + 0.1)
                                    .opacity(0.8)
                                Rectangle().fill(Theme.transitionColor(s.transition)).frame(height: 3)
                            }
                            .frame(width: max(s.length * scale - 2, 2), height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Color.white : Color.clear, lineWidth: 2))
                            .shadow(color: on ? Theme.pink : .clear, radius: 6)
                        }
                        .buttonStyle(.plain)
                        .offset(x: s.start * scale + 1)
                        .help("\(s.id)번 컷 · \(Catalog.transition(s.transition).name)")
                    }
                    // 자막
                    ForEach(plan.subtitles) { sub in
                        let on = selection == .subtitle(sub.id)
                        Button { selection = .subtitle(sub.id); seek(sub.start + 0.05) } label: {
                            Text(sub.text.replacingOccurrences(of: "\n", with: " "))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .frame(width: max((sub.end - sub.start) * scale - 2, 10), height: 24, alignment: .leading)
                                .background(Theme.hex(sub.accent).opacity(on ? 0.9 : 0.55), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Color.white : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .offset(x: sub.start * scale + 1, y: 52)
                        .help(Catalog.style(sub.style).name)
                    }
                    // 재생 위치
                    Rectangle().fill(Theme.pink).frame(width: 2, height: 90)
                        .shadow(color: Theme.pink, radius: 4)
                        .offset(x: min(max(current, 0), plan.duration) * scale - 1, y: -4)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture { loc in seek(Double(loc.x / scale)) }
            }
        }
    }
}

// MARK: - 직접 수정 (인스펙터)

struct Inspector: View {
    @EnvironmentObject var model: AppModel
    @Binding var selection: TimelineSelection?
    @Binding var plan: EditPlan
    var clips: [MediaItem]

    var body: some View {
        GlassCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selection {
                    case .segment(let id):
                        if let i = plan.segments.firstIndex(where: { $0.id == id }) { segmentEditor(i) }
                    case .subtitle(let id):
                        if let i = plan.subtitles.firstIndex(where: { $0.id == id }) { subtitleEditor(i) }
                    case nil:
                        overview
                    }

                    if model.draftChanged {
                        Divider().overlay(Theme.stroke)
                        Button { model.rebuildFromDraft() } label: {
                            Label("바꾼 내용으로 다시 만들기", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NeonButtonStyle())
                        .disabled(model.isBusy)
                        Button("되돌리기") { model.draft = model.currentVersion?.plan }
                            .buttonStyle(GhostButtonStyle())
                    }
                }
                .font(.system(size: 12))
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "직접 고치기", symbol: "slider.horizontal.below.rectangle")
            Text("아래 타임라인에서 컷이나 자막을 누르면 여기서 바로 고칠 수 있어요. 말로 부탁하려면 오른쪽 채팅을 쓰세요.")
                .foregroundStyle(Theme.dim)
            Divider().overlay(Theme.stroke)
            Text("CC (색보정)").font(.system(size: 12, weight: .bold))
            Picker("프리셋", selection: $plan.cc.preset) {
                ForEach(Catalog.ccPresets) { Text($0.name).tag($0.id) }
            }
            LabeledSlider(title: "색보정 세기", value: $plan.cc.intensity, left: "약하게", right: "강하게")
            LabeledSlider(title: "번짐(글로우)", value: $plan.cc.bloom, left: "선명", right: "몽환")
            LabeledSlider(title: "그레인", value: $plan.cc.grain, left: "깨끗", right: "필름")
            LabeledSlider(title: "비네팅", value: $plan.cc.vignette, left: "없음", right: "진하게")
        }
    }

    @ViewBuilder
    private func segmentEditor(_ i: Int) -> some View {
        let seg = plan.segments[i]
        SectionHeader(title: "\(seg.id)번 컷", subtitle: String(format: "%.2f – %.2f초", seg.start, seg.end), symbol: "scissors")
        Thumbnail(url: URL(fileURLWithPath: seg.clip), time: seg.clipIn + 0.1)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        Picker("클립", selection: $plan.segments[i].clip) {
            ForEach(clips) { c in Text(c.name).tag(c.url.path) }
        }
        HStack {
            Text("클립 시작")
            Slider(value: $plan.segments[i].clipIn, in: 0...max(clipDuration(seg.clip) - seg.length * seg.speed, 0.01))
            Text(String(format: "%.1f", plan.segments[i].clipIn)).font(.system(size: 11, design: .monospaced)).frame(width: 34)
        }
        Picker("전환", selection: $plan.segments[i].transition) {
            ForEach(Catalog.transitions) { Text($0.name).tag($0.id) }
        }
        HStack {
            Text("속도")
            Slider(value: $plan.segments[i].speed, in: 0.25...2)
            Text(String(format: "%.2fx", plan.segments[i].speed)).font(.system(size: 11, design: .monospaced)).frame(width: 42)
        }
        HStack {
            Text("줌인")
            Slider(value: $plan.segments[i].push, in: 0...0.3)
        }
        Toggle("흔들림", isOn: $plan.segments[i].shake).toggleStyle(.switch).tint(Theme.pink)
        Button("선택 해제") { selection = nil }.buttonStyle(GhostButtonStyle())
    }

    @ViewBuilder
    private func subtitleEditor(_ i: Int) -> some View {
        let sub = plan.subtitles[i]
        SectionHeader(title: "자막 \(sub.id)", subtitle: String(format: "%.2f – %.2f초", sub.start, sub.end), symbol: "captions.bubble")
        StylePreview(style: sub.style, text: String(sub.text.prefix(8)), accent: Theme.hex(sub.accent), size: 22)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        TextField("내용", text: $plan.subtitles[i].text, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...3)
        Picker("스타일", selection: $plan.subtitles[i].style) {
            ForEach(Catalog.styles) { Text($0.name).tag($0.id) }
        }
        Picker("폰트", selection: $plan.subtitles[i].font) {
            ForEach(Catalog.fonts) { Text($0.name).tag($0.id) }
        }
        HStack {
            ColorPicker("글자색", selection: hexBinding(\.color, i))
            ColorPicker("테두리·빛", selection: hexBinding(\.accent, i))
        }
        HStack {
            Text("크기")
            Slider(value: $plan.subtitles[i].size, in: 30...240)
            Text("\(Int(plan.subtitles[i].size))").font(.system(size: 11, design: .monospaced)).frame(width: 30)
        }
        HStack {
            Text("높이")
            Slider(value: $plan.subtitles[i].y, in: 0.1...0.9)
        }
        HStack {
            Text("시작")
            Slider(value: $plan.subtitles[i].start, in: 0...max(plan.duration - 0.3, 0.1))
        }
        HStack {
            Text("끝")
            Slider(value: $plan.subtitles[i].end, in: min(plan.subtitles[i].start + 0.2, plan.duration)...plan.duration)
        }
        HStack {
            Button("선택 해제") { selection = nil }.buttonStyle(GhostButtonStyle())
            Spacer()
            Button(role: .destructive) {
                plan.subtitles.remove(at: i)
                selection = nil
            } label: { Label("삭제", systemImage: "trash") }
                .buttonStyle(GhostButtonStyle())
        }
    }

    private func clipDuration(_ path: String) -> Double {
        clips.first { $0.url.path == path }?.duration ?? 1
    }

    private func hexBinding(_ key: WritableKeyPath<EditPlan.Subtitle, String>, _ i: Int) -> Binding<SwiftUI.Color> {
        Binding(
            get: { Theme.hex(plan.subtitles[i][keyPath: key]) },
            set: { c in
                let ns = NSColor(c).usingColorSpace(.sRGB) ?? .white
                plan.subtitles[i][keyPath: key] = HexColor.hex(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent))
            }
        )
    }
}

// MARK: - 채팅으로 수정 요청

struct ChatPanel: View {
    @EnvironmentObject var model: AppModel
    @State private var input = ""
    @FocusState private var focused: Bool

    private let quick = ["자막 더 크게", "효과 좀 줄여줘", "더 몽환적으로 번지게", "컷 더 빠르게", "색감 더 쨍하게", "자막 핑크 네온으로", "마지막에 줌 펀치 세게"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill").foregroundStyle(Theme.neon)
                Text("수정 요청").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Toggle("바로 반영", isOn: $model.autoRebuild)
                    .toggleStyle(.switch).controlSize(.mini).tint(Theme.pink)
                    .font(.system(size: 10.5))
                    .help("켜면 AI가 고친 내용으로 바로 AE에서 다시 만들어요")
            }
            .padding(.horizontal, 16)
            .padding(.top, 38)
            .padding(.bottom, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if model.chat.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("영상을 보고 마음에 안 드는 부분을 편하게 말해 주세요.")
                                Text("예) \"2번째 자막 노란색으로\", \"처음 3초는 슬로모션\", \"플래시 다 빼줘\"")
                                    .foregroundStyle(Theme.dim)
                            }
                            .font(.system(size: 12))
                            .padding(14)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        }
                        ForEach(model.chat) { m in Bubble(entry: m).id(m.id) }
                        if model.isBusy && model.status.contains("수정") {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("고치는 중…").font(.system(size: 11)).foregroundStyle(Theme.dim)
                            }
                            .id("typing")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                .onChange(of: model.chat.count) { _, _ in
                    if let last = model.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quick, id: \.self) { q in
                        Button(q) { model.sendRevision(q) }
                            .buttonStyle(GhostButtonStyle())
                            .disabled(model.isBusy)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 8)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("어디를 어떻게 바꿀까요?", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(10)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(focused ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Theme.stroke)))
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 13, weight: .black))
                        .frame(width: 34, height: 34)
                        .background(Theme.neonDiagonal, in: Circle())
                        .shadow(color: Theme.pink.opacity(0.6), radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || model.isBusy)
            }
            .padding(14)
        }
        .background(Color.black.opacity(0.25))
    }

    private func send() {
        guard !model.isBusy else { return }
        let t = input
        input = ""
        model.sendRevision(t)
    }
}

struct Bubble: View {
    var entry: ChatEntry

    var body: some View {
        HStack {
            if entry.role == .user { Spacer(minLength: 40) }
            Text(entry.text)
                .font(.system(size: 12.5))
                .textSelection(.enabled)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(entry.role == .system ? Color.orange : Color.white)
            if entry.role != .user { Spacer(minLength: 40) }
        }
    }

    private var background: AnyShapeStyle {
        switch entry.role {
        case .user: return AnyShapeStyle(Theme.neon.opacity(0.85))
        case .assistant: return AnyShapeStyle(Color.white.opacity(0.09))
        case .system: return AnyShapeStyle(Color.orange.opacity(0.12))
        }
    }
}
