import XCTest
@testable import NihongoTube

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
            ("こんにちは", nil),
        ]
        for (input, id) in cases {
            XCTAssertEqual(parseVideoId(input), id, input)
        }
    }

    func testExtractCaptionTracksFromHtml() {
        let html = #"<script>var ytInitialPlayerResponse = {"captions":{"playerCaptionsTracklistRenderer":{"captionTracks":[{"baseUrl":"https://www.youtube.com/api/timedtext?v=x&lang=ja&fmt=srv3","name":{"simpleText":"日本語 \"自動\" [x]"},"languageCode":"ja","kind":"asr","isTranslatable":true}],"audioTracks":[]}}};</script>"#
        let tracks = normalizeTracks(extractJsonAfter(html, key: "captionTracks"))
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks[0].baseUrl, "https://www.youtube.com/api/timedtext?v=x&lang=ja&fmt=srv3")
        XCTAssertEqual(tracks[0].name, "日本語 \"自動\" [x]")
        XCTAssertEqual(tracks[0].kind, "asr")
        XCTAssertNil(extractJsonAfter("nothing", key: "captionTracks"))
    }

    func testJson3Url() {
        XCTAssertEqual(json3Url("https://y/api/timedtext?v=x&fmt=srv3&lang=ja"), "https://y/api/timedtext?v=x&lang=ja&fmt=json3")
        XCTAssertEqual(json3Url("https://y/t?v=x", tlang: "ko"), "https://y/t?v=x&fmt=json3&tlang=ko")
    }

    func testPlanAcceptsRegionalJapaneseCode() {
        let plan = planTracks([
            CaptionTrack(baseUrl: "https://y/t?lang=ja&kind=asr", languageCode: "ja", kind: "asr"),
            CaptionTrack(baseUrl: "https://y/t?lang=ja-JP", languageCode: "ja-JP"),
        ])
        XCTAssertEqual(plan?.ja.languageCode, "ja-JP")
        XCTAssertEqual(plan?.koSource, .autoTranslate)
        XCTAssertEqual(plan?.koUrl, "https://y/t?lang=ja-JP&fmt=json3&tlang=ko")
    }

    func testPlanFallsBackToAutoJapanese() {
        let plan = planTracks([CaptionTrack(baseUrl: "https://y/t?lang=ja", languageCode: "ja", kind: "asr")])
        XCTAssertEqual(plan?.ja.kind, "asr")
    }

    func testPlanUsesKoreanTrack() {
        let plan = planTracks([
            CaptionTrack(baseUrl: "https://y/t?lang=ja", languageCode: "ja"),
            CaptionTrack(baseUrl: "https://y/t?lang=ko", languageCode: "ko"),
        ])
        XCTAssertEqual(plan?.koSource, .manual)
        XCTAssertEqual(plan?.koUrl, "https://y/t?lang=ko&fmt=json3")
    }

    func testPlanWithoutJapanese() {
        XCTAssertNil(planTracks([CaptionTrack(baseUrl: "u", languageCode: "en")]))
        XCTAssertNil(planTracks([CaptionTrack(baseUrl: "u?a=1", languageCode: "ja", isTranslatable: false)])?.koUrl)
    }
}
