import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 사전 시트에 넘길 문맥
struct WordContext: Identifiable {
    let id = UUID()
    let words: [String]
    let tap: Int
    let sentenceEn: String
    let sentenceKo: String
    let videoId: String
    let timeMs: Int
}

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
        let player = app.player
        VStack(spacing: 0) {
            urlBar
            // 플레이어(PlayerOverlay)가 이 자리 위에 겹쳐 그려진다
            Color.black
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    if player.videoId == nil {
                        Text(urlError ? "유튜브 링크를 확인해 주세요" : "영상을 열면 여기서 재생돼요")
                            .font(.subheadline).foregroundStyle(.gray)
                    }
                }
                .anchorPreference(key: PlayerSlotKey.self, value: .bounds) { $0 }
            toolbar
            currentCard
            transcript
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
            Toggle("영", isOn: Binding(get: { player.showEn }, set: { player.showEn = $0 }))
                .toggleStyle(.button)
            Toggle("한", isOn: Binding(get: { player.showKo }, set: { player.showKo = $0 }))
                .toggleStyle(.button)
            Toggle(isOn: Binding(get: { player.showOnVideo }, set: { player.showOnVideo = $0 })) {
                Image(systemName: "captions.bubble")
            }
            .toggleStyle(.button)
            .accessibilityLabel("영상 위 자막")
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
                    Text(player.error ?? player.info ?? "")
                        .foregroundStyle(player.error == nil ? Color.secondary : Color.red)
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

    private var currentCard: some View {
        let player = app.player
        let idx = player.currentIndex
        let cue = idx >= 0 && idx < player.cues.count ? player.cues[idx] : nil
        return VStack(alignment: .leading, spacing: 6) {
            if let cue {
                if player.showEn && !cue.en.isEmpty {
                    TappableText(text: cue.en, highlight: app.vocab.highlight) { tap, words in
                        app.openWord(cue: cue, tap: tap, words: words)
                    }
                    .font(.title3.weight(.semibold))
                }
                if player.showKo && !cue.ko.isEmpty {
                    Text(cue.ko).font(.body).foregroundStyle(.blue)
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
        .padding(.horizontal, 12)
    }

    private var transcript: some View {
        let player = app.player
        let idx = player.currentIndex
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(player.cues.enumerated()), id: \.offset) { i, cue in
                        TranscriptRow(cue: cue, active: i == idx, showEn: player.showEn, showKo: player.showKo,
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
    let showEn: Bool
    let showKo: Bool
    let highlight: HighlightIndex

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(formatTime(cue.start))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if showEn && !cue.en.isEmpty {
                    TappableText(text: cue.en, highlight: highlight).font(.subheadline)
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
