import AppKit
import CoreGraphics
import CoreText
import Foundation
import UniformTypeIdentifiers

enum BabybelExportFormat {
    case word
    case pdf
    case plainText

    var fileExtension: String {
        switch self {
        case .word: "docx"
        case .pdf: "pdf"
        case .plainText: "txt"
        }
    }

    var contentType: UTType {
        switch self {
        case .word: UTType(filenameExtension: "docx") ?? .data
        case .pdf: .pdf
        case .plainText: .plainText
        }
    }

    var panelTitle: String {
        switch self {
        case .word: "Export Word Document"
        case .pdf: "Export PDF"
        case .plainText: "Export Plain Text"
        }
    }
}

enum BabybelDocumentExporter {
    static func export(text: String, format: BabybelExportFormat, suggestedName: String) throws {
        let panel = NSSavePanel()
        panel.title = format.panelTitle
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(suggestedName).\(format.fileExtension)"
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch format {
        case .word:
            try writeWordDocument(text, to: url)
        case .pdf:
            try writePDF(text, to: url)
        case .plainText:
            try Data(plainText(text).utf8).write(to: url, options: .atomic)
        }
    }

    private static func plainText(_ markdown: String) -> String {
        markdown.components(separatedBy: .newlines).map { line in
            if line.hasPrefix("### ") { return String(line.dropFirst(4)) }
            if line.hasPrefix("## ") { return String(line.dropFirst(3)) }
            if line.hasPrefix("# ") { return String(line.dropFirst(2)) }
            return line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "`", with: "")
        }.joined(separator: "\n")
    }

    private static func writePDF(_ markdown: String, to url: URL) throws {
        let text = plainText(markdown)
        let font = NSFont.systemFont(ofSize: 11)
        let attributedText = NSAttributedString(string: text, attributes: [.font: font])
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText as CFAttributedString)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var range = CFRange(location: 0, length: 0)
        let textLength = attributedText.length
        while range.location < textLength || textLength == 0 && range.location == 0 {
            context.beginPDFPage(nil)
            let pageRect = CGRect(x: 54, y: 54, width: 504, height: 684)
            let path = CGPath(rect: pageRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            context.endPDFPage()
            if visibleRange.length == 0 { break }
            range.location += visibleRange.length
        }
        context.closePDF()
    }

    private static func writeWordDocument(_ markdown: String, to url: URL) throws {
        let paragraphs = markdown.components(separatedBy: .newlines).map { line -> String in
            let style: String
            let contents: String
            if line.hasPrefix("### ") {
                style = "<w:pPr><w:pStyle w:val=\"Heading2\"/></w:pPr>"
                contents = String(line.dropFirst(4))
            } else if line.hasPrefix("## ") {
                style = "<w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr>"
                contents = String(line.dropFirst(3))
            } else if line.hasPrefix("# ") {
                style = "<w:pPr><w:pStyle w:val=\"Title\"/></w:pPr>"
                contents = String(line.dropFirst(2))
            } else {
                style = ""
                contents = line
            }
            let escaped = xmlEscape(contents)
            let run = escaped.isEmpty ? "" : "<w:r><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r>"
            return "<w:p>\(style)\(run)</w:p>"
        }.joined()

        let documentXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>\(paragraphs)<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>
        """
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>
        """
        let rootRelationships = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
        """
        let documentRelationships = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
        """
        let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style></w:styles>
        """

        let entries: [(String, Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRelationships.utf8)),
            ("word/document.xml", Data(documentXML.utf8)),
            ("word/_rels/document.xml.rels", Data(documentRelationships.utf8)),
            ("word/styles.xml", Data(styles.utf8))
        ]
        try makeStoredZip(entries).write(to: url, options: .atomic)
    }

    private static func xmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func makeStoredZip(_ entries: [(String, Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for (path, contents) in entries {
            let name = Data(path.utf8)
            let checksum = crc32(contents)
            let localOffset = UInt32(archive.count)

            archive.appendLE(UInt32(0x04034b50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(checksum)
            archive.appendLE(UInt32(contents.count))
            archive.appendLE(UInt32(contents.count))
            archive.appendLE(UInt16(name.count))
            archive.appendLE(UInt16(0))
            archive.append(name)
            archive.append(contents)

            centralDirectory.appendLE(UInt32(0x02014b50))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(checksum)
            centralDirectory.appendLE(UInt32(contents.count))
            centralDirectory.appendLE(UInt32(contents.count))
            centralDirectory.appendLE(UInt16(name.count))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt32(0))
            centralDirectory.appendLE(localOffset)
            centralDirectory.append(name)
        }

        let centralOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLE(UInt32(0x06054b50))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt32(centralDirectory.count))
        archive.appendLE(centralOffset)
        archive.appendLE(UInt16(0))
        return archive
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
            }
        }
        return crc ^ UInt32.max
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { self.append(contentsOf: $0) }
    }
}
