import XCTest
@testable import TubeVocab

final class NaverDictTests: XCTestCase {
    /// 네이버 영어사전 api3 응답 모양 (필요한 칸만)
    private let sample = #"""
    {"searchResultMap":{"searchResultListMap":{"WORD":{"query":"go","total":3,"items":[
      {"entryId":"b1","expEntry":"<strong>going</strong>","meansCollector":[{"partOfSpeech":"명사","partOfSpeech2":"noun","means":[{"order":"1","value":"가기"}]}]},
      {"entryId":"a1","expEntry":"<strong>go</strong>","searchPhoneticSymbolList":[
          {"symbolType":"영국","symbolTypeCode":"UK","symbolValue":"ɡəʊ"},
          {"symbolType":"미국","symbolTypeCode":"US","symbolValue":"ɡoʊ"}],
        "meansCollector":[
          {"partOfSpeech":"동사","partOfSpeech2":"verb","means":[
            {"order":"1","value":"<b>가다</b>, 이동하다","exampleOri":"<strong>Go</strong> home.","exampleTrans":"집에 &amp; 가.</>"},
            {"order":"2","value":"(구어) 말하다"},
            {"order":"3","value":"  "}]},
          {"partOfSpeech":"명사","partOfSpeech2":"noun","means":[{"order":"1","value":"시도"}]}]},
      {"entryId":"c1","expEntry":"<strong>GO</strong>","meansCollector":[{"partOfSpeech2":"abbreviation","value":"<span>general order</span>"}]}
    ]}}}}
    """#

    func testParsesHeadwordsPosAndMeanings() {
        let entries = NaverDictParser.parse(Data(sample.utf8), query: "Go")
        // 검색어와 같은 표제어(go, GO)가 앞, going 은 뒤
        XCTAssertEqual(entries.map(\.word), ["go", "go", "GO", "going"])
        let verb = entries[0]
        XCTAssertEqual(verb.pos, "verb")
        XCTAssertEqual(verb.source, .naver)
        XCTAssertEqual(verb.ipa, "[ɡoʊ]")
        XCTAssertEqual(verb.senses.map(\.gloss), ["가다, 이동하다", "(구어) 말하다"]) // 빈 뜻은 버림
        XCTAssertEqual(verb.senses[0].examples.first?.text, "Go home.")
        XCTAssertEqual(verb.senses[0].examples.first?.ko, "집에 & 가.")
        XCTAssertEqual(verb.senses[1].tags, ["colloquial"])
        XCTAssertEqual(entries[1].pos, "noun")
        // 예전 응답 모양(뜻이 value 하나)도 읽는다
        XCTAssertEqual(entries[2].pos, "abbrev")
        XCTAssertEqual(entries[2].senses.first?.gloss, "general order")
    }

    func testBrokenOrEmptyResponses() {
        XCTAssertTrue(NaverDictParser.parse(Data("not json".utf8), query: "x").isEmpty)
        XCTAssertTrue(NaverDictParser.parse(Data(#"{"searchResultMap":{}}"#.utf8), query: "x").isEmpty)
    }

    func testMergePutsNaverFirstWithUniqueIDs() {
        let naver = NaverDictParser.parse(Data(sample.utf8), query: "go")
        let local = Entry(id: 1, word: "go", pos: "verb", source: .ko, senses: [Sense(id: 0, gloss: "가다", tags: [])])
        let base = LookupResult(surface: "went", lemmas: ["went", "go"], guessedPos: [], phrases: [], entries: [local])
        let merged = mergeNaver(base, word: naver, phrases: [:])
        XCTAssertEqual(merged.entries.first?.source, .naver)
        XCTAssertEqual(merged.entries.last, local)
        XCTAssertEqual(Set(merged.entries.map(\.id)).count, merged.entries.count)
        XCTAssertTrue(merged.entries.dropLast().allSatisfy { $0.id < 0 })
    }

    func testCleanHTML() {
        XCTAssertEqual(NaverDictParser.cleanHTML("<b>a</b>&nbsp; &lt;b&gt;\n c"), "a <b> c")
    }
}
