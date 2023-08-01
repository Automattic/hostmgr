import Foundation
import prlctl

public class DIContainer {

    #if arch(arm64)
    private static var dependencies: [String: Any] = [
        "VMManager": AppleSiliconVMManager(),
        "RemoteVMLibrary": AppleSiliconVMLibrary()
    ]
    #else
    private static let parallels = Parallels()
    private static var dependencies: [String: Any] = [
        "VMManager": ParallelsVMManager(parallels: parallels),
        "Parallels": parallels,
        "RemoteVMLibrary": ParallelsRemoteVMRepository()
    ]
    #endif

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
