import Foundation

enum ImportError: LocalizedError {
    case encoding, empty

    var errorDescription: String? {
        switch self {
        case .encoding: return "글자 인코딩을 읽을 수 없어요."
        case .empty: return "단어가 없어요. 첫 줄 열 이름(단어, 의미 …)을 확인해 주세요."
        }
    }
}

/// 단어장 목록을 기기에 저장해요 (Documents/wordsheet.json)
@MainActor
final class Store: ObservableObject {
    @Published private(set) var decks: [Deck] = []

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("wordsheet.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Deck].self, from: data) {
            decks = saved
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(decks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("저장 실패: \(error)")
        }
    }

    /// CSV 파일을 새 단어장으로 가져오고, 그 단어장 id를 돌려줘요.
    @discardableResult
    func importFile(_ url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let text = CSV.decode(data) else { throw ImportError.encoding }
        let entries = CSV.entries(from: CSV.parse(text))
        guard !entries.isEmpty else { throw ImportError.empty }
        let deck = Deck(name: url.deletingPathExtension().lastPathComponent, entries: entries)
        decks.append(deck)
        save()
        return deck.id
    }

    func delete(_ id: String) {
        decks.removeAll { $0.id == id }
        save()
    }

    func rename(_ id: String, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = decks.firstIndex(where: { $0.id == id }) else { return }
        decks[i].name = n
        save()
    }

    func setMarker(_ marker: Marker?, entry: String, deck: String) {
        guard let d = decks.firstIndex(where: { $0.id == deck }),
              let e = decks[d].entries.firstIndex(where: { $0.id == entry }) else { return }
        decks[d].entries[e].marker = marker
        save()
    }

    func clearMarkers(deck: String) {
        guard let d = decks.firstIndex(where: { $0.id == deck }) else { return }
        for i in decks[d].entries.indices { decks[d].entries[i].marker = nil }
        save()
    }
}
