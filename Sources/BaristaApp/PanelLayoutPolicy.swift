import CoreGraphics

struct PanelLayout: Equatable {
    let contentSize: CGSize
}

enum PanelLayoutPolicy {
    static let layout = PanelLayout(contentSize: CGSize(width: 640, height: 411))
    static let gap: CGFloat = 6
    static let cornerRadius: CGFloat = 16

    static func frame(
        contentSize: CGSize,
        below anchorFrame: CGRect,
        in visibleFrame: CGRect
    ) -> CGRect {
        let proposedFrame = CGRect(
            x: anchorFrame.midX - contentSize.width / 2,
            y: anchorFrame.minY - gap - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )
        return clampedFrame(proposedFrame, to: visibleFrame)
    }

    static func clampedFrame(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        var result = frame
        let maximumOriginX = max(visibleFrame.minX, visibleFrame.maxX - frame.width)
        let maximumOriginY = max(visibleFrame.minY, visibleFrame.maxY - frame.height)

        result.origin.x = min(max(frame.origin.x, visibleFrame.minX), maximumOriginX)
        result.origin.y = min(max(frame.origin.y, visibleFrame.minY), maximumOriginY)
        return result
    }
}
