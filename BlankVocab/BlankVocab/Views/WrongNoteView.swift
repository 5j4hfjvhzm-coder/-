import SwiftUI

/// 오답노트: 많이 틀린 단어부터 모아 보고, 바로 다시 풀어요.
struct WrongNoteView: View {
    let bookIDs: [Int]
    @Environment(Store.self) private var store
    @State private var confirmClear = false

    var body: some View {
        let words = store.words(in: bookIDs)
            .filter { $0.wrongCount > 0 }
            .sorted { $0.wrongCount != $1.wrongCount ? $0.wrongCount > $1.wrongCount : $0.w < $1.w }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if words.isEmpty {
                    Text("아직 틀린 단어가 없어요. 👍")
                        .foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    Text("틀린 단어 \(words.count)개 · 많이 틀린 순서")
                        .font(.subheadline).foregroundStyle(Theme.sub)
                    FlowLayout {
                        Button("빈칸 퀴즈로 다시 풀기") {
                            store.startWords(words, mode: .wrongNote, ids: bookIDs, label: "📝 오답노트")
                        }
                        .buttonStyle(.pillPrimary)
                        Button("가장 많이 틀린 10개만") {
                            store.startWords(Array(words.prefix(10)), mode: .wrongNote, ids: bookIDs, label: "📝 오답노트 TOP 10")
                        }
                        .buttonStyle(.pill)
                    }
                    VStack(spacing: 0) {
                        ForEach(words) { w in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.w).font(.headline)
                                    Text(w.m).font(.subheadline).foregroundStyle(Theme.sub)
                                }
                                Spacer(minLength: 0)
                                Text("\(w.wrongCount)회")
                                    .font(.footnote.weight(.heavy))
                                    .foregroundStyle(Theme.bad)
                                Button { Speech.shared.say(w.w) } label: { Image(systemName: "speaker.wave.2") }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(Theme.sub)
                                    .accessibilityLabel("읽기")
                                Button { store.toggleStar(wordID: w.id) } label: {
                                    Image(systemName: w.star ? "star.fill" : "star")
                                        .foregroundStyle(w.star ? Theme.starOn : Theme.sub)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("헷갈리는 단어 표시")
                            }
                            .padding(.vertical, 10)
                            if w.id != words.last?.id { Divider().overlay(Theme.line) }
                        }
                    }
                    .card()
                    Button("오답 기록 지우기", role: .destructive) { confirmClear = true }
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationTitle("오답노트")
        .navigationBarTitleDisplayMode(.inline)
        .alert("오답 기록을 지울까요?", isPresented: $confirmClear) {
            Button("지우기", role: .destructive) { store.clearWrongCount(bookIDs) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("단어는 그대로 있고, 틀린 횟수만 0으로 돌아가요.")
        }
    }
}
