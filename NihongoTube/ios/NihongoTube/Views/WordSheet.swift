import SwiftUI
import UIKit

/// 자막 단어를 탭하면 뜨는 사전 시트. 뜻을 여러 개 골라 한 단어로 "모르는 단어로 저장".
struct WordSheet: View {
    let ctx: WordContext
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var results: [LookupResult]?
    @State private var pick = 0
    /// 고른 항목 번호
    @State private var selected: Set<Int> = []
    @State private var saved = false

    private var current: LookupResult? {
        guard let results, pick < results.count else { return nil }
        return results[pick]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let r = current {
                    Text(r.term).font(.largeTitle.bold())
                    if !r.reading.isEmpty && r.reading != r.term {
                        Text(r.reading).font(.title3).foregroundStyle(.secondary)
                    }
                    SpeakButton(text: r.term).font(.title3)
                } else {
                    Text(String(Array(ctx.sentence).dropFirst(ctx.at).prefix(6))).font(.title.bold())
                }
                Spacer()
                Button("닫기") { dismiss() }
            }
            if let r = current, !r.reasons.isEmpty {
                Text("\(r.surface) ← \(r.reasons.joined(separator: " · "))")
                    .font(.caption).foregroundStyle(Color.accentColor)
            }
            contextLine
            if let results, results.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(results.prefix(8).enumerated()), id: \.offset) { i, r in
                            Button(r.term) { choose(i) }
                                .buttonStyle(.bordered)
                                .tint(i == pick ? Color.accentColor : Color.secondary)
                                .controlSize(.small)
                        }
                    }
                }
            }

            ScrollView {
                Group {
                    if let err = app.dictError {
                        Text(err).foregroundStyle(.red)
                    } else if let r = current {
                        EntryList(entries: r.entries, mainReading: r.reading, selected: selected) { k in
                            saved = false
                            if selected.contains(k) { selected.remove(k) } else { selected.insert(k) }
                        }
                    } else if results != nil {
                        Text("사전에 없는 말이에요. 앞뒤 글자를 눌러 보거나 단어장 탭의 사전 검색에서 찾아보세요.")
                            .foregroundStyle(.secondary)
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
            .disabled(selected.isEmpty || saved || current == nil)
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            guard let store = app.dict else { results = []; return }
            let found = lookupAt(ctx.sentence, at: ctx.at, store: store)
            results = found
            choose(0)
        }
    }

    /// 문장에서 찾은 부분을 굵게
    private var contextLine: some View {
        let chars = Array(ctx.sentence)
        let start = min(ctx.at, chars.count)
        let len = current?.length ?? 1
        let end = min(chars.count, start + len)
        return (Text(String(chars[..<start]))
            + Text(String(chars[start..<end])).bold().foregroundColor(.orange)
            + Text(String(chars[end...])))
            .font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
    }

    private var existing: SavedWord? {
        guard let r = current else { return nil }
        return app.vocab.saved(term: r.term, sentence: ctx.sentence, videoId: ctx.videoId)
    }

    private var buttonTitle: String {
        if saved { return "저장했어요 ✓" }
        if selected.isEmpty { return "뜻을 골라 주세요 (여러 개 가능)" }
        return existing == nil ? "뜻 \(selected.count)개로 저장" : "고른 뜻 \(selected.count)개로 바꾸기"
    }

    /// 후보 고르기: 이미 저장한 단어면 저장한 뜻을 표시, 아니면 첫 뜻
    private func choose(_ i: Int) {
        pick = i
        saved = false
        selected = []
        guard let r = current else { return }
        if let w = existing {
            for (k, e) in r.entries.enumerated() where w.meanings.contains(where: { $0.ko == e.ko }) {
                selected.insert(k)
            }
        }
        if selected.isEmpty, !r.entries.isEmpty { selected = [0] }
    }

    private func save() {
        guard let r = current, !selected.isEmpty else { return }
        app.vocab.add(Self.makeWord(ctx: ctx, result: r, selected: selected.sorted()))
        saved = true
    }

    static func makeWord(ctx: WordContext, result r: LookupResult, selected: [Int]) -> SavedWord {
        let meanings = selected.filter { $0 < r.entries.count }.map { k in
            Meaning(ko: r.entries[k].ko, def: r.entries[k].def, reading: r.entries[k].reading)
        }
        return SavedWord(
            surface: r.surface, term: r.term, reading: r.reading, readings: r.readings, meanings: meanings,
            sentence: ctx.sentence, sentenceKo: ctx.sentenceKo, start: r.start,
            videoId: ctx.videoId, timeMs: ctx.timeMs
        )
    }
}

/// 사전 항목 목록 (체크해서 고르기). onToggle 이 없으면 보기만.
struct EntryList: View {
    let entries: [DictEntry]
    var mainReading: String = ""
    var selected: Set<Int> = []
    var onToggle: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(entries.enumerated()), id: \.offset) { k, e in
                let on = selected.contains(k)
                HStack(alignment: .top, spacing: 10) {
                    if onToggle != nil {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Color.accentColor : Color.secondary)
                            .font(.title3)
                    } else {
                        Text("\(k + 1)").font(.subheadline.bold()).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(e.ko).font(.body.weight(.semibold))
                            if !e.reading.isEmpty && e.reading != mainReading {
                                Text(e.reading).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if !e.def.isEmpty {
                            Text(e.def).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(on ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .onTapGesture { onToggle?(k) }
            }
        }
    }
}
