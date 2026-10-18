import SwiftUI
import UIKit

/// 단어장 탭: 저장 단어 목록·검색·삭제·원문 보기 + 사전 직접 검색
struct WordsView: View {
    enum Mode: String, CaseIterable {
        case mine = "내 단어"
        case dict = "사전 검색"
    }

    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var mode: Mode = .mine
    @State private var query = ""
    @State private var showSync = false
    /// 아이패드: 오른쪽에 보이는 단어
    @State private var selected: UUID?

    var body: some View {
        if sizeClass == .regular {
            // 아이패드·맥: 왼쪽 목록, 오른쪽 단어 상세
            NavigationSplitView {
                list(split: true)
            } detail: {
                NavigationStack {
                    if let id = selected, app.vocab.word(id: id) != nil {
                        WordDetailView(id: id).id(id)
                    } else {
                        ContentUnavailableView("단어를 골라 주세요", systemImage: "book",
                                               description: Text("왼쪽 목록에서 단어를 고르면 뜻과 원문 문장이 여기에 보여요."))
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                list(split: false)
                    .navigationDestination(for: UUID.self) { id in
                        WordDetailView(id: id)
                    }
            }
        }
    }

    private func list(split: Bool) -> some View {
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
            case .mine: myWords(split: split)
            case .dict: DictSearchView()
            }
        }
        .navigationTitle("단어장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSync = true
                } label: {
                    Image(systemName: app.sync.isConnected
                          ? (app.sync.error == nil ? "checkmark.icloud" : "exclamationmark.icloud")
                          : "icloud.slash")
                }
                .accessibilityLabel("기기 간 동기화")
            }
        }
        .sheet(isPresented: $showSync) { SyncView() }
    }

    private var filtered: [SavedWord] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return app.vocab.words }
        let qh = toHiragana(q)
        return app.vocab.words.filter { w in
            ([w.surface, w.term, w.reading, w.summary, w.sentence, w.sentenceKo]).contains {
                $0.lowercased().contains(q) || toHiragana($0).contains(qh)
            }
        }
    }

    /// split 이면 고른 단어를 오른쪽에 보여 주고(selection), 아니면 화면을 밀어 넣는다(navigationDestination)
    private func myWords(split: Bool) -> some View {
        List(selection: split ? $selected : nil) {
            if app.vocab.words.isEmpty {
                Text("영상 자막에서 단어를 탭해 저장해 보세요.")
                    .foregroundStyle(.secondary)
            }
            ForEach(filtered) { w in
                NavigationLink(value: w.id) {
                    WordRow(word: w)
                }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(word.term).font(.headline)
                if !word.reading.isEmpty && word.reading != word.term {
                    Text(word.reading).font(.subheadline).foregroundStyle(.secondary)
                }
                SpeakButton(text: word.term).font(.caption)
                Spacer()
                if word.star {
                    Text("★").font(.caption).foregroundStyle(.orange)
                }
            }
            Text(word.summary)
                .font(.subheadline).lineLimit(1)
            Text(word.sentence)
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

    var body: some View {
        if let w = app.vocab.word(id: id) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(w.term).font(.largeTitle.bold())
                            if !w.reading.isEmpty && w.reading != w.term {
                                Text(w.reading).font(.title3).foregroundStyle(.secondary)
                            }
                            SpeakButton(text: w.term).font(.title3)
                        }
                        if w.surface != w.term {
                            Text("문장 속 모양: \(w.surface)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("고른 뜻 \(w.meanings.count)개") {
                    ForEach(Array(w.meanings.enumerated()), id: \.offset) { i, m in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1)").font(.subheadline.bold()).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(m.ko).font(.body.weight(.semibold))
                                if !m.def.isEmpty {
                                    Text(m.def).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("원문 문장") {
                    TappableText(text: w.sentence, highlight: buildHighlightIndex([w.target]))
                        .font(.title3)
                    SpeakButton(text: w.sentence, label: "문장 듣기")
                    if !w.sentenceKo.isEmpty {
                        Text(w.sentenceKo).foregroundStyle(.secondary)
                    }
                    if !w.videoId.isEmpty {
                        Button {
                            app.showInVideo(w)
                        } label: {
                            Label("영상에서 보기 (\(formatTime(w.timeMs)))", systemImage: "play.rectangle")
                        }
                    }
                }
                Section("시험") {
                    Toggle("★ 헷갈리는 단어", isOn: Binding(get: { w.star }, set: { _ in app.vocab.toggleStar(id: w.id) }))
                    LabeledContent("맞힘 / 틀림", value: "\(w.correct) / \(w.wrong)")
                }
                Section {
                    Button("단어 삭제", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle(w.term)
            .navigationBarTitleDisplayMode(.inline)
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

/// 사전 직접 검색 (활용형도 기본형으로 찾음)
struct DictSearchView: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var results: [LookupResult] = []

    var body: some View {
        VStack(spacing: 0) {
            TextField("일본어 단어 (예: 食べました, 行った, がんばる)", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let err = app.dictError {
                        Text(err).foregroundStyle(.red)
                    } else if results.isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("사전에 없어요. 기본형(예: 食べる)이나 히라가나로도 찾아보세요.").foregroundStyle(.secondary)
                    }
                    ForEach(results.prefix(6)) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(r.term).font(.title2.bold())
                                if !r.reading.isEmpty && r.reading != r.term {
                                    Text(r.reading).foregroundStyle(.secondary)
                                }
                                SpeakButton(text: r.term)
                            }
                            if !r.reasons.isEmpty {
                                Text("\(r.surface) ← \(r.reasons.joined(separator: " · "))")
                                    .font(.caption).foregroundStyle(Color.accentColor)
                            }
                            EntryList(entries: r.entries, mainReading: r.reading)
                        }
                    }
                    Text(dictionaryCredits)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .task(id: query) {
            // 입력을 잠깐 기다렸다가 찾기
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let store = app.dict else { return }
            results = lookupQuery(query, store: store)
        }
    }
}

/// 내장 사전 출처
let dictionaryCredits = """
사전: 국립국어원 한국어기초사전 일본어판(CC BY-SA 2.0 KR), 네이버 한일사전 데이터. \
Lyroxide/yomichan-ko-dic 의 한→일 사전을 일→한으로 뒤집어 만들었어요.
"""
