import SwiftUI

struct ProblemCard: View {
    @EnvironmentObject var store: Store
    let problem: Problem
    let index: Int
    let sheetID: String
    let done: Bool
    var focus: FocusState<String?>.Binding

    @State private var text: String
    @State private var showWhy = false
    @State private var retry = ""
    @State private var retryResult: Bool?
    /// nil 이면 설정(한국어 뜻 펼쳐 보기)을 따라요
    @State private var showKo: Bool?
    @State private var showPad: Bool

    private var koVisible: Bool { showKo ?? store.settings.showKorean }

    init(problem: Problem, index: Int, sheetID: String, done: Bool, focus: FocusState<String?>.Binding) {
        self.problem = problem
        self.index = index
        self.sheetID = sheetID
        self.done = done
        self.focus = focus
        _text = State(initialValue: problem.userAnswer)
        // 필기한 적이 있으면 연습장을 펼쳐 둬요
        _showPad = State(initialValue: DrawingStore.exists(problem.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            top
            TappableText(text: problem.text)
            if let ko = problem.ko {
                korean(ko)
            }
            if let e = problem.expr {
                ExprView(expr: e + " =")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
            if showPad {
                ScratchPad(problemID: problem.id)
            }
            if problem.kind == .choice { choices } else { numberInput }
            if done { result }
        }
        .padding()
        // 2열일 때 옆 카드와 높이를 맞춰요
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: done ? 2 : 0)
        )
        .onChange(of: text) { _, v in
            if !done { store.setAnswer(v, problem: problem.id, sheet: sheetID) }
        }
    }

    private var borderColor: Color {
        guard done else { return .clear }
        return problem.correct == true ? .green.opacity(0.6) : .red.opacity(0.6)
    }

    private var top: some View {
        HStack {
            Text("Q\(index)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(problem.unit.color))
            Text("Unit \(problem.unit.number) · \(problem.unit.english)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if done {
                Image(systemName: problem.correct == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(problem.correct == true ? .green : .red)
            }
            Button { withAnimation { showPad.toggle() } } label: {
                Image(systemName: showPad ? "pencil.circle.fill" : "pencil.circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showPad ? "연습장 닫기" : "연습장 열기 (필기)")
            Button { Speech.shared.say(problem) } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("문제 읽어주기")
        }
    }

    // MARK: - 한국어 뜻

    private func korean(_ ko: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showKo = !koVisible }
            } label: {
                Label(koVisible ? "한국어 뜻 숨기기" : "한국어 뜻 보기",
                      systemImage: koVisible ? "chevron.up.circle" : "character.book.closed")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderless)
            if koVisible {
                Text(ko)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.15)))
            }
        }
    }

    // MARK: - 입력

    private var numberInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Answer", text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3.monospacedDigit())
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)))
                    .disabled(done)
                    .focused(focus, equals: problem.id)
                    .submitLabel(.next)
                if let u = problem.unitLabel {
                    Text(u).font(.title3).foregroundStyle(.secondary)
                }
            }
            if !done && (problem.unit == .fractionMul || problem.answer.contains("/")) {
                Text("분수는 3/4, 대분수는 1 2/3 처럼 띄어서 써요")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var choices: some View {
        VStack(spacing: 8) {
            ForEach(problem.choices ?? [], id: \.self) { c in
                Button {
                    guard !done else { return }
                    text = c
                } label: {
                    HStack {
                        Image(systemName: icon(for: c))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c).multilineTextAlignment(.leading)
                            if koVisible, let k = Glossary.choiceKo[c] {
                                Text(k).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .foregroundStyle(.primary)
                    .background(RoundedRectangle(cornerRadius: 10).fill(fill(for: c)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func icon(for c: String) -> String {
        if done && c == problem.answer { return "checkmark.circle.fill" }
        if done && c == text { return "xmark.circle.fill" }
        return c == text ? "largecircle.fill.circle" : "circle"
    }

    private func fill(for c: String) -> Color {
        if done {
            if c == problem.answer { return .green.opacity(0.2) }
            if c == text { return .red.opacity(0.2) }
            return Color(.tertiarySystemFill)
        }
        return c == text ? Color.orange.opacity(0.25) : Color(.tertiarySystemFill)
    }

    // MARK: - 채점 결과

    private var result: some View {
        VStack(alignment: .leading, spacing: 8) {
            if problem.kind == .number {
                HStack(alignment: .firstTextBaseline) {
                    Text("Answer:").bold()
                    Text(problem.answer + (problem.unitLabel.map { " \($0)" } ?? ""))
                        .font(.body.monospacedDigit().bold())
                        .foregroundStyle(.green)
                }
                if problem.correct == true, let a = Frac.parse(problem.answer), let b = Frac.parse(text),
                   a == b, normalized(text) != normalized(problem.answer), problem.answer.contains("/") {
                    Text("정답! 가장 간단한 꼴은 \(problem.answer) 이에요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            DisclosureGroup(isExpanded: $showWhy) {
                TappableText(text: problem.explanation, font: .callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } label: {
                Label("풀이 보기 (Solution)", systemImage: "lightbulb")
                    .font(.callout.bold())
            }
            .onAppear { if problem.correct != true { showWhy = true } }

            if problem.correct != true && problem.kind == .number { retryBox }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill).opacity(0.6)))
    }

    /// 틀린 문제 다시 풀어보기 (점수는 바뀌지 않아요)
    private var retryBox: some View {
        HStack {
            TextField("다시 풀어보기", text: $retry)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground)))
                .onChange(of: retry) { _, _ in retryResult = nil }
            Button("확인") {
                retryResult = store.retryCheck(retry, problem: problem.id, sheet: sheetID)
            }
            .buttonStyle(.bordered)
            .disabled(retry.trimmingCharacters(in: .whitespaces).isEmpty)
            if let r = retryResult {
                Image(systemName: r ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(r ? .green : .red)
            }
        }
    }

    private func normalized(_ s: String) -> String {
        s.replacingOccurrences(of: ",", with: "").split(separator: " ").joined(separator: " ")
    }
}

/// 식을 크게 보여줘요. "3/4" 같은 분수는 세로로 그려요.
struct ExprView: View {
    let expr: String

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(Array(expr.split(separator: " ").map(String.init).enumerated()), id: \.offset) { _, token in
                if let slash = token.firstIndex(of: "/"), token.count > 2 {
                    VStack(spacing: 4) {
                        Text(token[..<slash])
                        Text(token[token.index(after: slash)...])
                    }
                    .padding(.horizontal, 3)
                    .overlay(Rectangle().frame(height: 2))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                } else {
                    Text(token)
                }
            }
        }
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
