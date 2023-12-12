import Foundation

enum S3Error: Error {
    case unknownHttpError
    case fileNotFound(String, String)
}
