import AppKit

struct StatusItemPresentation {
    static let fixedLength: CGFloat = 100

    let title: String
    let accessibilityValue: String

    init(isActive: Bool, remainingTimeText: String?) {
        guard isActive else {
            // A non-empty title keeps NSStatusBarButton at the same height as its active state.
            title = " "
            accessibilityValue = "Inactive"
            return
        }

        if let remainingTimeText {
            title = remainingTimeText.count <= 8 ? remainingTimeText : "99h+"
            accessibilityValue = "Active, \(remainingTimeText) remaining"
        } else {
            title = "On"
            accessibilityValue = "Active"
        }
    }

    static func anchorRect(in bounds: NSRect) -> NSRect {
        NSRect(
            x: bounds.midX - 0.5,
            y: bounds.midY - 0.5,
            width: 1,
            height: 1
        )
    }
}
