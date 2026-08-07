import CoreGraphics
import XCTest
@testable import BaristaApp

final class PanelLayoutPolicyTests: XCTestCase {
    func testPanelUsesOneFixedGeometry() {
        XCTAssertEqual(PanelLayoutPolicy.layout.contentSize, CGSize(width: 640, height: 411))
    }

    func testFrameAlreadyInsideVisibleAreaDoesNotMove() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1_440, height: 875)
        let frame = CGRect(x: 500, y: 400, width: 650, height: 421)

        XCTAssertEqual(PanelLayoutPolicy.clampedFrame(frame, to: visibleFrame), frame)
    }

    func testFrameIsClampedInsideEveryVisibleEdge() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1_440, height: 875)
        let size = CGSize(width: 650, height: 421)
        let frames = [
            CGRect(origin: CGPoint(x: 50, y: 300), size: size),
            CGRect(origin: CGPoint(x: 1_200, y: 300), size: size),
            CGRect(origin: CGPoint(x: 500, y: 0), size: size),
            CGRect(origin: CGPoint(x: 500, y: 700), size: size),
        ]

        for frame in frames {
            let result = PanelLayoutPolicy.clampedFrame(frame, to: visibleFrame)

            XCTAssertGreaterThanOrEqual(result.minX, visibleFrame.minX)
            XCTAssertLessThanOrEqual(result.maxX, visibleFrame.maxX)
            XCTAssertGreaterThanOrEqual(result.minY, visibleFrame.minY)
            XCTAssertLessThanOrEqual(result.maxY, visibleFrame.maxY)
            XCTAssertEqual(result.size, frame.size)
        }
    }

    func testPanelIsCenteredBelowItsAnchor() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 875)
        let anchorFrame = CGRect(x: 700, y: 880, width: 22, height: 22)

        let frame = PanelLayoutPolicy.frame(
            contentSize: PanelLayoutPolicy.layout.contentSize,
            below: anchorFrame,
            in: visibleFrame
        )

        XCTAssertEqual(frame.midX, anchorFrame.midX)
        XCTAssertEqual(frame.maxY, anchorFrame.minY - PanelLayoutPolicy.gap)
    }
}
