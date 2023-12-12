import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

public struct S3ListResponse {

    public let bucketName: String
    public let prefix: String?
    public let marker: String?
    public let maxKeys: Int
    public let isTruncated: Bool
    public let objects: [S3Object]

    static func from(response: AWSResponse) throws -> S3ListResponse {
        try S3ListResponseParser(data: response.data).parse()
    }
}

class S3ListResponseParser: NSObject {

    private let parser: XMLParser

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()

        self.parser.delegate = self
    }

    @discardableResult
    func parse() throws -> S3ListResponse {
        _ = self.parser.parse()

        if let error = self.parser.parserError ?? self.error {
            throw error
        }

        guard
            let bucketName = self.name,
            let maxKeys = self.maxKeys,
            let isTruncated = self.truncated
        else {
            throw InvalidDataError()
        }

        return S3ListResponse(
            bucketName: bucketName,
            prefix: self.prefix,
            marker: self.marker,
            maxKeys: maxKeys,
            isTruncated: isTruncated,
            objects: self.objects
        )
    }

    // MARK: Header Elements
    var name: String?
    var prefix: String?
    var maxKeys: Int?
    var truncated: Bool?
    var marker: String?

    // MARK: Contents Elements
    var key: String?
    var lastModified: Date?
    var eTag: String?
    var size: Int?
    var storageClass: String?

    var currentElement: ParserElement?

    var objects: [S3Object] = []

    var rootElementValidator = XMLDataValidator(expectedRootElementName: ParserElement.root.rawValue)
    var error: Error?
}

extension S3ListResponseParser: XMLParserDelegate {

    enum ParserElement: String {
        case root = "ListBucketResult"
        case contents = "Contents"
        case name = "Name"
        case prefix = "Prefix"
        case maxKeys = "MaxKeys"
        case truncated = "IsTruncated"
        case marker = "Marker"
        case key = "Key"
        case lastModified = "LastModified"
        case eTag = "ETag"
        case size = "Size"
        case storageClass = "StorageClass"
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
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard
            let element = ParserElement(rawValue: elementName),
            element == .contents, // We only need to finalize the `Contents` element

            let key = self.key,
            let size = self.size,
            let eTag = self.eTag,
            let lastModified = self.lastModified,
            let storageClass = self.storageClass

        else {
            self.currentElement = nil // Without this, we'll store whitespace beween elements
            return
        }

        self.objects.append(S3Object(
            key: key,
            size: size,
            eTag: eTag,
            lastModifiedAt: lastModified,
            storageClass: storageClass
        ))

        // Reset all values before we start parsing the next object
        self.key = nil
        self.lastModified = nil
        self.eTag = nil
        self.size = nil
        self.storageClass = nil
    }

    // swiftlint:disable cyclomatic_complexity
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch self.currentElement {
        case .name: self.name = string
        case .prefix: self.prefix = string
        case .maxKeys: self.maxKeys = Int(string)
        case .truncated: self.truncated = Bool(string)
        case .marker: self.marker = string
        case .key: self.key = string
        case .lastModified: self.lastModified = parseISO8601String(string)
        case .eTag: self.eTag = string
        case .size: self.size = Int(string)
        case .storageClass: self.storageClass = string
        default: break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        self.error = error
        parser.abortParsing()
    }
}
