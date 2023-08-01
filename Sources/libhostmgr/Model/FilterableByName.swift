import Foundation

public protocol FilterableByName {
    var name: String { get }
}

extension Array where Element: FilterableByName {
    func filter(includingItemsIn array: [String]) -> [Element] {
        self.filter { array.contains($0.name) }
    }

    func filter(excludingItemsIn array: [String]) -> [Element] {
        self.filter { !array.contains($0.name) }
    }
}
