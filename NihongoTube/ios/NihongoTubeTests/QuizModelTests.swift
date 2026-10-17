import XCTest
@testable import NihongoTube

@MainActor
final class QuizModelTests: XCTestCase {
    /// 테스트마다 새 저장 파일
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("quiz-\(UUID().uuidString).json")
    }

    func testModesAndStarFilter() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let quiz = QuizModel(fileURL: url)
        let words = [makeWord("行った", term: "行く", star: true), makeWord("見た", term: "見る"), makeWord("寝た", term: "寝る")]
        quiz.start(.all, words: words)
        XCTAssertEqual(quiz.run?.n, 3)
        quiz.start(.star, words: words)
        XCTAssertEqual(quiz.run?.list, [words[0].id])
        quiz.setSkip(true)
        XCTAssertEqual(quiz.count(words), 2)
        quiz.start(.test, words: words)
        XCTAssertEqual(quiz.run?.label, "전체 테스트 (★ 제외)")
    }

    func testCheckAcceptsKanaAndTracksWrong() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let quiz = QuizModel(fileURL: url)
        let w = makeWord("食べた", term: "食べる", readings: ["たべる"])
        quiz.start(.all, words: [w])
        XCTAssertNil(quiz.check("  ", word: w, blankAnswer: "食べた"))
        XCTAssertEqual(quiz.check("たべた", word: w, blankAnswer: "食べた"), true)
        XCTAssertEqual(quiz.run?.ok, 1)
        quiz.start(.all, words: [w])
        XCTAssertEqual(quiz.check("のんだ", word: w, blankAnswer: "食べた"), false)
        XCTAssertEqual(quiz.run?.wrong, [w.id])
        quiz.next()
        XCTAssertEqual(quiz.run?.finished, true)
        quiz.retryWrong()
        XCTAssertEqual(quiz.run?.list, [w.id])
    }

    func testSaveAndResume() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let words = [makeWord("行った", term: "行く"), makeWord("見た", term: "見る"), makeWord("寝た", term: "寝る")]
        let quiz = QuizModel(fileURL: url)
        quiz.start(.all, words: words)
        let first = quiz.run!.currentID!
        quiz.check("x", word: words.first { $0.id == first }!, blankAnswer: "x")
        quiz.saveSession()
        XCTAssertEqual(quiz.data.sess.first?.i, 1)
        let reopened = QuizModel(fileURL: url)
        reopened.resume(reopened.data.sess[0].sid, words: words)
        XCTAssertEqual(reopened.run?.i, 1)
    }
}
