import Foundation

public enum LocalVMImageSortingStrategy {
    case name
    case size

    var sortMethod: (any LocalVMImage, any LocalVMImage) throws -> Bool {
        switch self {
        case .name: return sortByName
        case .size: return sortBySize
        }
    }

    func sortByName(_ lhs: any LocalVMImage, _ rhs: any LocalVMImage) -> Bool {
        lhs.name.compare(rhs.name, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
    }

    func sortBySize(_ lhs: any LocalVMImage, _ rhs: any LocalVMImage) throws -> Bool {
        try lhs.fileSize < rhs.fileSize
    }
}
