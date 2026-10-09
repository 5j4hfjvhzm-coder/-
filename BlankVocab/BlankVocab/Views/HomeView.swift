import SwiftUI
import UniformTypeIdentifiers

enum Route: Hashable {
    case book(Int)
    case chat([Int])
    case settings
}

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var path: [Route] = []
    @State private var selected: Set<Int> = []
    @State private var newName = ""
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmDelete: Book?

    private var selectedIDs: [Int] { store.data.books.map(\.id).filter(selected.contains) }
    private var allIDs: [Int] { store.data.books.map(\.id) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if !store.data.sess.isEmpty { sessions }
                    books
                    if !store.data.books.isEmpty { multiCard }
                    newBook
                    backup
                    Text("파일 첫 줄에 단어(W), 의미(M), 예문(E) 열이 있으면 돼요. 품사(POS)도 읽어요. 데이터는 이 기기에 저장돼요.")
                        .font(.footnote)
                        .foregroundStyle(Theme.sub)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.bg.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.settings) } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("설정")
                }
            }
            .navigationDestination(for: Route.self) { r in
                switch r {
                case .book(let id): BookView(bookID: id)
                case .chat(let ids): ChatView(bookIDs: ids)
                case .settings: SettingsView()
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { store.quiz != nil }, set: { if !$0 { store.quiz = nil } })) {
            QuizView().environment(store)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .json], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.importFiles(urls) }
        }
        .fileExporter(isPresented: $exporting, document: DataDocument(data: store.backupData(), type: .json),
                      contentType: .json, defaultFilename: "blank-vocab-backup") { result in
            if case .success = result { store.show("백업을 저장했어요.") }
        }
        .alert("단어장을 삭제할까요?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
               presenting: confirmDelete) { b in
            Button("삭제", role: .destructive) {
                selected.remove(b.id)
                store.deleteBook(b.id)
            }
            Button("취소", role: .cancel) {}
        } message: { b in
            Text("\"\(b.name)\"의 단어 \(b.words.count)개가 모두 지워져요.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            (Text("빈칸 채우기로\n") + Text("알아서 외워지는").foregroundColor(Theme.pri) + Text(" 단어장"))
                .font(.system(size: 28, weight: .heavy))
                .lineSpacing(2)
            Text("예문의 빈칸에 단어를 써 보세요.")
                .font(.subheadline)
                .foregroundStyle(Theme.sub)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("이어서 하기")
            ForEach(store.data.sess) { o in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o.label).font(.headline)
                        Text("\(o.i) / \(o.list.count) 완료 · \(o.t.formatted(date: .numeric, time: .omitted))")
                            .font(.footnote).foregroundStyle(Theme.sub)
                    }
                    Spacer(minLength: 0)
                    Button("삭제") { store.deleteSession(o.sid) }
                        .foregroundStyle(Theme.sub)
                    Button("이어하기") { store.resume(o.sid) }
                        .buttonStyle(.pillPrimary)
                }
                .card()
            }
        }
    }

    @ViewBuilder
    private var books: some View {
        if store.data.books.isEmpty {
            Text("아직 단어장이 없어요. 아래에서 만들거나 파일을 가져오세요.")
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            ForEach(store.data.books) { b in
                HStack(spacing: 10) {
                    Button {
                        if selected.contains(b.id) { selected.remove(b.id) } else { selected.insert(b.id) }
                    } label: {
                        Image(systemName: selected.contains(b.id) ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundStyle(Theme.pri)
                    }
                    .accessibilityLabel("\(b.name) 선택")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.headline)
                        Text("단어 \(b.words.count)개").font(.footnote).foregroundStyle(Theme.sub)
                    }
                    Spacer(minLength: 0)
                    Button("삭제") { confirmDelete = b }
                        .foregroundStyle(Theme.sub)
                    Button("열기") { path.append(.book(b.id)) }
                        .buttonStyle(.pillPrimary)
                }
                .card()
            }
        }
    }

    private var multiCard: some View {
        let ids = selectedIDs
        let pool = ids.isEmpty ? allIDs : ids
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("여러 단어장 테스트")
            VStack(alignment: .leading, spacing: 12) {
                Text("위 목록에서 단어장을 체크하면 선택한 단어장의 단어를 섞어서 테스트해요. (선택 \(ids.count)개 · \(store.count(ids))단어)")
                    .font(.subheadline).foregroundStyle(Theme.sub)
                SkipToggle()
                FlowLayout {
                    Button("선택한 단어장 테스트") { store.start(.test, ids: ids, multi: true) }
                        .buttonStyle(.pillPrimary)
                        .disabled(store.count(ids) == 0)
                    Button("모든 단어장 테스트 (\(store.count(allIDs))단어)") { store.start(.test, ids: allIDs, multi: true) }
                        .buttonStyle(.pill)
                        .disabled(store.count(allIDs) == 0)
                    Button("🤖 AI 프리토킹") { path.append(.chat(pool)) }
                        .buttonStyle(.pill)
                    Button("★ 헷갈리는 단어만 (\(store.starCount(pool)))") { store.start(.star, ids: pool, multi: true) }
                        .buttonStyle(.pill)
                        .disabled(store.starCount(allIDs) == 0)
                }
            }
            .card()
        }
    }

    private var newBook: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("새 단어장")
            HStack(spacing: 8) {
                TextField("단어장 이름", text: $newName)
                    .field()
                    .submitLabel(.done)
                    .onSubmit(addBook)
                Button("만들기", action: addBook)
                    .buttonStyle(.pillPrimary)
            }
            .card()
            FlowLayout {
                Button("CSV 파일 가져오기") { importing = true }
                    .buttonStyle(.pill)
                Button("샘플 단어장") { store.addSample() }
                    .buttonStyle(.pill)
            }
        }
    }

    private var backup: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("백업")
            VStack(alignment: .leading, spacing: 10) {
                Text("전체 백업(.json)을 파일 앱이나 iCloud Drive, Google Drive에 저장할 수 있어요. 복원은 위의 \"CSV 파일 가져오기\"에서 같은 파일을 선택하면 돼요. 웹 버전 백업 파일도 그대로 가져올 수 있어요.")
                    .font(.subheadline).foregroundStyle(Theme.sub)
                Button("전체 백업 저장") { exporting = true }
                    .buttonStyle(.pillPrimary)
                    .disabled(store.data.books.isEmpty)
            }
            .card()
        }
    }

    private func addBook() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let id = store.addBook(name: n)
        newName = ""
        path.append(.book(id))
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .padding(.top, 14)
    }
}

struct SkipToggle: View {
    @Environment(Store.self) private var store
    var body: some View {
        Toggle("★ 헷갈리는 단어는 빼고 풀기", isOn: Binding(get: { store.data.skip }, set: { store.setSkip($0) }))
            .font(.subheadline)
            .tint(Theme.pri)
    }
}

/// fileExporter 로 저장할 파일
struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    var type: UTType

    init(data: Data, type: UTType) {
        self.data = data
        self.type = type
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        type = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
