import AppKit
import SwiftUI

struct BaristaPanelView: View {
    @ObservedObject private var controller: CaffeinateController
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var panelVisibility = PanelVisibilityMonitor()
    private let layout: PopoverLayout

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

    init(controller: CaffeinateController, layout: PopoverLayout) {
        _controller = ObservedObject(initialValue: controller)
        self.layout = layout
        let initialList = ProcessLister.fetch()
        _processList = State(initialValue: initialList)
        _lastProcessRefresh = State(initialValue: initialList.isEmpty ? nil : Date())
    }

    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: layout.contentWidth)
        .frame(maxHeight: layout.maximumContentHeight)
        .background(panelBackground)
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

            configurationSections

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
        .onAppear {
            syncSelectedProcess()
        }
    }

    @ViewBuilder
    private var configurationSections: some View {
        if layout.stacksSections {
            VStack(alignment: .leading, spacing: 16) {
                assertionsSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                sessionSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onPreferenceChange(SectionHeightKey.self) { sectionHeight = $0 }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                assertionsSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                sessionSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onPreferenceChange(SectionHeightKey.self) { sectionHeight = $0 }
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
            .frame(minHeight: layout.stacksSections ? nil : sectionHeight, alignment: .topLeading)
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
            .frame(minHeight: layout.stacksSections ? nil : sectionHeight, alignment: .topLeading)
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
