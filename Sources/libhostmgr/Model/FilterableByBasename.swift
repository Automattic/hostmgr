import Foundation
import prlctl

public protocol FilterableByBasename {
    var basename: String { get }
}

extension Array where Element: FilterableByBasename {
    func filter(includingItemsIn array: [String]) -> [Element] {
        self.filter { array.contains($0.basename) }
    }

    func filter(excludingItemsIn array: [String]) -> [Element] {
        self.filter { !array.contains($0.basename) }
    }
}

extension VM: FilterableByBasename {
    public var basename: String {
        self.name
    }
}
