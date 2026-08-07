import AppKit

struct StatusItemPresentation {
    static let length = NSStatusItem.variableLength
    static let iconRegionWidth: CGFloat = 36
    static let actionMask: NSEvent.EventTypeMask = [.leftMouseDown]
    static let imagePosition: NSControl.ImagePosition = .imageRight

    let title: String
    let accessibilityValue: String

    init(isActive: Bool, remainingTimeText: String?) {
        guard isActive else {
            title = ""
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
            x: max(bounds.minX, bounds.maxX - iconRegionWidth / 2 - 0.5),
            y: bounds.midY - 0.5,
            width: 1,
            height: 1
        )
    }
}
