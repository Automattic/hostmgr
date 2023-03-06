import Foundation

public struct LocalVMImage: Equatable, Hashable, FilterableByBasename {

    public enum VMImageState: String {
        case compressed
        case packaged
        case ready
    }

    struct VMExtension: Equatable {

        static let validVMExtensions = [
            VMExtension(name: "pvm", state: .ready, architecture: .x64),
            VMExtension(name: "pvmp", state: .packaged, architecture: .x64),
            VMExtension(name: "aar", state: .compressed, architecture: .x64),

            VMExtension(name: "bundle", state: .ready, architecture: .arm64),
            VMExtension(name: "vmtemplate", state: .packaged, architecture: .arm64),
            VMExtension(name: "aar", state: .compressed, architecture: .arm64)
        ]

        let name: String
        let state: VMImageState
        let architecture: ProcessorArchitecture

        init?(path: URL) {
            guard let newSelf = Self.validVMExtensions.first(where: {
                if $0.name == "aar" {
                    if path.lastPathComponent.contains(".pvmp.aar") {
                        return $0.architecture == .x64
                    }

                    if path.lastPathComponent.contains(".vmpackage.aar") {
                        return $0.architecture == .arm64
                    }

                    return false
                }

                return $0.name == path.pathExtension
            }) else {
                return nil
            }

            self = newSelf
        }

        init(name: String, state: VMImageState, architecture: ProcessorArchitecture) {
            self.name = name
            self.state = state
            self.architecture = architecture
        }
    }

    public let path: URL
    let vmExtension: VMExtension

    init?(path: URL) {
        /// Validate that the path is a valid VM image, otherwise return nil
        guard let vmExtension = VMExtension(path: path) else {
            return nil
        }

        self.path = path
        self.vmExtension = vmExtension
    }

    public var filename: String {
        path.lastPathComponent
    }

    public var basename: String {
        if architecture == .arm64 {
            return path
                .deletingPathExtension()
                .lastPathComponent
                .replacingOccurrences(of: ".vmpackage", with: "")
        } else {
            return path
                .deletingPathExtension()
                .lastPathComponent
        }
    }

    var fileExtension: String {
        path.pathExtension
    }

    public var architecture: ProcessorArchitecture {
        vmExtension.architecture
    }

    public var state: VMImageState {
        vmExtension.state
    }

    public var fileSize: Int {
        get throws {
            try FileManager.default.size(ofObjectAt: path)
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.path)
    }
}
