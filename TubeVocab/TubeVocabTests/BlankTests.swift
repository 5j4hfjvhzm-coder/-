import XCTest
@testable import TubeVocab

final class BlankTests: XCTestCase {
    let went = BlankTarget(surface: "went", lemma: "go", forms: ["goes", "going", "gone", "went"])

    func testBlanksSavedSurfaceKeepingCase() {
        XCTAssertEqual(makeBlank("Went home early.", went),
                       BlankQuestion(before: "", answer: "Went", after: " home early.", display: "_____"))
    }

    func testDoesNotTouchSubstrings() {
        let q = makeBlank("Good things are gone, so go.", BlankTarget(surface: "go", lemma: "go", forms: []))
        XCTAssertEqual(q?.before, "Good things are gone, so ")
        XCTAssertEqual(q?.after, ".")
    }

    func testMultiWord() {
        let q = makeBlank("She gave up on it.", BlankTarget(surface: "gave up", lemma: "give up", forms: []))
        XCTAssertEqual(q, BlankQuestion(before: "She ", answer: "gave up", after: " on it.", display: "_____ _____"))
    }

    func testSeparableSpan() {
        let q = makeBlank("Please pick it up now.", BlankTarget(surface: "pick it up", lemma: "pick up", forms: []))
        XCTAssertEqual(q?.answer, "pick it up")
    }

    func testCurlyApostrophe() {
        let q = makeBlank("I don’t know.", BlankTarget(surface: "don't", lemma: "do", forms: []))
        XCTAssertEqual(q?.answer, "don’t")
    }

    func testFallsBackToInflectedForm() {
        // 문장이 저장 때와 다른 활용형이어도 찾기
        XCTAssertEqual(makeBlank("She goes there.", went)?.answer, "goes")
        XCTAssertNil(makeBlank("Nothing here.", went))
    }

    func testAcceptsInflectedAndBaseForms() {
        XCTAssertTrue(isCorrect("went", went))
        XCTAssertTrue(isCorrect("  GO ", went))
        XCTAssertTrue(isCorrect("gone", went))
        XCTAssertFalse(isCorrect("goed", went))
        XCTAssertFalse(isCorrect("", went))
        XCTAssertTrue(isCorrect("give  up", BlankTarget(surface: "gave up", lemma: "give up", forms: [])))
    }

    func testFirstLetterHint() {
        XCTAssertEqual(firstLetterHint("went"), "w___")
        XCTAssertEqual(firstLetterHint("gave up"), "g___ u_")
        XCTAssertEqual(quizHintText("went"), "w＿＿＿ (4글자)")
        XCTAssertEqual(quizHintText("gave up"), "g＿＿＿ u＿ (6글자)")
    }
}

final class HighlightTests: XCTestCase {
    func testInflectedAndMultiWord() {
        let idx = buildHighlightIndex([
            BlankTarget(surface: "went", lemma: "go", forms: ["goes", "going", "gone", "went"]),
            BlankTarget(surface: "gave up", lemma: "give up", forms: []),
        ])
        let toks = tokenize("We went and gave up, going on.")
        let marks = highlightTokens(toks, idx)
        XCTAssertEqual(toks.indices.filter { marks[$0] }.map { toks[$0].text }, ["went", "gave", "up", "going"])
    }
}
