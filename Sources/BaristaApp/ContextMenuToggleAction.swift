import Foundation

enum ContextMenuToggleAction {
    static func perform(
        isActive: Bool,
        defaults: UserDefaults,
        stop: () -> Void,
        startManual: () -> Void
    ) {
        if isActive {
            stop()
            return
        }

        defaults.set(SessionMode.manual.rawValue, forKey: BaristaDefaults.sessionModeKey)
        startManual()
    }
}
