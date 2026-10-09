import SwiftUI

struct QuizView: View {
    @Environment(Store.self) private var store
    @State private var answer = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let q = store.quiz {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if q.finished {
                            ResultView(q: q)
                        } else if let x = q.current {
                            question(q, x)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder
    private func question(_ q: Quiz, _ x: Word) -> some View {
        let b = Blank(x)
        let done = q.done

        HStack(spacing: 10) {
            Button { store.quiz = nil } label: { Image(systemName: "xmark").font(.headline) }
                .foregroundStyle(Theme.sub)
                .accessibilityLabel("닫기")
            ProgressView(value: Double(q.i), total: Double(max(q.n, 1)))
                .tint(Theme.pri)
            Text("\(q.i + 1)/\(q.n)").font(.footnote).monospacedDigit()
        }
        .padding(.bottom, 12)

        VStack(alignment: .leading, spacing: 0) {
            Text(q.isTest ? "테스트" : "퀴즈")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.pri)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Theme.soft, in: UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(x.m).font(.title3.weight(.heavy)).foregroundStyle(Theme.ok)
                    if !x.p.isEmpty { Text("(\(x.p))").font(.footnote).foregroundStyle(Theme.sub) }
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
                        .onSubmit(check)
                        .field()
                        .padding(.top, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Theme.card, in: UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20))
        }

        if let done, !done.ok {
            Text("정답은 **\(b.ans)** 이에요.")
                .hintBox()
            Button("🤖 AI로 틀린 이유 설명") { Task { await store.explainWrong() } }
                .buttonStyle(.pill)
                .disabled(q.explaining)
        }
        if !q.explanation.isEmpty {
            Text(q.explanation)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.soft, in: RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
        }
        if q.hint && done == nil {
            Text(b.hintText).hintBox()
        }

        FlowLayout {
            Button("힌트 보기") { store.showHint() }
                .buttonStyle(.pill)
                .disabled(q.hint || done != nil || q.isTest)
            Button {
                store.toggleStar(wordID: x.id)
            } label: {
                Text(x.star ? "★ 헷갈려요" : "☆ 헷갈려요")
                    .foregroundStyle(x.star ? Color(hex: 0xB88700) : Theme.pri)
            }
            .buttonStyle(.pill)
            .accessibilityLabel("헷갈리는 단어 표시")
            Button { Speech.shared.say(b.fullSentence) } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(.pill)
                .disabled(q.isTest && done == nil)
                .accessibilityLabel("문장 읽기")
            Button(done == nil ? "확인" : "다음", action: check)
                .buttonStyle(.pillPrimary)
                .keyboardShortcut(.defaultAction)
        }

        Toggle("정답 확인 후 문장 자동으로 읽기", isOn: Binding(get: { store.data.auto }, set: { store.setAuto($0) }))
            .font(.subheadline)
            .foregroundStyle(Theme.sub)
            .tint(Theme.pri)
            .padding(.top, 10)
        Button("💾 저장하고 나가기") { store.saveSession() }
            .buttonStyle(.pill)
            .padding(.top, 4)
            .onAppear { focused = true }
    }

    /// 예문 + 빈칸. 입력하는 동안 빈칸에 글자가 보이고, 확인 후엔 정답이 색으로 표시돼요.
    private func sentence(_ b: Blank, done: Quiz.Done?) -> Text {
        let blank: Text
        if let done {
            blank = Text(b.ans).bold().foregroundColor(done.ok ? Theme.ok : Theme.bad)
        } else {
            let typed = answer.trimmingCharacters(in: .whitespaces)
            let width = max(b.ans.count, 5)
            let shown = typed.isEmpty ? String(repeating: "\u{2007}", count: width) : typed
            blank = Text(" \(shown) ").bold().foregroundColor(Theme.pri).underline(true, color: Theme.pri)
        }
        return Text(b.pre) + blank + Text(b.post)
    }

    private func check() {
        guard let q = store.quiz else { return }
        if q.done != nil {
            answer = ""
            store.next()
            focused = true
        } else {
            store.check(answer)
            if store.quiz?.done == nil { focused = true }
        }
    }
}

private struct ResultView: View {
    let q: Quiz
    @Environment(Store.self) private var store

    var body: some View {
        let wrong = q.uniqueWrong
        VStack(alignment: .leading, spacing: 10) {
            Text("\(q.isTest ? "테스트 결과" : "끝!") \(q.ok) / \(q.n) 정답")
                .font(.system(size: 28, weight: .heavy))
                .padding(.top, 20)
            Text(wrong.isEmpty ? "모두 맞혔어요!" : "틀린 단어를 확인해 보세요.")
                .font(.subheadline).foregroundStyle(Theme.sub)
            if !wrong.isEmpty {
                SectionTitle("틀린 단어")
                VStack(spacing: 0) {
                    ForEach(wrong) { w in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(w.w).font(.headline).frame(minWidth: 96, alignment: .leading)
                            Text(w.m)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if w.id != wrong.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .card()
            }
            FlowLayout {
                if !wrong.isEmpty {
                    Button("틀린 문제 다시 풀기 (\(wrong.count))") { store.retryWrong() }
                        .buttonStyle(.pillPrimary)
                }
                Button("처음부터 다시") { store.restart() }
                    .buttonStyle(.pill)
                Button(q.ids != nil ? "목록으로" : "단어장으로") { store.quiz = nil }
                    .buttonStyle(.pill)
            }
            .padding(.top, 6)
        }
    }
}

private extension View {
    func hintBox() -> some View {
        self
            .font(.system(size: 15))
            .foregroundStyle(Theme.hintInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.hint, in: RoundedRectangle(cornerRadius: 16))
    }
}
