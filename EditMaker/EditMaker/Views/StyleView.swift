import SwiftUI

struct StyleView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(title: "스타일 고르기", subtitle: "잘 모르겠으면 전부 'AI 자동'으로 두세요. AI가 레퍼런스를 보고 골라요.")

                HStack(alignment: .top, spacing: 18) {
                    subtitlesCard.frame(maxWidth: .infinity)
                    optionsCard.frame(width: 340)
                }

                styleCard
                ccCard

                HStack(spacing: 14) {
                    Spacer()
                    if model.selectedAE == nil {
                        Chip(text: "After Effects를 찾지 못했어요 · 설정에서 확인", symbol: "exclamationmark.triangle.fill", tint: .orange)
                    }
                    Button {
                        model.generate()
                    } label: {
                        Label("Edit 만들기", systemImage: "sparkles")
                    }
                    .buttonStyle(NeonButtonStyle(big: true))
                    .disabled(!model.canGenerate || model.selectedAE == nil)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(30)
        }
    }

    // MARK: 자막

    private var subtitlesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "자막", subtitle: "한 줄 = 자막 하나 · 비워 두면 자막 없이", symbol: "captions.bubble.fill")
                ZStack(alignment: .topLeading) {
                    if model.subtitleText.isEmpty {
                        Text("이거랑 같이 먹어야지\n씨러!\n오늘도 귀여움 한도 초과 ♡")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                            .padding(.horizontal, 5).padding(.vertical, 8)
                    }
                    TextEditor(text: $model.subtitleText)
                        .font(.system(size: 14, design: .rounded))
                        .scrollContentBackground(.hidden)
                }
                .frame(height: 150)
                .padding(8)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
                Text("팁: 느낌표(!)가 있으면 임팩트, ?·~·ㅋ·♡가 있으면 귀여운 스타일, 긴 문장은 타자기 스타일을 먼저 고려해요.")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim)
            }
        }
    }

    // MARK: 옵션

    private var optionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "편집", symbol: "timeline.selection")
                Picker("화면 비율", selection: $model.aspect) {
                    ForEach(AspectOption.allCases) { Text($0.name).tag($0) }
                }
                Picker("컷 타이밍", selection: $model.cutMode) {
                    ForEach(CutMode.allCases) { Text($0.name).tag($0) }
                }
                Toggle(isOn: $model.limitLength) {
                    Text("길이 제한")
                }
                if model.limitLength {
                    HStack {
                        Slider(value: $model.maxLength, in: 5...60, step: 1)
                        Text("\(Int(model.maxLength))초").font(.system(size: 12, weight: .bold, design: .monospaced)).frame(width: 40)
                    }
                }
                LabeledSlider(title: "효과 양", value: $model.effectAmount, left: "잔잔", right: "화려")
                LabeledSlider(title: "번짐(글로우)", value: $model.bloom, left: "선명", right: "몽환")
                Divider().overlay(Theme.stroke)
                Toggle(isOn: $model.useAIDirector) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI 감독")
                        Text(model.hasAIKey ? "레퍼런스 장면을 보고 자막·효과를 다듬어요" : "설정에서 API 키를 넣으면 켜져요")
                            .font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                    }
                }
                .disabled(!model.hasAIKey)
                Toggle(isOn: $model.renderPreview) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("미리보기 영상 렌더")
                        Text("끄면 AE 프로젝트만 만들어요 (빠름)").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(Theme.pink)
            .font(.system(size: 12.5, weight: .medium))
        }
    }

    // MARK: 자막 스타일

    private var styleCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "자막 스타일", subtitle: "After Effects 효과로 만들어져요", symbol: "textformat.alt")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    AutoCard(selected: model.subtitleStyle == "auto", detail: "자막 내용과 레퍼런스에 맞춰 자막마다 다르게") {
                        model.subtitleStyle = "auto"
                    }
                    ForEach(Catalog.styles) { s in
                        SelectCard(selected: model.subtitleStyle == s.id, action: { model.subtitleStyle = s.id }) {
                            VStack(alignment: .leading, spacing: 8) {
                                StylePreview(style: s.id, text: "씨러!", accent: Theme.pink)
                                    .frame(height: 56)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                                Text(s.name).font(.system(size: 12.5, weight: .bold, design: .rounded))
                                Text(s.detail).font(.system(size: 10.5)).foregroundStyle(Theme.dim).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: CC

    private var ccCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "CC (색보정)", subtitle: "조정 레이어에 글로우·색감·그레인을 쌓아요", symbol: "camera.filters")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    AutoCard(selected: model.ccPreset == "auto", detail: "레퍼런스 색감을 분석해서") {
                        model.ccPreset = "auto"
                    }
                    ForEach(Catalog.ccPresets) { c in
                        SelectCard(selected: model.ccPreset == c.id, action: { model.ccPreset = c.id }) {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: ccColors(c.id), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(Image(systemName: c.symbol).font(.system(size: 20)).foregroundStyle(.white.opacity(0.9)))
                                    .frame(height: 56)
                                Text(c.name).font(.system(size: 12.5, weight: .bold, design: .rounded))
                                Text(c.detail).font(.system(size: 10.5)).foregroundStyle(Theme.dim).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func ccColors(_ id: String) -> [Color] {
        switch id {
        case "dreamy_glow": return [Color(red: 1, green: 0.7, blue: 0.9), Color(red: 0.6, green: 0.45, blue: 0.95)]
        case "vivid_pop": return [Color(red: 1, green: 0.3, blue: 0.4), Color(red: 1, green: 0.8, blue: 0.2)]
        case "soft_film": return [Color(red: 0.95, green: 0.8, blue: 0.6), Color(red: 0.6, green: 0.45, blue: 0.35)]
        case "cool_night": return [Color(red: 0.2, green: 0.25, blue: 0.6), Color(red: 0.55, green: 0.4, blue: 0.9)]
        default: return [Color(white: 0.85), Color(white: 0.5)]
        }
    }
}

struct LabeledSlider: View {
    var title: String
    @Binding var value: Double
    var left: String
    var right: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.pink)
            }
            Slider(value: $value, in: 0...1).tint(Theme.pink)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(.system(size: 10)).foregroundStyle(Theme.dim)
        }
    }
}

