import AppKit
import SwiftUI

@main
struct BaristaApp: App {
    @StateObject private var controller = CaffeinateController()
    @State private var isDarkMode: Bool = false
    @StateObject private var panelVisibility = PanelVisibilityMonitor()

    @AppStorage("barista.preventDisplaySleep") private var preventDisplaySleep: Bool = false
    @AppStorage("barista.preventIdleSleep") private var preventIdleSleep: Bool = true
    @AppStorage("barista.preventDiskSleep") private var preventDiskSleep: Bool = false
    @AppStorage("barista.preventSystemSleep") private var preventSystemSleep: Bool = false
    @AppStorage("barista.declareUserActive") private var declareUserActive: Bool = false
    @AppStorage("barista.sessionMode") private var sessionModeRaw: String = SessionMode.manual.rawValue
    @AppStorage("barista.durationValue") private var durationValue: Int = 30
    @AppStorage("barista.durationUnit") private var durationUnitRaw: String = DurationUnit.minutes.rawValue
    @AppStorage("barista.waitPid") private var waitPidText: String = ""
    @AppStorage("barista.waitPidName") private var waitPidName: String = ""
    @AppStorage("barista.commandLine") private var commandLine: String = ""

    @State private var processList: [RunningProcess]
    @State private var lastProcessRefresh: Date?
    @State private var selectedProcessId: Int = -1
    @State private var isSettingPidFromPicker: Bool = false
    @State private var sectionHeight: CGFloat = 0

    init() {
        let initialList = ProcessLister.fetch()
        _processList = State(initialValue: initialList)
        _lastProcessRefresh = State(initialValue: initialList.isEmpty ? nil : Date())
    }

    var body: some Scene {
        MenuBarExtra {
            content
        } label: {
            HStack(spacing: 6) {
                statusIcon
                if let labelText = menuLabelText {
                    Text(labelText)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuLabelText: String? {
        guard controller.isActive else { return nil }
        if let remaining = controller.remainingTimeText {
            return remaining
        }
        return "On"
    }

    private var statusIcon: some View {
        Image(nsImage: StatusIcon.image(active: controller.isActive))
            .renderingMode(.template)
            .frame(width: 18, height: 18)
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
            refreshAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSApplicationDidChangeEffectiveAppearanceNotification"))) { _ in
            refreshAppearance()
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

    private func refreshAppearance() {
        let appearance = NSApplication.shared.effectiveAppearance
        isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

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

                if configuration.shouldShowSystemSleepNote {
                    Text("Note: system sleep prevention only applies on AC power.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if configuration.shouldShowUserActiveNote {
                    Text("Note: user active defaults to 5 seconds unless Duration mode is used.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
                        .textFieldStyle(.roundedBorder)
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
                    .textFieldStyle(.roundedBorder)
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
