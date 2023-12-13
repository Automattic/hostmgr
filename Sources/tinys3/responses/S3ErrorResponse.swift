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
        return try S3ErrorResponseParser(data: response.data).parse()
    }
}

class S3ErrorResponseParser: NSObject {
    private let parser: XMLParser

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    @discardableResult
    func parse() throws -> S3ErrorResponse {
        _ = self.parser.parse()

        if let error = self.parser.parserError ?? self.error {
            throw error
        }

        guard
            let code = self.code,
            let message = self.message,
            let requestId = self.requestId,
            let hostId = self.hostId
        else {
            throw InvalidDataError()
        }

        return S3ErrorResponse(
            code: code,
            message: message,
            requestId: requestId,
            hostId: hostId,
            extra: self.extra
        )
    }

    // MARK: Error Elements
    var code: String?
    var message: String?
    var hostId: String?
    var requestId: String?

    var extra: [String: String] = [:]
    var error: Error?

    var currentElement: ParserElement?
    var rootElementValidator = XMLDataValidator(expectedRootElementName: ParserElement.root.rawValue)
}

extension S3ErrorResponseParser: XMLParserDelegate {
    enum ParserElement: String {
        case root = "Error"
        case code = "Code"
        case message = "Message"
        case requestId = "RequestId"
        case hostID = "HostId"

        // Extras
        case endpoint = "Endpoint"
        case bucket = "Bucket"
        case key = "Key"
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        self.currentElement = ParserElement(rawValue: elementName)

        self.rootElementValidator.validate(elementName: elementName) { error in
            self.parser(parser, parseErrorOccurred: error)
        }
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred error: Error
    ) {
        self.error = error
        parser.abortParsing()
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        self.currentElement = nil // Without this, we'll store the whitespace beween elements
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch self.currentElement {
        case .code: self.code = string
        case .message: self.message = string
        case .requestId: self.requestId = string
        case .hostID: self.hostId = string
        default:
            if let element = self.currentElement {
                self.extra[element.rawValue] = string
            }
        }
    }
}
