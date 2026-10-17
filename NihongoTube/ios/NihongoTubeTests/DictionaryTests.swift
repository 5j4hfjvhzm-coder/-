import XCTest
@testable import NihongoTube

final class DictionaryTests: XCTestCase {
    private let dict = fixtureDict()

    private func top(_ text: String, _ at: Int = 0) -> String? {
        lookupAt(text, at: at, store: dict).first?.term
    }

    func testConjugationsFindDictionaryForm() {
        XCTAssertEqual(top("食べました。"), "食べる")
        XCTAssertEqual(top("読んだ本"), "読む")
        XCTAssertEqual(top("学校に行った", 3), "行く")
        XCTAssertEqual(top("待っています"), "待つ")
        XCTAssertEqual(top("忘れてしまった"), "忘れる")
        XCTAssertEqual(top("食べちゃった"), "食べる")
        XCTAssertEqual(top("読まない"), "読む")
        XCTAssertEqual(top("書かなかった"), "書く")
        XCTAssertEqual(top("行きたくない"), "行く")
        XCTAssertEqual(top("楽しかった"), "楽しい")
        XCTAssertEqual(top("高くない"), "高い")
        XCTAssertEqual(top("勉強しました"), "勉強する")
        XCTAssertEqual(top("来ました"), "来る")
        XCTAssertEqual(top("話せる"), "話す")
        XCTAssertEqual(top("たべた"), "たべる")
    }

    func testLongestMatchAndPosition() {
        XCTAssertEqual(top("日本語を"), "日本語")
        XCTAssertEqual(top("今日は"), "今日")
        XCTAssertEqual(top("私は日本語を勉強しています", 6), "勉強する")
        XCTAssertEqual(top("コーヒーを飲む"), "コーヒー")
    }

    func testResultCarriesSurfaceAndReasons() throws {
        let r = try XCTUnwrap(lookupAt("食べました", at: 0, store: dict).first)
        XCTAssertEqual(r.surface, "食べました")
        XCTAssertEqual(r.length, 5)
        XCTAssertEqual(r.reading, "たべる")
        XCTAssertFalse(r.reasons.isEmpty)
    }

    func testStopsAtPunctuation() {
        XCTAssertTrue(lookupAt("。食べる", at: 0, store: dict).isEmpty)
        XCTAssertEqual(lookupQuery("  食べました ", store: dict).first?.term, "食べる")
    }

    func testDecodeEntries() {
        let list = DictEntry.decodeList(#"[["たべる","먹다","음식을 먹다."],["","먹고살다"]]"#)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].def, "음식을 먹다.")
        XCTAssertEqual(list[1].def, "")
    }

    func testMostCommonReadingFirst() {
        let r = LookupResult(surface: "行く", start: 0, length: 2, term: "行く", reasons: [],
                             entries: [DictEntry(reading: "ゆく", ko: "가다", def: ""),
                                       DictEntry(reading: "いく", ko: "떠나다", def: ""),
                                       DictEntry(reading: "いく", ko: "올라가다", def: "")])
        XCTAssertEqual(r.readings, ["いく", "ゆく"])
    }

    /// 앱에 들어 있는 진짜 사전으로
    func testBundledDictionary() throws {
        let db: JaDictDB
        do { db = try JaDictDB.bundled() } catch { throw XCTSkip("사전 파일 없음") }
        XCTAssertEqual(lookupAt("食べました", at: 0, store: db).first?.entries.first?.ko, "먹다")
        XCTAssertEqual(lookupAt("頑張ってる", at: 0, store: db).first?.term, "頑張る")
    }
}
