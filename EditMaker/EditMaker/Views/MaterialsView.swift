import SwiftUI

struct MaterialsView: View {
    @EnvironmentObject var model: AppModel

    private let videoTypes = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(title: "재료 넣기", subtitle: "따라 하고 싶은 edit 영상(레퍼런스)과, 편집에 쓸 클립들을 끌어다 놓으세요.")

                HStack(alignment: .top, spacing: 18) {
                    referenceCard.frame(maxWidth: .infinity)
                    VStack(spacing: 18) {
                        extrasCard
                    }
                    .frame(width: 320)
                }

                clipsCard

                HStack {
                    Spacer()
                    Button {
                        model.step = .style
                    } label: {
                        Label("다음: 스타일 고르기", systemImage: "arrow.right")
                    }
                    .buttonStyle(NeonButtonStyle(big: true))
                    .disabled(model.referenceURL == nil || model.clips.isEmpty)
                }
            }
            .padding(30)
        }
    }

    // MARK: 레퍼런스

    private var referenceCard: some View {
        GlassCard(glow: model.analysis != nil) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "레퍼런스 영상", subtitle: "컷 타이밍 · 비트 · 색감을 따라 해요", symbol: "film.stack")
                if let url = model.referenceURL {
                    HStack(spacing: 8) {
                        if model.keyframes.isEmpty {
                            ForEach(0..<4, id: \.self) { i in
                                Thumbnail(url: url, time: Double(i) * 2 + 0.5)
                                    .aspectRatio(9 / 16, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        } else {
                            ForEach(Array(model.keyframes.enumerated()), id: \.offset) { _, cg in
                                Image(decorative: cg, scale: 1)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(9 / 16, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .frame(maxHeight: 260)

                    HStack {
                        Text(url.lastPathComponent).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Spacer()
                        Button("바꾸기") { pickReference() }.buttonStyle(GhostButtonStyle())
                    }

                    if let a = model.analysis {
                        AnalysisChips(a: a)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(model.status).font(.system(size: 12)).foregroundStyle(Theme.dim)
                        }
                    }
                } else {
                    DropZone(onDrop: { urls in if let u = urls.first { model.setReference(u) } }) {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.tv.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(Theme.neon)
                                .shadow(color: Theme.pink.opacity(0.5), radius: 14)
                            Text("레퍼런스 edit 영상을 여기에 끌어다 놓기")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("틱톡·릴스에서 저장한 edit 영상 (mp4, mov)").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                            Button("파일 고르기") { pickReference() }.buttonStyle(NeonButtonStyle())
                        }
                        .padding(.vertical, 50)
                    }
                }
            }
        }
    }

    private func pickReference() {
        if let u = Panels.open(types: videoTypes, multiple: false, title: "레퍼런스 영상 고르기").first {
            model.setReference(u)
        }
    }

    // MARK: 음악 · 자료

    private var extrasCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "음악", subtitle: "선택", symbol: "music.note")
                HStack {
                    Image(systemName: model.musicURL == nil ? "waveform" : "music.note.list")
                        .foregroundStyle(Theme.pink)
                    Text(model.musicURL?.lastPathComponent ?? (model.referenceURL == nil ? "레퍼런스 소리를 써요" : "레퍼런스 영상의 소리를 그대로 써요"))
                        .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
                    Spacer()
                }
                HStack {
                    Button("다른 음악") {
                        if let u = Panels.open(types: Array(MediaAnalyzer.audioExts) + ["mp4", "mov"], multiple: false, title: "음악 고르기").first {
                            model.musicURL = u
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    if model.musicURL != nil {
                        Button("되돌리기") { model.musicURL = nil }.buttonStyle(GhostButtonStyle())
                    }
                }

                Divider().overlay(Theme.stroke)

                SectionHeader(title: "CC 자료 (.ffx)", subtitle: "선택", symbol: "slider.horizontal.3")
                Text("갖고 있는 색보정·효과 프리셋 파일을 넣으면 CC 레이어에 같이 적용해요.")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim)
                DropZone(onDrop: { model.addClips($0.filter { $0.pathExtension.lowercased() == "ffx" }) }) {
                    VStack(spacing: 6) {
                        if model.presets.isEmpty {
                            Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(Theme.purple)
                            Text(".ffx 끌어다 놓기").font(.system(size: 11.5, weight: .semibold))
                        } else {
                            ForEach(model.presets, id: \.self) { p in
                                HStack {
                                    Image(systemName: "wand.and.rays").foregroundStyle(Theme.purple)
                                    Text(p.lastPathComponent).font(.system(size: 11)).lineLimit(1)
                                    Spacer()
                                    Button { model.presets.removeAll { $0 == p } } label: { Image(systemName: "xmark.circle.fill") }
                                        .buttonStyle(.plain).foregroundStyle(Theme.dim)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                Button("파일 고르기") { model.addClips(Panels.open(types: ["ffx"], multiple: true, title: "프리셋 고르기")) }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    // MARK: 클립

    private var clipsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(title: "내 클립", subtitle: "\(model.clips.count)개 · 영상이나 사진", symbol: "photo.stack.fill")
                    Button {
                        model.addClips(Panels.open(types: videoTypes + Array(MediaAnalyzer.imageExts), multiple: true, title: "클립 고르기"))
                    } label: { Label("추가", systemImage: "plus") }
                    .buttonStyle(GhostButtonStyle())
                }
                DropZone(onDrop: { model.addClips($0) }) {
                    if model.clips.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 34)).foregroundStyle(Theme.neon)
                            Text("편집에 쓸 클립들을 한꺼번에 끌어다 놓기").font(.system(size: 13, weight: .bold, design: .rounded))
                            Text("직캠, 무대, 브이로그 클립 등 · 많을수록 다양해져요").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                            ForEach(model.clips) { c in ClipTile(clip: c) }
                        }
                        .padding(14)
                    }
                }
            }
        }
    }
}

struct ClipTile: View {
    @EnvironmentObject var model: AppModel
    var clip: MediaItem
    @State private var hover = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Thumbnail(url: clip.url, time: clip.duration * 0.3)
                .aspectRatio(9 / 16, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(clip.isStill ? "사진" : String(format: "%.1f초", clip.duration))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(hover ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Theme.stroke), lineWidth: hover ? 2 : 1)
                )
            if hover {
                Button { withAnimation { model.removeClip(clip) } } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18)).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.pink)
                }
                .buttonStyle(.plain)
                .padding(5)
            }
        }
        .help(clip.name)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

struct AnalysisChips: View {
    var a: ReferenceAnalysis

    var body: some View {
        HStack(spacing: 8) {
            Chip(text: String(format: "%.1f초", a.duration), symbol: "clock", tint: .white)
            Chip(text: "컷 \(a.cuts.count)개", symbol: "scissors", tint: Theme.pink)
            Chip(text: "\(Int(a.bpm.rounded())) BPM", symbol: "metronome.fill", tint: Theme.cyan)
            Chip(text: "에너지 \(Int(a.energy * 100))", symbol: "bolt.fill", tint: .yellow)
            HStack(spacing: 4) {
                Circle().fill(Theme.hex(HexColor.hex(h: a.hue, s: max(a.saturation, 0.35), b: max(a.brightness, 0.6))))
                    .frame(width: 12, height: 12)
                Text("색감").font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
    }
}

struct PageTitle: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.dim)
        }
        .padding(.top, 14)
    }
}
