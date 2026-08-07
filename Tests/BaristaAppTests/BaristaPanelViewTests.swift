import AppKit
import SwiftUI
import XCTest
@testable import BaristaApp

@MainActor
final class BaristaPanelViewTests: XCTestCase {
    func testPanelDoesNotInstallAScrollView() {
        let layout = PanelLayoutPolicy.layout
        let hostingView = makeHostingView(controller: CaffeinateController(), layout: layout)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(hostingView.fittingSize, layout.contentSize)
        XCTAssertFalse(containsScrollView(in: hostingView))
    }

    func testStartStopStateCannotChangePanelSize() {
        let layout = PanelLayoutPolicy.layout
        let controller = CaffeinateController()
        let hostingView = makeHostingView(controller: controller, layout: layout)
        hostingView.layoutSubtreeIfNeeded()
        let inactiveSize = hostingView.fittingSize

        controller.isActive = true
        controller.statusText = "Active"
        controller.activeSummary = "Idle | 30 min"
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(inactiveSize, layout.contentSize)
        XCTAssertEqual(hostingView.fittingSize, layout.contentSize)
    }

    private func makeHostingView(
        controller: CaffeinateController,
        layout: PanelLayout
    ) -> NSHostingView<BaristaPanelView> {
        let hostingView = NSHostingView(
            rootView: BaristaPanelView(controller: controller, layout: layout)
        )
        hostingView.frame = NSRect(origin: .zero, size: layout.contentSize)
        return hostingView
    }

    private func containsScrollView(in view: NSView) -> Bool {
        if view is NSScrollView {
            return true
        }
        return view.subviews.contains(where: containsScrollView)
    }
}
