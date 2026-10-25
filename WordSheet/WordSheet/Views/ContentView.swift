import SwiftUI
import UniformTypeIdentifiers

/// 왼쪽: 단어장 목록 / 오른쪽: 단어장 화면
struct ContentView: View {
    @EnvironmentObject private var store: Store
    @State private var selection: String?
    @State private var importing = false
    @State private var message: String?
    @State private var renamingID: String?
    @State private var newName = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.decks) { deck in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deck.name)
                            .font(.headline)
                        Text("\(deck.entries.count)단어 · 형광펜 \(deck.markedCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(deck.id)
                    .contextMenu {
                        Button {
                            newName = deck.name
                            renamingID = deck.id
                        } label: {
                            Label("이름 바꾸기", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            delete(deck.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.decks[$0].id }
                    for id in ids { delete(id) }
                }
            }
            .navigationTitle("단어장")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        importing = true
                    } label: {
                        Label("CSV 가져오기", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .overlay {
                if store.decks.isEmpty {
                    ContentUnavailableView {
                        Label("단어장이 없어요", systemImage: "doc.text")
                    } description: {
                        Text("빈칸 단어장에서 내보낸 CSV 파일을 가져오세요.")
                    } actions: {
                        Button("CSV 가져오기") { importing = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        } detail: {
            if let id = selection, store.decks.contains(where: { $0.id == id }) {
                DeckView(deckID: id)
                    .id(id)
            } else {
                ContentUnavailableView("단어장을 고르세요", systemImage: "sidebar.left")
            }
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .alert("이름 바꾸기", isPresented: Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })) {
            TextField("이름", text: $newName)
            Button("저장") {
                if let id = renamingID { store.rename(id, to: newName) }
                renamingID = nil
            }
            Button("취소", role: .cancel) { renamingID = nil }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("확인", role: .cancel) {}
        }
        .onAppear {
            if selection == nil { selection = store.decks.first?.id }
        }
    }

    private func delete(_ id: String) {
        if selection == id { selection = nil }
        store.delete(id)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var fails: [String] = []
            for url in urls {
                do {
                    selection = try store.importFile(url)
                } catch {
                    fails.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            if !fails.isEmpty {
                message = "가져오지 못한 파일\n" + fails.joined(separator: "\n")
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}
