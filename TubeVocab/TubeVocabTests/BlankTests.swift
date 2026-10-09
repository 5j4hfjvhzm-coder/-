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
    }

    func testChoicesAreUniqueAndExcludeSameLemma() {
        let c = makeChoices(answer: "went", target: went, pool: ["go", "gone", "apple", "run", "cool", "apple"], rand: seededRandom(42))
        XCTAssertEqual(c.count, 4)
        XCTAssertTrue(c.contains("went"))
        XCTAssertEqual(Set(c.map { $0.lowercased() }).count, 4)
        XCTAssertFalse(c.contains("go"))
        XCTAssertFalse(c.contains("gone"))
    }

    func testChoicesFillFromFallback() {
        XCTAssertEqual(makeChoices(answer: "went", target: went, pool: [], rand: seededRandom(1)).count, 4)
    }

    func testMultiWordAnswerPrefersMultiWordDistractors() {
        let c = makeChoices(answer: "gave up", target: BlankTarget(surface: "gave up", lemma: "give up", forms: []),
                            pool: ["look into", "run out", "cat", "dog", "tree"], rand: seededRandom(3))
        XCTAssertGreaterThanOrEqual(c.filter { $0.contains(" ") }.count, 3)
    }

    func testSameSeedSameChoices() {
        let a = makeChoices(answer: "went", target: went, pool: ["a1", "b2", "c3", "d4"], rand: seededRandom(7))
        let b = makeChoices(answer: "went", target: went, pool: ["a1", "b2", "c3", "d4"], rand: seededRandom(7))
        XCTAssertEqual(a, b)
    }
}

final class SrsTests: XCTestCase {
    private let day = 86_400_000

    func testIntervalsWhenCorrect() {
        var s = SrsState(stage: 0, dueAt: 0)
        var gaps: [Int] = []
        for _ in 0..<8 {
            s = review(s, correct: true, now: 0)
            gaps.append(s.dueAt / day)
        }
        XCTAssertEqual(gaps, [1, 3, 7, 14, 30, 60, 60, 60])
    }

    func testWrongResetsAndComesBackInTenMinutes() {
        XCTAssertEqual(review(SrsState(stage: 4, dueAt: 0), correct: false, now: 1000),
                       SrsState(stage: 0, dueAt: 1000 + wrongDelayMs))
        XCTAssertEqual(describeDue(wrongDelayMs, now: 0), "10분 뒤")
        XCTAssertEqual(describeDue(-1, now: 0), "지금 복습")
        XCTAssertEqual(describeDue(3 * day, now: 0), "3일 뒤")
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
