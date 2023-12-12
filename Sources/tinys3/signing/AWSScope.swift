import Foundation

struct AWSScope: CustomStringConvertible {
    let date: Date
    let region: String
    let service: String
    let requestType: String

    init(region: String, date: Date = Date(), service: String = "s3", requestType: String = "aws4_request") {
        self.date = date
        self.region = region
        self.service = service
        self.requestType = requestType
    }

    var description: String {
        [
            formattedDatestamp(from: self.date),
            self.region,
            self.service,
            self.requestType
        ].joined(separator: "/")
    }
}
