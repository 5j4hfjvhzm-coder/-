import XCTest
@testable import NihongoTube

final class BlankTests: XCTestCase {
    private let target = BlankTarget(surface: "食べた", term: "食べる", readings: ["たべる"], start: 7)

    func testBlankUsesSavedPosition() throws {
        let b = try XCTUnwrap(makeBlank("昨日ラーメンを食べた。", target))
        XCTAssertEqual(b.before, "昨日ラーメンを")
        XCTAssertEqual(b.answer, "食べた")
        XCTAssertEqual(b.after, "。")
    }

    func testBlankFallsBackToSearch() throws {
        let b = try XCTUnwrap(makeBlank("また食べた", BlankTarget(surface: "食べた", term: "食べる", readings: [], start: 99)))
        XCTAssertEqual(b.before, "また")
        XCTAssertNil(makeBlank("飲んだ", target))
    }

    func testAcceptedAnswers() {
        XCTAssertTrue(isCorrect("食べた", target))
        XCTAssertTrue(isCorrect("食べる", target))
        XCTAssertTrue(isCorrect("たべた", target))
        XCTAssertTrue(isCorrect("タベル", target))
        XCTAssertTrue(isCorrect(" 食べた。", target))
        XCTAssertTrue(isCorrect("たべました", target))
        XCTAssertFalse(isCorrect("のむ", target))
        XCTAssertFalse(isCorrect("", target))
        XCTAssertTrue(isCorrect("いく", BlankTarget(surface: "行く", term: "行く", readings: ["ゆく", "いく"])))
    }

    func testHint() {
        XCTAssertEqual(quizHintText("食べた"), "食＿＿ (3글자)")
    }

    func testHighlight() {
        let idx = buildHighlightIndex([target])
        XCTAssertEqual(highlightMarks("昨日食べた", idx), [false, false, true, true, true])
        // 가나 한 글자는 칠하지 않는다
        XCTAssertEqual(highlightMarks("はい", buildHighlightIndex([BlankTarget(surface: "は", term: "は", readings: [])])), [false, false])
    }

    func testSegmentsCoverWholeText() {
        let text = "私は学生です。"
        let segs = segmentJapanese(text)
        XCTAssertEqual(segs.map(\.text).joined(), text)
        XCTAssertFalse(segs.last!.isWord) // 。
        XCTAssertEqual(segs.first?.start, 0)
    }
}
