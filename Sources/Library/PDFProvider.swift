import SwiftUI

public class PDFProvider: ContentProvider {
    public let book: Book
    public let fileURL: URL
    
    public required init(book: Book, fileURL: URL) {
        self.book = book
        self.fileURL = fileURL
    }
    
    public func load() async throws {
        // PDFKit handles loading internally when the view is created, 
        // but we could perform pre-flight checks here if needed.
    }
    
    @MainActor
    public func renderView() -> AnyView {
        AnyView(PDFReaderView(book: book, url: fileURL))
    }
}
