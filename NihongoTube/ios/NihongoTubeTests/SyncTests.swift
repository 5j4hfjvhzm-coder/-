import XCTest
@testable import NihongoTube

final class SyncMergeTests: XCTestCase {
    func testUnionAndNewerWins() {
        let id = UUID()
        var phone = makeWord("行った", term: "行く", id: id, created: 1)
        phone.updatedAt = 5
        phone.starred = true
        var mac = makeWord("行った", term: "行く", id: id, created: 1)
        mac.updatedAt = 3
        let other = makeWord("見た", term: "見る", created: 2)
        let merged = SyncMerge.merge(local: [mac, other], localDeleted: [:], remote: SyncFile(words: [phone]), now: 10)
        XCTAssertEqual(merged.words.count, 2)
        XCTAssertTrue(merged.words.first { $0.id == id }!.star)
    }

    func testDeletionSpreads() {
        var w = makeWord("寝た", term: "寝る", created: 1)
        w.updatedAt = 2
        let merged = SyncMerge.merge(local: [], localDeleted: [w.id.uuidString: 5], remote: SyncFile(words: [w]), now: 10)
        XCTAssertTrue(merged.words.isEmpty)
    }

    @MainActor
    func testStoreReplacesMeaningsWhenSavedAgain() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("words-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = VocabStore(fileURL: url)
        var a = makeWord("食べた", term: "食べる", readings: ["たべる"])
        store.add(a)
        a.id = UUID()
        a.meanings = [Meaning(ko: "먹고살다", def: "", reading: "たべる")]
        store.add(a)
        XCTAssertEqual(store.words.count, 1)
        XCTAssertEqual(store.words[0].summary, "먹고살다")
        XCTAssertNotNil(store.saved(term: "食べる", sentence: a.sentence, videoId: "v"))
        XCTAssertEqual(VocabStore(fileURL: url).words.count, 1)
    }
}
