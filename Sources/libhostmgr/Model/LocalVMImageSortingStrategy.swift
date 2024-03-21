import Foundation

public enum LocalVMImageSortingStrategy {
    case name  // Sort by Name first, then by State
    case size  // Sort by Size
    case state // Sort by State first, then by Name

    var sortMethod: (LocalVMImage, LocalVMImage) throws -> Bool {
        switch self {
        case .name: return sortByName
        case .size: return sortBySize
        case .state: return sortByState
        }
    }

    // Sort by Name first, then by State if same Name
    func sortByName(_ lhs: LocalVMImage, _ rhs: LocalVMImage) -> Bool {
        switch nameCompare(lhs, rhs) {
        case .orderedDescending: false
        case .orderedSame: stateCompare(lhs, rhs) == .orderedAscending
        case .orderedAscending: true
        }
    }

    func sortBySize(_ lhs: LocalVMImage, _ rhs: LocalVMImage) throws -> Bool {
        try lhs.fileSize < rhs.fileSize
    }

    // Sort by State first, then by Name if same State
    func sortByState(_ lhs: LocalVMImage, _ rhs: LocalVMImage) -> Bool {
        switch stateCompare(lhs, rhs) {
        case .orderedDescending: false
        case .orderedSame: nameCompare(lhs, rhs) == .orderedAscending
        case .orderedAscending: true
        }
    }

    private func nameCompare(_ lhs: LocalVMImage, _ rhs: LocalVMImage) -> ComparisonResult {
        lhs.name.compare(rhs.name, options: [.diacriticInsensitive, .caseInsensitive])
    }

    private func stateCompare(_ lhs: LocalVMImage, _ rhs: LocalVMImage) -> ComparisonResult {
        let lhsOrder = VMImageState.allCases.firstIndex(of: lhs.state) ?? 0
        let rhsOrder = VMImageState.allCases.firstIndex(of: rhs.state) ?? 0
        return lhsOrder < rhsOrder ? .orderedDescending : lhsOrder == rhsOrder ? .orderedSame : .orderedAscending
    }

}
