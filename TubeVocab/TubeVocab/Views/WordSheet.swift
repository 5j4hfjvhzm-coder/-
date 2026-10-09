import SwiftUI
import UIKit

/// 자막 단어를 탭하면 뜨는 사전 시트. 뜻을 골라 "모르는 단어로 저장".
struct WordSheet: View {
    let ctx: WordContext
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var result: LookupResult?
    @State private var selected: DictSelection?
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
                        DictionaryView(result: result, selectedKey: selected?.key) { s in
                            selected = s
                            saved = false
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
                    }
                }
                .padding(.vertical, 6)
            }

            Button(action: save) {
                Text(saved ? "저장했어요 ✓" : selected == nil ? "뜻을 하나 골라 주세요" : "모르는 단어로 저장")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected == nil || saved)
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

    private func save() {
        guard let sel = selected, let store = app.dict else { return }
        app.vocab.add(Self.makeWord(store: store, ctx: ctx, selection: sel))
        saved = true
    }

    static func makeWord(store: DictStore, ctx: WordContext, selection sel: DictSelection) -> SavedWord {
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
        let koGloss = sel.entry.source == .ko
        return SavedWord(
            surface: surface,
            lemma: lemma,
            forms: forms,
            pos: sel.entry.pos,
            sense: sel.sense.gloss,
            senseTags: sel.sense.tags,
            senseKo: koGloss ? sel.sense.gloss : sel.sense.ko.joined(separator: ", "),
            sentenceEn: ctx.sentenceEn,
            sentenceKo: ctx.sentenceKo,
            videoId: ctx.videoId,
            timeMs: ctx.timeMs
        )
    }
}
