import Foundation
import Observation

/// 최근 검색어와 ★ 저장한 단어를 기기에 저장해요.
@MainActor
@Observable
final class Store {
    private(set) var recents: [String] = []
    private(set) var saved: [NaverDict.Entry] = []

    private let recentsKey = "recents"
    private let savedKey = "saved"
    private let maxRecents = 30

    init() {
        let d = UserDefaults.standard
        recents = d.stringArray(forKey: recentsKey) ?? []
        if let data = d.data(forKey: savedKey),
           let list = try? JSONDecoder().decode([NaverDict.Entry].self, from: data) {
            saved = list
        }
    }

    // MARK: 최근 검색

    func addRecent(_ query: String) {
        recents.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        recents.insert(query, at: 0)
        if recents.count > maxRecents { recents.removeLast(recents.count - maxRecents) }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    func removeRecents(at offsets: IndexSet) {
        recents.remove(atOffsets: offsets)
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    func clearRecents() {
        recents = []
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    // MARK: 단어장 (★)

    func isSaved(_ entry: NaverDict.Entry) -> Bool {
        saved.contains { Self.same($0, entry) }
    }

    func toggleSave(_ entry: NaverDict.Entry) {
        if isSaved(entry) {
            saved.removeAll { Self.same($0, entry) }
        } else {
            saved.insert(entry, at: 0)
        }
        persistSaved()
    }

    func removeSaved(at offsets: IndexSet) {
        saved.remove(atOffsets: offsets)
        persistSaved()
    }

    private func persistSaved() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: savedKey)
        }
    }

    /// 검색할 때마다 id가 새로 생겨서, 단어 + 위첨자 번호로 같은 단어인지 봐요.
    private static func same(_ a: NaverDict.Entry, _ b: NaverDict.Entry) -> Bool {
        a.word == b.word && a.superscript == b.superscript
    }
}
