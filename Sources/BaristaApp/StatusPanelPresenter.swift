import AppKit

final class StatusPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class StatusPanelPresenter {
    private let panel: StatusPanelWindow
    private let contentSize: NSSize

    var isShown: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    init(contentViewController: NSViewController, contentSize: NSSize) {
        self.contentSize = contentSize
        panel = StatusPanelWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        panel.contentViewController = contentViewController
        panel.setContentSize(contentSize)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.animationBehavior = .none
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    @discardableResult
    func toggle(relativeTo button: NSStatusBarButton, anchorRect: NSRect) -> Bool {
        if isShown {
            close()
            return false
        }

        guard let statusWindow = button.window else { return false }
        let anchorInWindow = button.convert(anchorRect, to: nil)
        let anchorOnScreen = statusWindow.convertToScreen(anchorInWindow)
        let visibleFrame = statusWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        NSApp.activate(ignoringOtherApps: true)
        show(anchorFrame: anchorOnScreen, visibleFrame: visibleFrame)
        return isShown
    }

    func show(anchorFrame: NSRect, visibleFrame: NSRect) {
        guard !isShown else { return }
        let targetFrame = PanelLayoutPolicy.frame(
            contentSize: contentSize,
            below: anchorFrame,
            in: visibleFrame
        )
        panel.setFrame(targetFrame, display: false)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        panel.orderOut(nil)
    }

    func owns(_ event: NSEvent) -> Bool {
        event.window === panel
    }
}
