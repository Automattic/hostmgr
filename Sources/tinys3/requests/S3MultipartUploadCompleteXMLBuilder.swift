import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

protocol XMLDocumentBuilder {
    func build(options: XMLEncodingOptions) -> String
    func build(options: XMLEncodingOptions) -> Data
}

struct XMLEncodingOptions: OptionSet {
    let rawValue: Int

    static let prettyPrinted    = XMLEncodingOptions(rawValue: 1 << 0)
    static let encoded          = XMLEncodingOptions(rawValue: 1 << 1)
}

struct S3MultipartUploadCompleteXMLBuilder: XMLDocumentBuilder {

    private let document: XMLDocument
    private let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

    init() {
        let rootElement = XMLElement(name: "CompleteMultipartUpload")
        rootElement.setAttributesWith(["xmlns": "http://s3.amazonaws.com/doc/2006-03-01/"])

        self.document = XMLDocument(rootElement: rootElement)
    }

    init(document: XMLDocument) {
        self.document = document
    }

    @discardableResult
    func addPart(_ part: MultipartUploadOperation.AWSUploadedPart) -> Self {
        let partNode = XMLElement(name: "Part")
        partNode.addChild(XMLElement(name: "PartNumber", stringValue: String(part.number)))
        partNode.addChild(XMLElement(name: "ETag", stringValue: part.eTag))
        document.rootElement()?.addChild(partNode)

        return self
    }

    @discardableResult
    func addParts(_ parts: [MultipartUploadOperation.AWSUploadedPart]) -> Self {
        for part in parts {
            addPart(part)
        }

        return self
    }

    func build(options: XMLEncodingOptions = []) -> String {
        let xmlOptions = options.contains(.prettyPrinted) ? XMLElement.Options.nodePrettyPrint : []
        let originalString = document.xmlString(options: xmlOptions).trimmingCharacters(in: .whitespacesAndNewlines)

        guard options.contains(.encoded) else {
            return originalString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return originalString
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func build(options: XMLEncodingOptions = []) -> Data {
        let xmlOptions = options.contains(.prettyPrinted) ? XMLElement.Options.nodePrettyPrint : []
        return document.xmlData(options: xmlOptions)
    }
}
