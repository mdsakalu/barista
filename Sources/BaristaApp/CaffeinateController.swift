import Foundation
import SwiftUI

final class CaffeinateController: ObservableObject {
    @Published var isActive: Bool = false
    @Published var statusText: String = "Inactive"
    @Published var activeSummary: String = "Idle sleep (default) | Manual"
    @Published private(set) var remainingTimeText: String? = nil

    private var process: Process?
    private let caffeinatePath = "/usr/bin/caffeinate"
    private var countdownTimer: Timer?
    private var countdownEnd: Date?

    func toggle(with configuration: CaffeinateConfiguration, summary: String) {
        if isActive {
            stop()
        } else {
            start(with: configuration, summary: summary)
        }
    }

    func restart(with configuration: CaffeinateConfiguration, summary: String) {
        if isActive {
            stop()
            startAfterStop(configuration: configuration, summary: summary, attempts: 0)
        } else {
            start(with: configuration, summary: summary)
        }
    }

    func start(with configuration: CaffeinateConfiguration, summary: String) {
        guard process == nil else { return }
        guard let arguments = configuration.buildArguments() else {
            statusText = configuration.validationMessage ?? "Invalid configuration"
            return
        }

        configureCountdown(using: configuration)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: caffeinatePath)
        process.arguments = arguments
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.process = nil
                self?.isActive = false
                self?.statusText = "Inactive"
                self?.clearCountdown()
            }
        }

        do {
            try process.run()
            self.process = process
            isActive = true
            activeSummary = summary
            statusText = "Active"
        } catch {
            statusText = "Error: \(error.localizedDescription)"
            clearCountdown()
        }
    }

    func stop() {
        guard let process else { return }
        statusText = "Stopping..."
        process.terminate()
        clearCountdown()
    }

    deinit {
        process?.terminate()
        countdownTimer?.invalidate()
    }

    private func configureCountdown(using configuration: CaffeinateConfiguration) {
        guard configuration.sessionMode == .timeout else {
            clearCountdown()
            return
        }

        let seconds = configuration.durationSeconds
        guard seconds > 0 else {
            clearCountdown()
            return
        }

        countdownEnd = Date().addingTimeInterval(TimeInterval(seconds))
        updateRemainingTime()

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func updateRemainingTime() {
        guard let end = countdownEnd else {
            remainingTimeText = nil
            return
        }
        let remaining = max(0, end.timeIntervalSinceNow)
        remainingTimeText = formatRemaining(remaining)
        if remaining <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private func formatRemaining(_ remaining: TimeInterval) -> String {
        let totalSeconds = Int(remaining.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startAfterStop(configuration: CaffeinateConfiguration, summary: String, attempts: Int) {
        guard process != nil else {
            start(with: configuration, summary: summary)
            return
        }
        if attempts >= 20 {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startAfterStop(configuration: configuration, summary: summary, attempts: attempts + 1)
        }
    }

    private func clearCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownEnd = nil
        remainingTimeText = nil
    }
}
