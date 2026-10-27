import SwiftUI

/// 스피킹: 예문을 듣고 따라 말하면 얼마나 비슷한지 점수를 알려줘요.
struct SpeakView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store
    @State private var recognizer = SpeechRecognizer()
    @State private var items: [Word] = []
    @State private var index = 0
    @State private var score: Int?
    @State private var best: [String: Int] = [:]
    @State private var started = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if items.isEmpty && started {
                    Text("예문이 있는 단어가 없어요. CSV에 예문(E) 열을 넣어 주세요.")
                        .foregroundStyle(Theme.sub)
                        .padding(.top, 40)
                } else if index < items.count {
                    practice(items[index])
                } else if started {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("끝! 평균 \(average)점")
                            .font(.system(size: 28, weight: .heavy))
                            .padding(.top, 20)
                        Button("새로 연습하기") { build() }
                            .buttonStyle(.pillPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle("스피킹")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !started else { return }
            started = true
            build()
        }
        .onDisappear { recognizer.stop() }
        .onChange(of: recognizer.isRecording) { _, recording in
            // 녹음이 끝나면 채점
            guard !recording, index < items.count, !recognizer.transcript.isEmpty else { return }
            grade(items[index])
        }
    }

    private var average: Int {
        best.isEmpty ? 0 : best.values.reduce(0, +) / best.count
    }

    @ViewBuilder
    private func practice(_ w: Word) -> some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(index), total: Double(max(items.count, 1)))
                .tint(Theme.pri)
            Text("\(index + 1)/\(items.count)").font(.footnote).monospacedDigit()
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("이 문장을 소리 내어 말해 보세요")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.sub)
            Text(w.sentenceEN)
                .font(.system(size: 22, weight: .semibold))
                .lineSpacing(6)
            if !w.sentenceKO.isEmpty {
                Text(w.sentenceKO).font(.subheadline).foregroundStyle(Theme.sub)
            }
            Button { Speech.shared.say(w.sentenceEN) } label: {
                Label("원어민 발음 듣기", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.pill)
            .disabled(recognizer.isRecording)
        }
        .card()

        VStack(spacing: 12) {
            Button {
                if recognizer.isRecording {
                    recognizer.stop()
                } else {
                    score = nil
                    Task { await recognizer.start() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recognizer.isRecording ? Theme.bad : Theme.pri)
                        .frame(width: 84, height: 84)
                    Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recognizer.isRecording ? "녹음 멈추기" : "말하기 시작")
            Text(recognizer.isRecording ? "듣고 있어요… 다 말하면 ■ 를 누르세요" : "🎙 버튼을 누르고 말하세요")
                .font(.footnote)
                .foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity)

        if let e = recognizer.error {
            Text(e).font(.footnote).foregroundStyle(Theme.bad)
        }

        if !recognizer.transcript.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("내가 말한 문장").font(.caption.weight(.heavy)).foregroundStyle(Theme.pri)
                Text(recognizer.transcript).font(.body)
                if let score {
                    Text("\(score)점 · \(comment(score))")
                        .font(.headline)
                        .foregroundStyle(score >= 80 ? Theme.ok : score >= 50 ? Theme.starOn : Theme.bad)
                    missed(w)
                }
            }
            .card()
        }

        FlowLayout {
            Button(index + 1 < items.count ? "다음 문장" : "결과 보기") {
                recognizer.stop()
                recognizer.transcript = ""
                score = nil
                index += 1
            }
            .buttonStyle(score != nil ? PillButtonStyle(primary: true) : PillButtonStyle(primary: false))
            .disabled(recognizer.isRecording)
        }
    }

    /// 빠뜨리거나 다르게 말한 단어
    @ViewBuilder
    private func missed(_ w: Word) -> some View {
        let said = Set(SpeechRecognizer.words(recognizer.transcript))
        let target = SpeechRecognizer.words(w.sentenceEN)
        let miss = target.filter { !said.contains($0) }
        if !miss.isEmpty {
            Text("다시 연습할 단어: " + miss.joined(separator: ", "))
                .font(.footnote)
                .foregroundStyle(Theme.sub)
        }
    }

    private func comment(_ s: Int) -> String {
        switch s {
        case 90...: return "완벽해요! 🎉"
        case 70..<90: return "아주 좋아요!"
        case 50..<70: return "조금만 더 또박또박!"
        default: return "다시 들어보고 따라 해 봐요"
        }
    }

    private func grade(_ w: Word) {
        let s = SpeechRecognizer.score(said: recognizer.transcript, target: w.sentenceEN)
        score = s
        let first = best[w.id] == nil
        best[w.id] = max(best[w.id] ?? 0, s)
        if first { store.record(w.id, correct: s >= 70) }
    }

    private func build() {
        let candidates = store.words(in: bookIDs).filter { SpeechRecognizer.words($0.sentenceEN).count >= 2 }
        items = Array(candidates.shuffled().prefix(10))
        index = 0
        score = nil
        best = [:]
        recognizer.transcript = ""
    }
}
