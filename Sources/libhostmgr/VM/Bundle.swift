import Foundation

protocol Bundle {
    var root: URL { get }

    var configurationFilePath: URL { get }

    var auxImageFilePath: URL { get }

    var diskImageFilePath: URL { get }
}

extension Bundle {
    var configurationFilePath: URL {
        root.appendingPathComponent("config.json")
    }

    var diskImageFilePath: URL {
        root.appendingPathComponent("image.img")
    }

    var auxImageFilePath: URL {
        root.appendingPathComponent("aux.img")
    }

    static func configurationFilePath(for url: URL) -> URL {
        url.appendingPathComponent("config.json")
    }
}

protocol TemplateBundle: Bundle {
    var manifestFilePath: URL { get }
}

extension TemplateBundle {
    var manifestFilePath: URL {
        root.appendingPathComponent("manifest.json")
    }
}
