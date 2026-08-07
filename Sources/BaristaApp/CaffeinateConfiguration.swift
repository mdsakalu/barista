import Foundation

enum SessionMode: String, CaseIterable, Identifiable {
    case manual
    case timeout
    case waitPid
    case command

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "Manual"
        case .timeout:
            return "Duration"
        case .waitPid:
            return "Wait for PID"
        case .command:
            return "Command"
        }
    }
}

enum DurationUnit: String, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seconds:
            return "sec"
        case .minutes:
            return "min"
        case .hours:
            return "hr"
        }
    }

    var multiplier: Int {
        switch self {
        case .seconds:
            return 1
        case .minutes:
            return 60
        case .hours:
            return 3600
        }
    }
}

struct CaffeinateConfiguration: Equatable {
    var preventDisplaySleep: Bool
    var preventIdleSleep: Bool
    var preventDiskSleep: Bool
    var preventSystemSleep: Bool
    var declareUserActive: Bool

    var sessionMode: SessionMode
    var durationValue: Int
    var durationUnit: DurationUnit
    var waitPidText: String
    var commandLine: String

    var validationMessage: String? {
        switch sessionMode {
        case .timeout:
            if durationSeconds <= 0 {
                return "Enter a duration greater than zero."
            }
        case .waitPid:
            if waitPidValue == nil {
                return "Enter a valid PID."
            }
        case .command:
            let trimmed = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Enter a command to run."
            }
            if CommandLineParser.parse(commandLine) == nil {
                return "Command line has unmatched quotes."
            }
        case .manual:
            break
        }
        return nil
    }

    var configurationSummary: String {
        let assertions = assertionsSummary()
        let session = sessionSummary()
        if assertions.isEmpty {
            return "Idle sleep (default) | \(session)"
        }
        return "\(assertions) | \(session)"
    }

    var shouldShowUserActiveNote: Bool {
        declareUserActive && sessionMode != .timeout
    }

    var shouldShowSystemSleepNote: Bool {
        preventSystemSleep
    }

    var durationSeconds: Int {
        let value = max(0, durationValue)
        let result = value.multipliedReportingOverflow(by: durationUnit.multiplier)
        return result.overflow ? Int.max : result.partialValue
    }

    var waitPidValue: Int? {
        let trimmed = waitPidText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    func buildArguments() -> [String]? {
        if validationMessage != nil {
            return nil
        }

        var args = assertionArguments()

        switch sessionMode {
        case .timeout:
            args.append("-t")
            args.append("\(durationSeconds)")
        case .waitPid:
            if let pid = waitPidValue {
                args.append("-w")
                args.append("\(pid)")
            }
        case .command:
            if let commandArgs = CommandLineParser.parse(commandLine), !commandArgs.isEmpty {
                args.append(contentsOf: commandArgs)
            }
        case .manual:
            break
        }

        return args
    }

    private func assertionArguments() -> [String] {
        var flags: [String] = []
        if preventDisplaySleep { flags.append("-d") }
        if preventIdleSleep { flags.append("-i") }
        if preventDiskSleep { flags.append("-m") }
        if preventSystemSleep { flags.append("-s") }
        if declareUserActive { flags.append("-u") }
        return flags
    }

    private func assertionsSummary() -> String {
        var labels: [String] = []
        if preventDisplaySleep { labels.append("Display") }
        if preventIdleSleep { labels.append("Idle") }
        if preventDiskSleep { labels.append("Disk") }
        if preventSystemSleep { labels.append("System") }
        if declareUserActive { labels.append("User active") }
        return labels.joined(separator: ", ")
    }

    private func sessionSummary() -> String {
        switch sessionMode {
        case .manual:
            return "Manual"
        case .timeout:
            let value = max(0, durationValue)
            return "\(value) \(durationUnit.title)"
        case .waitPid:
            return "PID \(waitPidValue.map(String.init) ?? "?")"
        case .command:
            let args = CommandLineParser.parse(commandLine) ?? []
            if let first = args.first {
                return "Command \(first)"
            }
            return "Command"
        }
    }
}
