import AppKit
import XCTest
@testable import BaristaApp

final class StatusItemPresentationTests: XCTestCase {
    func testInactivePresentationUsesOneCompactVariableLengthItem() {
        let presentation = StatusItemPresentation(isActive: false, remainingTimeText: nil)

        XCTAssertEqual(StatusItemPresentation.length, NSStatusItem.variableLength)
        XCTAssertEqual(StatusItemPresentation.iconRegionWidth, 36)
        XCTAssertEqual(StatusItemPresentation.actionMask, [.leftMouseDown])
        XCTAssertEqual(StatusItemPresentation.imagePosition, .imageRight)
        XCTAssertEqual(presentation.title, "")
        XCTAssertEqual(presentation.accessibilityValue, "Inactive")
    }

    func testActivePresentationDisplaysCountdownAndExposesItAccessibly() {
        let presentation = StatusItemPresentation(isActive: true, remainingTimeText: "1:00:00")

        XCTAssertEqual(presentation.title, "1:00:00")
        XCTAssertEqual(presentation.accessibilityValue, "Active, 1:00:00 remaining")
    }

    func testUntimedActivePresentationUsesCompactOnLabel() {
        let presentation = StatusItemPresentation(isActive: true, remainingTimeText: nil)

        XCTAssertEqual(presentation.title, "On")
        XCTAssertEqual(presentation.accessibilityValue, "Active")
    }

    func testStatusIconUsesMenuBarDimensions() {
        XCTAssertEqual(StatusIcon.image(active: false).size, NSSize(width: 18, height: 18))
        XCTAssertEqual(StatusIcon.image(active: true).size, NSSize(width: 18, height: 18))
    }

    func testPanelAnchorStaysInTheTrailingIconRegion() {
        let inactiveBounds = NSRect(x: 0, y: 0, width: 36, height: 22)
        let activeBounds = NSRect(x: 0, y: 0, width: 79, height: 22)
        let inactiveAnchor = StatusItemPresentation.anchorRect(in: inactiveBounds)
        let activeAnchor = StatusItemPresentation.anchorRect(in: activeBounds)

        XCTAssertEqual(inactiveBounds.maxX - inactiveAnchor.midX, 18)
        XCTAssertEqual(activeBounds.maxX - activeAnchor.midX, 18)
        XCTAssertEqual(inactiveAnchor.midY, inactiveBounds.midY)
        XCTAssertEqual(activeAnchor.midY, activeBounds.midY)
    }
}
