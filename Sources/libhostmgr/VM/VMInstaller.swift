import Virtualization

public class VMInstaller {

    enum Errors: Error {
        case unsupportedRestoreImage
        case invalidHardwareModel
        case unsupportedHardware
        case invalidMachineIdentifier
    }

    public typealias ProgressCallback = (Progress) -> Void

    private var installationObserver: NSKeyValueObservation?
    private let restoreImageUrl: URL
    private let bundle: VMBundle

    @MainActor
    public init(
        forBundle bundle: VMBundle,
        restoreImage: VZMacOSRestoreImage
    ) throws {

        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            throw Errors.unsupportedRestoreImage
        }

        guard macOSConfiguration.hardwareModel.isSupported else {
            throw Errors.unsupportedHardware
        }

        self.restoreImageUrl = restoreImage.url
        self.bundle = bundle
    }

    @MainActor
    public func install(progressCallback: @escaping ProgressCallback) async throws {
        let vmConfiguration = try self.bundle.virtualMachineConfiguration()
        try vmConfiguration.validate()

        let url = self.restoreImageUrl

        let virtualMachine = VZVirtualMachine(configuration: vmConfiguration)

        let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: url)

        // Observe installation progress
        installationObserver = installer.progress.observe(\.fractionCompleted, options: [.new]) { (progress, _) in
            progress.kind = .installation
            progressCallback(progress)
        }

        try await installer.install()

        installationObserver?.invalidate()

        try await virtualMachine.stop()
    }
}
