import XCTest
@testable import TubeVocab

final class SyncMergeTests: XCTestCase {
    private func word(_ s: String, created: Int, updated: Int? = nil, id: UUID = UUID()) -> SavedWord {
        var w = SavedWord(id: id, surface: s, lemma: s, forms: [], pos: "noun", sense: s, senseTags: [], senseKo: s,
                          sentenceEn: "\(s) here.", sentenceKo: "", videoId: "v", timeMs: 0, createdAt: created)
        w.updatedAt = updated
        return w
    }

    func testUnionOfBothDevices() {
        let a = word("apple", created: 1), b = word("banana", created: 2)
        let merged = SyncMerge.merge(local: [a], localDeleted: [:], remote: SyncFile(words: [b]), now: 10)
        XCTAssertEqual(merged.words.map(\.surface), ["banana", "apple"]) // 최근 저장 순
    }

    func testNewerEditWins() {
        let id = UUID()
        var phone = word("cool", created: 1, updated: 5, id: id)
        phone.starred = true
        let mac = word("cool", created: 1, updated: 3, id: id)
        let merged = SyncMerge.merge(local: [mac], localDeleted: [:], remote: SyncFile(words: [phone]), now: 10)
        XCTAssertEqual(merged.words.count, 1)
        XCTAssertTrue(merged.words[0].star)
    }

    func testDeletionSpreads() {
        let w = word("gone", created: 1, updated: 2)
        // 맥에서 지움 → 폰 파일에 아직 있음
        let merged = SyncMerge.merge(local: [], localDeleted: [w.id.uuidString: 5], remote: SyncFile(words: [w]), now: 10)
        XCTAssertTrue(merged.words.isEmpty)
        XCTAssertEqual(merged.deleted[w.id.uuidString], 5)
    }

    func testEditAfterDeleteSurvives() {
        let w = word("back", created: 1, updated: 9)
        let merged = SyncMerge.merge(local: [w], localDeleted: [:],
                                     remote: SyncFile(words: [], deleted: [w.id.uuidString: 5]), now: 10)
        XCTAssertEqual(merged.words.count, 1)
    }

    func testOldTombstonesAreDropped() {
        let merged = SyncMerge.merge(local: [], localDeleted: ["x": 0], remote: nil,
                                     now: SyncMerge.tombstoneMaxAgeMs + 1)
        XCTAssertTrue(merged.deleted.isEmpty)
    }

    func testFirstSyncWithoutRemoteFile() {
        let a = word("apple", created: 1)
        let merged = SyncMerge.merge(local: [a], localDeleted: [:], remote: nil, now: 10)
        XCTAssertEqual(merged.words, [a])
    }

    @MainActor
    func testStoreKeepsTombstonesAndTimestamps() {
        let url = FileManager.default.temporaryDirectory.appending(path: "words-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = VocabStore(fileURL: url)
        var changes = 0
        store.onLocalChange = { changes += 1 }
        let w = word("kept", created: 1)
        store.add(w)
        XCTAssertNotNil(store.words[0].updatedAt)
        store.remove(id: w.id)
        XCTAssertNotNil(store.deleted[w.id.uuidString])
        XCTAssertEqual(changes, 2)

        // 동기화 결과 반영은 다시 동기화를 부르지 않는다
        store.replaceFromSync(words: [word("synced", created: 3)], deleted: [:])
        XCTAssertEqual(changes, 2)
        XCTAssertEqual(VocabStore(fileURL: url).words.map(\.surface), ["synced"])
    }
}
