import CoreGraphics
import XCTest
@testable import BaristaApp

final class PopoverLayoutPolicyTests: XCTestCase {
    func testLargeDisplayUsesPreferredPanelSize() {
        let layout = PopoverLayoutPolicy.layout(
            forVisibleSize: CGSize(width: 2_560, height: 1_317)
        )

        XCTAssertEqual(layout.contentWidth, 640)
        XCTAssertEqual(layout.maximumContentHeight, 1_269)
        XCTAssertFalse(layout.stacksSections)
    }

    func testNarrowDisplayLeavesRoomForPopoverChrome() {
        let layout = PopoverLayoutPolicy.layout(
            forVisibleSize: CGSize(width: 640, height: 600)
        )

        XCTAssertEqual(layout.contentWidth, 592)
        XCTAssertEqual(layout.maximumContentHeight, 552)
        XCTAssertFalse(layout.stacksSections)
    }

    func testVeryNarrowDisplayStacksSections() {
        let layout = PopoverLayoutPolicy.layout(
            forVisibleSize: CGSize(width: 500, height: 480)
        )

        XCTAssertEqual(layout.contentWidth, 452)
        XCTAssertEqual(layout.maximumContentHeight, 432)
        XCTAssertTrue(layout.stacksSections)
    }

    func testTinyVisibleFrameNeverForcesPanelPastAvailableSpace() {
        let layout = PopoverLayoutPolicy.layout(
            forVisibleSize: CGSize(width: 300, height: 250)
        )

        XCTAssertEqual(layout.contentWidth, 252)
        XCTAssertEqual(layout.maximumContentHeight, 202)
        XCTAssertTrue(layout.stacksSections)
    }
}
