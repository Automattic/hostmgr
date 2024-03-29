import Foundation
import OSLog

/// Resolves local virtual machines by name or handle
///
/// VMs can be bundles or templates, and they might be in the working directory if they're  a running VM, or they
/// could be in the `vm-images` directory if they're a template. Within the `vm-images` directory, they could
/// be a `.vmtemplate` or `.bundle` file, depending on whether they've been converted to a template or not.
///
/// This object papers over those distinctions and makes it possible to just say "get a VM called `foo`" and
/// have it work.
struct VMResolver {

    enum Result {
        case bundle(VMBundle)
        case template(VMTemplate)
    }

    static func resolve(_ identifier: String, fileManager: FileManagerProto = FileManager.default) throws -> Result {
        Logger.helper.debug("Resolving VM: \(identifier)")

        let path = try resolvePath(for: identifier, fileManager: fileManager)

        if path.path().hasSuffix(".vmtemplate.aar") {
            let template = VMTemplate(at: path)
            Logger.helper.debug("Resolved template at: \(template.root)")
            return .template(template)
        }

        if path.path().hasSuffix(".vmtemplate") {
            let template = VMTemplate(at: path)
            Logger.helper.debug("Resolved template at: \(template.root)")
            return .template(template)
        }

        if path.pathExtension == "bundle" {
            let bundle = try VMBundle(at: path)
            Logger.helper.debug("Resolved bundle at: \(bundle.root)")
            return .bundle(bundle)
        }

        throw HostmgrError.invalidVMStatus(path)
    }

    static func resolveBundle(
        named identifier: String,
        fileManager: FileManagerProto = FileManager.default
    ) throws -> any Bundle {
        switch try resolve(identifier, fileManager: fileManager) {
        case .bundle(let bundle): return bundle
        case .template(let template): return template
        }
    }

    static func resolvePath(
        for identifier: String,
        fileManager: FileManagerProto = FileManager.default
    ) throws -> URL {
        let workingVMPath = Paths.toWorkingAppleSiliconVM(named: identifier)

        if try fileManager.directoryExists(at: workingVMPath) {
            return workingVMPath
        }

        let vmBundlePath = Paths.toAppleSiliconVM(named: identifier)

        if try fileManager.directoryExists(at: vmBundlePath) {
            return vmBundlePath
        }

        let vmTemplatePath = Paths.toVMTemplate(named: identifier)

        if try fileManager.directoryExists(at: vmTemplatePath) {
            return vmTemplatePath
        }

        let vmArchivePath = Paths.toArchivedVM(named: identifier)

        if fileManager.fileExists(at: vmArchivePath) {
            return vmArchivePath
        }

        throw HostmgrError.localVMNotFound(identifier)
    }
}
