import AVFoundation
import SwiftUI

/// 기억력 부스터: 최근 7일 동안 공부한 단어의 예문을 이어서 들려줘요.
struct BoosterView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store
    @State private var player = SentencePlayer()
    @State private var started = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if player.items.isEmpty && started {
                Spacer()
                Text("최근 7일 동안 공부한 단어가 없어요.\n오늘의 학습이나 퀴즈를 먼저 풀어 보세요.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if let item = player.current {
                Text("최근 7일 동안 공부한 문장 \(player.items.count)개")
                    .font(.footnote).foregroundStyle(Theme.sub)
                ProgressView(value: Double(player.index), total: Double(max(player.items.count - 1, 1)))
                    .tint(Theme.pri)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.w).font(.title2.weight(.heavy))
                        Text(item.m).font(.subheadline).foregroundStyle(Theme.ok)
                    }
                    Text(item.speakText)
                        .font(.system(size: 22, weight: .semibold))
                        .lineSpacing(6)
                    if player.showKorean && !item.sentenceKO.isEmpty {
                        Text(item.sentenceKO).foregroundStyle(Theme.sub)
                    }
                }
                .card()
                .frame(maxHeight: .infinity, alignment: .top)

                Toggle("한국어 해석 보기", isOn: $player.showKorean).tint(Theme.pri)
                Toggle("끝나면 처음부터 반복", isOn: $player.repeatAll).tint(Theme.pri)

                HStack(spacing: 12) {
                    Button { player.previous() } label: { Image(systemName: "backward.fill") }
                        .buttonStyle(.pill)
                        .accessibilityLabel("이전 문장")
                    Button { player.isPlaying ? player.pause() : player.play() } label: {
                        Label(player.isPlaying ? "일시정지" : "재생", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pillPrimary)
                    Button { player.next() } label: { Image(systemName: "forward.fill") }
                        .buttonStyle(.pill)
                        .accessibilityLabel("다음 문장")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle("기억력 부스터")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !started else { return }
            started = true
            let weekAgo = (Date().timeIntervalSince1970 - 7 * 86_400) * 1000
            let recent = store.words(in: bookIDs)
                .filter { $0.seen >= weekAgo }
                .sorted { $0.seen > $1.seen }
            player.items = recent
        }
        .onDisappear { player.pause() }
    }
}

/// 문장을 하나씩 읽고, 끝나면 잠깐 쉬었다가 다음 문장으로 넘어가요.
@MainActor
@Observable
final class SentencePlayer: NSObject, AVSpeechSynthesizerDelegate {
    var items: [Word] = []
    var index = 0
    var isPlaying = false
    var showKorean = true
    var repeatAll = false

    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private var gapTask: Task<Void, Never>?

    var current: Word? { index < items.count ? items[index] : nil }

    override init() {
        super.init()
        synth.delegate = self
    }

    func play() {
        guard !items.isEmpty else { return }
        if index >= items.count { index = 0 }
        isPlaying = true
        speakCurrent()
    }

    func pause() {
        isPlaying = false
        gapTask?.cancel()
        synth.stopSpeaking(at: .immediate)
    }

    func next() {
        guard !items.isEmpty else { return }
        index = min(index + 1, items.count - 1)
        if isPlaying { speakCurrent() }
    }

    func previous() {
        index = max(index - 1, 0)
        if isPlaying { speakCurrent() }
    }

    private func speakCurrent() {
        gapTask?.cancel()
        synth.stopSpeaking(at: .immediate)
        guard let w = current else { return }
        Speech.activatePlayback()
        synth.speak(Speech.utterance(w.speakText))
    }

    private func finishedOne() {
        guard isPlaying else { return }
        gapTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, !Task.isCancelled, self.isPlaying else { return }
            if self.index + 1 < self.items.count {
                self.index += 1
                self.speakCurrent()
            } else if self.repeatAll {
                self.index = 0
                self.speakCurrent()
            } else {
                self.isPlaying = false
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishedOne() }
    }
}
