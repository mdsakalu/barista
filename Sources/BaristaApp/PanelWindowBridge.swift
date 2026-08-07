import AppKit
import Combine
import SwiftUI

final class PanelVisibilityMonitor: ObservableObject {
    @Published var isVisible: Bool = true

    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []

    func attach(to window: NSWindow?) {
        guard let window, window !== self.window else { return }
        detach()
        self.window = window
        isVisible = window.isVisible

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.setVisible(true)
        })
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.setVisible(false)
        })
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.setVisible(false)
        })
    }

    deinit {
        detach()
    }

    private func detach() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        window = nil
    }

    private func setVisible(_ value: Bool) {
        if Thread.isMainThread {
            isVisible = value
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isVisible = value
            }
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            onWindow(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            onWindow(nsView?.window)
        }
    }
}