struct SelectCard<Content: View>: View {
    var selected: Bool
    var action: () -> Void
    @ViewBuilder var content: Content
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(selected ? 0.1 : (hover ? 0.06 : 0.03)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selected ? AnyShapeStyle(Theme.neonDiagonal) : AnyShapeStyle(Theme.stroke), lineWidth: selected ? 2 : 1)
                )
                .shadow(color: selected ? Theme.pink.opacity(0.35) : .clear, radius: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

struct AutoCard: View {
    var selected: Bool
    var detail: String
    var action: () -> Void

    var body: some View {
        SelectCard(selected: selected, action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.neonDiagonal.opacity(0.85))
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("AUTO").font(.system(size: 16, weight: .black, design: .rounded)).tracking(2)
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 56)
                Text("AI 자동").font(.system(size: 12.5, weight: .bold, design: .rounded))
                Text(detail).font(.system(size: 10.5)).foregroundStyle(Theme.dim).lineLimit(2)
            }
        }
    }
}

/// 앱 안에서 자막 스타일 느낌을 흉내 낸 미리보기 (실제 결과는 AE 효과로 만들어져요)
struct StylePreview: View {
    var style: String
    var text: String
    var accent: Color
    var size: CGFloat = 24
    @State private var phase = false

    var body: some View {
        let font = Font.custom(Catalog.style(style).font, size: size)
        ZStack {
            switch style {
            case "neon_glow":
                ZStack {
                    Text(text).font(font).foregroundStyle(Color.red.opacity(0.7)).offset(x: -2)
                    Text(text).font(font).foregroundStyle(Color.cyan.opacity(0.7)).offset(x: 2)
                    Text(text).font(font).foregroundStyle(Color(red: 1, green: 0.9, blue: 0.96))
                }
                .blendMode(.screen)
                .shadow(color: accent, radius: 6).shadow(color: accent, radius: 14)
            case "soft_blur":
                Text(text).font(font).foregroundStyle(.white)
                    .blur(radius: phase ? 0 : 3)
                    .shadow(color: accent.opacity(0.8), radius: 10)
            case "impact_pop":
                Text(text).font(Font.custom(Catalog.style(style).font, size: size * 1.2)).foregroundStyle(.white)
                    .shadow(color: accent, radius: 0, x: 2, y: 2)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 3)
                    .scaleEffect(phase ? 1 : 1.12)
            case "typewriter":
                Text(phase ? text : String(text.prefix(1))).font(font).foregroundStyle(.white)
                    .shadow(color: accent.opacity(0.6), radius: 6)
            case "cute_bounce":
                Text(text).font(font).foregroundStyle(.white)
                    .shadow(color: accent, radius: 0, x: 0, y: 2)
                    .offset(y: phase ? 0 : -5)
                    .rotationEffect(.degrees(phase ? 0 : -4))
            case "light_sweep":
                Text(text).font(font).foregroundStyle(
                    LinearGradient(colors: [.white.opacity(0.75), .white, .white.opacity(0.75)],
                                   startPoint: phase ? .leading : .trailing, endPoint: phase ? .trailing : .leading)
                )
                .shadow(color: accent.opacity(0.8), radius: 8)
            case "glitch":
                ZStack {
                    Text(text).font(font).foregroundStyle(Color.red).offset(x: phase ? -4 : 2)
                    Text(text).font(font).foregroundStyle(Color.cyan).offset(x: phase ? 4 : -2)
                    Text(text).font(font).foregroundStyle(.white)
                }
                .blendMode(.screen)
            default:
                Text(text).font(Font.custom(Catalog.style(style).font, size: size * 0.8)).tracking(4).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { phase = true }
        }
    }
}
