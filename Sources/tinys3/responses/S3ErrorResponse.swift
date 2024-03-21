import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

struct S3ErrorResponse: Error {

    let code: String
    let message: String

    let requestId: String
    let hostId: String

    let extra: [String: String]

    static func from(response: AWSResponse) throws -> S3ErrorResponse {
        let doc = try XMLDocument(data: response.data)
        let root = try doc.rootElement(expectedName: "Error")

        let extra = ["Endpoint", "Bucket", "Key"].reduce(into: [:]) { dict, key in
            dict[key] = try? root.value(forElementName: key)
        }

        return S3ErrorResponse(
            code: try root.value(forElementName: "Code"),
            message: try root.value(forElementName: "Message"),
            requestId: try root.value(forElementName: "RequestId"),
            hostId: try root.value(forElementName: "HostId"),
            extra: extra
        )
    }
}
