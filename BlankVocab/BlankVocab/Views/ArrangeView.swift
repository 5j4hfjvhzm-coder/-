import SwiftUI

/// 문장 배열: 섞인 단어 카드를 눌러 예문을 순서대로 완성해요.
struct ArrangeView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct Token: Identifiable, Hashable {
        let id: Int
        let text: String
    }

    @State private var items: [Word] = []
    @State private var index = 0
    @State private var pool: [Token] = []
    @State private var placed: [Token] = []
    @State private var checked: Bool?
    @State private var correct = 0
    @State private var wrong: [Word] = []
    @State private var started = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if items.isEmpty && started {
                    Text("예문(3~14단어)이 있는 단어가 없어요. CSV에 예문(E) 열을 넣어 주세요.")
                        .foregroundStyle(Theme.sub)
                        .padding(.top, 40)
                } else if index < items.count {
                    question(items[index])
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
        .navigationTitle("문장 배열")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !started else { return }
            started = true
            build()
        }
    }

    @ViewBuilder
    private func question(_ w: Word) -> some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(index), total: Double(max(items.count, 1)))
                .tint(Theme.pri)
            Text("\(index + 1)/\(items.count)").font(.footnote).monospacedDigit()
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("단어 카드를 순서대로 눌러 문장을 완성하세요")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.sub)
            Text(w.sentenceKO.isEmpty ? "\(w.w) · \(w.m)" : w.sentenceKO)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.ok)
        }
        .card()

        // 내가 만든 문장
        FlowLayout(spacing: 8) {
            ForEach(placed) { t in
                Button { unplace(t) } label: { chip(t.text, filled: true) }
                    .buttonStyle(.plain)
                    .disabled(checked != nil)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 2))

        // 남은 카드
        FlowLayout(spacing: 8) {
            ForEach(pool) { t in
                Button { place(t) } label: { chip(t.text, filled: false) }
                    .buttonStyle(.plain)
                    .disabled(checked != nil)
            }
        }

        if let ok = checked {
            Text(ok ? "정답이에요! 🎉" : "정답 문장")
                .font(.headline)
                .foregroundStyle(ok ? Theme.ok : Theme.bad)
            Text(w.sentenceEN)
                .font(.body.weight(.semibold))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.soft, in: RoundedRectangle(cornerRadius: 14))
        }

        FlowLayout {
            if checked == nil {
                Button("확인") { check(w) }
                    .buttonStyle(.pillPrimary)
                    .disabled(!pool.isEmpty)
                Button("다시 놓기") { reset(w) }
                    .buttonStyle(.pill)
                    .disabled(placed.isEmpty)
            } else {
                Button(index + 1 < items.count ? "다음" : "결과 보기") { next() }
                    .buttonStyle(.pillPrimary)
            }
            Button { Speech.shared.say(w.sentenceEN) } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(.pill)
                .disabled(checked == nil)
                .accessibilityLabel("문장 읽기")
        }
    }

    private var borderColor: Color {
        switch checked {
        case .some(true): return Theme.ok
        case .some(false): return Theme.bad
        case .none: return Theme.line
        }
    }

    private func chip(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(filled ? Theme.ink : Theme.pri)
            .background(filled ? Theme.soft : Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: filled ? 0 : 1.5))
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("끝! \(correct) / \(items.count) 정답")
                .font(.system(size: 28, weight: .heavy))
                .padding(.top, 20)
            FlowLayout {
                if !wrong.isEmpty {
                    Button("틀린 문장만 다시 (\(wrong.count))") { build(from: wrong) }
                        .buttonStyle(.pillPrimary)
                }
                Button("새로 풀기") { build() }
                    .buttonStyle(.pill)
                Button("나가기") { dismiss() }
                    .buttonStyle(.pill)
            }
        }
    }

    // MARK: - 동작

    static func tokens(_ sentence: String) -> [String] {
        sentence.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    private func place(_ t: Token) {
        pool.removeAll { $0.id == t.id }
        placed.append(t)
    }

    private func unplace(_ t: Token) {
        placed.removeAll { $0.id == t.id }
        pool.append(t)
    }

    private func reset(_ w: Word) {
        pool = (placed + pool).sorted { $0.id < $1.id }.shuffled()
        placed = []
    }

    private func check(_ w: Word) {
        let answer = Self.tokens(w.sentenceEN).map(Blank.normalize)
        // 같은 단어가 두 번 나와도 되게 글자로 비교해요.
        let mine = placed.map { Blank.normalize($0.text) }
        let ok = mine == answer
        checked = ok
        if ok { correct += 1 } else { wrong.append(w) }
        store.record(w.id, correct: ok)
        Speech.shared.say(w.sentenceEN)
    }

    private func next() {
        index += 1
        load()
    }

    private func load() {
        checked = nil
        placed = []
        guard index < items.count else { pool = []; return }
        let words = Self.tokens(items[index].sentenceEN)
        var shuffled = words.enumerated().map { Token(id: $0.offset, text: $0.element) }.shuffled()
        // 우연히 원래 순서 그대로 섞이면 한 번 더 섞어요.
        if shuffled.map(\.id) == Array(0..<shuffled.count), shuffled.count > 1 { shuffled.reverse() }
        pool = shuffled
    }

    private func build(from source: [Word]? = nil) {
        let candidates = (source ?? store.words(in: bookIDs)).filter {
            let n = Self.tokens($0.sentenceEN).count
            return n >= 3 && n <= 14
        }
        items = Array(candidates.shuffled().prefix(source == nil ? 10 : candidates.count))
        index = 0
        correct = 0
        wrong = []
        load()
    }
}
