import Foundation
import ZIPFoundation

enum EPUBParserError: Error {
    case invalidArchive
    case missingContainer
    case missingOPF
    case parsingFailed
}

struct EPUBParser: Sendable {
    let unzippedURL: URL
    let opfURL: URL
    let spineItems: [URL]
    
    init(fileURL: URL) async throws {
        // Create a unique temporary directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Unzip the EPUB
        try FileManager.default.unzipItem(at: fileURL, to: tempDir)
        self.unzippedURL = tempDir
        
        // Find OPF from container.xml
        let containerURL = tempDir.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path),
              let containerData = try? Data(contentsOf: containerURL) else {
            throw EPUBParserError.missingContainer
        }
        
        // Naive XML parsing to find the OPF path
        guard let containerXML = String(data: containerData, encoding: .utf8),
              let fullPathRange = containerXML.range(of: "full-path=\""),
              let endQuoteRange = containerXML.range(of: "\"", range: fullPathRange.upperBound..<containerXML.endIndex) else {
            throw EPUBParserError.missingOPF
        }
        
        let opfPath = String(containerXML[fullPathRange.upperBound..<endQuoteRange.lowerBound])
        self.opfURL = tempDir.appendingPathComponent(opfPath)
        
        // Parse OPF to find Spine
        guard FileManager.default.fileExists(atPath: opfURL.path),
              let opfData = try? Data(contentsOf: opfURL),
              let opfXML = String(data: opfData, encoding: .utf8) else {
            throw EPUBParserError.parsingFailed
        }
        
        // Highly naive regex/string searching to match IDREF to HREFs
        // In a real app, use an XMLParser or Fuzi
        var manifest: [String: String] = [:]
        
        // Extract manifest items
        let itemPattern = "<item\\s+[^>]*id=\"([^\"]+)\"[^>]*href=\"([^\"]+)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: itemPattern, options: []) {
            let nsString = opfXML as NSString
            let matches = regex.matches(in: opfXML, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges == 3 {
                    let id = nsString.substring(with: match.range(at: 1))
                    let href = nsString.substring(with: match.range(at: 2))
                    manifest[id] = href
                }
            }
        }
        
        // Extract spine items
        var spine: [URL] = []
        let spinePattern = "<itemref\\s+[^>]*idref=\"([^\"]+)\"[^>]*/>"
        if let regex = try? NSRegularExpression(pattern: spinePattern, options: []) {
            let nsString = opfXML as NSString
            let matches = regex.matches(in: opfXML, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges == 2 {
                    let idref = nsString.substring(with: match.range(at: 1))
                    if let href = manifest[idref] {
                        let itemURL = opfURL.deletingLastPathComponent().appendingPathComponent(href)
                        spine.append(itemURL)
                    }
                }
            }
        }
        
        if spine.isEmpty {
            throw EPUBParserError.parsingFailed
        }
        
        self.spineItems = spine
    }
    
    func cleanup() {
        try? FileManager.default.removeItem(at: unzippedURL)
    }
}
