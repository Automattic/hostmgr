import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AWSResponse {
    let response: HTTPURLResponse
    let data: Data

    enum AWSResponseError: LocalizedError {

        case invalidResponse
        case invalidData(code: Int)
        case httpError(code: Int)
        case awsError(code: Int, error: S3ErrorResponse)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return nil
            case .invalidData(let code):
                return HTTPURLResponse.localizedString(forStatusCode: code)
            case .httpError(let code):
                return HTTPURLResponse.localizedString(forStatusCode: code)
            case .awsError(_, let error):
                return error.message + "\n" + error.extra.map { "\($0.key):\($0.value)" }.joined(separator: "\n")
            }
        }
    }

    init(response: HTTPURLResponse?, data: Data?) throws {

        guard let response = response else {
            throw AWSResponseError.invalidResponse
        }

        guard let data = data else {
            throw AWSResponseError.invalidData(code: response.statusCode)
        }

        self.response = response
        self.data = data
    }

    @discardableResult
    func validate() throws -> AWSResponse {
        if wasSuccessful {
            return self
        }

        if data.isEmpty {
            throw AWSResponseError.httpError(code: self.response.statusCode)
        }

        let errorResponse = try S3ErrorResponse.from(response: self)
        let error = AWSResponseError.awsError(code: self.response.statusCode, error: errorResponse)
        throw error
    }

    var headers: HttpHeaders {
        HttpHeaders(from: self.response)
    }

    func value(forHTTPHeaderField key: HttpHeaders.HeaderType) -> String? {
        headers[key]
    }

    var wasSuccessful: Bool {
        return (200...299).contains(self.response.statusCode)
    }
}
