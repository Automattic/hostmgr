import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

struct S3CreateMultipartUploadResponse {

    let bucket: String
    let key: String
    let uploadId: String

    static func from(response: AWSResponse) throws -> S3CreateMultipartUploadResponse {
        return try S3CreateMultipartUploadResponseParser(data: response.data).parse()
    }
}

class S3CreateMultipartUploadResponseParser: NSObject {
    private let parser: XMLParser

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    @discardableResult
    func parse() throws -> S3CreateMultipartUploadResponse {
        _ = self.parser.parse()

        if let error = self.parser.parserError {
            throw error
        }

        guard
            let bucket = self.bucket,
            let key = self.key,
            let uploadId = self.uploadId
        else {
            throw InvalidDataError()
        }

        return S3CreateMultipartUploadResponse(
            bucket: bucket,
            key: key,
            uploadId: uploadId
        )
    }

    // MARK: Error Elements
    var bucket: String?
    var key: String?
    var uploadId: String?

    var error: Error?

    var currentElement: ParserElement?
    var rootElementValidator = XMLDataValidator(expectedRootElementName: ParserElement.root.rawValue)
}

extension S3CreateMultipartUploadResponseParser: XMLParserDelegate {
    enum ParserElement: String {
        case root = "InitiateMultipartUploadResult"
        case bucket = "Bucket"
        case key = "Key"
        case uploadId = "UploadId"
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
        guard let currentElement = self.currentElement else {
            return
        }

        switch currentElement {
        case .bucket: self.bucket = string
        case .key: self.key = string
        case .uploadId: self.uploadId = string
        case .root: break
        }
    }
}
