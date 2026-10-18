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
    /// 네이버 사전 상태 안내 (불러오는 중 / 연결 실패)
    @State private var naverNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ctx.words[ctx.tap]).font(.title.bold())
                SpeakButton(text: ctx.words[ctx.tap]).font(.title3)
                Spacer()
                Button("닫기") { dismiss() }
            }
            Text(ctx.sentenceEn)
                .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            if let naverNote {
                Text(naverNote).font(.caption).foregroundStyle(.secondary)
            }

            ScrollView {
                Group {
                    if let result {
                        DictionaryView(result: result, selectedKeys: Set(selected.map(\.key))) { s in
                            toggle(s)
                        }
                    } else if let err = app.dictError, naverNote == nil {
                        Text(err).foregroundStyle(.red)
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
            // 1) 내장 사전으로 바로 (기본형·숙어 찾기도 여기서)
            var local = LookupResult.empty
            local.surface = ctx.words[ctx.tap]
            if let store = app.dict {
                local = lookupInContext(store, words: ctx.words, tap: ctx.tap)
                result = local
            }
            // 2) 네이버 사전: 숙어(gave up → give up)와 기본형(went → go)으로 찾아 맨 위에
            naverNote = "네이버 사전 찾는 중…"
            let surface = normalizeWord(ctx.words[ctx.tap])
            let wordQuery = local.lemmas.first { $0 != surface } ?? surface
            let phraseQueries = Array(local.phrases.prefix(2).map { $0.match.phrase.lowercased() })
            async let wordHits = NaverDictService.shared.search(wordQuery)
            var phraseHits: [String: [Entry]] = [:]
            var failed = false
            for q in phraseQueries {
                if let hits = await NaverDictService.shared.search(q) { phraseHits[q] = hits } else { failed = true }
            }
            let words = await wordHits
            if words == nil { failed = true }
            guard !Task.isCancelled else { return }
            // 고른 뜻은 그대로 두고 목록만 바꾼다
            result = mergeNaver(local, word: words ?? [], phrases: phraseHits)
            naverNote = failed ? "네이버 사전에 연결하지 못해서 내장 사전으로 보여 줘요." : nil
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
        guard !selected.isEmpty else { return }
        // 내장 사전은 활용형 목록(정답 인정·하이라이트용)에만 쓴다
        let store = app.dict ?? MemoryDictStore(entries: [], forms: [])
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
                ko: s.entry.source == .en ? s.sense.ko.joined(separator: ", ") : s.sense.gloss,
                tags: s.sense.tags,
                pos: s.entry.pos
            )
        })
        return word
    }
}
