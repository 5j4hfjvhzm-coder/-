import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 영상 탭: 링크 입력, 플레이어 자리, 현재 자막 크게, 전체 대본
struct VideoView: View {
    @Environment(AppModel.self) private var app
    @State private var url = ""
    @State private var urlError = false
    @State private var showImporter = false
    @State private var lastUserScroll = Date.distantPast

    private static let subtitleTypes: [UTType] =
        [UTType(filenameExtension: "srt"), UTType(filenameExtension: "vtt")].compactMap { $0 } + [.plainText, .text, .data]

    var body: some View {
        GeometryReader { geo in
            // 아이패드 가로·넓은 맥 창: 왼쪽 영상·자막 카드, 오른쪽 대본
            if geo.size.width >= 700 && geo.size.width > geo.size.height {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        urlBar
                        // 아래 자막 카드가 보이도록 영상 높이를 화면의 절반 남짓으로
                        playerSlot
                            .frame(maxHeight: geo.size.height * 0.55)
                        toolbar
                        playBar
                        currentCard
                        Spacer(minLength: 0)
                    }
                    .frame(width: geo.size.width * 0.6)
                    Divider()
                    transcript
                }
            } else {
                VStack(spacing: 0) {
                    urlBar
                    playerSlot
                    toolbar
                    playBar
                    currentCard
                    transcript
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: Binding(get: { app.wordContext }, set: { app.wordContext = $0 })) { ctx in
            WordSheet(ctx: ctx)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.subtitleTypes) { result in
            if case .success(let fileURL) = result {
                app.player.loadSubtitleFile(fileURL)
            }
        }
    }

    /// 플레이어(PlayerOverlay)가 이 자리 위에 겹쳐 그려진다
    private var playerSlot: some View {
        let player = app.player
        return Color.black
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if player.videoId == nil {
                    Text(urlError ? "유튜브 링크를 확인해 주세요" : "일본어 영상 링크를 열면 여기서 재생돼요")
                        .font(.subheadline).foregroundStyle(.gray)
                }
            }
            .anchorPreference(key: PlayerSlotKey.self, value: .bounds) { $0 }
    }

    private var urlBar: some View {
        HStack(spacing: 8) {
            TextField("유튜브 링크 붙여넣기", text: $url)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit(open)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(urlError ? Color.red : Color.clear))
            if url.isEmpty {
                PasteButton(payloadType: String.self) { strings in
                    if let s = strings.first {
                        url = s
                        open()
                    }
                }
                .labelStyle(.iconOnly)
            }
            Button("열기", action: open)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func open() {
        urlError = !app.player.open(url)
        if !urlError { hideKeyboard() }
    }

    private var toolbar: some View {
        let player = app.player
        return HStack(spacing: 6) {
            Toggle("일", isOn: Binding(get: { player.showJa }, set: { player.showJa = $0 }))
                .toggleStyle(.button)
            Toggle("한", isOn: Binding(get: { player.showKo }, set: { player.showKo = $0 }))
                .toggleStyle(.button)
            Toggle(isOn: Binding(get: { player.showOnVideo }, set: { player.showOnVideo = $0 })) {
                Image(systemName: "captions.bubble")
            }
            .toggleStyle(.button)
            .accessibilityLabel("영상 위 자막")
            Button {
                player.setFullscreen(true)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
            .disabled(player.videoId == nil)
            .accessibilityLabel("전체화면")
            Button {
                showImporter = true
            } label: {
                Label("자막 파일", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            Group {
                if player.loading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(player.info ?? "")
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// 재생 방식 줄: 지금 방식, 막혔을 때 안내, 다른 방식으로 / 유튜브 앱에서 열기
    @ViewBuilder
    private var playBar: some View {
        let player = app.player
        if player.videoId != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let err = player.error {
                    Text(err).font(.caption).foregroundStyle(.red)
                } else if let note = player.playInfo {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                } else if !player.videoReady {
                    Text("영상 불러오는 중… 안 뜨면 자동으로 다른 방식으로 열어요").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button {
                        player.switchMode()
                    } label: {
                        Label("다른 방식으로 재생", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        player.openInYouTubeApp()
                    } label: {
                        Label("유튜브 앱에서 열기", systemImage: "arrow.up.forward.app")
                    }
                    Spacer(minLength: 0)
                    Text(player.mode.label).font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private var currentCard: some View {
        let player = app.player
        let idx = player.currentIndex
        let cue = idx >= 0 && idx < player.cues.count ? player.cues[idx] : nil
        return VStack(alignment: .leading, spacing: 6) {
            if let cue {
                if player.showJa && !cue.ja.isEmpty {
                    TappableText(text: cue.ja, highlight: app.vocab.highlight) { at in
                        app.openWord(cue: cue, at: at)
                    }
                    .font(.title2.weight(.medium))
                    .lineSpacing(4)
                }
                if !cue.ko.isEmpty {
                    if player.showsKo(at: idx) {
                        Text(cue.ko).font(.body).foregroundStyle(.blue)
                    } else {
                        Text("한국어 자막 가림 · 이 카드나 영상 위 자막을 두 번 탭하면 보여요")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(player.videoId == nil ? "자막의 단어를 탭하면 사전이 열려요" : "자막을 기다리는 중…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(count: 2) { player.toggleKoReveal() }
        .padding(.horizontal, 12)
    }

    private var transcript: some View {
        let player = app.player
        let idx = player.currentIndex
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(player.cues.enumerated()), id: \.offset) { i, cue in
                        TranscriptRow(cue: cue, active: i == idx, showJa: player.showJa, showKo: player.showKo,
                                      highlight: app.vocab.highlight)
                            .id(i)
                            .onTapGesture { player.seek(cue.start) }
                    }
                }
                .padding(.vertical, 8)
            }
            .simultaneousGesture(DragGesture().onChanged { _ in lastUserScroll = Date() })
            .onChange(of: idx) { _, new in
                // 직접 스크롤한 뒤 4초 동안은 자동 스크롤 멈춤
                guard new >= 0, Date().timeIntervalSince(lastUserScroll) > 4 else { return }
                withAnimation { proxy.scrollTo(new, anchor: UnitPoint(x: 0.5, y: 0.3)) }
            }
        }
    }
}

private struct TranscriptRow: View {
    let cue: BiCue
    let active: Bool
    let showJa: Bool
    let showKo: Bool
    let highlight: HighlightIndex

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(formatTime(cue.start))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if showJa && !cue.ja.isEmpty {
                    TappableText(text: cue.ja, highlight: highlight).font(.body)
                }
                if showKo && !cue.ko.isEmpty {
                    Text(cue.ko).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(active ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
