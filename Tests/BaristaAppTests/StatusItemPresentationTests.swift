import AppKit
import XCTest
@testable import BaristaApp

final class StatusItemPresentationTests: XCTestCase {
    func testInactivePresentationKeepsStatusItemGeometryStable() {
        let presentation = StatusItemPresentation(isActive: false, remainingTimeText: nil)

        XCTAssertEqual(StatusItemPresentation.fixedLength, 100)
        XCTAssertEqual(presentation.title, " ")
        XCTAssertEqual(presentation.accessibilityValue, "Inactive")
    }

    func testActivePresentationUsesCountdownWhenAvailable() {
        let presentation = StatusItemPresentation(isActive: true, remainingTimeText: "1:00:00")

        XCTAssertEqual(presentation.title, "1:00:00")
        XCTAssertEqual(presentation.accessibilityValue, "Active, 1:00:00 remaining")
    }

    func testAnchorUsesStableCenterPoint() {
        let anchor = StatusItemPresentation.anchorRect(
            in: NSRect(x: 0, y: 0, width: 100, height: 22)
        )

        XCTAssertEqual(anchor, NSRect(x: 49.5, y: 10.5, width: 1, height: 1))
    }
}
