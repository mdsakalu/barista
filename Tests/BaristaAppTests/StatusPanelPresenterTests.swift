import AppKit
import XCTest
@testable import BaristaApp

final class StatusPanelPresenterTests: XCTestCase {
    func testVisiblePanelIgnoresAnchorChangesUntilItIsClosed() {
        let layout = PanelLayoutPolicy.layout
        let contentController = NSViewController()
        contentController.view = NSView(frame: NSRect(origin: .zero, size: layout.contentSize))
        let presenter = StatusPanelPresenter(
            contentViewController: contentController,
            contentSize: layout.contentSize
        )
        defer { presenter.close() }

        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 875)
        let firstAnchor = NSRect(x: 700, y: 880, width: 22, height: 22)
        let movedAnchor = NSRect(x: 1_200, y: 880, width: 79, height: 22)

        presenter.show(anchorFrame: firstAnchor, visibleFrame: visibleFrame)
        let firstFrame = presenter.frame
        presenter.show(anchorFrame: movedAnchor, visibleFrame: visibleFrame)

        XCTAssertTrue(presenter.isShown)
        XCTAssertEqual(presenter.frame, firstFrame)

        presenter.close()
        presenter.show(anchorFrame: movedAnchor, visibleFrame: visibleFrame)

        XCTAssertEqual(
            presenter.frame,
            PanelLayoutPolicy.frame(
                contentSize: layout.contentSize,
                below: movedAnchor,
                in: visibleFrame
            )
        )
        XCTAssertNotEqual(presenter.frame, firstFrame)
    }
}
