import XCTest
@testable import TubeVocab

/// 앱에 들어 있는 dict.db(WordNet + open-english-korean-dict + kengdic 으로 만든 것)로
/// SQLite 저장소 + 문맥 조회를 끝까지 확인.
final class SQLDictStoreTests: XCTestCase {
    var store: SQLDictStore!

    override func setUpWithError() throws {
        store = try SQLDictStore.bundled()
    }

    func testWentToGoWithKorean() {
        let r = Fixtures.look(store, "We went to the park", "went")
        XCTAssertTrue(r.lemmas.contains("go"))
        XCTAssertEqual(r.entries.first?.word, "go")
        XCTAssertTrue(r.entries.contains { $0.source == .ko && $0.senses.contains { $0.gloss == "가다" } })
        XCTAssertTrue(r.entries.contains { $0.source == .en && $0.word == "go" })
    }

    func testGaveUpPhraseWithKorean() {
        let r = Fixtures.look(store, "She gave up.", "gave")
        let giveUp = r.phrases.first { $0.match.phrase == "give up" }
        XCTAssertNotNil(giveUp)
        XCTAssertTrue(giveUp?.entries.contains { $0.source == .ko && $0.senses.contains { $0.gloss == "포기하다" } } ?? false)
    }

    func testPickItUp() {
        let r = Fixtures.look(store, "You can pick it up later", "up")
        XCTAssertTrue(r.phrases.map(\.match.phrase).contains("pick up"))
    }

    func testMadeUpMyMind() {
        let r = Fixtures.look(store, "I finally made up my mind", "mind")
        XCTAssertEqual(r.phrases.first?.match.phrase, "make up one's mind")
        XCTAssertEqual(r.phrases.first?.surface, "made up my mind")
    }

    func testPosFromPreviousWord() {
        XCTAssertEqual(Fixtures.look(store, "I read a book", "book").entries.first?.pos, "noun")
        XCTAssertEqual(Fixtures.look(store, "I need to book a room", "book").entries.first?.pos, "verb")
    }

    func testNewWordFromKoreanDictionary() {
        let r = Fixtures.look(store, "That guy is sus", "sus")
        XCTAssertTrue(r.entries.contains { $0.senses.contains { $0.gloss == "의심스러운" } })
    }

    func testFormsAndPrefix() {
        XCTAssertTrue(Set(store.formsOf("give")).isSuperset(of: ["gave", "given", "gives", "giving"]))
        XCTAssertTrue(store.searchPrefix("give u", limit: 5).contains("give up"))
    }
}
