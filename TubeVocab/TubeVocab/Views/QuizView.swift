import SwiftUI
import UIKit

/// 시험 탭: 저장했던 문장에서 단어를 빈칸으로 가리고 맞히기 (간격 반복)
struct QuizView: View {
    @Environment(AppModel.self) private var app
    @State private var session: QuizSession?

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    QuizCard(session: session) { self.session = nil }
                        .id(session.id)
                } else {
                    start
                }
            }
            .navigationTitle("빈칸 시험")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var start: some View {
        let now = nowMs()
        let words = app.vocab.words
        let due = words.filter { $0.dueAt <= now }.sorted { $0.dueAt < $1.dueAt }
        let next = words.map(\.dueAt).filter { $0 > now }.min()
        return VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("\(due.count)").font(.system(size: 56, weight: .bold))
                Text("지금 복습할 단어").foregroundStyle(.secondary)
                if due.isEmpty, let next {
                    Text("다음 복습: \(describeDue(next, now: now))").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 20)

            Button {
                session = QuizSession(words: due, practice: false)
            } label: {
                Text("복습 시작").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(due.isEmpty)

            Button {
                session = QuizSession(words: words.shuffled(), practice: true)
            } label: {
                Text("전체 연습 (기록 안 함)").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .disabled(words.isEmpty)

            Text("맞히면 1·3·7·14·30·60일 뒤, 틀리면 10분 뒤에 다시 나와요.\n활용형·기본형 모두 정답으로 인정해요.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

/// 시작할 때 문제 목록을 고정 (풀면서 단어장이 바뀌어도 순서 유지)
struct QuizSession: Identifiable {
    let id = UUID()
    let words: [SavedWord]
    /// 연습 모드는 간격 반복 기록을 바꾸지 않는다
    let practice: Bool
}

private struct QuizCard: View {
    let session: QuizSession
    let onFinish: () -> Void

    @Environment(AppModel.self) private var app
    @State private var index = 0
    @State private var input = ""
    @State private var verdict: Bool?
    @State private var showKoHint = false
    @State private var showLetterHint = false
    @State private var score = 0
    @FocusState private var focused: Bool

    private var word: SavedWord? { index < session.words.count ? session.words[index] : nil }
    private var blank: BlankQuestion? { word.flatMap { makeBlank($0.sentenceEn, $0.target) } }
    private var answer: String { blank?.answer ?? word?.surface ?? "" }

    var body: some View {
        if let w = word {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ProgressView(value: Double(index), total: Double(session.words.count))
                    Text("\(index + 1) / \(session.words.count)\(session.practice ? " · 연습" : "")")
                        .font(.caption).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        // 빈칸에 들어갈 단어의 뜻 (저장할 때 고른 뜻)
                        if blank != nil {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("뜻").font(.caption.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentColor, in: Capsule())
                                Text(w.summary).font(.headline)
                                TagBadges(tags: w.senseTags)
                            }
                        }
                        sentence(w)
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    hints(w)

                    typing(w)

                    if let verdict {
                        feedback(w, correct: verdict)
                    }
                }
                .padding()
            }
            .onAppear(perform: prepare)
            .onChange(of: index) { _, _ in prepare() }
        } else {
            VStack(spacing: 14) {
                Text("끝!").font(.largeTitle.bold())
                Text("\(session.words.count)개 중 \(score)개 맞힘").font(.title3)
                Button("처음으로", action: onFinish).buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: 화면 조각

    @ViewBuilder
    private func sentence(_ w: SavedWord) -> some View {
        if let b = blank {
            let filled = verdict != nil
            (Text(b.before)
                + Text(filled ? b.answer : b.display)
                    .bold()
                    .foregroundColor(filled ? (verdict == true ? .green : .red) : .accentColor)
                + Text(b.after))
        } else {
            // 문장에서 단어를 못 찾으면 뜻으로 묻기
            VStack(alignment: .leading, spacing: 4) {
                Text("이 뜻의 단어는?").font(.caption).foregroundStyle(.secondary)
                Text(w.summary)
                if verdict != nil { Text(w.surface).bold() }
            }
        }
    }

    private func hints(_ w: SavedWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("힌트: 한국어 자막") { showKoHint = true }
                    .disabled(w.sentenceKo.isEmpty || showKoHint)
                Button("힌트: 첫 글자") { showLetterHint = true }
                    .disabled(showLetterHint)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            if showKoHint && !w.sentenceKo.isEmpty {
                Text(w.sentenceKo).foregroundStyle(.blue)
            }
            if showLetterHint {
                Text(firstLetterHint(answer)).font(.title3.monospaced())
            }
        }
    }

    private func typing(_ w: SavedWord) -> some View {
        HStack {
            TextField("빈칸에 들어갈 말", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit { check(input, w) }
                .disabled(verdict != nil)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            Button("확인") { check(input, w) }
                .buttonStyle(.borderedProminent)
                .disabled(verdict != nil || input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func feedback(_ w: SavedWord, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "정답!" : "틀렸어요 · 정답: \(answer)",
                  systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(correct ? Color.green : Color.red)
            HStack(spacing: 16) {
                SpeakButton(text: answer, label: "단어 듣기")
                SpeakButton(text: w.sentenceEn, label: "문장 듣기")
            }
            .font(.subheadline)
            Text(w.summary).font(.subheadline)
            if !w.sentenceKo.isEmpty { Text(w.sentenceKo).font(.subheadline).foregroundStyle(.secondary) }
            if !session.practice {
                Text(correct ? "다음 복습: \(nextIntervalText(w))" : "10분 뒤에 다시 나와요")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(index + 1 < session.words.count ? "다음" : "결과 보기") { index += 1 }
                .buttonStyle(.borderedProminent)
        }
    }

    /// w 는 세션 시작 때의 값(답하기 전 단계)이므로 그 단계의 간격이 다음 복습까지의 기간
    private func nextIntervalText(_ w: SavedWord) -> String {
        "\(intervalDays[min(w.stage, intervalDays.count - 1)])일 뒤"
    }

    // MARK: 동작

    private func prepare() {
        input = ""
        verdict = nil
        showKoHint = false
        showLetterHint = false
        focused = word != nil
    }

    private func check(_ value: String, _ w: SavedWord) {
        guard verdict == nil else { return }
        let ok = isCorrect(value, w.target, blankAnswer: blank?.answer)
        verdict = ok
        if ok { score += 1 }
        // 답을 확인하면 정답 단어를 읽어 준다
        Speech.shared.say(answer, slow: !answer.contains(" "))
        if !session.practice {
            app.vocab.answer(id: w.id, correct: ok)
        }
    }
}
