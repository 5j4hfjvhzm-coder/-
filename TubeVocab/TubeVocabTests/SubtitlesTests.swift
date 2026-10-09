import XCTest
@testable import TubeVocab

final class Json3Tests: XCTestCase {
    func testManualTrackCleansTextAndSkipsNewlineEvents() {
        let json = Json3(events: [
            Json3Event(tStartMs: 0, dDurationMs: 2000, segs: [Json3Seg(utf8: "Hello\nthere &amp; welcome")]),
            Json3Event(tStartMs: 2000, dDurationMs: 1500, segs: [Json3Seg(utf8: "\n")]),
            Json3Event(tStartMs: 3000, dDurationMs: 2000, segs: [Json3Seg(utf8: "It&#39;s me.")]),
        ])
        XCTAssertEqual(json3ToCues(json), [
            Cue(start: 0, end: 2000, text: "Hello there & welcome"),
            Cue(start: 3000, end: 5000, text: "It's me."),
        ])
    }

    func testRollingCaptionsAreTrimmedAtNextStart() {
        let json = Json3(events: [
            Json3Event(tStartMs: 0, dDurationMs: 5000, segs: [Json3Seg(utf8: "첫 줄")]),
            Json3Event(tStartMs: 2000, dDurationMs: 4000, segs: [Json3Seg(utf8: "둘째 줄")]),
        ])
        let cues = json3ToCues(json)
        XCTAssertEqual(cues[0].end, 2000)
        XCTAssertEqual(cues[1], Cue(start: 2000, end: 6000, text: "둘째 줄"))
    }

    func testAsrWordsUseOffsetsAndIgnoreAppendEvents() {
        let json = Json3(events: [
            Json3Event(tStartMs: 1000, dDurationMs: 3000, segs: [
                Json3Seg(utf8: "so"), Json3Seg(utf8: " I", tOffsetMs: 200), Json3Seg(utf8: " gave", tOffsetMs: 400),
            ]),
            Json3Event(tStartMs: 1900, dDurationMs: 2100, segs: [Json3Seg(utf8: "\n")], aAppend: 1),
            Json3Event(tStartMs: 1900, dDurationMs: 2000, segs: [Json3Seg(utf8: "up")]),
        ])
        XCTAssertEqual(json3ToWords(json), [
            TimedWord(t: 1000, text: "so"), TimedWord(t: 1200, text: "I"),
            TimedWord(t: 1400, text: "gave"), TimedWord(t: 1900, text: "up"),
        ])
    }

    func testDecodesRealJson3Shape() throws {
        let data = Data(#"{"wireMagic":"pb3","events":[{"tStartMs":0,"dDurationMs":1000,"segs":[{"utf8":"Hi"}]}]}"#.utf8)
        let json = try JSONDecoder().decode(Json3.self, from: data)
        XCTAssertEqual(json3ToCues(json).first?.text, "Hi")
    }
}

final class SentenceMergeTests: XCTestCase {
    private func w(_ t: Int, _ s: String) -> TimedWord { TimedWord(t: t, text: s) }

    func testSplitsAtPunctuation() {
        let cues = wordsToSentences([w(0, "Hi"), w(300, "there."), w(600, "How"), w(900, "are"), w(1200, "you?")])
        XCTAssertEqual(cues.map(\.text), ["Hi there.", "How are you?"])
        XCTAssertEqual(cues.map(\.start), [0, 600])
    }

    func testSplitsAtLongPauseOnlyAfterMinWords() {
        let ws = [w(0, "so"), w(200, "today"), w(400, "we"), w(600, "will"), w(2000, "learn"), w(2200, "words")]
        XCTAssertEqual(wordsToSentences(ws).map(\.text), ["so today we will", "learn words"])
        XCTAssertEqual(wordsToSentences([w(0, "a"), w(1500, "b"), w(1700, "c"), w(1900, "d")]).map(\.text), ["a b c d"])
    }

    func testForcedSplitAtMaxWords() {
        let many = (0..<20).map { w($0 * 100, "w\($0)") }
        XCTAssertEqual(wordsToSentences(many, options: SentenceOptions(maxWords: 10)).count, 2)
    }

    func testEndDoesNotPassNextStart() {
        let cues = wordsToSentences([w(0, "one."), w(800, "two.")])
        XCTAssertLessThanOrEqual(cues[0].end, 800)
    }

