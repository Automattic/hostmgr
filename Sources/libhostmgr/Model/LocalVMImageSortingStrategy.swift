import Foundation

public enum LocalVMImageSortingStrategy {
    case name
    case size

    var sortMethod: (LocalVMImage, LocalVMImage) throws -> Bool {
        switch self {
        case .name: return sortByName
        case .size: return sortBySize
        }
    }

    func sortByName(_ lhs: LocalVMImage, _ rhs: LocalVMImage) -> Bool {
        lhs.name.compare(rhs.name, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
    }

    func sortBySize(_ lhs: LocalVMImage, _ rhs: LocalVMImage) throws -> Bool {
        try lhs.fileSize < rhs.fileSize
    }
}
