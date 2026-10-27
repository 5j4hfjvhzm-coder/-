import SwiftUI

/// 4지선다: 단어 보고 뜻 고르기 / 뜻 보고 단어 고르기 / 실력 진단(20문제)
struct ChoiceQuizView: View {
    let bookIDs: [Int]
    let kind: ChoiceKind
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct Question {
        var word: Word
        /// true면 영어 단어를 보고 뜻을 골라요.
        var askMeaning: Bool
        var options: [Word]
    }

    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var picked: String?
    @State private var correctIDs: Set<String> = []
    @State private var wrong: [Word] = []
    @State private var started = false

    private var title: String {
        switch kind {
        case .meaning: return "뜻 고르기"
        case .word: return "단어 고르기"
        case .levelTest: return "실력 진단"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if questions.isEmpty && started {
                    Text("단어가 4개 이상 있어야 4지선다를 만들 수 있어요.")
                        .foregroundStyle(Theme.sub)
                        .padding(.top, 40)
                } else if index < questions.count {
                    question(questions[index])
                } else if started {
                    result
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !started else { return }
            started = true
            build()
        }
    }

    // MARK: - 문제

    @ViewBuilder
    private func question(_ q: Question) -> some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(index), total: Double(max(questions.count, 1)))
                .tint(Theme.pri)
            Text("\(index + 1)/\(questions.count)").font(.footnote).monospacedDigit()
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(q.askMeaning ? "이 단어의 뜻은?" : "이 뜻의 영어 단어는?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.sub)
            HStack(alignment: .firstTextBaseline) {
                Text(q.askMeaning ? q.word.w : q.word.m)
                    .font(.system(size: q.askMeaning ? 32 : 26, weight: .heavy))
                    .foregroundStyle(q.askMeaning ? Theme.ink : Theme.ok)
                Spacer()
                if q.askMeaning {
                    Button { Speech.shared.say(q.word.w) } label: { Image(systemName: "speaker.wave.2.fill") }
                        .buttonStyle(.pill)
                        .accessibilityLabel("읽기")
                }
            }
        }
        .card()

        VStack(spacing: 10) {
            ForEach(q.options) { o in
                Button { pick(o, in: q) } label: {
                    HStack {
                        Text(q.askMeaning ? o.m : o.w)
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if picked != nil && o.id == q.word.id { Image(systemName: "checkmark.circle.fill") }
                        else if picked == o.id { Image(systemName: "xmark.circle.fill") }
                    }
                    .foregroundStyle(optionColor(o, q))
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(optionBackground(o, q), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
            }
        }

        if picked != nil {
            if !q.word.e.isEmpty {
                Text(q.word.e)
                    .font(.subheadline)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.soft, in: RoundedRectangle(cornerRadius: 14))
            }
            WordDetailCard(word: q.word)
            Button(index + 1 < questions.count ? "다음" : "결과 보기") {
                picked = nil
                index += 1
            }
            .buttonStyle(.pillPrimary)
        }
    }

    private func optionColor(_ o: Word, _ q: Question) -> Color {
        guard let picked else { return Theme.ink }
        if o.id == q.word.id { return .white }
        if o.id == picked { return .white }
        return Theme.sub
    }

    private func optionBackground(_ o: Word, _ q: Question) -> Color {
        guard let picked else { return Theme.card }
        if o.id == q.word.id { return Theme.ok }
        if o.id == picked { return Theme.bad }
        return Theme.card
    }

    private func pick(_ o: Word, in q: Question) {
        guard picked == nil else { return }
        picked = o.id
        let ok = o.id == q.word.id
        if ok { correctIDs.insert(q.word.id) } else { wrong.append(q.word) }
        store.record(q.word.id, correct: ok)
        if q.askMeaning == false || ok { Speech.shared.say(q.word.w) }
    }

    // MARK: - 결과

    private var result: some View {
        let total = questions.count
        let score = total == 0 ? 0 : Int((Double(correctIDs.count) / Double(total) * 100).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            Text(kind == .levelTest ? "진단 결과" : "끝!")
                .font(.system(size: 28, weight: .heavy))
                .padding(.top, 20)
            Text("\(correctIDs.count) / \(total) 정답 · \(score)점")
                .font(.title3.weight(.semibold))
            if kind == .levelTest {
                Text(verdict(score))
                    .font(.subheadline)
                    .foregroundStyle(Theme.sub)
                if !correctIDs.isEmpty {
                    Button("맞힌 단어 \(correctIDs.count)개를 '외움'으로 표시하고 오늘의 학습에서 빼기") {
                        store.markMastered(correctIDs)
                        store.show("\(correctIDs.count)개를 외운 단어로 표시했어요.")
                    }
                    .buttonStyle(.pill)
                }
            }
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
                    Button("틀린 단어만 다시 (\(wrong.count))") { build(from: wrong) }
                        .buttonStyle(.pillPrimary)
                }
                Button("새로 풀기") { build() }
                    .buttonStyle(.pill)
                Button("나가기") { dismiss() }
                    .buttonStyle(.pill)
            }
        }
    }

    private func verdict(_ score: Int) -> String {
        switch score {
        case 90...: return "대부분 알고 있어요! 맞힌 단어는 외움으로 표시하고, 틀린 단어 위주로 오늘의 학습을 해 보세요."
        case 70..<90: return "꽤 잘 알고 있어요. 틀린 단어를 오답노트와 오늘의 학습으로 복습해요."
        case 40..<70: return "절반 정도 알고 있어요. 하루 목표를 정해서 매일 조금씩 외워 봐요."
        default: return "처음 보는 단어가 많아요. 하루 목표를 5~10개로 시작해 보세요."
        }
    }

    // MARK: - 문제 만들기

    private func build(from source: [Word]? = nil) {
        let pool = store.words(in: bookIDs).filter { !$0.w.isEmpty && !$0.m.isEmpty }
        // 보기가 4개가 되도록 다른 단어장 단어도 오답 보기로 써요.
        let distractorPool = pool.count >= 4 ? pool : store.allWords.filter { !$0.w.isEmpty && !$0.m.isEmpty }
        guard distractorPool.count >= 4 else {
            questions = []
            index = 0
            return
        }
        var targets = (source ?? pool).shuffled()
        if source == nil { targets = Array(targets.prefix(20)) }

        questions = targets.map { w in
            let ask: Bool
            switch kind {
            case .meaning: ask = true
            case .word: ask = false
            case .levelTest: ask = Bool.random()
            }
            var others: [Word] = []
            for d in distractorPool.shuffled() where others.count < 3 {
                if d.id == w.id || d.w.lowercased() == w.w.lowercased() || d.m == w.m { continue }
                if others.contains(where: { $0.w.lowercased() == d.w.lowercased() || $0.m == d.m }) { continue }
                others.append(d)
            }
            return Question(word: w, askMeaning: ask, options: (others + [w]).shuffled())
        }
        .filter { $0.options.count == 4 }
        index = 0
        picked = nil
        correctIDs = []
        wrong = []
    }
}
