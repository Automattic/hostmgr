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

        guard let root = doc.rootElement(), root.name == "Error" else {
            throw InvalidDataError()
        }

        guard
            let code = root.elements(forName: "Code").first?.stringValue,
            let message = root.elements(forName: "Message").first?.stringValue,
            let requestId = root.elements(forName: "RequestId").first?.stringValue,
            let hostId = root.elements(forName: "HostId").first?.stringValue
        else {
            throw InvalidDataError()
        }

        var extra = [String: String]()
        extra["Endpoint"] = root.elements(forName: "Endpoint").first?.stringValue
        extra["Bucket"] = root.elements(forName: "Bucket").first?.stringValue
        extra["Key"] = root.elements(forName: "Key").first?.stringValue

        return S3ErrorResponse(
            code: code,
            message: message,
            requestId: requestId,
            hostId: hostId,
            extra: extra
        )
    }
}
