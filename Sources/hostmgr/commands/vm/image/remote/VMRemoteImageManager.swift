import Foundation
import Cocoa
import libhostmgr

import IOKit.pwr_mgt

class SystemSleepManager {

    private let reason: String
    private var assertionID: IOPMAssertionID = 0

    init(reason: String) {
        self.reason = reason
    }

    /// Re-enable sleep mode after disabling it
    ///
    /// Returns a boolean indicating success
    @discardableResult
    func enable() -> Bool {
        return IOPMAssertionRelease(assertionID) == kIOReturnSuccess
    }

    /// Disable Sleep until such time as `enable` is called
    ///
    /// Returns a boolean indicating success
    @discardableResult
    func disable() -> Bool {
        return IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        ) == kIOReturnSuccess
    }

    static func disableSleepFor(reason: String = "Running Operation", _ callback: () throws -> Void) rethrows {
        let manager = SystemSleepManager(reason: reason)
        manager.disable()
        try callback()
        manager.enable()
    }
}
