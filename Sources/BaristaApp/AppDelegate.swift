import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = CaffeinateController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var hostingController: NSHostingController<BaristaPanelView>?
    private var currentPopoverLayout: PopoverLayout?
    private var aboutWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []
    private var popoverFrameObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BaristaDefaults.register()
        CaffeinateController.cleanupOrphanedProcess()
        NSApp.setActivationPolicy(.accessory)
        setupPopover()
        setupStatusItem()
        observeController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    private func setupPopover() {
        let layout = PopoverLayoutPolicy.layout(
            forVisibleSize: NSScreen.main?.visibleFrame.size ?? CGSize(width: 640, height: 800)
        )
        let panelView = BaristaPanelView(controller: controller, layout: layout)
        let hostingController = NSHostingController(rootView: panelView)
        self.hostingController = hostingController
        currentPopoverLayout = layout
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: StatusItemPresentation.fixedLength)
        guard let button = statusItem?.button else { return }
        button.image = StatusIcon.image(active: controller.isActive)
        button.image?.isTemplate = true
        button.setAccessibilityLabel("Barista")
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItemDisplay()
    }

    private func observeController() {
        controller.$isActive
            .combineLatest(controller.$remainingTimeText)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.type == .rightMouseDown {
            if popover.isShown {
                popover.performClose(nil)
            }
            showContextMenu(event: event, button: sender)
        } else {
            togglePopover(button: sender)
        }
    }

    private func togglePopover(button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        updatePopoverLayout(for: button.window?.screen)
        let anchorRect = popoverAnchorRect(for: button)
        popover.show(relativeTo: anchorRect, of: button, preferredEdge: .minY)
        startClampingPopover()
    }

    private func updatePopoverLayout(for screen: NSScreen?) {
        let visibleSize = (screen ?? NSScreen.main)?.visibleFrame.size
            ?? CGSize(width: 640, height: 800)
        let layout = PopoverLayoutPolicy.layout(forVisibleSize: visibleSize)
        guard layout != currentPopoverLayout, let hostingController else { return }

        hostingController.rootView = BaristaPanelView(controller: controller, layout: layout)
        hostingController.view.layoutSubtreeIfNeeded()
        currentPopoverLayout = layout
    }

    private func startClampingPopover() {
        stopClampingPopover()
        guard let popoverWindow = popover.contentViewController?.view.window else { return }

        // Clamp immediately, then observe every frame change so animation can't escape.
        clampWindow(popoverWindow)

        popoverFrameObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: popoverWindow,
            queue: .main
        ) { [weak self, weak popoverWindow] _ in
            guard let window = popoverWindow else { return }
            self?.clampWindow(window)
        }

        // Also observe close to tear down.
        cancellables.insert(
            NotificationCenter.default.publisher(for: NSPopover.didCloseNotification, object: popover)
                .first()
                .sink { [weak self] _ in self?.stopClampingPopover() }
        )
    }

    private func stopClampingPopover() {
        if let observer = popoverFrameObserver {
            NotificationCenter.default.removeObserver(observer)
            popoverFrameObserver = nil
        }
    }

    private func clampWindow(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        var frame = window.frame

        if frame.maxX > visible.maxX {
            frame.origin.x = visible.maxX - frame.width
        }
        if frame.minX < visible.minX {
            frame.origin.x = visible.minX
        }
        if frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }

        if frame != window.frame {
            window.setFrame(frame, display: false)
        }
    }

    private func popoverAnchorRect(for button: NSStatusBarButton) -> NSRect {
        StatusItemPresentation.anchorRect(in: button.bounds)
    }

    private func showContextMenu(event: NSEvent?, button: NSStatusBarButton) {
        let menu = buildContextMenu()
        if let event {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else {
            statusItem?.menu = menu
            button.performClick(nil)
            statusItem?.menu = nil
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let (configuration, _) = currentConfiguration()
        let toggleTitle = controller.isActive ? "Stop" : "Start"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = controller.isActive || configuration.validationMessage == nil
        menu.addItem(toggleItem)

        let quickMenuItem = NSMenuItem(title: "Quick Duration", action: nil, keyEquivalent: "")
        let quickMenu = NSMenu()
        quickMenu.addItem(makeMenuItem(title: "5m", action: #selector(startQuickDuration5m)))
        quickMenu.addItem(makeMenuItem(title: "15m", action: #selector(startQuickDuration15m)))
        quickMenu.addItem(makeMenuItem(title: "30m", action: #selector(startQuickDuration30m)))
        quickMenu.addItem(makeMenuItem(title: "1h", action: #selector(startQuickDuration1h)))
        quickMenu.addItem(makeMenuItem(title: "2h", action: #selector(startQuickDuration2h)))
        quickMenuItem.submenu = quickMenu
        menu.addItem(quickMenuItem)

        menu.addItem(.separator())

        let pidItem = makeCaffeinatePidItem()
        menu.addItem(pidItem)

        let aboutItem = NSMenuItem(title: "About Barista", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func makeCaffeinatePidItem() -> NSMenuItem {
        if let info = CaffeinateController.trackedPidInfo() {
            let title = info.isRunning
                ? "Force Stop Caffeinate (PID \(info.pid))"
                : "Clear stale Caffeinate PID (\(info.pid))"
            let item = NSMenuItem(title: title, action: #selector(forceStopCaffeinate), keyEquivalent: "")
            item.target = self
            return item
        }
        let item = NSMenuItem(title: "No Caffeinate PID", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleFromMenu() {
        ContextMenuToggleAction.perform(
            isActive: controller.isActive,
            defaults: .standard,
            stop: controller.stop
        ) {
            let (configuration, summary) = currentConfiguration()
            controller.start(with: configuration, summary: summary)
        }
    }

    @objc private func startQuickDuration5m() { startQuickDuration(5, .minutes) }
    @objc private func startQuickDuration15m() { startQuickDuration(15, .minutes) }
    @objc private func startQuickDuration30m() { startQuickDuration(30, .minutes) }
    @objc private func startQuickDuration1h() { startQuickDuration(1, .hours) }
    @objc private func startQuickDuration2h() { startQuickDuration(2, .hours) }

    private func startQuickDuration(_ value: Int, _ unit: DurationUnit) {
        setDuration(value, unit)
        let (configuration, summary) = currentConfiguration()
        controller.restart(with: configuration, summary: summary)
    }

    @objc private func forceStopCaffeinate() {
        if controller.isActive {
            controller.stop()
        }
        CaffeinateController.terminateTrackedProcess()
    }

    private func setDuration(_ value: Int, _ unit: DurationUnit) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: BaristaDefaults.durationValueKey)
        defaults.set(unit.rawValue, forKey: BaristaDefaults.durationUnitKey)
        defaults.set(SessionMode.timeout.rawValue, forKey: BaristaDefaults.sessionModeKey)
    }

    @objc private func showAbout() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.aboutWindow == nil {
                self.aboutWindow = self.buildAboutWindow()
            }
            guard let aboutWindow = self.aboutWindow else { return }
            NSApplication.shared.activate(ignoringOtherApps: true)
            aboutWindow.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        controller.stop()
        NSApplication.shared.terminate(nil)
    }

    private func updateStatusItemDisplay() {
        guard let button = statusItem?.button else { return }
        let presentation = StatusItemPresentation(
            isActive: controller.isActive,
            remainingTimeText: controller.remainingTimeText
        )
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .regular
        )

        button.image = StatusIcon.image(active: controller.isActive)
        button.attributedTitle = NSAttributedString(
            string: presentation.title,
            attributes: [.font: font]
        )
        button.setAccessibilityValue(presentation.accessibilityValue)
        button.toolTip = "Barista — \(presentation.accessibilityValue)"
    }

    private func buildAboutWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
        window.title = "About Barista"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        return window
    }

    private func currentConfiguration() -> (configuration: CaffeinateConfiguration, summary: String) {
        let defaults = UserDefaults.standard
        let sessionModeRaw = defaults.string(forKey: BaristaDefaults.sessionModeKey) ?? SessionMode.manual.rawValue
        let sessionMode = SessionMode(rawValue: sessionModeRaw) ?? .manual
        let durationUnitRaw = defaults.string(forKey: BaristaDefaults.durationUnitKey) ?? DurationUnit.minutes.rawValue
        let durationUnit = DurationUnit(rawValue: durationUnitRaw) ?? .minutes
        let configuration = CaffeinateConfiguration(
            preventDisplaySleep: defaults.bool(forKey: BaristaDefaults.preventDisplaySleepKey),
            preventIdleSleep: defaults.bool(forKey: BaristaDefaults.preventIdleSleepKey),
            preventDiskSleep: defaults.bool(forKey: BaristaDefaults.preventDiskSleepKey),
            preventSystemSleep: defaults.bool(forKey: BaristaDefaults.preventSystemSleepKey),
            declareUserActive: defaults.bool(forKey: BaristaDefaults.declareUserActiveKey),
            sessionMode: sessionMode,
            durationValue: defaults.integer(forKey: BaristaDefaults.durationValueKey),
            durationUnit: durationUnit,
            waitPidText: defaults.string(forKey: BaristaDefaults.waitPidKey) ?? "",
            commandLine: defaults.string(forKey: BaristaDefaults.commandLineKey) ?? ""
        )
        var summary = configuration.configurationSummary
        let waitPidName = defaults.string(forKey: BaristaDefaults.waitPidNameKey) ?? ""
        if configuration.sessionMode == .waitPid, !waitPidName.isEmpty {
            summary += " | \(waitPidName)"
        }
        return (configuration, summary)
    }
}
