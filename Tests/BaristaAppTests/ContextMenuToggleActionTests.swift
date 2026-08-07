import Foundation
import XCTest
@testable import BaristaApp

final class ContextMenuToggleActionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ContextMenuToggleActionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testActiveSessionStopsWithoutChangingConfiguration() {
        defaults.set(SessionMode.timeout.rawValue, forKey: BaristaDefaults.sessionModeKey)
        var didStop = false
        var didStart = false

        ContextMenuToggleAction.perform(
            isActive: true,
            defaults: defaults,
            stop: { didStop = true },
            startManual: { didStart = true }
        )

        XCTAssertTrue(didStop)
        XCTAssertFalse(didStart)
        XCTAssertEqual(
            defaults.string(forKey: BaristaDefaults.sessionModeKey),
            SessionMode.timeout.rawValue
        )
    }

    func testInactiveSessionSwitchesToManualBeforeStarting() {
        defaults.set(SessionMode.timeout.rawValue, forKey: BaristaDefaults.sessionModeKey)
        var didStop = false
        var observedModeAtStart: String?

        ContextMenuToggleAction.perform(
            isActive: false,
            defaults: defaults,
            stop: { didStop = true },
            startManual: {
                observedModeAtStart = self.defaults.string(
                    forKey: BaristaDefaults.sessionModeKey
                )
            }
        )

        XCTAssertFalse(didStop)
        XCTAssertEqual(observedModeAtStart, SessionMode.manual.rawValue)
    }
}
