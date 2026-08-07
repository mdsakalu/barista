import XCTest
@testable import BaristaApp

final class CaffeinateConfigurationTests: XCTestCase {
    func testDurationBuildsExpectedCaffeinateArguments() {
        let configuration = CaffeinateConfiguration(
            preventDisplaySleep: true,
            preventIdleSleep: true,
            preventDiskSleep: false,
            preventSystemSleep: false,
            declareUserActive: false,
            sessionMode: .timeout,
            durationValue: 90,
            durationUnit: .minutes,
            waitPidText: "",
            commandLine: ""
        )

        XCTAssertEqual(configuration.buildArguments(), ["-d", "-i", "-t", "5400"])
    }

    func testOversizedDurationSaturatesInsteadOfOverflowing() {
        let configuration = CaffeinateConfiguration(
            preventDisplaySleep: false,
            preventIdleSleep: true,
            preventDiskSleep: false,
            preventSystemSleep: false,
            declareUserActive: false,
            sessionMode: .timeout,
            durationValue: Int.max,
            durationUnit: .hours,
            waitPidText: "",
            commandLine: ""
        )

        XCTAssertEqual(configuration.durationSeconds, Int.max)
    }

    func testCommandPreservesEmptyArguments() {
        let configuration = CaffeinateConfiguration(
            preventDisplaySleep: false,
            preventIdleSleep: true,
            preventDiskSleep: false,
            preventSystemSleep: false,
            declareUserActive: false,
            sessionMode: .command,
            durationValue: 30,
            durationUnit: .minutes,
            waitPidText: "",
            commandLine: #"/usr/bin/printf "%s" """#
        )

        XCTAssertEqual(
            configuration.buildArguments(),
            ["-i", "/usr/bin/printf", "%s", ""]
        )
    }
}
