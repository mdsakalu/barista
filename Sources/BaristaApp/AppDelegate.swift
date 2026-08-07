import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = CaffeinateController()
    private var statusItem: NSStatusItem?
    private var panelPresenter: StatusPanelPresenter?
    private var aboutWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BaristaDefaults.register()
        CaffeinateController.cleanupOrphanedProcess()
        NSApp.setActivationPolicy(.accessory)
        setupPanel()
        setupStatusItem()
        observeController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeEventMonitors()
        panelPresenter?.close()
        controller.stop()
    }

    private func setupPanel() {
        let layout = PanelLayoutPolicy.layout
        let panelView = BaristaPanelView(controller: controller, layout: layout)
        let hostingController = NSHostingController(rootView: panelView)
        hostingController.preferredContentSize = layout.contentSize
        panelPresenter = StatusPanelPresenter(
            contentViewController: hostingController,
            contentSize: layout.contentSize
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: StatusItemPresentation.length)
        guard let button = statusItem?.button else { return }
        button.imagePosition = StatusItemPresentation.imagePosition
        button.setAccessibilityLabel("Barista")
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: StatusItemPresentation.actionMask)

        updateStatusItemDisplay()
        installLocalEventMonitor()
    }

    private func observeController() {
        controller.$isActive
            .combineLatest(controller.$remainingTimeText)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.closePanel()
            }
            .store(in: &cancellables)
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.type == .rightMouseDown {
            closePanel()
            showContextMenu(event: event, button: sender)
        } else {
            togglePanel(button: sender)
        }
    }

    private func togglePanel(button: NSStatusBarButton) {
        guard let panelPresenter else { return }
        let isShown = panelPresenter.toggle(
            relativeTo: button,
            anchorRect: StatusItemPresentation.anchorRect(in: button.bounds)
        )
        if isShown {
            installGlobalEventMonitor()
        } else {
            removeGlobalEventMonitor()
        }
    }

    private func closePanel() {
        removeGlobalEventMonitor()
        panelPresenter?.close()
    }

    private func installLocalEventMonitor() {
        guard localEventMonitor == nil else { return }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }

            if event.type == .keyDown, event.keyCode == 53, self.panelPresenter?.isShown == true {
                self.closePanel()
                return nil
            }

            if let button = self.statusItemButton(targetedBy: event) {
                if event.type == .rightMouseDown {
                    self.closePanel()
                    self.showContextMenu(event: event, button: button)
                    return nil
                }
                return event
            }

            if self.panelPresenter?.isShown == true,
               self.panelPresenter?.owns(event) == false {
                self.closePanel()
            }
            return event
        }
    }

    private func installGlobalEventMonitor() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePanel()
            }
        }
    }

    private func removeEventMonitors() {
        removeGlobalEventMonitor()
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    private func removeGlobalEventMonitor() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func event(_ event: NSEvent, targets button: NSStatusBarButton) -> Bool {
        guard event.window === button.window else { return false }
        let point = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(point)
    }

    private func statusItemButton(targetedBy event: NSEvent) -> NSStatusBarButton? {
        guard let button = statusItem?.button,
              self.event(event, targets: button) else { return nil }
        return button
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
        button.image?.isTemplate = true
        button.imagePosition = StatusItemPresentation.imagePosition
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
