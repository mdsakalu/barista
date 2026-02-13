import AppKit
import Combine
import SwiftUI

@main
struct BaristaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = CaffeinateController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var aboutWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

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
        let panelView = BaristaPanelView(controller: controller)
        let hostingController = NSHostingController(rootView: panelView)
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = StatusIcon.image(active: controller.isActive)
        button.image?.isTemplate = true
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
        let anchorRect = popoverAnchorRect(for: button)
        popover.show(relativeTo: anchorRect, of: button, preferredEdge: .minY)
        clampPopoverToScreen()
    }

    private func clampPopoverToScreen() {
        guard let popoverWindow = popover.contentViewController?.view.window,
              let screen = popoverWindow.screen ?? NSScreen.main
        else { return }

        let visibleFrame = screen.visibleFrame
        var frame = popoverWindow.frame

        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width
        }
        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
        }
        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
        }

        if frame != popoverWindow.frame {
            popoverWindow.setFrame(frame, display: false)
        }
    }

    private func popoverAnchorRect(for button: NSStatusBarButton) -> NSRect {
        if let cell = button.cell as? NSButtonCell {
            let imageRect = cell.imageRect(forBounds: button.bounds)
            if !imageRect.isEmpty {
                return imageRect
            }
        }
        return button.bounds
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
        setSessionModeManual()
        let (configuration, summary) = currentConfiguration()
        controller.toggle(with: configuration, summary: summary)
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

    private func setSessionModeManual() {
        UserDefaults.standard.set(SessionMode.manual.rawValue, forKey: BaristaDefaults.sessionModeKey)
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
        button.image = StatusIcon.image(active: controller.isActive)
        if let labelText = menuLabelText() {
            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.attributedTitle = NSAttributedString(string: labelText, attributes: [.font: font])
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
        }
    }

    private func menuLabelText() -> String? {
        guard controller.isActive else { return nil }
        if let remaining = controller.remainingTimeText {
            return remaining
        }
        return "On"
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

private enum BaristaDefaults {
    static let preventDisplaySleepKey = "barista.preventDisplaySleep"
    static let preventIdleSleepKey = "barista.preventIdleSleep"
    static let preventDiskSleepKey = "barista.preventDiskSleep"
    static let preventSystemSleepKey = "barista.preventSystemSleep"
    static let declareUserActiveKey = "barista.declareUserActive"
    static let sessionModeKey = "barista.sessionMode"
    static let durationValueKey = "barista.durationValue"
    static let durationUnitKey = "barista.durationUnit"
    static let waitPidKey = "barista.waitPid"
    static let waitPidNameKey = "barista.waitPidName"
    static let commandLineKey = "barista.commandLine"

    static func register() {
        UserDefaults.standard.register(defaults: [
            preventDisplaySleepKey: false,
            preventIdleSleepKey: true,
            preventDiskSleepKey: false,
            preventSystemSleepKey: false,
            declareUserActiveKey: false,
            sessionModeKey: SessionMode.manual.rawValue,
            durationValueKey: 30,
            durationUnitKey: DurationUnit.minutes.rawValue,
            waitPidKey: "",
            waitPidNameKey: "",
            commandLineKey: ""
        ])
    }
}

struct BaristaPanelView: View {
    @ObservedObject private var controller: CaffeinateController
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var panelVisibility = PanelVisibilityMonitor()

    @AppStorage(BaristaDefaults.preventDisplaySleepKey) private var preventDisplaySleep: Bool = false
    @AppStorage(BaristaDefaults.preventIdleSleepKey) private var preventIdleSleep: Bool = true
    @AppStorage(BaristaDefaults.preventDiskSleepKey) private var preventDiskSleep: Bool = false
    @AppStorage(BaristaDefaults.preventSystemSleepKey) private var preventSystemSleep: Bool = false
    @AppStorage(BaristaDefaults.declareUserActiveKey) private var declareUserActive: Bool = false
    @AppStorage(BaristaDefaults.sessionModeKey) private var sessionModeRaw: String = SessionMode.manual.rawValue
    @AppStorage(BaristaDefaults.durationValueKey) private var durationValue: Int = 30
    @AppStorage(BaristaDefaults.durationUnitKey) private var durationUnitRaw: String = DurationUnit.minutes.rawValue
    @AppStorage(BaristaDefaults.waitPidKey) private var waitPidText: String = ""
    @AppStorage(BaristaDefaults.waitPidNameKey) private var waitPidName: String = ""
    @AppStorage(BaristaDefaults.commandLineKey) private var commandLine: String = ""

    @State private var processList: [RunningProcess]
    @State private var lastProcessRefresh: Date?
    @State private var selectedProcessId: Int = -1
    @State private var isSettingPidFromPicker: Bool = false
    @State private var sectionHeight: CGFloat = 0

    init(controller: CaffeinateController) {
        _controller = ObservedObject(initialValue: controller)
        let initialList = ProcessLister.fetch()
        _processList = State(initialValue: initialList)
        _lastProcessRefresh = State(initialValue: initialList.isEmpty ? nil : Date())
    }

    var body: some View {
        content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusSection
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        MoleculeActiveGlow(colors: MoleculeStyle.catppuccinLatte.glowColors,
                                           isActive: controller.isActive,
                                           isVisible: panelVisibility.isVisible)
                            .frame(width: 96, height: 96)
                        MoleculeIcon(style: .catppuccinLatte)
                            .frame(width: 72, height: 72)
                    }
                    .offset(y: -6)
                }
                .background(WindowAccessor { window in
                    panelVisibility.attach(to: window)
                })

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                assertionsSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                sessionSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onPreferenceChange(SectionHeightKey.self) { sectionHeight = $0 }

            Divider()

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }

                Spacer()

                Button(controller.isActive ? "Stop" : "Start") {
                    controller.toggle(with: configuration, summary: configurationSummaryWithDetails)
                }
                .disabled(!controller.isActive && configuration.validationMessage != nil)
            }
        }
        .padding(10)
        .frame(width: 640)
        .background(panelBackground)
        .onAppear {
            syncSelectedProcess()
        }
    }

    private var panelBackground: some View {
        ZStack {
            if let image = PanelBackground.image {
                GeometryReader { geo in
                    panelBackgroundImage(image, size: geo.size)
                }
            } else {
                LinearGradient(
                    colors: [isDarkMode ? Color.black.opacity(0.06) : Color.white.opacity(0.08), Color.clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
    }


    @ViewBuilder
    private func panelBackgroundImage(_ image: NSImage, size: CGSize) -> some View {
        let base = Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .opacity(0.3)

        if !isDarkMode {
            base
                .colorInvert()
                .overlay(
                    LinearGradient(colors: [Color.white.opacity(0.2), Color.clear],
                                   startPoint: .topTrailing,
                                   endPoint: .bottomLeading)
                )
        } else {
            base
                .overlay(
                    LinearGradient(colors: [Color.black.opacity(0.25), Color.clear],
                                   startPoint: .topTrailing,
                                   endPoint: .bottomLeading)
                )
        }
    }

    private var isDarkMode: Bool { colorScheme == .dark }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(controller.statusText)
                .font(.headline)
                .foregroundStyle(controller.statusText.hasPrefix("Error") ? .red : .primary)

            Text(controller.isActive ? controller.activeSummary : configurationSummaryWithDetails)
                .font(.caption)
                .foregroundStyle(.secondary)

            timeLeftLine
        }
    }

    private var timeLeftLine: some View {
        let remaining = controller.remainingTimeText ?? "0:00"
        return Text("Time left: \(remaining)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(minHeight: 12, alignment: .leading)
            .opacity((controller.isActive && controller.remainingTimeText != nil) ? 1 : 0)
    }

    private var assertionsSection: some View {
        GroupBox("Assertions") {
            VStack(alignment: .leading, spacing: 8) {
                assertionToggle(
                    title: "Keep display awake",
                    detail: "Prevents screensaver and display sleep. Best for presentations.",
                    isOn: $preventDisplaySleep
                )
                assertionToggle(
                    title: "Keep system awake",
                    detail: "Stops idle system sleep while still allowing screen sleep/saver.",
                    isOn: $preventIdleSleep
                )
                assertionToggle(
                    title: "Keep disks awake",
                    detail: "Prevents disk idle sleep for long transfers or servers.",
                    isOn: $preventDiskSleep
                )
                assertionToggle(
                    title: "Keep Mac awake on AC",
                    detail: "Prevents system sleep on AC power; screen can still sleep.",
                    isOn: $preventSystemSleep
                )
                assertionToggle(
                    title: "Pulse user activity",
                    detail: "Simulates user activity; defaults to 5 seconds unless Duration is set.",
                    isOn: $declareUserActive
                )

                noteLine("Note: system sleep prevention only applies on AC power.",
                         isVisible: configuration.shouldShowSystemSleepNote)
                noteLine("Note: user active defaults to 5 seconds unless Duration mode is used.",
                         isVisible: configuration.shouldShowUserActiveNote)
            }
            .background(SectionHeightReader())
            .frame(minHeight: sectionHeight, alignment: .topLeading)
            .allowsHitTesting(!controller.isActive)
            .opacity(controller.isActive ? 0.48 : 1)
        }
    }

    private var sessionSection: some View {
        GroupBox("Session") {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SessionMode.allCases) { mode in
                        RadioRow(
                            title: mode.title,
                            isSelected: sessionMode == mode,
                            outlineOpacity: outlineOpacity
                        ) {
                            sessionModeRaw = mode.rawValue
                        }
                    }
                }

                sessionModeOptions
                    .frame(height: SessionModePanel.height, alignment: .topLeading)
            }
            .background(SectionHeightReader())
            .frame(minHeight: sectionHeight, alignment: .topLeading)
            .allowsHitTesting(!controller.isActive)
            .opacity(controller.isActive ? 0.48 : 1)
        }
    }

    private func noteLine(_ text: String, isVisible: Bool) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(minHeight: 12, alignment: .leading)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(!isVisible)
    }

    @ViewBuilder
    private var sessionModeOptions: some View {
        switch sessionMode {
        case .manual:
            Text("Runs until you stop it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .timeout:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Duration", value: $durationValue, format: .number)
                        .textFieldStyle(TranslucentTextFieldStyle())
                        .frame(width: 80)
                    Picker("Unit", selection: $durationUnitRaw) {
                        ForEach(DurationUnit.allCases) { unit in
                            Text(unit.title).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("5m") { setDuration(5, .minutes) }
                    Button("15m") { setDuration(15, .minutes) }
                    Button("30m") { setDuration(30, .minutes) }
                    Button("1h") { setDuration(1, .hours) }
                    Button("2h") { setDuration(2, .hours) }
                }

                Text("Menu bar shows a live countdown while running.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                let message = (!controller.isActive ? configuration.validationMessage : nil)
                Text(message ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .frame(minHeight: 12, alignment: .leading)
                    .opacity(message == nil ? 0 : 1)
            }
        case .waitPid:
            VStack(alignment: .leading, spacing: 8) {
                Picker("Running process", selection: $selectedProcessId) {
                    Text("Select a process").tag(-1)
                    ForEach(processList) { process in
                        Text(process.displayLabel).tag(process.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProcessId) { newValue in
                    guard newValue != -1,
                          let process = processList.first(where: { $0.id == newValue })
                    else { return }
                    isSettingPidFromPicker = true
                    waitPidText = "\(process.id)"
                    waitPidName = process.name
                }

                HStack(spacing: 8) {
                    Button("Refresh list") { refreshProcessList() }
                    if let refreshText = processRefreshText {
                        Text(refreshText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    TextField("PID", text: $waitPidText)
                        .textFieldStyle(TranslucentTextFieldStyle())
                        .frame(width: 140)
                        .onChange(of: waitPidText) { _ in
                            if isSettingPidFromPicker {
                                isSettingPidFromPicker = false
                                return
                            }
                            waitPidName = ""
                            if selectedProcessId != -1 {
                                selectedProcessId = -1
                            }
                        }

                    let pidMessage = (!controller.isActive && configuration.validationMessage != nil) ? configuration.validationMessage : nil
                    Text(pidMessage ?? " ")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .frame(minWidth: 120, alignment: .leading)
                        .opacity(pidMessage == nil ? 0 : 1)
                }

                Text("Choose a running process or enter a PID manually.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .command:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Command", text: $commandLine)
                    .textFieldStyle(TranslucentTextFieldStyle())
                let message = (!controller.isActive ? configuration.validationMessage : nil)
                Text(message ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .frame(minHeight: 12, alignment: .leading)
                    .opacity(message == nil ? 0 : 1)
                Text("Example: /usr/bin/pmset -g assertions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Duration and PID options are ignored when running a command.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func assertionToggle(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(nil)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(OutlineCheckboxStyle(outlineOpacity: outlineOpacity))
    }

    private var configuration: CaffeinateConfiguration {
        CaffeinateConfiguration(
            preventDisplaySleep: preventDisplaySleep,
            preventIdleSleep: preventIdleSleep,
            preventDiskSleep: preventDiskSleep,
            preventSystemSleep: preventSystemSleep,
            declareUserActive: declareUserActive,
            sessionMode: sessionMode,
            durationValue: durationValue,
            durationUnit: durationUnit,
            waitPidText: waitPidText,
            commandLine: commandLine
        )
    }

    private var configurationSummaryWithDetails: String {
        var summary = configuration.configurationSummary
        if sessionMode == .waitPid, !waitPidName.isEmpty {
            summary += " | \(waitPidName)"
        }
        return summary
    }

    private var sessionMode: SessionMode {
        SessionMode(rawValue: sessionModeRaw) ?? .manual
    }

    private var durationUnit: DurationUnit {
        DurationUnit(rawValue: durationUnitRaw) ?? .minutes
    }

    private var sessionModeBinding: Binding<SessionMode> {
        Binding(
            get: { SessionMode(rawValue: sessionModeRaw) ?? .manual },
            set: { sessionModeRaw = $0.rawValue }
        )
    }

    private var processRefreshText: String? {
        guard let lastProcessRefresh else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Updated \(formatter.string(from: lastProcessRefresh))"
    }

    private var outlineOpacity: Double { 0.42 }


    private func setDuration(_ value: Int, _ unit: DurationUnit) {
        durationValue = value
        durationUnitRaw = unit.rawValue
        sessionModeRaw = SessionMode.timeout.rawValue
    }

    private func startQuickDuration(_ value: Int, _ unit: DurationUnit) {
        setDuration(value, unit)
        controller.restart(with: configuration, summary: configurationSummaryWithDetails)
    }

    private func refreshProcessList() {
        processList = ProcessLister.fetch()
        lastProcessRefresh = processList.isEmpty ? nil : Date()
        syncSelectedProcess()
    }

    private func syncSelectedProcess() {
        guard let pid = Int(waitPidText),
              processList.contains(where: { $0.id == pid }) else {
            selectedProcessId = -1
            return
        }
        selectedProcessId = pid
    }
}

private struct OutlineCheckboxStyle: ToggleStyle {
    let outlineOpacity: Double

    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.primary.opacity(outlineOpacity), lineWidth: 1)
                        .frame(width: 14, height: 14)
                    if configuration.isOn {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.primary.opacity(0.9))
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(NSColor.windowBackgroundColor))
                    }
                }
                configuration.label
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TranslucentTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) private var colorScheme

    func _body(configuration: TextField<_Label>) -> some View {
        let strokeOpacity: Double = colorScheme == .dark ? 0.25 : 0.2
        configuration
            .textFieldStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

private struct AboutView: View {
    private let appName: String
    private let versionValue: String
    private let buildValue: String?
    private let repoURL = URL(string: "https://github.com/mdsakalu/barista")!
    private let repoLabel = "mdsakalu/barista"
    @State private var isHoveringLink = false

    init() {
        let bundle = Bundle.main
        appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Barista"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        versionValue = version ?? "dev"
        buildValue = build
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: StatusIcon.image(active: true))
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(.primary)
            Text(appName)
                .font(.title2)
                .fontWeight(.semibold)
            VStack(spacing: 4) {
                aboutInfoRow(label: "Version", value: versionValue)
                if let buildValue {
                    aboutInfoRow(label: "Build", value: buildValue)
                }
            }
            Button {
                NSWorkspace.shared.open(repoURL)
            } label: {
                HStack(spacing: 6) {
                    if let mark = GitHubMark.image {
                        Image(nsImage: mark)
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .padding(3)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                    }
                    Text(repoLabel)
                        .underline(isHoveringLink, color: Color.primary.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringLink = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private func aboutInfoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 54, alignment: .trailing)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private enum GitHubMark {
    static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "GitHub-Mark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()
}

private struct RadioRow: View {
    let title: String
    let isSelected: Bool
    let outlineOpacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(outlineOpacity), lineWidth: 1)
                        .frame(width: 12, height: 12)
                    if isSelected {
                        Circle()
                            .fill(Color.primary.opacity(0.9))
                            .frame(width: 6, height: 6)
                    }
                }
                Text(title)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private enum SessionModePanel {
    static let height: CGFloat = 140
}

private struct SectionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SectionHeightReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: SectionHeightKey.self, value: proxy.size.height)
        }
    }
}

private final class PanelVisibilityMonitor: ObservableObject {
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

private struct WindowAccessor: NSViewRepresentable {
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

private enum MoleculeStyle: String, CaseIterable, Identifiable {
    case catppuccinLatte

    var id: String { rawValue }

    var palette: MoleculePalette {
        switch self {
        case .catppuccinLatte:
            return MoleculePalette(
                carbon: Color(hex: 0x8839EF),
                nitrogen: Color(hex: 0x1E66F5),
                oxygen: Color(hex: 0xD20F39),
                hydrogen: Color(hex: 0x179299)
            )
        }
    }

    var glowColors: [Color] {
        // Catppuccin Latte accents: mauve, blue, sapphire, peach.
        [
            Color(hex: 0x8839EF),
            Color(hex: 0x1E66F5),
            Color(hex: 0x209FB5),
            Color(hex: 0xFE640B)
        ]
    }

    var lineStyle: AnyShapeStyle {
        let colors = [palette.carbon, palette.nitrogen, palette.oxygen, palette.hydrogen]
            .map { $0.opacity(0.9) }
        return AnyShapeStyle(LinearGradient(colors: colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
    }

    var lineWidth: CGFloat { 1.6 }

    var nodeSize: CGFloat { 6 }

    func atomFill(for kind: AtomKind) -> AnyShapeStyle {
        let color: Color
        switch kind {
        case .oxygen:
            color = palette.oxygen
        case .nitrogen:
            color = palette.nitrogen
        case .methyl:
            color = palette.hydrogen
        case .carbon:
            color = palette.carbon
        }

        let top = color.opacity(1.0)
        let bottom = color.opacity(0.8)
        return AnyShapeStyle(
            LinearGradient(colors: [top, bottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
    }
}

private struct MoleculeIcon: View {
    let style: MoleculeStyle

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let atoms: [Atom] = [
                Atom(point: CGPoint(x: w * 0.30, y: h * 0.26), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.48, y: h * 0.22), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.62, y: h * 0.32), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.62, y: h * 0.56), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.44, y: h * 0.68), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.26, y: h * 0.58), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.74, y: h * 0.26), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.82, y: h * 0.46), kind: .carbon),
                Atom(point: CGPoint(x: w * 0.72, y: h * 0.64), kind: .nitrogen),
                Atom(point: CGPoint(x: w * 0.12, y: h * 0.14), kind: .methyl),
                Atom(point: CGPoint(x: w * 0.10, y: h * 0.74), kind: .methyl),
                Atom(point: CGPoint(x: w * 0.90, y: h * 0.18), kind: .methyl),
                Atom(point: CGPoint(x: w * 0.48, y: h * 0.06), kind: .oxygen),
                Atom(point: CGPoint(x: w * 0.40, y: h * 0.88), kind: .oxygen)
            ]

            let bonds: [Bond] = [
                Bond(a: 0, b: 1, kind: .single),
                Bond(a: 1, b: 2, kind: .single),
                Bond(a: 2, b: 3, kind: .single),
                Bond(a: 3, b: 4, kind: .single),
                Bond(a: 4, b: 5, kind: .single),
                Bond(a: 5, b: 0, kind: .single),

                Bond(a: 2, b: 6, kind: .single),
                Bond(a: 6, b: 7, kind: .single),
                Bond(a: 7, b: 8, kind: .single),
                Bond(a: 8, b: 3, kind: .single),
                Bond(a: 3, b: 2, kind: .single),

                Bond(a: 0, b: 9, kind: .single),
                Bond(a: 5, b: 10, kind: .single),
                Bond(a: 6, b: 11, kind: .single),

                Bond(a: 1, b: 12, kind: .double),
                Bond(a: 4, b: 13, kind: .double)
            ]

            ZStack {
                let bondPath = Path { path in
                    for bond in bonds {
                        addBond(to: &path,
                                from: atoms[bond.a].point,
                                to: atoms[bond.b].point,
                                kind: bond.kind,
                                offset: style.lineWidth * 0.6)
                    }
                }

                bondPath
                    .stroke(style.lineStyle,
                            style: StrokeStyle(lineWidth: style.lineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))

                ForEach(0..<atoms.count, id: \.self) { index in
                    let atom = atoms[index]
                    Circle()
                        .fill(style.atomFill(for: atom.kind))
                        .frame(width: nodeSize(for: atom.kind), height: nodeSize(for: atom.kind))
                        .position(atom.point)
                        .shadow(color: Color.black.opacity(0.12), radius: 0.8, x: 0, y: 0)
                }
            }
        }
    }

    private func nodeSize(for kind: AtomKind) -> CGFloat {
        switch kind {
        case .methyl:
            return style.nodeSize * 0.8
        case .oxygen:
            return style.nodeSize * 1.0
        default:
            return style.nodeSize
        }
    }

    private func addBond(to path: inout Path, from start: CGPoint, to end: CGPoint, kind: BondKind, offset: CGFloat) {
        switch kind {
        case .single:
            path.move(to: start)
            path.addLine(to: end)
        case .double:
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = max(1, sqrt(dx * dx + dy * dy))
            let ox = -dy / length * offset
            let oy = dx / length * offset
            let a1 = CGPoint(x: start.x + ox, y: start.y + oy)
            let b1 = CGPoint(x: end.x + ox, y: end.y + oy)
            let a2 = CGPoint(x: start.x - ox, y: start.y - oy)
            let b2 = CGPoint(x: end.x - ox, y: end.y - oy)
            path.move(to: a1)
            path.addLine(to: b1)
            path.move(to: a2)
            path.addLine(to: b2)
        }
    }
}

private enum AtomKind {
    case carbon
    case nitrogen
    case oxygen
    case methyl
}

private struct Atom {
    let point: CGPoint
    let kind: AtomKind
}

private enum BondKind {
    case single
    case double
}

private struct Bond {
    let a: Int
    let b: Int
    let kind: BondKind
}

private struct MoleculeActiveGlow: View {
    let colors: [Color]
    let isActive: Bool
    let isVisible: Bool

    private let transitionDuration: TimeInterval = 3
    private let tickInterval: TimeInterval = 0.12

    var body: some View {
        Group {
            if isActive && isVisible {
                TimelineView(.periodic(from: .now, by: tickInterval)) { context in
                    let color = interpolatedColor(at: context.date)
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height)
                        let glowRadius = size * 0.55
                        let innerRadius = size * 0.18
                        let outerRadius = size * 0.32

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(colors: [
                                        color.opacity(0.9),
                                        color.opacity(0.45),
                                        color.opacity(0)
                                    ], center: .center, startRadius: 0, endRadius: glowRadius)
                                )
                                .frame(width: size, height: size)
                                .blur(radius: outerRadius)

                            Circle()
                                .fill(color.opacity(0.55))
                                .frame(width: size * 0.5, height: size * 0.5)
                                .blur(radius: innerRadius)
                        }
                        .frame(width: size, height: size)
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    private func interpolatedColor(at date: Date) -> Color {
        guard colors.count > 1 else { return colors.first ?? .clear }
        let total = transitionDuration * Double(colors.count)
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        let index = Int(t / transitionDuration)
        let progress = (t / transitionDuration) - Double(index)
        let c1 = colors[index % colors.count]
        let c2 = colors[(index + 1) % colors.count]
        return Color.lerp(from: c1, to: c2, t: progress)
    }
}

private struct MoleculePalette {
    let carbon: Color
    let nitrogen: Color
    let oxygen: Color
    let hydrogen: Color
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func lerp(from: Color, to: Color, t: Double) -> Color {
        let a = from.rgba
        let b = to.rgba
        let r = a.r + (b.r - a.r) * t
        let g = a.g + (b.g - a.g) * t
        let bval = a.b + (b.b - a.b) * t
        let o = a.a + (b.a - a.a) * t
        return Color(.sRGB, red: r, green: g, blue: bval, opacity: o)
    }

    private var rgba: (r: Double, g: Double, b: Double, a: Double) {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

private enum StatusIcon {
    private static let activeSymbolName = "cup.and.saucer.steam.fill"
    private static let inactiveSymbolName = "cup.and.saucer.steam"

    static func image(active: Bool) -> NSImage {
        if active {
            return loadSymbol(named: activeSymbolName)
                ?? loadSymbol(named: "cup.and.saucer.fill")
                ?? fallbackSymbol(named: "cup.and.saucer.fill")
        }
        return loadSymbol(named: inactiveSymbolName)
            ?? loadSymbol(named: "cup.and.saucer")
            ?? fallbackSymbol(named: "cup.and.saucer")
    }

    private static func loadSymbol(named name: String) -> NSImage? {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        if let image = NSImage(named: NSImage.Name(name)) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        return nil
    }

    private static func fallbackSymbol(named name: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let configured = symbol.withSymbolConfiguration(config) ?? symbol
            let symbolSize = configured.size
            let origin = NSPoint(x: (size.width - symbolSize.width) / 2,
                                 y: (size.height - symbolSize.height) / 2 - 1)
            configured.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

private enum PanelBackground {
    static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "CaffeineCrystals_Fibrous_10xDarkField",
                                          withExtension: "jpg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()
}
