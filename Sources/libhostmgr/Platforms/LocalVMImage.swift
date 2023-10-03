import Foundation

public protocol LocalVMImage: Equatable, FilterableByName {
    var state: VMImageState { get }
    var path: URL { get }
    var name: String { get }
    var fileSize: Int { get throws }

    init?(path: URL)

    static var validVMExtensions: [String] { get }
}

public enum VMImageState {
    case packaged
    case ready
}
