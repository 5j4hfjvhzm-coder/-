import SwiftUI
import UIKit

/// 자막 단어를 탭하면 뜨는 사전 시트. 뜻을 여러 개 골라 한 단어로 "모르는 단어로 저장".
struct WordSheet: View {
    let ctx: WordContext
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var result: LookupResult?
    /// 고른 순서대로
    @State private var selected: [DictSelection] = []
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ctx.words[ctx.tap]).font(.title.bold())
                Spacer()
                Button("닫기") { dismiss() }
            }
            Text(ctx.sentenceEn)
                .font(.footnote).foregroundStyle(.secondary).lineLimit(2)

            ScrollView {
                Group {
                    if let err = app.dictError {
                        Text(err).foregroundStyle(.red)
                    } else if let result {
                        DictionaryView(result: result, selectedKeys: Set(selected.map(\.key))) { s in
                            toggle(s)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
                    }
                }
                .padding(.vertical, 6)
            }

            Button(action: save) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty || saved)
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            if let store = app.dict {
                result = lookupInContext(store, words: ctx.words, tap: ctx.tap)
            }
        }
    }

    private var buttonTitle: String {
        if saved { return "저장했어요 ✓" }
        if selected.isEmpty { return "뜻을 골라 주세요 (여러 개 가능)" }
        return "뜻 \(selected.count)개로 저장"
    }

    /// 탭하면 고르고, 다시 탭하면 해제. 숙어 뜻과 단어 뜻은 섞지 않는다 (다른 쪽을 고르면 새로 시작).
    private func toggle(_ s: DictSelection) {
        saved = false
        if let i = selected.firstIndex(where: { $0.key == s.key }) {
            selected.remove(at: i)
        } else if let first = selected.first, Self.head(first) != Self.head(s) {
            selected = [s]
        } else {
            selected.append(s)
        }
    }

    private static func head(_ s: DictSelection) -> String {
        s.phraseSurface != nil ? "phrase:\(s.entry.word.lowercased())" : "word"
    }

    private func save() {
        guard !selected.isEmpty, let store = app.dict else { return }
        app.vocab.add(Self.makeWord(store: store, ctx: ctx, selections: selected))
        saved = true
    }

    static func makeWord(store: DictStore, ctx: WordContext, selections: [DictSelection]) -> SavedWord {
        let sel = selections[0]
        let surface = sel.phraseSurface ?? ctx.words[ctx.tap]
        let lemma = sel.entry.word.lowercased()
        var forms: [String]
        if sel.phraseSurface != nil {
            // give up → gave up / given up / giving up ...
            let parts = lemma.split(separator: " ").map(String.init)
            let rest = parts.dropFirst().joined(separator: " ")
            forms = store.formsOf(parts[0]).map { "\($0) \(rest)" }
        } else {
            forms = store.formsOf(lemma)
        }
        forms = uniqued([normalizeWord(surface)] + forms)
        var word = SavedWord(
            surface: surface,
            lemma: lemma,
            forms: forms,
            pos: sel.entry.pos,
            sense: "",
            senseTags: [],
            senseKo: "",
            sentenceEn: ctx.sentenceEn,
            sentenceKo: ctx.sentenceKo,
            videoId: ctx.videoId,
            timeMs: ctx.timeMs
        )
        word.setMeanings(selections.map { s in
            Meaning(
                gloss: s.sense.gloss,
                ko: s.entry.source == .ko ? s.sense.gloss : s.sense.ko.joined(separator: ", "),
                tags: s.sense.tags,
                pos: s.entry.pos
            )
        })
        return word
    }
}
