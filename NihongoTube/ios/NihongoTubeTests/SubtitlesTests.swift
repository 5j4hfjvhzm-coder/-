import XCTest
@testable import NihongoTube

final class SubtitlesTests: XCTestCase {
    func testBilingualSrtSplitsByLanguage() {
        let srt = "1\n00:00:01,000 --> 00:00:03,500\nこんにちは\n안녕하세요\n\n2\n00:00:04,000 --> 00:00:05,000\n<i>元気？</i>\n"
        let cues = parseSrtVtt(srt)
        XCTAssertEqual(cues.count, 2)
        let (ja, ko) = splitBilingual(cues)
        XCTAssertEqual(ja.map(\.text), ["こんにちは", "元気？"])
        XCTAssertEqual(ko.map(\.text), ["안녕하세요"])
        let bi = alignBilingual(ja, ko)
        XCTAssertEqual(bi[0].ko, "안녕하세요")
        XCTAssertEqual(bi[1].ko, "")
    }

    func testKoreanLineWithKanaStaysJapanese() {
        XCTAssertFalse(isKoreanLine("「すごい」라고 했다"))
        XCTAssertTrue(isKoreanLine("정말 대단해"))
    }

    func testAutoCaptionWordsJoinWithoutSpaces() {
        let ws = [TimedWord(t: 0, text: "今日"), TimedWord(t: 200, text: "は"), TimedWord(t: 400, text: "いい"),
                  TimedWord(t: 600, text: "天気。"), TimedWord(t: 3000, text: "行こう")]
        let s = wordsToSentences(ws)
        XCTAssertEqual(s.map(\.text), ["今日はいい天気。", "行こう"])
    }

    func testMergeLinesJapanese() {
        let lines = [Cue(start: 0, end: 1000, text: "ちょっと"), Cue(start: 1000, end: 2000, text: "待って。"),
                     Cue(start: 2100, end: 3000, text: "はい")]
        XCTAssertEqual(mergeLinesToSentences(lines).map(\.text), ["ちょっと待って。", "はい"])
    }

    func testPlanPrefersJapaneseManualAndTranslatesKorean() {
        let tracks = [
            CaptionTrack(baseUrl: "https://x/a?lang=ja&kind=asr", languageCode: "ja", kind: "asr"),
            CaptionTrack(baseUrl: "https://x/b?lang=ja", languageCode: "ja"),
            CaptionTrack(baseUrl: "https://x/c?lang=en", languageCode: "en"),
        ]
        let plan = planTracks(tracks)
        XCTAssertEqual(plan?.ja.baseUrl, "https://x/b?lang=ja")
        XCTAssertEqual(plan?.koSource, .autoTranslate)
        XCTAssertEqual(plan?.koUrl, "https://x/b?lang=ja&fmt=json3&tlang=ko")
        XCTAssertNil(planTracks([CaptionTrack(baseUrl: "https://x/c", languageCode: "en")]))
    }

    func testDecodeShiftJISFile() throws {
        let text = "1\n00:00:01,000 --> 00:00:02,000\nありがとう\n"
        guard let data = text.data(using: .shiftJIS) else { throw XCTSkip("Shift_JIS 를 지원하지 않는 환경") }
        XCTAssertEqual(decodeSubtitleData(data).map(parseSrtVtt)?.first?.text, "ありがとう")
    }
}
