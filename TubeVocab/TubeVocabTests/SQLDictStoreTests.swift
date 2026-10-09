import XCTest
@testable import TubeVocab

/// 앱에 들어있는 dict.db(scripts/build_dict.py 로 만든 샘플)로 SQLite 저장소 + 문맥 조회를 끝까지 확인.
/// 전체 덤프로 dict.db 를 다시 만들어도 통과해야 하는 내용만 확인한다.
final class SQLDictStoreTests: XCTestCase {
    var store: SQLDictStore!

    override func setUpWithError() throws {
        store = try SQLDictStore.bundled()
    }

    func testWentToGoWithKorean() {
        let r = Fixtures.look(store, "We went to the park", "went")
        XCTAssertEqual(r.entries.first?.word, "go")
        XCTAssertTrue(r.entries.contains { $0.source == .ko && $0.senses.contains { $0.gloss.contains("가다") } })
    }

    func testPickItUp() {
        let r = Fixtures.look(store, "You can pick it up later", "up")
        XCTAssertEqual(r.phrases.first?.match.phrase, "pick up")
    }

    func testMadeUpMyMind() {
        let r = Fixtures.look(store, "I finally made up my mind", "mind")
        XCTAssertEqual(r.phrases.first?.match.phrase, "make up one's mind")
        XCTAssertEqual(r.phrases.first?.surface, "made up my mind")
    }

    func testSlangSense() {
        let r = Fixtures.look(store, "That was sick", "sick")
        let en = r.entries.first { $0.source == .en }
        XCTAssertNotNil(en?.senses.first { $0.tags.contains("slang") })
    }

    func testFormsAndPrefix() {
        XCTAssertTrue(Set(store.formsOf("give")).isSuperset(of: ["gave", "given"]))
        XCTAssertTrue(store.searchPrefix("giv", limit: 5).contains("give up"))
    }
}
