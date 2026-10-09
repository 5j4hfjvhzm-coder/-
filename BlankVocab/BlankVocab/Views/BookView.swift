import SwiftUI
import UniformTypeIdentifiers

struct BookView: View {
    let bookID: Int
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var w = ""
    @State private var m = ""
    @State private var e = ""
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case w, m, e }

    var body: some View {
        Group {
            if let b = store.book(bookID) {
                content(b)
            } else {
                Color.clear
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ b: Book) -> some View {
        let stars = b.words.filter(\.star).count
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(b.name).font(.system(size: 28, weight: .heavy))
                Text("단어 \(b.words.count)개").font(.subheadline).foregroundStyle(Theme.sub)
                SkipToggle().padding(.vertical, 4)
                FlowLayout {
                    Button("전체 퀴즈 (\(store.count([b.id]))문제)") { store.start(.all, ids: [b.id], multi: false) }
                        .buttonStyle(.pillPrimary)
                        .disabled(b.words.isEmpty)
                    Button("전체 테스트") { store.start(.test, ids: [b.id], multi: false) }
                        .buttonStyle(.pill)
                        .disabled(b.words.isEmpty)
                    Button("★ 헷갈리는 단어 (\(stars))") { store.start(.star, ids: [b.id], multi: false) }
                        .buttonStyle(.pill)
                        .disabled(stars == 0)
                    NavigationLink(value: Route.chat([b.id])) { Text("🤖 AI 프리토킹") }
                        .buttonStyle(.pill)
                }

                SectionTitle("단어 추가")
                VStack(spacing: 8) {
                    TextField("단어 (예: resource)", text: $w)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .w)
                        .submitLabel(.next)
                        .onSubmit { focus = .m }
                        .field()
                    TextField("뜻 (예: 자원)", text: $m)
                        .focused($focus, equals: .m)
                        .submitLabel(.next)
                        .onSubmit { focus = .e }
                        .field()
                    TextField("예문 (단어가 들어간 영어 문장)", text: $e)
                        .textInputAutocapitalization(.sentences)
                        .focused($focus, equals: .e)
                        .submitLabel(.done)
                        .onSubmit(addWord)
                        .field()
                    HStack(spacing: 8) {
                        Button("추가", action: addWord).buttonStyle(.pillPrimary)
                        Button("파일로 추가") { importing = true }.buttonStyle(.pill)
                        Spacer()
                    }
                }
                .card()

                SectionTitle("단어 목록")
                VStack(spacing: 0) {
                    if b.words.isEmpty {
                        Text("단어를 추가하면 여기에 나와요.")
                            .foregroundStyle(Theme.sub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    }
                    ForEach(b.words) { word in
                        WordRow(word: word, bookID: b.id)
                        if word.id != b.words.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .card()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("CSV 저장") { exporting = true }
                Button("삭제", role: .destructive) { confirmDelete = true }
                    .foregroundStyle(Theme.bad)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.importFiles(urls, intoBook: b.id) }
        }
        .fileExporter(isPresented: $exporting, document: DataDocument(data: Data(CSV.export(b).utf8), type: .commaSeparatedText),
                      contentType: .commaSeparatedText, defaultFilename: b.name) { result in
            if case .success = result { store.show("CSV를 저장했어요.") }
        }
        .alert("단어장을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) {
                dismiss()
                store.deleteBook(b.id)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\"\(b.name)\"의 단어 \(b.words.count)개가 모두 지워져요.")
        }
    }

    private func addWord() {
        let tw = w.trimmingCharacters(in: .whitespaces)
        let tm = m.trimmingCharacters(in: .whitespaces)
        let te = e.trimmingCharacters(in: .whitespaces)
        guard !tw.isEmpty, !tm.isEmpty else {
            store.show("단어와 뜻을 입력하세요")
            return
        }
        store.addWord(to: bookID, Word(w: tw, m: tm, e: te))
        w = ""
        m = ""
        e = ""
        focus = .w
    }
}

private struct WordRow: View {
    let word: Word
    let bookID: Int
    @Environment(Store.self) private var store

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(word.w)
                .font(.headline)
                .frame(minWidth: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.m)
                if !word.e.isEmpty {
                    Text(word.e).font(.footnote).foregroundStyle(Theme.sub)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button { Speech.shared.say(word.w + ". " + word.e) } label: { Image(systemName: "speaker.wave.2") }
                    .accessibilityLabel("읽기")
                Button { store.toggleStar(wordID: word.id) } label: {
                    Image(systemName: word.star ? "star.fill" : "star")
                        .foregroundStyle(word.star ? Theme.starOn : Theme.sub)
                }
                .accessibilityLabel("헷갈리는 단어 표시")
                Button { store.deleteWord(bookID: bookID, wordID: word.id) } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("삭제")
            }
            .foregroundStyle(Theme.sub)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
    }
}