    func testMergeLines() {
        let merged = mergeLinesToSentences([
            Cue(start: 0, end: 1000, text: "I really wanted to"),
            Cue(start: 1000, end: 2000, text: "give up."),
            Cue(start: 2100, end: 3000, text: "But I did not."),
        ])
        XCTAssertEqual(merged.map(\.text), ["I really wanted to give up.", "But I did not."])
    }
}

final class AlignTests: XCTestCase {
    let en = [
        Cue(start: 0, end: 3000, text: "I wanted to give up."),
        Cue(start: 3000, end: 6000, text: "But I kept going."),
    ]

    func testAttachesToMaxOverlap() {
        let ko = [
            Cue(start: 0, end: 1500, text: "포기하고"),
            Cue(start: 1500, end: 3200, text: "싶었어요."),
            Cue(start: 3300, end: 6000, text: "하지만 계속했죠."),
        ]
        XCTAssertEqual(alignBilingual(en, ko).map(\.ko), ["포기하고 싶었어요.", "하지만 계속했죠."])
    }

    func testNearWithinOneSecondOtherwiseDropped() {
        let ko = [Cue(start: 6200, end: 6800, text: "가까움"), Cue(start: 20000, end: 21000, text: "멀리")]
        let r = alignBilingual(en, ko)
        XCTAssertEqual(r[1].ko, "가까움")
        XCTAssertFalse(r.map(\.ko).joined().contains("멀리"))
    }

    func testDuplicateTranslationOnce() {
        let ko = [Cue(start: 0, end: 1000, text: "안녕"), Cue(start: 1000, end: 2000, text: "안녕")]
        XCTAssertEqual(alignBilingual(en, ko)[0].ko, "안녕")
    }

    func testKoreanOnly() {
        XCTAssertEqual(alignBilingual([], [Cue(start: 0, end: 1, text: "가")]), [BiCue(start: 0, end: 1, en: "", ko: "가")])
    }

    func testFindCueIndex() {
        let cues = [Cue(start: 0, end: 1000, text: ""), Cue(start: 2000, end: 3000, text: ""), Cue(start: 3000, end: 4000, text: "")]
        let cases: [(Int, Int)] = [(-1, -1), (0, 0), (1500, 0), (2999, 1), (3000, 2), (99999, 2)]
        for (t, idx) in cases {
            XCTAssertEqual(findCueIndex(cues, t), idx, "t=\(t)")
        }
    }
}

final class SrtVttTests: XCTestCase {
    func testSrt() {
        let srt = "1\r\n00:00:01,000 --> 00:00:02,500\r\n<i>Hello</i> world\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\nSecond\r\nline\r\n"
        XCTAssertEqual(parseSrtVtt(srt), [
            Cue(start: 1000, end: 2500, text: "Hello world"),
            Cue(start: 3000, end: 4000, text: "Second\nline"),
        ])
    }

    func testVtt() {
        let vtt = """
        WEBVTT
        Kind: captions

        intro
        00:01.200 --> 00:02.000 align:start position:0%
        Hi

        01:00:00.000 --> 01:00:01.000
        Late
        """
        XCTAssertEqual(parseSrtVtt(vtt), [
            Cue(start: 1200, end: 2000, text: "Hi"),
            Cue(start: 3_600_000, end: 3_601_000, text: "Late"),
        ])
    }

    func testBilingualFileIsSplitByHangul() {
        let (en, ko) = splitBilingual([Cue(start: 0, end: 1000, text: "I gave up.\n나는 포기했어.")])
        XCTAssertEqual(en.first?.text, "I gave up.")
        XCTAssertEqual(ko.first?.text, "나는 포기했어.")
    }

    func testCp949File() {
        let cp949 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosKorean.rawValue)))
        let data = "1\n00:00:01,000 --> 00:00:02,000\n안녕하세요\n".data(using: cp949)!
        XCTAssertEqual(parseSrtVtt(decodeSubtitleData(data) ?? "").first?.text, "안녕하세요")
    }

    func testFormatTime() {
        XCTAssertEqual(formatTime(65_000), "1:05")
        XCTAssertEqual(formatTime(3_725_000), "1:02:05")
    }
}
