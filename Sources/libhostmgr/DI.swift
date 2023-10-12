import Foundation

public class DIContainer {

    private static let dependencies: [String: Any] = [
        "VMManager": AppleSiliconVMManager(),
        "RemoteVMLibrary": AppleSiliconVMLibrary()
    ]

    public static func resolve<Service>(_ type: Service.Type) -> Service {
        let serviceName = String(describing: type.self)

        guard let service = dependencies[serviceName] as? Service else {
            preconditionFailure("\(serviceName) is not registered")
        }

        return service
    }
}

@propertyWrapper
public struct DIInjected<Service> {

    var service: Service

    public init() {
        self.service = DIContainer.resolve(Service.self)
    }

    public var wrappedValue: Service {
        get { self.service }
        mutating set { service = newValue }
    }
}
