import Foundation

enum BaristaDefaults {
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
