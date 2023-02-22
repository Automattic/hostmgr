import Foundation
import Virtualization

@available(macOS 13.0, *)
public struct VMLauncher {

    public static func prepareVirtualMachine(named name: String) throws -> VZVirtualMachine {
        let configuration = try prepareBundle(named: name).virtualMachineConfiguration()
        try configuration.validate()

        return VZVirtualMachine(configuration: configuration)
    }

    public static func prepareBundle(named name: String) throws -> VMBundle {
        debugPrint("Preparing Bundle named \(name)")

        guard let localVM = try findLocalVM(named: name) else {
            throw CocoaError(.fileNoSuchFile)
        }

        debugPrint("Found: \(localVM)")

        /// We never run packaged VMs directly – instead, we make a copy, turning it back into a regular bundle
        if localVM.state == .packaged {
            debugPrint(localVM.path)
            return try VMTemplate(at: localVM.path).createEphemeralCopy()
        }

        /// If this isn't a VM template, just launch it directly
        return try VMBundle.fromExistingBundle(at: localVM.path)
    }

    /// Try to resolve VMs – it's possible there's more than one present with the same name.
    ///
    ///  Prioritizes VM Templates, then VMs  – ignores archives because they're not launchable
    public static func findLocalVM(named name: String) throws -> LocalVMImage? {
        if let template = try LocalVMRepository().lookupTemplate(withName: name) {
            return template
        }

        if let bundle = try LocalVMRepository().lookupBundle(withName: name) {
            return bundle
        }

        return nil
    }
}
