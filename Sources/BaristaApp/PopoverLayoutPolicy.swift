import CoreGraphics

struct PopoverLayout: Equatable {
    let contentWidth: CGFloat
    let maximumContentHeight: CGFloat
    let stacksSections: Bool
}

enum PopoverLayoutPolicy {
    private static let preferredContentWidth: CGFloat = 640
    private static let popoverChromeAllowance: CGFloat = 48
    private static let stackedSectionsThreshold: CGFloat = 560

    static func layout(forVisibleSize visibleSize: CGSize) -> PopoverLayout {
        let availableWidth = max(1, visibleSize.width - popoverChromeAllowance)
        let contentWidth = min(preferredContentWidth, availableWidth)
        let maximumContentHeight = max(1, visibleSize.height - popoverChromeAllowance)

        return PopoverLayout(
            contentWidth: contentWidth,
            maximumContentHeight: maximumContentHeight,
            stacksSections: contentWidth < stackedSectionsThreshold
        )
    }
}
