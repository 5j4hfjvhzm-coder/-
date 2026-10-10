import SwiftUI
import UIKit

/// 시험 탭. 예전 "빈칸 단어장" 앱과 같은 방식:
/// 전체 퀴즈 / 전체 테스트 / ★ 헷갈리는 단어만, 이어서 하기, 틀린 문제 다시 풀기.
struct QuizView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            Group {
                if let q = app.quiz.run {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if q.finished {
                                QuizResultView(q: q)
                            } else {
                                QuizQuestionView(q: q)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    QuizHome()
                }
            }
            .navigationTitle("빈칸 시험")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if let t = app.quiz.toast {
                    Text(t)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - 첫 화면

private struct QuizHome: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let quiz = app.quiz
        let words = app.vocab.words
        let stars = words.filter(\.star).count
        List {
            if !quiz.data.sess.isEmpty {
                Section("이어서 하기") {
                    ForEach(quiz.data.sess) { o in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.label).font(.subheadline.weight(.semibold))
                                Text("\(o.i)/\(o.list.count) · \(o.t.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("이어하기") { quiz.resume(o.sid, words: words) }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .swipeActions {
                            Button("삭제", role: .destructive) { quiz.deleteSession(o.sid) }
                        }
                    }
                }
            }

            Section {
                Button {
                    quiz.start(.all, words: words)
                } label: {
                    Label("전체 퀴즈 (\(quiz.count(words))단어)", systemImage: "pencil.line")
                }
                .disabled(quiz.count(words) == 0)
                Button {
                    quiz.start(.test, words: words)
                } label: {
                    Label("전체 테스트 (\(quiz.count(words))단어)", systemImage: "checklist")
                }
                .disabled(quiz.count(words) == 0)
                Button {
                    quiz.start(.star, words: words)
                } label: {
                    Label("★ 헷갈리는 단어만 (\(stars))", systemImage: "star.fill")
                }
                .disabled(stars == 0)
                Toggle("★ 헷갈리는 단어는 빼고 풀기",
                       isOn: Binding(get: { quiz.data.skip }, set: { quiz.setSkip($0) }))
            } footer: {
                Text("퀴즈는 힌트(첫 글자)와 문장 읽기를 쓸 수 있고, 테스트는 힌트 없이 풀어요. 활용형·기본형 모두 정답으로 인정해요.")
            }

            if words.isEmpty {
                Text("영상 자막에서 단어를 탭해 저장하면 여기서 시험을 볼 수 있어요.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 문제

private struct QuizQuestionView: View {
    let q: QuizRun
    @Environment(AppModel.self) private var app
    @State private var answer = ""
    @FocusState private var focused: Bool

    var body: some View {
        if let id = q.currentID, let x = app.vocab.word(id: id) {
            content(x)
        } else {
            // 풀던 중에 단어장에서 지운 단어
            Text("삭제된 단어예요.").foregroundStyle(.secondary)
            Button("다음") { app.quiz.next() }.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func content(_ x: SavedWord) -> some View {
        let b = makeBlank(x.sentenceEn, x.target) ?? BlankQuestion(before: "", answer: x.surface, after: "", display: "_____")
        let done = q.done

        HStack(spacing: 10) {
            Button { app.quiz.run = nil } label: { Image(systemName: "xmark").font(.headline) }
                .foregroundStyle(.secondary)
                .accessibilityLabel("닫기")
            ProgressView(value: Double(q.i), total: Double(max(q.n, 1)))
            Text("\(q.i + 1)/\(q.n)").font(.footnote).monospacedDigit()
        }
        .padding(.bottom, 8)

        VStack(alignment: .leading, spacing: 0) {
            Text(q.isTest ? "테스트" : "퀴즈")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.12),
                            in: UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(x.summary).font(.title3.weight(.heavy)).foregroundStyle(.green)
                    if let pos = posKorean[x.pos] {
                        Text("(\(pos))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                sentence(b, done: done)
                    .font(.system(size: 22))
                    .lineSpacing(8)
                if done == nil {
                    TextField("빈칸에 들어갈 단어", text: $answer)
                        .font(.system(size: 20, weight: .heavy))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .focused($focused)
                        .onSubmit { check(x, b) }
                        .padding(12)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20))
        }

        if let done, !done.ok {
            Text("정답은 **\(b.answer)** 이에요.").hintBox()
        }
        if q.hint && done == nil {
            VStack(alignment: .leading, spacing: 6) {
                Text(quizHintText(b.answer))
                if !x.sentenceKo.isEmpty {
                    Text(x.sentenceKo).font(.subheadline)
                }
            }
            .hintBox()
        }

        HStack(spacing: 8) {
            Button("힌트 보기") { app.quiz.showHint() }
                .disabled(q.hint || done != nil || q.isTest)
            Button {
                app.vocab.toggleStar(id: x.id)
            } label: {
                Text(x.star ? "★ 헷갈려요" : "☆ 헷갈려요")
                    .foregroundStyle(x.star ? Color.orange : Color.accentColor)
            }
            .accessibilityLabel("헷갈리는 단어 표시")
            Button { Speech.shared.say(x.sentenceEn) } label: { Image(systemName: "speaker.wave.2.fill") }
                .disabled(q.isTest && done == nil)
                .accessibilityLabel("문장 읽기")
            Spacer(minLength: 0)
            Button(done == nil ? "확인" : "다음") { check(x, b) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .buttonStyle(.bordered)

        Toggle("정답 확인 후 문장 자동으로 읽기",
               isOn: Binding(get: { app.quiz.data.auto }, set: { app.quiz.setAuto($0) }))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        Button("💾 저장하고 나가기") { app.quiz.saveSession() }
            .buttonStyle(.bordered)
            .padding(.top, 4)
            .onAppear { focused = true }
    }

    /// 예문 + 빈칸. 입력하는 동안 빈칸에 글자가 보이고, 확인 후엔 정답이 색으로 표시돼요.
    private func sentence(_ b: BlankQuestion, done: QuizRun.Done?) -> Text {
        let blank: Text
        if let done {
            blank = Text(b.answer).bold().foregroundColor(done.ok ? .green : .red)
        } else {
            let typed = answer.trimmingCharacters(in: .whitespaces)
            let width = max(b.answer.count, 5)
            let shown = typed.isEmpty ? String(repeating: "\u{2007}", count: width) : typed
            blank = Text(" \(shown) ").bold().foregroundColor(.accentColor).underline(true, color: .accentColor)
        }
        return Text(b.before) + blank + Text(b.after)
    }

    private func check(_ x: SavedWord, _ b: BlankQuestion) {
        guard let run = app.quiz.run else { return }
        if run.done != nil {
            answer = ""
            app.quiz.next()
            focused = true
        } else if let ok = app.quiz.check(answer, word: x, blankAnswer: b.answer) {
            app.vocab.recordAnswer(id: x.id, correct: ok)
        } else {
            focused = true
        }
    }
}

// MARK: - 결과

private struct QuizResultView: View {
    let q: QuizRun
    @Environment(AppModel.self) private var app

    var body: some View {
        let wrong = q.uniqueWrong.compactMap { app.vocab.word(id: $0) }
        VStack(alignment: .leading, spacing: 10) {
            Text("\(q.isTest ? "테스트 결과" : "끝!") \(q.ok) / \(q.n) 정답")
                .font(.system(size: 28, weight: .heavy))
                .padding(.top, 20)
            Text(wrong.isEmpty ? "모두 맞혔어요!" : "틀린 단어를 확인해 보세요.")
                .font(.subheadline).foregroundStyle(.secondary)
            if !wrong.isEmpty {
                Text("틀린 단어").font(.headline).padding(.top, 8)
                VStack(spacing: 0) {
                    ForEach(wrong) { w in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(w.surface).font(.headline).frame(minWidth: 96, alignment: .leading)
                            Text(w.summary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if w.id != wrong.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            HStack(spacing: 8) {
                if !wrong.isEmpty {
                    Button("틀린 문제 다시 풀기 (\(wrong.count))") { app.quiz.retryWrong() }
                        .buttonStyle(.borderedProminent)
                }
                Button("처음부터 다시") { app.quiz.restart(words: app.vocab.words) }
                    .buttonStyle(.bordered)
                Button("목록으로") { app.quiz.run = nil }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 6)
        }
    }
}

private extension View {
    func hintBox() -> some View {
        self
            .font(.system(size: 15))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
    }
}
