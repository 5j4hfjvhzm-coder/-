import XCTest
@testable import NihongoTube

final class LayoutTests: XCTestCase {
    /// 아이패드 가로에서만 영상·대본을 나란히
    func testWideLayoutOnlyOnLandscapeTablet() {
        XCTAssertTrue(VideoView.isWide(CGSize(width: 1180, height: 760)))   // iPad Air 가로
        XCTAssertTrue(VideoView.isWide(CGSize(width: 1366, height: 970)))   // iPad Pro 13 가로
        XCTAssertFalse(VideoView.isWide(CGSize(width: 820, height: 1120)))  // iPad 세로
        XCTAssertFalse(VideoView.isWide(CGSize(width: 590, height: 760)))   // 화면 나누기 절반
        XCTAssertFalse(VideoView.isWide(CGSize(width: 852, height: 393)))   // iPhone 가로
    }
}
