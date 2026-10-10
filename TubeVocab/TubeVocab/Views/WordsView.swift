import SwiftUI
import UIKit

/// 단어장 탭: 저장 단어 목록·검색·삭제·원문 보기 + 사전 직접 검색
struct WordsView: View {
    enum Mode: String, CaseIterable {
        case mine = "내 단어"
        case dict = "사전 검색"
    }

    @Environment(AppModel.self) private var app
    @State private var mode: Mode = .mine
    @State private var query = ""
    @State private var path: [UUID] = []
    /// 뜻 가리기 모드: 한국어 뜻을 가리고, 두 번 탭하면 보여 준다
    @AppStorage("hideMeanings") private var hideMeanings = false
    /// 가리기 모드에서 두 번 탭해서 펼친 단어
    @State private var revealed: Set<UUID> = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("보기", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m == .mine ? "\(m.rawValue) (\(app.vocab.words.count))" : m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch mode {
                case .mine: myWords
                case .dict: DictSearchView()
                }
            }
            .navigationTitle("단어장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode == .mine {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            hideMeanings.toggle()
                            revealed = []
                        } label: {
                            Label(hideMeanings ? "뜻 보이기" : "뜻 가리기",
                                  systemImage: hideMeanings ? "eye.slash.fill" : "eye")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                WordDetailView(id: id)
            }
        }
    }

    private var filtered: [SavedWord] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return app.vocab.words }
        return app.vocab.words.filter { w in
            [w.surface, w.lemma, w.sense, w.summary, w.sentenceEn, w.sentenceKo].contains { $0.lowercased().contains(q) }
        }
    }

    private var myWords: some View {
        List {
            if app.vocab.words.isEmpty {
                Text("영상 자막에서 단어를 탭해 저장해 보세요.")
                    .foregroundStyle(.secondary)
            }
            if hideMeanings && !app.vocab.words.isEmpty {
                Label("뜻을 가렸어요. 단어를 두 번 탭하면 뜻이 보여요.", systemImage: "hand.tap")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(filtered) { w in
                let hidden = hideMeanings && !revealed.contains(w.id)
                HStack {
                    WordRow(word: w, hideMeaning: hidden)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                // 가리기 모드: 두 번 탭 → 뜻 보이기/가리기, 한 번 탭 → 상세 화면
                // 보통 모드: 한 번 탭 → 상세 화면 (두 번 탭을 기다리지 않게)
                .onTapGesture(count: hideMeanings ? 2 : 1) {
                    if hideMeanings {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if revealed.contains(w.id) { revealed.remove(w.id) } else { revealed.insert(w.id) }
                        }
                    } else {
                        path.append(w.id)
                    }
                }
                .onTapGesture { path.append(w.id) }
            }
            .onDelete { offsets in
                let list = filtered
                for i in offsets { app.vocab.remove(id: list[i].id) }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "단어·뜻·문장 검색")
    }
}

private struct WordRow: View {
    let word: SavedWord
    var hideMeaning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(word.surface).font(.headline)
                if word.lemma != word.surface.lowercased() {
                    Text(word.lemma).font(.subheadline).foregroundStyle(.secondary)
                }
                TagBadges(tags: word.senseTags)
                Spacer()
                Text(describeDue(word.dueAt, now: nowMs()))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            MeaningText(text: word.summary, hidden: hideMeaning)
                .font(.subheadline).lineLimit(1)
            Text(word.sentenceEn)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

/// 저장한 단어 하나: 원문 문장, 뜻, 영상으로 가기, 삭제
struct WordDetailView: View {
    let id: UUID
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @AppStorage("hideMeanings") private var hideMeanings = false
    @State private var revealed = false

    private var hidden: Bool { hideMeanings && !revealed }

    var body: some View {
        if let w = app.vocab.word(id: id) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(w.surface).font(.title2.bold())
                            Badge(label: posKorean[w.pos] ?? w.pos, tone: .blue)
                        }
                        if w.lemma != w.surface.lowercased() {
                            Text("기본형: \(w.lemma)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ForEach(Array(w.allMeanings.enumerated()), id: \.offset) { i, m in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1)").font(.subheadline.bold()).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                TagBadges(tags: m.tags)
                                if m.ko.isEmpty || m.ko == m.gloss {
                                    MeaningText(text: m.gloss, hidden: hidden && containsHangul(m.gloss))
                                } else {
                                    Text(m.gloss)
                                    MeaningText(text: m.ko, hidden: hidden).foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("고른 뜻 \(w.allMeanings.count)개")
                } footer: {
                    if hideMeanings {
                        Text(revealed ? "두 번 탭하면 다시 가려요." : "화면을 두 번 탭하면 한국어 뜻이 보여요.")
                    }
                }
                Section("원문 문장") {
                    TappableText(text: w.sentenceEn, highlight: buildHighlightIndex([w.target]))
                        .font(.body)
                    if !w.sentenceKo.isEmpty {
                        MeaningText(text: w.sentenceKo, hidden: hidden).foregroundStyle(.secondary)
                    }
                    if !w.videoId.isEmpty {
                        Button {
                            app.showInVideo(w)
                        } label: {
                            Label("영상에서 보기 (\(formatTime(w.timeMs)))", systemImage: "play.rectangle")
                        }
                    }
                }
                Section("복습") {
                    LabeledContent("다음 복습", value: describeDue(w.dueAt, now: nowMs()))
                    LabeledContent("맞힘 / 틀림", value: "\(w.correct) / \(w.wrong)")
                }
                Section {
                    Button("단어 삭제", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle(w.surface)
            .navigationBarTitleDisplayMode(.inline)
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                guard hideMeanings else { return }
                withAnimation(.easeOut(duration: 0.15)) { revealed.toggle() }
            })
            .confirmationDialog("이 단어를 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    app.vocab.remove(id: id)
                    dismiss()
                }
            }
        } else {
            Text("삭제된 단어예요.").foregroundStyle(.secondary)
        }
    }
}

/// 뜻 가리기 모드에서 가려지는 글자. 자리는 그대로 두고 흐리게 + 가림막.
struct MeaningText: View {
    let text: String
    let hidden: Bool

    var body: some View {
        Text(text)
            .blur(radius: hidden ? 7 : 0)
            .overlay(alignment: .leading) {
                if hidden {
                    Text("두 번 탭해서 뜻 보기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .accessibilityLabel(hidden ? "가려진 뜻" : text)
    }
}

/// 사전 직접 검색 (활용형·숙어도 찾음)
struct DictSearchView: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var result: LookupResult?
    @State private var suggestions: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            TextField("영어 단어나 표현 (예: went, gave up)", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { query = s }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 6)
            }

            ScrollView {
                if let err = app.dictError {
                    Text(err).foregroundStyle(.red).padding()
                } else if let result, !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    DictionaryView(result: result).padding()
                }
                Text(dictionaryCredits)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .task(id: query) {
            // 입력을 잠깐 기다렸다가 찾기
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let store = app.dict else { return }
            let q = query.trimmingCharacters(in: .whitespaces)
            result = lookupQuery(store, q)
            suggestions = q.count >= 2 ? store.searchPrefix(q, limit: 8).filter { $0 != q.lowercased() } : []
        }
    }
}

/// 내장 사전 출처 (CC BY-SA 4.0 저작자 표시)
let dictionaryCredits = """
사전 출처: WordNet 3.0 (Princeton University) · open-english-korean-dict \
(jhseo1211, CC BY-SA 4.0) · kengdic (Joe Speigle, MPL 2.0). \
내장 사전 파일(dict.db)은 CC BY-SA 4.0 으로 배포됩니다.
"""
