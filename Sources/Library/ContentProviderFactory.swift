import Foundation

enum ContentProviderError: Error {
    case unsupportedFormat(String)
    case fileNotFound
}

struct ContentProviderFactory {
    @MainActor
    static func provider(for book: Book) throws -> ContentProvider {
        guard let url = LibraryStore.getURL(for: book) else {
            throw ContentProviderError.fileNotFound
        }
        
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return PDFProvider(book: book, fileURL: url)
        case "epub":
            return EPUBProvider(book: book, fileURL: url)
        default:
            throw ContentProviderError.unsupportedFormat(ext)
        }
    }
}
