import XCTest
@testable import TubeVocab

final class SavedWordTests: XCTestCase {
    private func word(_ ko: String, sentence: String = "Recently we had a song battle.", createdAt: Int = 0) -> SavedWord {
        var w = SavedWord(
            surface: "recently", lemma: "recently", forms: ["recently"], pos: "adv",
            sense: "", senseTags: [], senseKo: "",
            sentenceEn: sentence, sentenceKo: "", videoId: "abc", timeMs: 1000, createdAt: createdAt
        )
        w.setMeanings([Meaning(gloss: ko, ko: ko, tags: [], pos: "adv")])
        return w
    }

    func testSeveralMeaningsInOneWord() {
        var w = word("요즘")
        w.setMeanings([
            Meaning(gloss: "5월", ko: "5월", tags: [], pos: "noun"),
            Meaning(gloss: "may의 뜻", ko: "아마", tags: ["informal"], pos: "verb"),
            Meaning(gloss: "Used to express possibility.", ko: "", tags: [], pos: "verb"),
        ])
        XCTAssertEqual(w.allMeanings.count, 3)
        XCTAssertEqual(w.summary, "5월, 아마, Used to express possibility.")
        XCTAssertEqual(w.senseKo, "5월, 아마")
        XCTAssertEqual(w.senseTags, ["informal"])
        XCTAssertEqual(w.pos, "noun")
    }

    func testOldSingleMeaningWordStillReads() throws {
        // 뜻 목록(meanings)이 없던 예전 저장 파일
        let json = #"[{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","surface":"released","lemma":"release","forms":[],"pos":"verb","sense":"놓아주다","senseTags":[],"senseKo":"놓아주다","sentenceEn":"It was released","sentenceKo":"","videoId":"v","timeMs":0,"createdAt":0,"stage":0,"dueAt":0,"correct":0,"wrong":0}]"#
        let list = try JSONDecoder().decode([SavedWord].self, from: Data(json.utf8))
        XCTAssertNil(list[0].meanings)
        XCTAssertEqual(list[0].summary, "놓아주다")
    }

    func testMergeDuplicatesFromSameSentence() {
        // 최근 저장이 앞: 근래에(가장 최근) → 요새 → 요즘(가장 먼저)
        let list = [word("근래에", createdAt: 3), word("요새", createdAt: 2), word("요즘", createdAt: 1),
                    word("다른 문장", sentence: "Recently it rained.", createdAt: 0)]
        let merged = SavedWord.mergeDuplicates(list)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].summary, "요즘, 요새, 근래에")
        XCTAssertEqual(merged[0].createdAt, 1) // 먼저 저장한 것 기준 (복습 기록 유지)
        XCTAssertEqual(merged[1].summary, "다른 문장")
    }

    @MainActor
    func testStoreAddMergesSameWordAndSentence() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "words-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = VocabStore(fileURL: url)
        store.add(word("요즘"))
        store.add(word("요새"))
        store.add(word("요즘")) // 같은 뜻을 또 저장해도 한 번만
        XCTAssertEqual(store.words.count, 1)
        XCTAssertEqual(store.words[0].summary, "요즘, 요새")

        // 다시 열어도 그대로
        let reopened = VocabStore(fileURL: url)
        XCTAssertEqual(reopened.words.map(\.summary), ["요즘, 요새"])
    }

    @MainActor
    func testOldDuplicateFileIsCleanedUpOnOpen() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "words-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode([word("요새", createdAt: 2), word("요즘", createdAt: 1)]).write(to: url)
        let store = VocabStore(fileURL: url)
        XCTAssertEqual(store.words.count, 1)
        let saved = try JSONDecoder().decode([SavedWord].self, from: Data(contentsOf: url))
        XCTAssertEqual(saved.count, 1)
    }
}
