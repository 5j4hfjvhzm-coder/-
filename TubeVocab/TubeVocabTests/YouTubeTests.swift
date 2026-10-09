import XCTest
@testable import TubeVocab

final class YouTubeTests: XCTestCase {
    func testParseVideoId() {
        let cases: [(String, String?)] = [
            ("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10s", "dQw4w9WgXcQ"),
            ("https://youtu.be/dQw4w9WgXcQ?si=abc", "dQw4w9WgXcQ"),
            ("youtube.com/shorts/dQw4w9WgXcQ", "dQw4w9WgXcQ"),
            ("https://m.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
            ("https://www.youtube.com/embed/dQw4w9WgXcQ", "dQw4w9WgXcQ"),
            ("https://www.youtube.com/live/dQw4w9WgXcQ?feature=share", "dQw4w9WgXcQ"),
            ("  dQw4w9WgXcQ ", "dQw4w9WgXcQ"),
            ("https://example.com/watch?v=dQw4w9WgXcQ", nil),
            ("hello", nil),
        ]
        for (input, id) in cases {
            XCTAssertEqual(parseVideoId(input), id, input)
        }
    }

    func testExtractCaptionTracksFromHtml() {
        let html = #"<script>var ytInitialPlayerResponse = {"captions":{"playerCaptionsTracklistRenderer":{"captionTracks":[{"baseUrl":"https://www.youtube.com/api/timedtext?v=x&lang=en&fmt=srv3","name":{"simpleText":"English \"auto\" [x]"},"languageCode":"en","kind":"asr","isTranslatable":true}],"audioTracks":[]}}};</script>"#
        let tracks = normalizeTracks(extractJsonAfter(html, key: "captionTracks"))
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks[0].baseUrl, "https://www.youtube.com/api/timedtext?v=x&lang=en&fmt=srv3")
        XCTAssertEqual(tracks[0].name, "English \"auto\" [x]")
        XCTAssertEqual(tracks[0].kind, "asr")
        XCTAssertNil(extractJsonAfter("nothing", key: "captionTracks"))
    }

    func testJson3Url() {
        XCTAssertEqual(json3Url("https://y/api/timedtext?v=x&fmt=srv3&lang=en"), "https://y/api/timedtext?v=x&lang=en&fmt=json3")
        XCTAssertEqual(json3Url("https://y/t?v=x", tlang: "ko"), "https://y/t?v=x&fmt=json3&tlang=ko")
    }

    func testPlanPrefersManualEnglishAndAutoTranslatesKorean() {
        let plan = planTracks([
            CaptionTrack(baseUrl: "https://y/t?lang=en&kind=asr", languageCode: "en", kind: "asr"),
            CaptionTrack(baseUrl: "https://y/t?lang=en-US", languageCode: "en-US"),
        ])
        XCTAssertEqual(plan?.en.languageCode, "en-US")
        XCTAssertEqual(plan?.koSource, .autoTranslate)
        XCTAssertEqual(plan?.koUrl, "https://y/t?lang=en-US&fmt=json3&tlang=ko")
    }

    func testPlanUsesKoreanTrack() {
        let plan = planTracks([
            CaptionTrack(baseUrl: "https://y/t?lang=en", languageCode: "en"),
            CaptionTrack(baseUrl: "https://y/t?lang=ko", languageCode: "ko"),
        ])
        XCTAssertEqual(plan?.koSource, .manual)
        XCTAssertEqual(plan?.koUrl, "https://y/t?lang=ko&fmt=json3")
    }

    func testPlanWithoutEnglish() {
        XCTAssertNil(planTracks([CaptionTrack(baseUrl: "u", languageCode: "ja")]))
        XCTAssertNil(planTracks([CaptionTrack(baseUrl: "u?a=1", languageCode: "en", isTranslatable: false)])?.koUrl)
    }
}
