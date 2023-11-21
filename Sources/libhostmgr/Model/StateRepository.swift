import Foundation

public protocol StateRepository {
    func read<T: Codable>(fromKey key: String) throws -> T?
    func write<T: Codable>(_ object: T, toKey key: String) throws
    func delete(key: String) throws
    func deleteAll() throws
}

struct FileStateRepository: StateRepository {

    let stateStorageDirectory: URL

    init(stateStorageDirectory: URL = Paths.stateRoot) {
        self.stateStorageDirectory = stateStorageDirectory
    }

    public func read<T: Codable>(fromKey key: String) throws -> T? {
        let destination = stateStorageDirectory.appendingPathComponent(key)

        guard
            try FileManager.default.directoryExists(at: stateStorageDirectory),
            FileManager.default.fileExists(at: destination)
        else {
            return nil
        }

        let data = try Data(contentsOf: destination)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func write<T: Codable>(_ object: T, toKey key: String) throws {
        try FileManager.default.createDirectory(at: stateStorageDirectory, withIntermediateDirectories: true)
        let destination = stateStorageDirectory.appendingPathComponent(key)

        let data = try JSONEncoder().encode(object)

        if FileManager.default.fileExists(at: destination) {
            try data.write(to: destination)
        } else {
            try FileManager.default.createFile(at: destination, contents: data)
        }
    }

    public func delete(key: String) throws {
        let destination = stateStorageDirectory.appendingPathComponent(key)

        guard FileManager.default.fileExists(at: destination) else {
            return
        }

        try FileManager.default.removeItem(at: destination)
    }

    public func deleteAll() throws {
        guard try FileManager.default.directoryExists(at: stateStorageDirectory) else {
            return
        }

        try FileManager.default.removeItem(at: stateStorageDirectory)
    }
}
