import Foundation

protocol RequestPerformer {
    var urlSession: URLSession { get }
}

extension RequestPerformer {
    func perform(_ request: AWSRequest) async throws -> AWSResponse {
        let (data, response) = try await perform(request.urlRequest)
        return try AWSResponse(response: response, data: data).validate()
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.urlSession.dataTask(with: request) { data, response, networkError in
                if let error = networkError {
                    continuation.resume(throwing: error)
                    return
                }

                if let data = data, let response = response as? HTTPURLResponse {
                    continuation.resume(with: .success((data, response)))
                    return
                }

                if let response = response as? HTTPURLResponse {
                    continuation.resume(with: .success((Data(), response)))
                    return
                }

                continuation.resume(throwing: S3Error.unknownHttpError)
            }

            task.resume()
        }
    }
}
