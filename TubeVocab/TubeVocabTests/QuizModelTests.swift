import XCTest
@testable import TubeVocab

@MainActor
final class QuizModelTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appending(path: "quiz-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    private func word(_ surface: String, lemma: String? = nil, forms: [String] = [], star: Bool = false) -> SavedWord {
        var w = SavedWord(
            surface: surface, lemma: lemma ?? surface, forms: forms, pos: "verb",
            sense: "", senseTags: [], senseKo: "",
            sentenceEn: "They \(surface) home.", sentenceKo: "", videoId: "v", timeMs: 0
        )
        w.starred = star
        return w
    }

    func testModesAndStarFilter() {
        let quiz = QuizModel(fileURL: url)
        let words = [word("went", star: true), word("ran"), word("sat")]
        quiz.start(.all, words: words)
        XCTAssertEqual(quiz.run?.n, 3)
        XCTAssertEqual(quiz.run?.label, "전체 퀴즈")

        quiz.start(.star, words: words)
        XCTAssertEqual(quiz.run?.list, [words[0].id])

        quiz.setSkip(true)
        XCTAssertEqual(quiz.count(words), 2)
        quiz.start(.test, words: words)
        XCTAssertEqual(quiz.run?.n, 2)
        XCTAssertEqual(quiz.run?.label, "전체 테스트 (★ 제외)")
        XCTAssertEqual(quiz.run?.isTest, true)
    }

    func testCheckAcceptsFormsAndTracksWrong() throws {
        let quiz = QuizModel(fileURL: url)
        let w = word("went", lemma: "go", forms: ["goes", "gone"])
        quiz.start(.all, words: [w])
        XCTAssertNil(quiz.check("   ", word: w, blankAnswer: "went"))
        XCTAssertEqual(quiz.check("GO", word: w, blankAnswer: "went"), true)
        XCTAssertNil(quiz.check("went", word: w, blankAnswer: "went")) // 이미 확인함
        XCTAssertEqual(quiz.run?.ok, 1)

        quiz.start(.all, words: [w])
        XCTAssertEqual(quiz.check("goed", word: w, blankAnswer: "went"), false)
        XCTAssertEqual(quiz.run?.wrong, [w.id])
        quiz.next()
        XCTAssertEqual(quiz.run?.finished, true)

        quiz.retryWrong()
        XCTAssertEqual(quiz.run?.list, [w.id])
        XCTAssertEqual(quiz.run?.i, 0)
        XCTAssertTrue(quiz.run?.label.hasPrefix("틀린 문제 다시") ?? false)
    }

    func testHintAndSaveAndResume() {
        let words = [word("went"), word("ran"), word("sat")]
        let quiz = QuizModel(fileURL: url)
        quiz.start(.all, words: words)
        quiz.showHint()
        XCTAssertEqual(quiz.run?.hint, true)
        let first = quiz.run!.currentID!
        quiz.check("x", word: words.first { $0.id == first }!, blankAnswer: "x")
        quiz.saveSession()
        XCTAssertNil(quiz.run)
        XCTAssertEqual(quiz.data.sess.count, 1)
        XCTAssertEqual(quiz.data.sess[0].i, 1) // 확인한 문제는 지나간 것으로

        // 앱을 다시 열어도 남아 있고, 그 사이 지운 단어는 빠진다
        let reopened = QuizModel(fileURL: url)
        let sid = reopened.data.sess[0].sid
        let remaining = words.filter { $0.id != reopened.data.sess[0].list[2] }
        reopened.resume(sid, words: remaining)
        XCTAssertEqual(reopened.run?.n, 2)
        XCTAssertEqual(reopened.run?.i, 1)

        // 끝까지 풀면 저장한 풀이는 지워진다
        reopened.next()
        XCTAssertEqual(reopened.run?.finished, true)
        XCTAssertTrue(reopened.data.sess.isEmpty)
    }

    func testOldSavedWordsHaveNoStar() throws {
        let json = #"[{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","surface":"released","lemma":"release","forms":[],"pos":"verb","sense":"놓아주다","senseTags":[],"senseKo":"놓아주다","sentenceEn":"It was released","sentenceKo":"","videoId":"v","timeMs":0,"createdAt":0,"stage":0,"dueAt":0,"correct":0,"wrong":0}]"#
        let list = try JSONDecoder().decode([SavedWord].self, from: Data(json.utf8))
        XCTAssertFalse(list[0].star)
    }

    func testHintText() {
        XCTAssertEqual(quizHintText("went"), "w＿＿＿ (4글자)")
    }
}
